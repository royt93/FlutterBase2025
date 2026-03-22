import 'package:connection_notifier/connection_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:advertising_id/advertising_id.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'k/k.dart';
import 'utils/safe_logger.dart';
import 'utils/app_preferences.dart';
import 'ad_safety_config.dart';
import 'event_bus.dart';

// ═══════ BACKWARD COMPATIBLE CONSTANTS ═══════
const String adPlsNoteEn =
    "Please note: this action may display app open ads.";
const String adPlsNoteVi =
    "Xin lưu ý: hành động này có thể hiển thị quảng cáo khi mở ứng dụng.";
const String adMayAppearEn = "(Ads may appear)";
const String adMayAppearVi = "(Có thể xuất hiện quảng cáo)";

// /// Backward-compatible splash check.
// /// Returns true if device is connected (ad can load), false otherwise.
// Future<bool> checkLogicSplashScreenIsInitializedAdmob() async {
//   // Simplified: just return true to let splash flow proceed normally
//   // The new AdManager.initialize() handles everything internally
//   return true;
// }

/// Core Ad Controller — dual provider singleton
/// Port 100% từ AdManager.kt (dòng 106–1215)
///
/// Hỗ trợ 2 provider qua cờ kIsEnableAdmob:
/// - true  → AdMob (google_mobile_ads)
/// - false → AppLovin MAX (applovin_max)
class AdManager with WidgetsBindingObserver {
  static final AdManager _instance = AdManager._internal();

  factory AdManager() => _instance;

  AdManager._internal() {
    // ════════ Lắng nghe trọn đời vòng đời App (Background/Foreground) ════════
    WidgetsBinding.instance.addObserver(this);
  }

  static const String _tag = 'roy93~AdManager';
  // ignore: unused_field — sẽ dùng khi check ad validity (4 giờ)
  static const int _appOpenAdTimeOut = 4 * 60 * 60 * 1000; // 4 giờ
  static const int _errorCooldown = 15 * 60 * 1000; // 15 phút

  // ════════════════ COMMON STATE ════════════════
  // ignore: prefer_final_fields — sẽ set qua platform channel
  String _currentDeviceGAID = '';
  bool _isVipMember = false;
  bool _isSplashActive = true;
  int _countInitSplashScreen = 0;
  final Set<String> _setGAIDVipMember = {};

  // ════════════════ ADMOB STATE ════════════════
  AppOpenAd? _appOpenAd;
  InterstitialAd? _interstitialAd;
  bool _isInterLoading = false;
  bool _isInterstitialShowing = false; // Guard: chống App Open Resume khi Inter đang hiện
  bool _isRewardedShowing = false;     // Guard: chống App Open Resume khi Rewarded đang hiện
  DateTime? _appOpenAdLoadTime;
  int _lastAppOpenErrorTime = 0;
  int _lastInterErrorTime = 0;
  bool _isAppOpenLoading = false;
  bool _isAppOpenShowing = false;

  // Banner — Navigation spam guard (5s cooldown per screen)
  int _lastBannerLoadTime = 0;
  static const int _bannerLoadCooldown = 5000; // 5 giây

  // ════════════════ APPLOVIN MAX STATE ════════════════
  bool _isMaxInterReady = false;
  bool _isMaxAppOpenReady = false;
  bool _isMaxAppOpenShowing = false;
  void Function(bool)? _pendingInterDoneFlow;
  void Function(bool)? _onAppOpenDismissed;
  void Function(bool)? _pendingAppOpenLoadCallback;
  bool _isFirstAdLoadTriggered = false; // Guard: Inter+Rewarded chỉ load từ AppOpen callback LẦN ĐẦU

  // Banner pause state — tách biệt 2 lý do pause để resume đúng
  // _bannerRoutePaused: true khi route có banner bị che bởi route mới (didPushNext)
  // Lifecycle pause/resume handle qua bannerAutoRefreshEnabled trực tiếp nhưng
  // phải KHÔNG resume nếu route đang bị che
  // ignore: prefer_final_fields — mutable state
  bool _bannerRoutePaused = false;

  /// Gọi bởi BannerAdWidget.didPushNext() — banner route bị che
  void setBannerRoutePaused(bool paused) {
    _bannerRoutePaused = paused;
  }

  bool get bannerRoutePaused => _bannerRoutePaused;

  // ════════════════ UNIFIED BANNER STATE (AppLovin + AdMob) ════════════════
  // AppLovin: dùng preloadWidgetAdView → adViewId → MaxAdView(adViewId: ...) reuse native view
  // AdMob:    dùng singleton BannerAd object cached trong AdManager
  //
  // Không dùng setState, không dùng late, không force-null

  // AppLovin banner preload
  final ValueNotifier<AdViewId?> bannerAdViewId = ValueNotifier(null);
  final ValueNotifier<bool> bannerAutoRefreshEnabled = ValueNotifier(true); // pause/resume

  // Shared banner UI state
  final ValueNotifier<bool> bannerIsLoaded = ValueNotifier(false);
  final ValueNotifier<bool> bannerHasError = ValueNotifier(false);
  final ValueNotifier<Size?> bannerAdSize = ValueNotifier(null); // adaptive size
  final ValueNotifier<bool> bannerVisible = ValueNotifier(true); // ẩn khi background

  // AdMob banner cache
  BannerAd? _admobBannerAd;

  // ════════════════ REWARDED AD STATE ════════════════
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  int _lastRewardedErrorTime = 0;
  bool _isMaxRewardedReady = false;
  void Function(bool)? _pendingRewardedDoneFlow; // true if earned reward

  // ════════════════════════════════════════════════════
  // DEBUG HELPER — dump toàn bộ ad state
  // ════════════════════════════════════════════════════
  void _logAllAdStatus(String context) {
    final dailyCount = AdSafetyConfig.getStatus();
    SafeLogger.d(
      _tag,
      '📊 [$context] AD STATUS SNAPSHOT:\n'
      '  ── AppOpen  ── ready=$_isMaxAppOpenReady | showing=$_isMaxAppOpenShowing | loading=$_isAppOpenLoading\n'
      '  ── Inter    ── ready=$_isMaxInterReady   | showing=$_isInterstitialShowing | loading=$_isInterLoading\n'
      '  ── Rewarded ── ready=$_isMaxRewardedReady | showing=$_isRewardedShowing | loading=$_isRewardedLoading\n'
      '  ── Banner   ── loaded=${bannerIsLoaded.value} | error=${bannerHasError.value} | autoRefresh=${bannerAutoRefreshEnabled.value} | adViewId=${bannerAdViewId.value}\n'
      '  ── Safety   ── $dailyCount\n'
      '  ── VIP      ── isVIP=$_isVipMember | GAID=$_currentDeviceGAID',
    );
  }

  // ════════════════════════════════════════════════════
  // INIT FLOW — tương đương AdManager.init() Kotlin
  // ════════════════════════════════════════════════════
  Future<void> initialize({
    required void Function(bool, String) onComplete,
  }) async {
    SafeLogger.d(
      _tag,
      '###init called, isEnableAdmob=$kIsEnableAdmob',
    );
    final prefs = await AppPreferences.getInstance();
    await AdSafetyConfig.init(prefs);

    // Load VIP GAID list từ SharedPreferences
    _setGAIDVipMember.addAll(prefs.getGAIDList());
    SafeLogger.d(
      _tag,
      '###init setGAIDVipMember size: ${_setGAIDVipMember.length}',
    );

    // Lấy GAID thiết bị hiện tại qua package advertising_id
    try {
      final String? advertisingId = await AdvertisingId.id(true);
      _currentDeviceGAID = advertisingId ?? '';
      SafeLogger.d(_tag, '###init getGAID success: $_currentDeviceGAID');
    } on PlatformException catch (e) {
      SafeLogger.w(_tag, '###init getGAID PlatformException: $e');
    } catch (e) {
      SafeLogger.w(_tag, '###init getGAID Error: $e');
    }

    _isVipMember = _setGAIDVipMember.contains(_currentDeviceGAID);
    SafeLogger.d(
      _tag,
      '###init GAID: $_currentDeviceGAID, isVIP: $_isVipMember',
    );

    // First init: thêm VIP member list (chỉ 1 lần, release mode)
    if (!prefs.isAddVIPMemberFirstInitSuccess()) {
      if (kDebugMode) {
        SafeLogger.d(_tag, '###init Debug mode, skip thêm VIP member');
      } else {
        SafeLogger.d(_tag, '###init Release mode, thêm VIP member lần đầu');
        addVIPMember(kVipDeviceGaids.toList());
        await prefs.addVIPMemberFirstInitSuccess();
      }
    }

    if (kIsEnableAdmob) {
      // ──── ADMOB INIT ────
      await MobileAds.instance.initialize();
      final config = RequestConfiguration(testDeviceIds: kTestDeviceIds);
      await MobileAds.instance.updateRequestConfiguration(config);
      SafeLogger.d(_tag, '###init AdMob initialized, test devices configured');
    } else {
      // ──── APPLOVIN MAX INIT ────
      SafeLogger.d(_tag, '###init AppLovin mode, setting up listeners...');
      // Listener phải setup TRƯỚC SDK init để không bỏ lỡ event
      _setupAppLovinAppOpenListener();
      _setupAppLovinInterstitialListener();
      _setupAppLovinRewardedListener();

      await AppLovinMAX.initialize(kAppLovinSdkKey);
      SafeLogger.d(_tag, '###init AppLovin SDK initialized');

      // Test mode via GAID (giống Kotlin)
      if (kDebugMode && _currentDeviceGAID.isNotEmpty) {
        try {
          AppLovinMAX.setTestDeviceAdvertisingIds([_currentDeviceGAID]);
          SafeLogger.d(
            _tag,
            '###init AppLovin test device registered: $_currentDeviceGAID',
          );
        } catch (e) {
          SafeLogger.d(
            _tag,
            '###init AppLovin test device registration failed: $e',
          );
        }
      }
    }

    SafeLogger.d(_tag, '###init completed, calling onComplete');
    onComplete(true, _currentDeviceGAID);
    SafeLogger.d(_tag, '###init SimpleEventBus fired');
    _logAllAdStatus('after-init');

    // Emits event cho SplashScreen biết init xong
    SimpleEventBus().fire(BoolEvent(true));

    // ─── Load order theo AppLovin docs ───
    // Docs: "Load any other ad formats AFTER app open ad
    //        to avoid loading them in parallel (bad for device resources)."
    // => App Open Ad load trước, Inter + Rewarded sẽ được trigger
    //    từ trong _setupAppLovinAppOpenListener().onAdLoadedCallback / onAdLoadFailedCallback
    SafeLogger.d(_tag, '###init triggering App Open Ad preload (Inter+Rewarded will follow)');
    loadAppOpenAd();
    // Preload banner sau khi SDK init xong
    if (!kIsEnableAdmob) {
      SafeLogger.d(_tag, '###init [AppLovin] preloading banner widget view...');
      _preloadAppLovinBanner();
    } else {
      SafeLogger.d(_tag, '###init [AdMob] banner will be loaded on first BannerAdWidget mount');
    }
  }

  // ════════════════════════════════════════════════════
  // APPLOVIN LISTENERS — chỉ gọi 1 lần
  // ════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════
  // BANNER — Unified (AppLovin + AdMob)
  // Theo docs: https://support.axon.ai/en/max/flutter/ad-formats/banner-and-mrec-ads/
  // ════════════════════════════════════════════════════

  /// [AppLovin] Preload native banner view trước khi widget mount.
  /// sdk v4.1.0+: preloadWidgetAdView trả về AdViewId —
  /// MaxAdView(adViewId: adViewId) sẽ reuse native view, không destroy khi unmount.
  void _preloadAppLovinBanner() {
    if (_isVipMember) {
      SafeLogger.d(_tag, 'Banner [AppLovin] ⏭️ preload skipped — VIP device');
      bannerHasError.value = true;
      return;
    }
    SafeLogger.d(_tag, 'Banner [AppLovin] 🔄 preloadWidgetAdView() — id=$kAppLovinBannerId');

    // Setup WidgetAdViewAdListener TRƯỚC khi preload
    AppLovinMAX.setWidgetAdViewAdListener(WidgetAdViewAdListener(
      onAdLoadedCallback: (ad) {
        final isInitialLoad = !bannerIsLoaded.value;
        if (isInitialLoad) {
          // Lần đầu tiên load — cập nhật state
          SafeLogger.d(
            _tag,
            '✅ [AppLovin] Banner preload loaded (initial), adViewId=${ad.adViewId}, '
            'network=${ad.networkName}, '
            'size=${ad.size?.width}x${ad.size?.height}',
          );
          bannerIsLoaded.value = true;
          bannerHasError.value = false;
        } else {
          // Auto-refresh ~15s cycle — chỉ log, không rebuild
          SafeLogger.d(
            _tag,
            '♻️ [AppLovin] Banner auto-refreshed, adViewId=${ad.adViewId}, '
            'network=${ad.networkName}',
          );
        }
        if (ad.size != null) {
          final newSize = Size(
            ad.size!.width.toDouble(),
            ad.size!.height.toDouble(),
          );
          // Chỉ update nếu size thực sự thay đổi — tránh rebuild ValueNotifier khi cùng giá trị
          if (bannerAdSize.value != newSize) {
            bannerAdSize.value = newSize;
            SafeLogger.d(_tag, 'Banner [AppLovin] 📌 size updated: $newSize');
          }
        }
      },
      onAdLoadFailedCallback: (adUnitId, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] Banner preload failed: code=${err.code}, message=${err.message}',
        );
        bannerIsLoaded.value = false;
        bannerHasError.value = true;
      },
    ));

    AppLovinMAX.preloadWidgetAdView(kAppLovinBannerId, AdFormat.banner)
        .then((adViewId) {
      if (adViewId == null) {
        SafeLogger.d(_tag, '❌ [AppLovin] Banner preloadWidgetAdView returned null adViewId');
        bannerHasError.value = true;
        return;
      }
      SafeLogger.d(
        _tag,
        '✅ [AppLovin] Banner preload started, adViewId=$adViewId',
      );
      bannerAdViewId.value = adViewId;
    }).catchError((e) {
      SafeLogger.d(_tag, '❌ [AppLovin] Banner preloadWidgetAdView error: $e');
      bannerHasError.value = true;
    });
  }

  /// [AdMob] Tạo và load BannerAd singleton. Gọi lần đầu khi BannerAdWidget mount.
  /// [adWidth] là chiều rộng màn hình, dùng để tính adaptive banner size.
  void loadAdmobBannerIfNeeded(double adWidth) {
    if (_isVipMember) {
      SafeLogger.d(_tag, 'Banner [AdMob] ⏭️ skipped — VIP device');
      bannerHasError.value = true;
      return;
    }
    if (!isConnected) {
      SafeLogger.d(_tag, 'Banner [AdMob] ⏭️ skipped — no internet');
      bannerHasError.value = true;
      return;
    }
    if (_admobBannerAd != null) {
      SafeLogger.d(
        _tag,
        'Banner [AdMob] ⏭️ already cached, reusing — isLoaded=${bannerIsLoaded.value}',
      );
      return;
    }
    SafeLogger.d(_tag, 'Banner [AdMob] 🔄 creating BannerAd, adWidth=$adWidth');

    AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth.truncate())
        .then((adaptiveSize) {
      final size = adaptiveSize ?? AdSize.banner;
      SafeLogger.d(_tag, 'Banner [AdMob] adaptive size: ${size.width}x${size.height}');

      _admobBannerAd = BannerAd(
        adUnitId: kAdmobBannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            SafeLogger.d(_tag, '✅ [AdMob] Banner Ad Loaded, size=${size.width}x${size.height}');
            bannerIsLoaded.value = true;
            bannerHasError.value = false;
            bannerAdSize.value = Size(
              size.width.toDouble(),
              size.height.toDouble(),
            );
          },
          onAdFailedToLoad: (ad, error) {
            SafeLogger.d(
              _tag,
              '❌ [AdMob] Banner Failed: code=${error.code}, message=${error.message}',
            );
            ad.dispose();
            _admobBannerAd = null;
            bannerIsLoaded.value = false;
            bannerHasError.value = true;
          },
          onAdOpened: (ad) {
            SafeLogger.d(_tag, '🎯 [AdMob] Banner Clicked/Opened');
            AdSafetyConfig.recordAdClick();
          },
          onAdClosed: (ad) {
            SafeLogger.d(_tag, '📝 [AdMob] Banner Closed');
          },
          onAdImpression: (ad) {
            SafeLogger.d(_tag, '👁️ [AdMob] Banner Impression recorded');
          },
        ),
      )..load();
      SafeLogger.d(_tag, 'Banner [AdMob] load() called');
    }).catchError((e) {
      SafeLogger.d(_tag, '❌ [AdMob] Banner getAdaptiveSize error: $e');
      bannerHasError.value = true;
    });
  }

  /// Lấy BannerAd đã cache (AdMob only). Null nếu chưa load.
  BannerAd? get admobBannerAd => _admobBannerAd;

  // ════════════════════════════════════════════════════
  // APPLOVIN LISTENERS — chỉ gọi 1 lần
  // ════════════════════════════════════════════════════

  void _setupAppLovinAppOpenListener() {
    SafeLogger.d(_tag, 'AppOpen [AppLovin] setting up listener');
    AppLovinMAX.setAppOpenAdListener(AppOpenAdListener(
      onAdLoadedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] App Open Ad Loaded');
        _isMaxAppOpenReady = true;
        _pendingAppOpenLoadCallback?.call(true);
        _pendingAppOpenLoadCallback = null;
        // ─── Chỉ trigger Inter + Rewarded LẦN ĐẦU sau init ───
        // Các lần reload sau (resume, preload next) KHÔNG cần trigger lại
        if (!_isFirstAdLoadTriggered) {
          _isFirstAdLoadTriggered = true;
          SafeLogger.d(_tag, '###loadOrder App Open loaded → now loading Inter + Rewarded (first time)');
          loadInterstitial();
          loadRewardedAd();
        } else {
          SafeLogger.d(_tag, '###loadOrder App Open reloaded → Inter+Rewarded already triggered, skip');
        }
      },
      onAdLoadFailedCallback: (id, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] App Open Ad Failed: code=${err.code}',
        );
        _lastAppOpenErrorTime = DateTime.now().millisecondsSinceEpoch;
        _isMaxAppOpenReady = false;
        _pendingAppOpenLoadCallback?.call(false);
        _pendingAppOpenLoadCallback = null;
        // ─── Fallback: chỉ trigger Inter + Rewarded LẦN ĐẦU ───
        if (!_isFirstAdLoadTriggered) {
          _isFirstAdLoadTriggered = true;
          SafeLogger.d(_tag, '###loadOrder App Open failed → fallback load Inter + Rewarded (first time)');
          loadInterstitial();
          loadRewardedAd();
        } else {
          SafeLogger.d(_tag, '###loadOrder App Open reload failed → Inter+Rewarded already triggered, skip');
        }
      },
      onAdDisplayedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] App Open Ad Shown');
        AdSafetyConfig.recordFullscreenAdShown();
        _isMaxAppOpenShowing = true;
      },
      onAdDisplayFailedCallback: (ad, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] App Open Display Failed: ${err.message}',
        );
        _isMaxAppOpenShowing = false;
        _isMaxAppOpenReady = false;
        _onAppOpenDismissed?.call(true);
        _onAppOpenDismissed = null;
      },
      onAdClickedCallback: (ad) {
        SafeLogger.d(_tag, '🎯 [AppLovin] App Open Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
      onAdHiddenCallback: (ad) {
        SafeLogger.d(
          _tag,
          '✅ [AppLovin] App Open Ad Dismissed — '
          'preloading next AppOpen ad...',
        );
        _isMaxAppOpenShowing = false;
        _isMaxAppOpenReady = false;
        _onAppOpenDismissed?.call(true);
        _onAppOpenDismissed = null;
        // Preload next ad
        SafeLogger.d(_tag, 'AppOpen [AppLovin] 🔄 preloading next AppOpen on hidden');
        AppLovinMAX.loadAppOpenAd(kAppLovinAppOpenId);
      },
    ));
  }

  void _setupAppLovinInterstitialListener() {
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Interstitial Ad Loaded');
        _isMaxInterReady = true;
        _isInterLoading = false; // reset guard
      },
      onAdLoadFailedCallback: (id, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] Interstitial Ad Failed: code=${err.code}. '
          'Cooldown ${_errorCooldown ~/ 1000}s started.',
        );
        _lastInterErrorTime = DateTime.now().millisecondsSinceEpoch;
        _isMaxInterReady = false;
        _isInterLoading = false; // reset guard
        // Clear pending callback on fail
        _pendingInterDoneFlow?.call(false);
        _pendingInterDoneFlow = null;
      },
      onAdDisplayedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Interstitial Ad Shown');
        AdSafetyConfig.recordFullscreenAdShown();
      },
      onAdDisplayFailedCallback: (ad, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] Interstitial Display Failed: ${err.message}',
        );
        _isInterstitialShowing = false; // BUG FIX: clear flag on display fail
        SafeLogger.d(_tag, 'Inter [AppLovin] 🔓 _isInterstitialShowing=false (display failed)');
        _pendingInterDoneFlow?.call(false);
        _pendingInterDoneFlow = null;
      },
      onAdClickedCallback: (ad) {
        SafeLogger.d(_tag, '🎯 [AppLovin] Interstitial Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
      onAdHiddenCallback: (ad) {
        SafeLogger.d(
          _tag,
          '✅ [AppLovin] Interstitial Ad Dismissed — '
          'preloading next Interstitial...',
        );
        _isMaxInterReady = false;
        _isInterLoading = false; // reset guard khi dismissed
        _isInterstitialShowing = false; // BUG FIX: clear showing flag khi AppLovin dismissed
        SafeLogger.d(_tag, 'Inter [AppLovin] 🔓 _isInterstitialShowing=false (dismissed)');
        _pendingInterDoneFlow?.call(true);
        _pendingInterDoneFlow = null;
        // Preload next ad
        SafeLogger.d(_tag, 'Inter [AppLovin] 🔄 preloading next Inter on hidden');
        AppLovinMAX.loadInterstitial(kAppLovinInterstitialId);
      },
    ));
  }

  void _setupAppLovinRewardedListener() {
    AppLovinMAX.setRewardedAdListener(RewardedAdListener(
      onAdLoadedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Rewarded Ad Loaded');
        _isMaxRewardedReady = true;
      },
      onAdLoadFailedCallback: (id, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] Rewarded Ad Failed: code=${err.code}, message=${err.message}. '
          'Cooldown ${_errorCooldown ~/ 1000}s started.',
        );
        _lastRewardedErrorTime = DateTime.now().millisecondsSinceEpoch;
        _isMaxRewardedReady = false;
        _isRewardedLoading = false; // reset guard
        _pendingRewardedDoneFlow?.call(false);
        _pendingRewardedDoneFlow = null;
      },
      onAdDisplayedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Rewarded Ad Shown');
        AdSafetyConfig.recordFullscreenAdShown();
      },
      onAdDisplayFailedCallback: (ad, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] Rewarded Display Failed: ${err.message}',
        );
        _isRewardedShowing = false; // BUG FIX: clear flag on display fail (mirror of inter fix)
        SafeLogger.d(_tag, 'Rewarded [AppLovin] 🔓 _isRewardedShowing=false (display failed)');
        _pendingRewardedDoneFlow?.call(false);
        _pendingRewardedDoneFlow = null;
      },
      onAdClickedCallback: (ad) {
        SafeLogger.d(_tag, '🎯 [AppLovin] Rewarded Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
      onAdHiddenCallback: (ad) {
        SafeLogger.d(
          _tag,
          '✅ [AppLovin] Rewarded Ad Dismissed — '
          'preloading next Rewarded...',
        );
        _isMaxRewardedReady = false;
        _isRewardedLoading = false; // reset guard khi dismissed
        _isRewardedShowing = false; // BUG FIX: clear flag on dismiss (mirror of inter fix)
        SafeLogger.d(_tag, 'Rewarded [AppLovin] 🔓 _isRewardedShowing=false (dismissed)');
        // Preload next ad
        SafeLogger.d(_tag, 'Rewarded [AppLovin] 🔄 preloading next Rewarded on hidden');
        AppLovinMAX.loadRewardedAd(kAppLovinRewardedId);
      },
      onAdReceivedRewardCallback: (ad, reward) {
        SafeLogger.d(
          _tag,
          '🏆 [AppLovin] Rewarded Ad Earned Reward — type=${reward.label}, amount=${reward.amount}',
        );
        _pendingRewardedDoneFlow?.call(true);
        _pendingRewardedDoneFlow = null;
      },
    ));
  }

  // ════════════════════════════════════════════════════
  // COOLDOWN & NETWORK HELPER
  // ════════════════════════════════════════════════════
  bool _isCooldown(int lastErrorTime) {
    if (lastErrorTime == 0) return false;
    return DateTime.now().millisecondsSinceEpoch - lastErrorTime < _errorCooldown;
  }

  bool get isConnected {
    try {
      return ConnectionNotifierTools.isConnected;
    } catch (_) {
      // Nếu plugin connection_notifier chưa kịp init trên Widget tree
      // sinh ra LateInitializationError, ta sẽ mặc định cho qua (trả về true).
      // Việc rớt mạng thực tế sẽ do SDK Native của AdMob/AppLovin tự trả về fail sau.
      return true;
    }
  }

  // ════════════════════════════════════════════════════
  // APP OPEN AD — LOAD
  // ════════════════════════════════════════════════════
  void loadAppOpenAd({void Function(bool)? onAdLoaded}) {
    SafeLogger.d(
      _tag,
      'loadAppOpenAd called, isEnableAdmob=$kIsEnableAdmob, isVIP=$_isVipMember',
    );
    if (_isVipMember) {
      SafeLogger.d(_tag, 'loadAppOpenAd ⏭️ skipped due to whitelist device');
      onAdLoaded?.call(false);
      return;
    }
    // Network check — tương đương NetworkUtils.isDeviceConnected(context)
    if (!isConnected) {
      SafeLogger.d(_tag, 'loadAppOpenAd ⏭️ no internet connection');
      onAdLoaded?.call(false);
      return;
    }
    if (_isCooldown(_lastAppOpenErrorTime)) {
      final remaining = _errorCooldown -
          (DateTime.now().millisecondsSinceEpoch - _lastAppOpenErrorTime);
      SafeLogger.d(
        _tag,
        'loadAppOpenAd ⏭️ cooldown, remaining=${remaining ~/ 1000}s',
      );
      onAdLoaded?.call(false);
      return;
    }

    if (kIsEnableAdmob) {
      _loadAppOpenAdAdmob(onAdLoaded: onAdLoaded);
    } else {
      _loadAppOpenAdAppLovin(onAdLoaded: onAdLoaded);
    }
  }

  void _loadAppOpenAdAdmob({void Function(bool)? onAdLoaded}) {
    // 1. Chống gọi double rác mạng khi đang tải
    if (_isAppOpenLoading) {
      SafeLogger.d(_tag, 'loadAppOpenAd ⏭️ already loading, skip request');
      onAdLoaded?.call(false);
      return;
    }

    // 2. Chống tải lại nếu Ad vẫn còn hạn sử dụng (4 giờ theo chuẩn chính thức Google)
    if (_appOpenAd != null && _appOpenAdLoadTime != null) {
      if (DateTime.now().difference(_appOpenAdLoadTime!).inHours < 4) {
        SafeLogger.d(_tag, 'loadAppOpenAd ⏭️ ad still valid (< 4h), no need to reload');
        onAdLoaded?.call(true);
        return;
      } else {
        SafeLogger.d(_tag, 'loadAppOpenAd 🔄 ad expired (> 4h), reloading...');
      }
    }

    _isAppOpenLoading = true;
    SafeLogger.d(_tag, 'loadAppOpenAd 🔄 requesting ad from AdMob...');

    AppOpenAd.load(
      adUnitId: kAdmobAppOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          SafeLogger.d(_tag, 'loadAppOpenAd ✅ Ad Loaded successfully');
          _appOpenAd = ad;
          _appOpenAdLoadTime = DateTime.now();
          _isAppOpenLoading = false;
          onAdLoaded?.call(true);
        },
        onAdFailedToLoad: (error) {
          SafeLogger.d(
            _tag,
            'loadAppOpenAd ❌ Failed: code=${error.code}, ${error.message}. '
            'Cooldown ${_errorCooldown ~/ 1000}s started.',
          );
          _lastAppOpenErrorTime = DateTime.now().millisecondsSinceEpoch;
          _isAppOpenLoading = false;
          onAdLoaded?.call(false);
        },
      ),
    );
  }

  void _loadAppOpenAdAppLovin({void Function(bool)? onAdLoaded}) {
    SafeLogger.d(
      _tag,
      'loadAppOpenAd [AppLovin] 🔄 requesting ad, id=$kAppLovinAppOpenId',
    );
    // BUG FIX #1: store callback — will be fired from global listener
    _pendingAppOpenLoadCallback = onAdLoaded;
    AppLovinMAX.loadAppOpenAd(kAppLovinAppOpenId);
  }

  // ════════════════════════════════════════════════════
  // APP OPEN AD — SHOW
  // bypassSafety: splash=true, resume=false
  // ════════════════════════════════════════════════════
  void showAppOpenAd({
    required void Function(bool) onAdDismiss,
    bool bypassSafety = false,
  }) {
    SafeLogger.d(
      _tag,
      'showAppOpenAd called, isEnableAdmob=$kIsEnableAdmob, '
      'isVIP=$_isVipMember, bypassSafety=$bypassSafety',
    );
    if (_isVipMember) {
      SafeLogger.d(_tag, 'showAppOpenAd ⏭️ skipped - Device in whitelist');
      onAdDismiss(false); // not shown
      return;
    }

    // Chống show trùng
    final isShowing = kIsEnableAdmob ? _isAppOpenShowing : _isMaxAppOpenShowing;
    if (isShowing) {
      SafeLogger.d(_tag, 'showAppOpenAd ⏭️ already showing');
      onAdDismiss(false); // not shown (was already showing)
      return;
    }

    // Safety checks — CHUNG (bypass cho splash screen)
    if (!bypassSafety) {
      final safetyResult = AdSafetyConfig.canShowFullscreenAd();
      if (!safetyResult.canShow) {
        SafeLogger.d(
          _tag,
          'showAppOpenAd 🛡️ blocked by AdSafety: ${safetyResult.reason}',
        );
        onAdDismiss(false); // blocked, not shown
        return;
      }
    } else {
      SafeLogger.d(_tag, 'showAppOpenAd 🛡️ safety bypassed (splash screen)');
    }

    if (kIsEnableAdmob) {
      _showAppOpenAdAdmob(onAdDismiss);
    } else {
      _showAppOpenAdAppLovin(onAdDismiss);
    }
  }

  void _showAppOpenAdAdmob(void Function(bool) onAdDismiss) {
    final ad = _appOpenAd; // local var avoids race condition
    if (ad == null) {
      SafeLogger.d(_tag, 'showAppOpenAd ⏭️ Ad not ready (null), skipping');
      onAdDismiss(false); // not shown
      return;
    }
    // Check ad validity (4 giờ)
    if (_appOpenAdLoadTime != null) {
      final hoursSinceLoad = DateTime.now().difference(_appOpenAdLoadTime!).inHours;
      SafeLogger.d(_tag, 'showAppOpenAd 🔄 ad age=${hoursSinceLoad}h, showing...');
    } else {
      SafeLogger.d(_tag, 'showAppOpenAd 🔄 showing ad (no load time recorded)');
    }
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        SafeLogger.d(_tag, 'showAppOpenAd ✅ Ad Shown full screen');
        AdSafetyConfig.recordFullscreenAdShown();
        _isAppOpenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        SafeLogger.d(_tag, 'showAppOpenAd ✅ Ad Dismissed by user');
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenShowing = false;
        onAdDismiss(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        SafeLogger.d(
          _tag,
          'showAppOpenAd [❌] Failed to Show: code=${error.code}, message=${error.message}',
        );
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenShowing = false;
        onAdDismiss(true);
      },
      onAdClicked: (ad) {
        SafeLogger.d(_tag, 'showAppOpenAd 🎯 Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
      onAdImpression: (ad) {
        SafeLogger.d(_tag, 'showAppOpenAd 👁️ Impression recorded');
      },
    );
    ad.show();
  }

  void _showAppOpenAdAppLovin(void Function(bool) onAdDismiss) {
    SafeLogger.d(
      _tag,
      '_showAppOpenAdAppLovin: isMaxAppOpenReady=$_isMaxAppOpenReady, '
      'isMaxAppOpenShowing=$_isMaxAppOpenShowing, '
      'hasPendingCallback=${_onAppOpenDismissed != null}',
    );
    if (!_isMaxAppOpenReady) {
      SafeLogger.d(_tag, 'showAppOpenAd [AppLovin] ⏭️ Ad not ready');
      onAdDismiss(false); // not shown
      return;
    }
    if (_isMaxAppOpenShowing) {
      SafeLogger.d(_tag, 'showAppOpenAd [AppLovin] ⏭️ already showing, skip double-show');
      onAdDismiss(false);
      return;
    }
    SafeLogger.d(_tag, 'showAppOpenAd [AppLovin] 🔄 calling showAppOpenAd native, adUnitId=$kAppLovinAppOpenId');
    // Store callback — will be invoked by the single load-time listener
    _onAppOpenDismissed = onAdDismiss;
    AppLovinMAX.showAppOpenAd(kAppLovinAppOpenId);
  }

  // ════════════════════════════════════════════════════
  // APP OPEN AD — RESUME (gọi từ WidgetsBindingObserver)
  // ════════════════════════════════════════════════════
  void showAppOpenAdOnResume() {
    SafeLogger.d(
      _tag,
      '▶️ showAppOpenAdOnResume triggered! isSplash=$_isSplashActive, isVIP=$_isVipMember',
    );
    if (_isSplashActive) {
      SafeLogger.d(_tag, 'showAppOpenAdOnResume ⏭️ ignored: splash is currently active');
      return;
    }
    if (_isVipMember) {
      SafeLogger.d(_tag, 'showAppOpenAdOnResume ⏭️ ignored: VIP device detected');
      return;
    }

    // Chống xung đột: nếu có full-screen ad khác đang hiện thì bỏ qua hoàn toàn
    if (_isInterstitialShowing) {
      SafeLogger.d(_tag, 'showAppOpenAdOnResume ⏭️ ignored: Interstitial Ad is currently showing');
      return;
    }
    if (_isRewardedShowing) {
      SafeLogger.d(_tag, 'showAppOpenAdOnResume ⏭️ ignored: Rewarded Ad is currently showing');
      return;
    }

    // Check with AdSafetyConfig.canShowAppOpenOnResume()
    if (!AdSafetyConfig.canShowAppOpenOnResume()) {
      SafeLogger.d(
        _tag,
        'showAppOpenAdOnResume 🛡️ blocked by AdSafetyConfig rules (cooldown/throttle)',
      );
      // Vẫn gọi load ngầm để sẵn sàng cho lần Resume sau
      SafeLogger.d(_tag, 'showAppOpenAdOnResume 🔄 forcing background reload for next time');
      loadAppOpenAd();
      return;
    }

    final adReady = kIsEnableAdmob ? (_appOpenAd != null) : _isMaxAppOpenReady;
    final isShowing =
        kIsEnableAdmob ? _isAppOpenShowing : _isMaxAppOpenShowing;

    SafeLogger.d(
      _tag,
      'ProcessLifecycle 🔎 EVALUATION: adReady=$adReady, isShowing=$isShowing',
    );

    // Nếu đã có ad sẵn sàng thì show ngay
    if (adReady && !isShowing) {
      SafeLogger.d(_tag, 'ProcessLifecycle 🚀 Conditions met & Ad is ready -> SHOWING NOW');
      showAppOpenAd(
        onAdDismiss: (wasActuallyShown) {
          if (wasActuallyShown) {
            SafeLogger.d(
              _tag,
              'ProcessLifecycle ✅ Ad dismissed by user, preloading next ad...',
            );
          } else {
            SafeLogger.d(
              _tag,
              'ProcessLifecycle 🔄 Ad blocked/skipped before show, preloading for next resume...',
            );
          }
          loadAppOpenAd();
        },
        bypassSafety: false,
      );
    } else {
      SafeLogger.d(
        _tag,
        'ProcessLifecycle 🔄 No ad ready, preloading for next resume',
      );
      loadAppOpenAd();
    }
  }

  // ════════════════════════════════════════════════════
  // LIFECYCLE OBSERVER (Background / Foreground)
  // ════════════════════════════════════════════════════
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SafeLogger.d(
      _tag,
      'didChangeAppLifecycleState: state=$state, '
      'isSplashActive=$_isSplashActive, isVIP=$_isVipMember',
    );
    if (state == AppLifecycleState.paused) {
      SafeLogger.d(_tag, 'ProcessLifecycle ⏸️ App went to BACKGROUND');
      _logAllAdStatus('lifecycle-paused');
      AdSafetyConfig.recordAppWentBackground();

      // ─── AppLovin banner: pause auto-refresh qua isAutoRefreshEnabled ValueNotifier ───
      // MaxAdView.didUpdateWidget sẽ detect thay đổi và gọi stopAutoRefresh() native
      if (!kIsEnableAdmob && bannerAdViewId.value != null) {
        SafeLogger.d(
          _tag,
          'Banner [AppLovin] ⏸️ pausing auto-refresh via bannerAutoRefreshEnabled=false',
        );
        bannerAutoRefreshEnabled.value = false;
      }

      // ─── AdMob banner: ẩn widget khi background ───
      // Google Mobile Ads SDK không expose pause() trong Flutter
      // Ẩn widget = SDK ngưng refresh do kông active
      if (kIsEnableAdmob && _admobBannerAd != null) {
        SafeLogger.d(
          _tag,
          'Banner [AdMob] ⏸️ hiding banner widget (app paused)',
        );
        bannerVisible.value = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      SafeLogger.d(_tag, 'ProcessLifecycle ▶️ App came to FOREGROUND');
      _logAllAdStatus('lifecycle-resumed');

      // ─── AppLovin banner: resume auto-refresh ───
      if (!kIsEnableAdmob) {
        if (bannerHasError.value) {
          // Banner đã fail trước đó → retry preload khi app vào foreground
          SafeLogger.d(
            _tag,
            'Banner [AppLovin] ▶️ bannerHasError=true, retrying preload on resume',
          );
          bannerHasError.value = false;          // reset → widget không render SizedBox.shrink
          bannerAdViewId.value = null;           // reset → widget render shimmer
          bannerAutoRefreshEnabled.value = true; // ← QUAN TRỌNG: reset trước preload
          //   paused event set nó thành false → nếu không reset, MaxAdView mount với
          //   isAutoRefreshEnabled=false → stopAutoRefresh() ngay lập tức → banner vô hình
          SafeLogger.d(_tag, 'Banner [AppLovin] ▶️ bannerAutoRefreshEnabled reset to true before retry');
          _preloadAppLovinBanner();

        } else if (bannerAdViewId.value != null) {
          // Chrome resume: chỉ resume nếu route hiện tại KHÔNG bị che bởi route khác
          // Nếu _bannerRoutePaused=true (đang navigate tới screen khác), giữ pause
          if (!_bannerRoutePaused) {
            SafeLogger.d(
              _tag,
              'Banner [AppLovin] ▶️ resuming auto-refresh via bannerAutoRefreshEnabled=true '
              '(_bannerRoutePaused=false ok)',
            );
            bannerAutoRefreshEnabled.value = true;
          } else {
            SafeLogger.d(
              _tag,
              'Banner [AppLovin] ⏭️ lifecycle resume but _bannerRoutePaused=true — '
              'keeping pause (banner route is covered)',
            );
          }
        }
      }

      // ─── AdMob banner: hiện lại widget hoặc retry nếu lỗi ───
      if (kIsEnableAdmob) {
        if (bannerHasError.value && _admobBannerAd == null) {
          SafeLogger.d(_tag, 'Banner [AdMob] ▶️ bannerHasError=true, retrying load on resume');
          bannerHasError.value = false;
          // Sẽ được load lại lần tới khi BannerAdWidget mount/rebuild
        } else if (_admobBannerAd != null) {
          SafeLogger.d(_tag, 'Banner [AdMob] ▶️ showing banner widget (app resumed)');
          bannerVisible.value = true;
        }
      }

      showAppOpenAdOnResume();

    } else if (state == AppLifecycleState.inactive) {
      SafeLogger.d(_tag, 'ProcessLifecycle ⚠️ App is INACTIVE (transition state)');
    } else if (state == AppLifecycleState.detached) {
      SafeLogger.d(_tag, 'ProcessLifecycle 🚧 App is DETACHED');
    } else if (state == AppLifecycleState.hidden) {
      SafeLogger.d(_tag, 'ProcessLifecycle 👁️ App is HIDDEN');
    }
  }

  // ════════════════════════════════════════════════════
  // INTERSTITIAL AD — LOAD
  // ════════════════════════════════════════════════════
  void loadInterstitial() {
    SafeLogger.d(
      _tag,
      'loadInterstitial called, isEnableAdmob=$kIsEnableAdmob, isVIP=$_isVipMember',
    );
    if (_isVipMember) {
      SafeLogger.d(_tag, 'loadInterstitial ⏭️ skipped due to whitelist');
      return;
    }
    // Network check — tương đương NetworkUtils.isDeviceConnected(context)
    if (!isConnected) {
      SafeLogger.d(_tag, 'loadInterstitial ⏭️ no internet');
      return;
    }
    if (_isCooldown(_lastInterErrorTime)) {
      final remaining = _errorCooldown -
          (DateTime.now().millisecondsSinceEpoch - _lastInterErrorTime);
      SafeLogger.d(
        _tag,
        'loadInterstitial ⏭️ cooldown, remaining=${remaining ~/ 1000}s',
      );
      return;
    }

    if (kIsEnableAdmob) {
      // Nếu ad còn tồn tại và chưa được show → skip reload
      if (_interstitialAd != null) {
        SafeLogger.d(_tag, 'loadInterstitial ⏭️ ad already in memory, no need to reload');
        return;
      }
      if (_isInterLoading) {
        SafeLogger.d(_tag, 'loadInterstitial ⏭️ already loading, skip request');
        return;
      }
      _isInterLoading = true;
      SafeLogger.d(_tag, 'loadInterstitial 🔄 requesting ad from AdMob...');
      InterstitialAd.load(
        adUnitId: kAdmobInterstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            SafeLogger.d(_tag, '✅ Interstitial Ad Loaded successfully');
            _interstitialAd = ad;
            _isInterLoading = false;
          },
          onAdFailedToLoad: (error) {
            SafeLogger.d(
              _tag,
              '❌ Interstitial Ad Failed: code=${error.code}, ${error.message}. '
              'Cooldown ${_errorCooldown ~/ 1000}s started.',
            );
            _lastInterErrorTime = DateTime.now().millisecondsSinceEpoch;
            _interstitialAd = null;
            _isInterLoading = false;
          },
        ),
      );
    } else {
      // AppLovin path
      if (_isMaxInterReady) {
        SafeLogger.d(_tag, 'loadInterstitial [AppLovin] ⏭️ ad already ready, no need to reload');
        return;
      }
      // Guard race condition: chống 2 request song song
      if (_isInterLoading) {
        SafeLogger.d(_tag, 'loadInterstitial [AppLovin] ⏭️ already loading, skip request');
        return;
      }
      _isInterLoading = true;
      SafeLogger.d(
        _tag,
        'loadInterstitial [AppLovin] 🔄 requesting ad, id=$kAppLovinInterstitialId',
      );
      AppLovinMAX.loadInterstitial(kAppLovinInterstitialId);
    }
  }

  // ════════════════════════════════════════════════════
  // INTERSTITIAL AD — SHOW
  // ════════════════════════════════════════════════════
  void showInterstitial({required void Function(bool) onDoneFlow}) {
    SafeLogger.d(
      _tag,
      'showInterstitial called, isEnableAdmob=$kIsEnableAdmob, isVIP=$_isVipMember',
    );
    if (_isVipMember) {
      SafeLogger.d(_tag, 'showInterstitial ⏭️ skipped - VIP whitelist');
      onDoneFlow(false);
      return;
    }

    // Safety checks — CHUNG cho cả AdMob và AppLovin
    final safetyResult = AdSafetyConfig.canShowFullscreenAd();
    if (!safetyResult.canShow) {
      SafeLogger.d(
        _tag,
        'showInterstitial 🛡️ blocked by AdSafety: ${safetyResult.reason}',
      );
      onDoneFlow(false);
      return;
    }

    if (kIsEnableAdmob) {
      _showInterstitialAdmob(onDoneFlow);
    } else {
      _showInterstitialAppLovin(onDoneFlow);
    }
  }

  void _showInterstitialAdmob(void Function(bool) onDoneFlow) {
    final ad = _interstitialAd; // BUG FIX #5: local var avoids race condition
    if (ad == null) {
      SafeLogger.d(_tag, 'showInterstitial ⏭️ Ad not ready');
      onDoneFlow(false);
      return;
    }
    SafeLogger.d(_tag, 'showInterstitial 🔄 showing ad');
    _isInterstitialShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showInterstitial ✅ Ad Shown full screen');
        AdSafetyConfig.recordFullscreenAdShown();
      },
      onAdDismissedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showInterstitial [✅] Ad Dismissed by user, reloading...');
        a.dispose();
        _interstitialAd = null;
        _isInterstitialShowing = false;
        SafeLogger.d(_tag, 'showInterstitial 🔓 _isInterstitialShowing=false (dismissed)');
        // Preload next ad
        loadInterstitial();
        onDoneFlow(true);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        SafeLogger.d(
          _tag,
          'showInterstitial [❌] Failed to Show: code=${error.code}, message=${error.message}',
        );
        a.dispose();
        _interstitialAd = null;
        _isInterstitialShowing = false;
        SafeLogger.d(_tag, 'showInterstitial 🔓 _isInterstitialShowing=false (fail to show)');
        onDoneFlow(false);
      },
      onAdClicked: (a) {
        SafeLogger.d(_tag, 'showInterstitial 🎯 Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
    );
    ad.show();
    SafeLogger.d(_tag, 'showInterstitial [AdMob] 📲 ad.show() called, waiting for callbacks...');
  }

  void _showInterstitialAppLovin(void Function(bool) onDoneFlow) {
    SafeLogger.d(
      _tag,
      '_showInterstitialAppLovin: isMaxInterReady=$_isMaxInterReady, '
      'isInterstitialShowing=$_isInterstitialShowing, '
      'isInterLoading=$_isInterLoading, '
      'hasPendingFlow=${_pendingInterDoneFlow != null}',
    );
    if (!_isMaxInterReady) {
      SafeLogger.d(_tag, 'showInterstitial [AppLovin] ⏭️ Ad not ready');
      onDoneFlow(false);
      return;
    }
    if (_isInterstitialShowing) {
      SafeLogger.d(_tag, 'showInterstitial [AppLovin] ⏭️ already showing, skip double-show');
      onDoneFlow(false);
      return;
    }
    SafeLogger.d(_tag, 'showInterstitial [AppLovin] 🔄 calling showInterstitial native, adUnitId=$kAppLovinInterstitialId');
    _isMaxInterReady = false; // prevent double-show
    _isInterstitialShowing = true;
    SafeLogger.d(_tag, 'showInterstitial [AppLovin] 🔒 _isMaxInterReady=false, _isInterstitialShowing=true');
    // Store callback — will be invoked on dismiss/fail
    _pendingInterDoneFlow = onDoneFlow;
    AppLovinMAX.showInterstitial(kAppLovinInterstitialId);
  }

  // ════════════════════════════════════════════════════
  // REWARDED AD — LOAD
  // ════════════════════════════════════════════════════
  void loadRewardedAd() {
    SafeLogger.d(
      _tag,
      'loadRewardedAd called, isEnableAdmob=$kIsEnableAdmob, isVIP=$_isVipMember',
    );
    if (_isVipMember) {
      SafeLogger.d(_tag, 'loadRewardedAd ⏭️ skipped due to whitelist');
      return;
    }
    if (!isConnected) {
      SafeLogger.d(_tag, 'loadRewardedAd ⏭️ no internet');
      return;
    }
    if (_isCooldown(_lastRewardedErrorTime)) {
      final remaining = _errorCooldown -
          (DateTime.now().millisecondsSinceEpoch - _lastRewardedErrorTime);
      SafeLogger.d(
        _tag,
        'loadRewardedAd ⏭️ cooldown, remaining=${remaining ~/ 1000}s',
      );
      return;
    }

    if (kIsEnableAdmob) {
      // Nếu ad còn tồn tại và chưa được show → skip reload
      if (_rewardedAd != null) {
        SafeLogger.d(_tag, 'loadRewardedAd ⏭️ ad already in memory, no need to reload');
        return;
      }
      if (_isRewardedLoading) {
        SafeLogger.d(_tag, 'loadRewardedAd ⏭️ already loading, skip request');
        return;
      }
      _isRewardedLoading = true;
      SafeLogger.d(_tag, 'loadRewardedAd 🔄 requesting ad from AdMob...');
      RewardedAd.load(
        adUnitId: kAdmobRewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            SafeLogger.d(_tag, '✅ Rewarded Ad Loaded successfully');
            _rewardedAd = ad;
            _isRewardedLoading = false;
          },
          onAdFailedToLoad: (error) {
            SafeLogger.d(
              _tag,
              '❌ Rewarded Ad Failed: code=${error.code}, ${error.message}. '
              'Cooldown ${_errorCooldown ~/ 1000}s started.',
            );
            _lastRewardedErrorTime = DateTime.now().millisecondsSinceEpoch;
            _rewardedAd = null;
            _isRewardedLoading = false;
          },
        ),
      );
    } else {
      // AppLovin path
      if (_isMaxRewardedReady) {
        SafeLogger.d(_tag, 'loadRewardedAd [AppLovin] ⏭️ ad already ready, no need to reload');
        return;
      }
      // Guard race condition: chống 2 request song song
      if (_isRewardedLoading) {
        SafeLogger.d(_tag, 'loadRewardedAd [AppLovin] ⏭️ already loading, skip request');
        return;
      }
      _isRewardedLoading = true;
      SafeLogger.d(
        _tag,
        'loadRewardedAd [AppLovin] 🔄 requesting ad, id=$kAppLovinRewardedId',
      );
      AppLovinMAX.loadRewardedAd(kAppLovinRewardedId);
    }
  }

  // ════════════════════════════════════════════════════
  // REWARDED AD — SHOW
  // ════════════════════════════════════════════════════
  void showRewardedAd({required void Function(bool) onEarnedReward}) {
    SafeLogger.d(
      _tag,
      'showRewardedAd called, isEnableAdmob=$kIsEnableAdmob, isVIP=$_isVipMember',
    );
    if (_isVipMember) {
      SafeLogger.d(_tag, 'showRewardedAd ⏭️ skipped - VIP whitelist');
      // Thường VIP được auto-thưởng luôn
      onEarnedReward(true);
      return;
    }

    final safetyResult = AdSafetyConfig.canShowFullscreenAd();
    if (!safetyResult.canShow) {
      SafeLogger.d(
        _tag,
        'showRewardedAd 🛡️ blocked by AdSafety: ${safetyResult.reason}',
      );
      onEarnedReward(false);
      return;
    }

    if (kIsEnableAdmob) {
      _showRewardedAdmob(onEarnedReward);
    } else {
      _showRewardedAppLovin(onEarnedReward);
    }
  }

  void _showRewardedAdmob(void Function(bool) onEarnedReward) {
    final ad = _rewardedAd;
    if (ad == null) {
      SafeLogger.d(_tag, 'showRewardedAd [AdMob] ⏭️ Ad not ready (null)');
      onEarnedReward(false);
      return;
    }
    SafeLogger.d(
      _tag,
      'showRewardedAd [AdMob] 🔄 showing ad, '
      'isRewardedShowing=$_isRewardedShowing → true',
    );
    bool hasEarned = false;
    _isRewardedShowing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showRewardedAd [AdMob] ✅ Ad Shown full screen');
        AdSafetyConfig.recordFullscreenAdShown();
      },
      onAdDismissedFullScreenContent: (a) {
        SafeLogger.d(
          _tag,
          'showRewardedAd [AdMob] ✅ Ad Dismissed, hasEarned=$hasEarned',
        );
        a.dispose();
        _rewardedAd = null;
        _isRewardedShowing = false;
        SafeLogger.d(_tag, 'showRewardedAd [AdMob] 🔓 _isRewardedShowing=false (dismissed)');
        loadRewardedAd(); // Preload next
        if (!hasEarned) onEarnedReward(false);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        SafeLogger.d(
          _tag,
          'showRewardedAd [AdMob] [❌] Failed to Show: code=${error.code}, message=${error.message}',
        );
        a.dispose();
        _rewardedAd = null;
        _isRewardedShowing = false;
        SafeLogger.d(_tag, 'showRewardedAd [AdMob] 🔓 _isRewardedShowing=false (fail to show)');
        onEarnedReward(false);
      },
      onAdClicked: (a) {
        SafeLogger.d(_tag, 'showRewardedAd [AdMob] 🎯 Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
    );
    ad.show(onUserEarnedReward: (AdWithoutView a, RewardItem reward) {
      SafeLogger.d(
        _tag,
        '🏆 showRewardedAd [AdMob] Earned Reward: type=${reward.type}, amount=${reward.amount}',
      );
      hasEarned = true;
      onEarnedReward(true);
    });
    SafeLogger.d(_tag, 'showRewardedAd [AdMob] 📲 ad.show() called, waiting for callbacks...');
  }

  void _showRewardedAppLovin(void Function(bool) onEarnedReward) {
    SafeLogger.d(
      _tag,
      '_showRewardedAppLovin: isMaxRewardedReady=$_isMaxRewardedReady, '
      'isRewardedShowing=$_isRewardedShowing',
    );
    if (_isRewardedShowing) {
      SafeLogger.d(_tag, 'showRewardedAd [AppLovin] ⏭️ already showing, skip');
      onEarnedReward(false);
      return;
    }
    if (!_isMaxRewardedReady) {
      SafeLogger.d(_tag, 'showRewardedAd [AppLovin] ⏭️ Ad not ready');
      onEarnedReward(false);
      return;
    }
    SafeLogger.d(_tag, 'showRewardedAd [AppLovin] 🔄 showing ad');
    _isMaxRewardedReady = false;
    _isRewardedShowing = true;
    _pendingRewardedDoneFlow = (earned) {
      SafeLogger.d(_tag, 'showRewardedAd [AppLovin] 🏆 earned=$earned, clearing _isRewardedShowing');
      _isRewardedShowing = false;
      onEarnedReward(earned);
    };
    AppLovinMAX.showRewardedAd(kAppLovinRewardedId);
  }

  // ════════════════════════════════════════════════════
  // SPLASH FLOW
  // ════════════════════════════════════════════════════
  void markSplashActive() {
    _isSplashActive = true;
    SafeLogger.d(_tag, 'markSplashActive');
  }

  void markSplashInactive() {
    _isSplashActive = false;
    SafeLogger.d(_tag, 'markSplashInactive');
  }

  bool get isSplashActive => _isSplashActive;
  int get countInitSplashScreen => _countInitSplashScreen;

  void incrementSplashCount() {
    _countInitSplashScreen++;
    SafeLogger.d(
      _tag,
      'incrementSplashCount count=$_countInitSplashScreen',
    );
  }

  // ════════════════════════════════════════════════════
  // VIP MEMBER MANAGEMENT
  // ════════════════════════════════════════════════════
  void addVIPMember(List<String> gaids) {
    _setGAIDVipMember.addAll(gaids);
    AppPreferences.instanceOrNull?.saveGAIDList(
      _setGAIDVipMember.toList(),
    );
    _isVipMember = _setGAIDVipMember.contains(_currentDeviceGAID);
    SafeLogger.d(
      _tag,
      'Thêm VIP members: ${gaids.length} => isVIP: $_isVipMember',
    );
    SafeLogger.d(
      _tag,
      'Tổng VIP members: ${_setGAIDVipMember.length}',
    );
  }

  void deleteVIPMember(List<String> gaids) {
    for (final g in gaids) {
      _setGAIDVipMember.remove(g);
    }
    AppPreferences.instanceOrNull?.saveGAIDList(
      _setGAIDVipMember.toList(),
    );
    _isVipMember = _setGAIDVipMember.contains(_currentDeviceGAID);
    SafeLogger.d(
      _tag,
      'Xóa VIP members: ${gaids.length} => isVIP: $_isVipMember',
    );
    SafeLogger.d(
      _tag,
      'Còn lại VIP members: ${_setGAIDVipMember.length}',
    );
  }

  bool isVIPMember() {
    SafeLogger.d(_tag, 'isVIPMember() = $_isVipMember, GAID=$_currentDeviceGAID');
    return _isVipMember;
  }

  // ════════════════════════════════════════════════════
  // BANNER GUARD — chống spam load khi navigate nhanh
  // ════════════════════════════════════════════════════
  /// Trả về true nếu được phép load banner mới.
  /// Cooldown 5s kể từ lần load cuối để tránh spam khi user navigate nhanh.
  bool canLoadBanner() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastBannerLoadTime;
    if (_lastBannerLoadTime > 0 && elapsed < _bannerLoadCooldown) {
      final remaining = (_bannerLoadCooldown - elapsed) ~/ 1000;
      SafeLogger.d(
        _tag,
        'canLoadBanner ⏭️ cooldown active, remaining=${remaining}s',
      );
      return false;
    }
    return true;
  }

  /// Ghi nhận thời điểm banner được load.
  void recordBannerLoad() {
    _lastBannerLoadTime = DateTime.now().millisecondsSinceEpoch;
    SafeLogger.d(_tag, 'canLoadBanner ✅ load allowed, timer reset');
  }

  // ════════════════════════════════════════════════════
  // PRE-CHECK — kiểm tra điều kiện show AD trước khi show dialog
  // Dùng bởi AdScreen để gate loading dialog
  // ════════════════════════════════════════════════════

  /// Kiểm tra Interstitial có thể show ngay bây giờ không.
  /// Không show ad, chỉ trả về bool — dùng để gate loading dialog.
  bool canShowInterstitial() {
    SafeLogger.d(
      _tag,
      'canShowInterstitial() pre-check: '
      'isVIP=$_isVipMember, '
      'isAdmob=$kIsEnableAdmob, '
      'admobAdNull=${_interstitialAd == null}, '
      'maxInterReady=$_isMaxInterReady, '
      'isInterShowing=$_isInterstitialShowing',
    );

    if (_isVipMember) {
      SafeLogger.d(_tag, 'canShowInterstitial ⏭️ VIP device');
      return false;
    }
    if (_isInterstitialShowing) {
      SafeLogger.d(_tag, 'canShowInterstitial ⏭️ already showing');
      return false;
    }

    // Safety pre-check
    final safety = AdSafetyConfig.canShowFullscreenAd();
    if (!safety.canShow) {
      SafeLogger.d(_tag, 'canShowInterstitial ⏭️ safety blocked: ${safety.reason}');
      return false;
    }

    // Ad readiness
    if (kIsEnableAdmob) {
      final ready = _interstitialAd != null;
      SafeLogger.d(_tag, 'canShowInterstitial [AdMob] → adReady=$ready');
      return ready;
    } else {
      SafeLogger.d(_tag, 'canShowInterstitial [AppLovin] → adReady=$_isMaxInterReady');
      return _isMaxInterReady;
    }
  }

  /// Kiểm tra Rewarded Ad có thể show ngay bây giờ không.
  /// Không show ad, chỉ trả về bool — dùng để gate loading dialog.
  bool canShowRewardedAd() {
    SafeLogger.d(
      _tag,
      'canShowRewardedAd() pre-check: '
      'isVIP=$_isVipMember, '
      'isAdmob=$kIsEnableAdmob, '
      'admobAdNull=${_rewardedAd == null}, '
      'maxRewardedReady=$_isMaxRewardedReady, '
      'isRewardedShowing=$_isRewardedShowing',
    );

    if (_isVipMember) {
      SafeLogger.d(_tag, 'canShowRewardedAd ⏭️ VIP device (auto-reward)');
      return true; // VIP nhận reward ngay, không cần ad
    }
    if (_isRewardedShowing) {
      SafeLogger.d(_tag, 'canShowRewardedAd ⏭️ already showing');
      return false;
    }

    // Safety pre-check
    final safety = AdSafetyConfig.canShowFullscreenAd();
    if (!safety.canShow) {
      SafeLogger.d(_tag, 'canShowRewardedAd ⏭️ safety blocked: ${safety.reason}');
      return false;
    }

    // Ad readiness
    if (kIsEnableAdmob) {
      final ready = _rewardedAd != null;
      SafeLogger.d(_tag, 'canShowRewardedAd [AdMob] → adReady=$ready');
      return ready;
    } else {
      SafeLogger.d(_tag, 'canShowRewardedAd [AppLovin] → adReady=$_isMaxRewardedReady');
      return _isMaxRewardedReady;
    }
  }

  // ════════════════════════════════════════════════════
  // DESTROY — giải phóng toàn bộ resources
  // Gọi khi không cần ad nữa (ví dụ: khi thực sự cần reset)
  // ════════════════════════════════════════════════════
  void destroy() {
    SafeLogger.d(_tag, 'destroy() called - releasing all ad resources');

    // ── WidgetsBinding lifecycle observer ──
    // QUAN TRỌNG: nếu không gọi removeObserver, AdManager singleton sẽ tiếp tục
    // nhận didChangeAppLifecycleState callbacks mãi mãi — đây là memory leak kinh điển
    SafeLogger.d(_tag, 'destroy() removing WidgetsBinding observer');
    WidgetsBinding.instance.removeObserver(this);

    // AdMob cleanup
    SafeLogger.d(_tag, 'destroy() [AdMob] disposing interstitialAd=${_interstitialAd != null}');
    _interstitialAd?.fullScreenContentCallback = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    SafeLogger.d(_tag, 'destroy() [AdMob] disposing appOpenAd=${_appOpenAd != null}');
    _appOpenAd?.fullScreenContentCallback = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    SafeLogger.d(_tag, 'destroy() [AdMob] disposing rewardedAd=${_rewardedAd != null}');
    _rewardedAd?.fullScreenContentCallback = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    SafeLogger.d(_tag, 'destroy() [AdMob] disposing admobBannerAd=${_admobBannerAd != null}');
    _admobBannerAd?.dispose();
    _admobBannerAd = null;

    // AppLovin cleanup
    SafeLogger.d(
      _tag,
      'destroy() [AppLovin] resetting state: '
      'appOpen=$_isMaxAppOpenReady, inter=$_isMaxInterReady, rewarded=$_isMaxRewardedReady',
    );
    _isMaxAppOpenReady = false;
    _isMaxAppOpenShowing = false;
    _isMaxInterReady = false;
    _isInterLoading = false;
    _isMaxRewardedReady = false;
    _isRewardedLoading = false;
    _pendingInterDoneFlow = null;
    _onAppOpenDismissed = null;
    _pendingAppOpenLoadCallback = null;
    _pendingRewardedDoneFlow = null;

    // Banner — reset values TRƯỚC khi dispose notifiers
    // (Widget listeners sẽ nhận giá trị reset cuối cùng)
    SafeLogger.d(_tag, 'destroy() resetting + disposing banner ValueNotifiers');
    bannerIsLoaded.value = false;
    bannerHasError.value = false;
    bannerAdViewId.value = null;
    bannerAutoRefreshEnabled.value = true;
    bannerVisible.value = true;
    bannerAdSize.value = null;
    // Dispose ValueNotifiers — giải phóng listener list trong ChangeNotifier
    bannerIsLoaded.dispose();
    bannerHasError.dispose();
    bannerAdViewId.dispose();
    bannerAutoRefreshEnabled.dispose();
    bannerVisible.dispose();
    bannerAdSize.dispose();

    // Common cleanup
    _isAppOpenShowing = false;
    _isAppOpenLoading = false;
    _isRewardedShowing = false;
    SafeLogger.d(_tag, 'destroy() ✅ all ad resources released');
  }
}
