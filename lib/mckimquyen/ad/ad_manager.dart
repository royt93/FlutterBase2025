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
  DateTime? _appOpenAdLoadTime;
  int _lastAppOpenErrorTime = 0;
  int _lastInterErrorTime = 0;
  bool _isAppOpenLoading = false;
  bool _isAppOpenShowing = false;

  // ════════════════ APPLOVIN MAX STATE ════════════════
  bool _isMaxInterReady = false;
  bool _isMaxAppOpenReady = false;
  bool _isMaxAppOpenShowing = false;
  void Function(bool)? _pendingInterDoneFlow;
  void Function(bool)? _onAppOpenDismissed;
  void Function(bool)? _pendingAppOpenLoadCallback;

  // ════════════════ REWARDED AD STATE ════════════════
  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  int _lastRewardedErrorTime = 0;
  bool _isMaxRewardedReady = false;
  void Function(bool)? _pendingRewardedDoneFlow; // true if earned reward

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

    // Emits event cho SplashScreen biết init xong
    SimpleEventBus().fire(BoolEvent(true));

    // Đảm bảo luôn load sẵn App Open Ad ngầm sau khi init xong
    // (Phòng trường hợp Splash bị hard-cap timeout bỏ qua bước load)
    SafeLogger.d(_tag, '###init triggering background preloads for all full-screen ads');
    loadAppOpenAd();
    loadInterstitial();
    loadRewardedAd();
  }

  // ════════════════════════════════════════════════════
  // APPLOVIN LISTENERS — chỉ gọi 1 lần
  // ════════════════════════════════════════════════════
  void _setupAppLovinAppOpenListener() {
    AppLovinMAX.setAppOpenAdListener(AppOpenAdListener(
      onAdLoadedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] App Open Ad Loaded');
        _isMaxAppOpenReady = true;
        // BUG FIX #1: fire pending callback from loadAppOpenAd()
        _pendingAppOpenLoadCallback?.call(true);
        _pendingAppOpenLoadCallback = null;
      },
      onAdLoadFailedCallback: (id, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] App Open Ad Failed: code=${err.code}',
        );
        _lastAppOpenErrorTime = DateTime.now().millisecondsSinceEpoch;
        _isMaxAppOpenReady = false;
        // BUG FIX #1: fire pending callback on fail too
        _pendingAppOpenLoadCallback?.call(false);
        _pendingAppOpenLoadCallback = null;
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
        SafeLogger.d(_tag, '✅ [AppLovin] App Open Ad Dismissed');
        _isMaxAppOpenShowing = false;
        _isMaxAppOpenReady = false;
        _onAppOpenDismissed?.call(true);
        _onAppOpenDismissed = null;
        // Preload next ad
        AppLovinMAX.loadAppOpenAd(kAppLovinAppOpenId);
      },
    ));
  }

  void _setupAppLovinInterstitialListener() {
    AppLovinMAX.setInterstitialListener(InterstitialListener(
      onAdLoadedCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Interstitial Ad Loaded');
        _isMaxInterReady = true;
      },
      onAdLoadFailedCallback: (id, err) {
        SafeLogger.d(
          _tag,
          '❌ [AppLovin] Interstitial Ad Failed: code=${err.code}. '
          'Cooldown ${_errorCooldown ~/ 1000}s started.',
        );
        _lastInterErrorTime = DateTime.now().millisecondsSinceEpoch;
        _isMaxInterReady = false;
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
        _pendingInterDoneFlow?.call(false);
        _pendingInterDoneFlow = null;
      },
      onAdClickedCallback: (ad) {
        SafeLogger.d(_tag, '🎯 [AppLovin] Interstitial Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
      onAdHiddenCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Interstitial Ad Dismissed');
        _isMaxInterReady = false;
        _pendingInterDoneFlow?.call(true);
        _pendingInterDoneFlow = null;
        // Preload next ad
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
          '❌ [AppLovin] Rewarded Ad Failed: code=${err.code}. '
          'Cooldown ${_errorCooldown ~/ 1000}s started.',
        );
        _lastRewardedErrorTime = DateTime.now().millisecondsSinceEpoch;
        _isMaxRewardedReady = false;
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
        _pendingRewardedDoneFlow?.call(false);
        _pendingRewardedDoneFlow = null;
      },
      onAdClickedCallback: (ad) {
        SafeLogger.d(_tag, '🎯 [AppLovin] Rewarded Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
      onAdHiddenCallback: (ad) {
        SafeLogger.d(_tag, '✅ [AppLovin] Rewarded Ad Dismissed');
        _isMaxRewardedReady = false;
        // Preload next ad
        AppLovinMAX.loadRewardedAd(kAppLovinRewardedId);
      },
      onAdReceivedRewardCallback: (ad, reward) {
        SafeLogger.d(_tag, '🏆 [AppLovin] Rewarded Ad Earned Reward');
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
      onAdDismiss(true);
      return;
    }

    // Chống show trùng
    final isShowing = kIsEnableAdmob ? _isAppOpenShowing : _isMaxAppOpenShowing;
    if (isShowing) {
      SafeLogger.d(_tag, 'showAppOpenAd ⏭️ already showing');
      onAdDismiss(true);
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
        onAdDismiss(true);
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
      onAdDismiss(true);
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
          'showAppOpenAd ❌ Failed to Show: ${error.message}',
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
    if (!_isMaxAppOpenReady) {
      SafeLogger.d(_tag, 'showAppOpenAd [AppLovin] ⏭️ Ad not ready');
      onAdDismiss(true);
      return;
    }
    SafeLogger.d(_tag, 'showAppOpenAd [AppLovin] 🔄 showing ad');
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
        onAdDismiss: (result) {
          SafeLogger.d(
            _tag,
            'ProcessLifecycle ✅ Ad dismissed by user, preloading next ad...',
          );
          // Sau khi show xong, preload ad mới
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
    if (state == AppLifecycleState.paused) {
      SafeLogger.d(_tag, 'ProcessLifecycle ⏸️ App went to BACKGROUND');
      AdSafetyConfig.recordAppWentBackground();
    } else if (state == AppLifecycleState.resumed) {
      SafeLogger.d(_tag, 'ProcessLifecycle ▶️ App came to FOREGROUND');
      showAppOpenAdOnResume();
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
      if (_isInterLoading) return;
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
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showInterstitial ✅ Ad Shown full screen');
        AdSafetyConfig.recordFullscreenAdShown();
      },
      onAdDismissedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showInterstitial ✅ Ad Dismissed by user');
        a.dispose();
        _interstitialAd = null;
        // Preload next ad
        loadInterstitial();
        onDoneFlow(true);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        SafeLogger.d(
          _tag,
          'showInterstitial ❌ Failed to Show: ${error.message}',
        );
        a.dispose();
        _interstitialAd = null;
        onDoneFlow(false);
      },
      onAdClicked: (a) {
        SafeLogger.d(_tag, 'showInterstitial 🎯 Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
    );
    ad.show();
  }

  void _showInterstitialAppLovin(void Function(bool) onDoneFlow) {
    if (!_isMaxInterReady) {
      SafeLogger.d(_tag, 'showInterstitial [AppLovin] ⏭️ Ad not ready');
      onDoneFlow(false);
      return;
    }
    SafeLogger.d(_tag, 'showInterstitial [AppLovin] 🔄 showing ad');
    // BUG FIX #6: mark not ready immediately to prevent double-show
    _isMaxInterReady = false;
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
      if (_isRewardedLoading) return;
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
      SafeLogger.d(_tag, 'showRewardedAd ⏭️ Ad not ready');
      onEarnedReward(false);
      return;
    }
    SafeLogger.d(_tag, 'showRewardedAd 🔄 showing ad');
    bool hasEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showRewardedAd ✅ Ad Shown full screen');
        AdSafetyConfig.recordFullscreenAdShown();
      },
      onAdDismissedFullScreenContent: (a) {
        SafeLogger.d(_tag, 'showRewardedAd ✅ Ad Dismissed by user');
        a.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next
        if (!hasEarned) onEarnedReward(false);
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        SafeLogger.d(
          _tag,
          'showRewardedAd ❌ Failed to Show: ${error.message}',
        );
        a.dispose();
        _rewardedAd = null;
        onEarnedReward(false);
      },
      onAdClicked: (a) {
        SafeLogger.d(_tag, 'showRewardedAd 🎯 Ad Clicked');
        AdSafetyConfig.recordAdClick();
      },
    );
    ad.show(onUserEarnedReward: (AdWithoutView a, RewardItem reward) {
      SafeLogger.d(_tag, '🏆 showRewardedAd Earned Reward: ${reward.amount}');
      hasEarned = true;
      onEarnedReward(true);
    });
  }

  void _showRewardedAppLovin(void Function(bool) onEarnedReward) {
    if (!_isMaxRewardedReady) {
      SafeLogger.d(_tag, 'showRewardedAd [AppLovin] ⏭️ Ad not ready');
      onEarnedReward(false);
      return;
    }
    SafeLogger.d(_tag, 'showRewardedAd [AppLovin] 🔄 showing ad');
    _isMaxRewardedReady = false;
    _pendingRewardedDoneFlow = onEarnedReward;
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
  // DESTROY — giải phóng toàn bộ resources
  // Gọi khi không cần ad nữa (ví dụ: khi thực sự cần reset)
  // ════════════════════════════════════════════════════
  void destroy() {
    SafeLogger.d(_tag, 'destroy() called - releasing all ad resources');
    // BUG FIX #4: call .dispose() before nullifying
    // AdMob cleanup
    _interstitialAd?.fullScreenContentCallback = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _appOpenAd?.fullScreenContentCallback = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _rewardedAd?.fullScreenContentCallback = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    // AppLovin cleanup
    _isMaxAppOpenReady = false;
    _isMaxAppOpenShowing = false;
    _isMaxInterReady = false;
    _isMaxRewardedReady = false;
    _pendingInterDoneFlow = null;
    _onAppOpenDismissed = null;
    _pendingAppOpenLoadCallback = null;
    _pendingRewardedDoneFlow = null;
    // Common cleanup
    _isAppOpenShowing = false;
    _isAppOpenLoading = false;
    _isRewardedLoading = false;
  }
}
