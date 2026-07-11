import 'dart:async';

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/ad_keys.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/util/duration_util.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/main/main_screen.dart';

import '../../core/base_stateful_state.dart';

class SplashScreen extends StatefulWidget {
  static String screenName = "/SplashScreen";

  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends BaseStatefulState<SplashScreen> {
  int _durationCountdown = 10;

  // ValueNotifier thay cho setState — không trigger rebuild toàn bộ widget
  final ValueNotifier<Color> _containerColorNotifier =
      ValueNotifier(ColorConstants.appColor);

  // Callback listener giữ reference để remove đúng khi dispose/navigate
  void Function(BoolEvent)? _eventListener;
  Timer? _hardCapTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    SafeLogger.d('SplashTrace', 'initState start mounted=$mounted');
    AdManager().markSplashActive();
    AdManager().incrementSplashCount();
    final count = AdManager().countInitSplashScreen;
    SafeLogger.d('SplashTrace', 'splash marked active count=$count');
    SafeLogger.d('Splash', 'initSplashScreen called, count=$count');

    // Giống native line 991-993: nếu splash bị gọi lại lần 2+ → navigate ngay
    if (count > 1) {
      SafeLogger.w('SplashTrace',
          'duplicate splash count=$count -> navigate immediately');
      SafeLogger.d('Splash',
          'initSplashScreen ⏭️ already called before, navigating immediately');
      // Mark inactive synchronously so any concurrent lifecycle resume in the
      // 1-frame postFrame gap doesn't see splash as still active.
      AdManager().markSplashInactive();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SafeLogger.d('SplashTrace', 'duplicate splash postFrame navigate');
        _navigateToMainSafely();
      });
      return;
    }

    // Hard cap 8s — chống treo splash (giống native MAX_TOTAL_SPLASH_MS)
    SafeLogger.d('SplashTrace', 'hard cap timer armed 8s');
    _hardCapTimer = Timer(const Duration(seconds: 8), () {
      SafeLogger.w('SplashTrace',
          'hard cap fired hasNavigated=$_hasNavigated mounted=$mounted');
      SafeLogger.d('Splash', '⏰ HARD CAP 8s reached, forcing navigation');
      _navigateToMainSafely();
    });

    // Listen for ad init completion (callback-based SimpleEventBus)
    _eventListener = (event) {
      SafeLogger.d('SplashTrace',
          'EventBus value=${event.value} hasNavigated=$_hasNavigated');
      SafeLogger.d('Splash',
          'EventBus received: ${event.value}, hasNavigated=$_hasNavigated');
      if (event.value && !_hasNavigated) {
        SafeLogger.d(
            'SplashTrace', 'SDK init event true -> loadAppOpenAd start');
        SafeLogger.d('Splash', '🔄 SDK init done, loading App Open Ad...');
        // Tải App Open Ad trước (giống native line 1046-1066)
        // Sau khi load xong mới show
        AdManager().loadAppOpenAd(onAdLoaded: (result) {
          SafeLogger.d('SplashTrace',
              'loadAppOpenAd done result=$result hasNavigated=$_hasNavigated mounted=$mounted');
          SafeLogger.d('Splash',
              'loadAppOpenAd result=$result, hasNavigated=$_hasNavigated');
          if (_hasNavigated) {
            SafeLogger.w('SplashTrace',
                'loadAppOpenAd ignored because already navigated');
            SafeLogger.d('Splash',
                '⏭️ already navigated by hard cap, ignoring ad result');
            return;
          }
          if (result) {
            SafeLogger.d('SplashTrace', 'App Open loaded -> show buffer');
            SafeLogger.d('Splash',
                '🔄 Ad loaded, showing AdLoadingDialog buffer (default loadingBufferMs=1000) then App Open Ad');
            if (!mounted) {
              SafeLogger.w(
                  'SplashTrace', 'not mounted before buffer -> navigate');
              _navigateToMainSafely();
              return;
            }
            AdLoadingDialog.showAdBuffer(context, onComplete: () {
              SafeLogger.d('SplashTrace',
                  'ad buffer complete mounted=$mounted hasNavigated=$_hasNavigated');
              if (!mounted) {
                SafeLogger.w(
                    'SplashTrace', 'not mounted after buffer -> navigate');
                _navigateToMainSafely();
                return;
              }
              // Cancel hard cap BEFORE showing ad — timer must not interrupt an active ad
              _hardCapTimer?.cancel();
              _hardCapTimer = null;
              SafeLogger.d(
                  'SplashTrace', 'hard cap cancelled -> showAppOpenAd');
              AdManager().showAppOpenAd(
                onAdDismiss: (dismissed) {
                  SafeLogger.d('SplashTrace',
                      'showAppOpenAd dismissed=$dismissed -> navigate');
                  SafeLogger.d(
                      'Splash', 'App Open Ad dismissed=$dismissed, navigating');
                  _navigateToMainSafely();
                },
                bypassSafety: true,
              );
            });
          } else {
            // Ad không load được → navigate luôn
            SafeLogger.w('SplashTrace', 'App Open not available -> navigate');
            SafeLogger.d('Splash',
                '⏭️ App Open Ad not available, navigating immediately');
            _navigateToMainSafely();
          }
        });
      } else if (!event.value) {
        SafeLogger.w('SplashTrace', 'SDK init event false -> navigate');
        SafeLogger.d('Splash', '⚠️ EventBus received false — SDK init issue');
        _navigateToMainSafely();
      }
    }; // end _eventListener
    SimpleEventBus().listen(_eventListener!);
    SafeLogger.d('SplashTrace', 'SimpleEventBus listener registered');

    if (kDebugMode) {
      _durationCountdown = 1;
      SafeLogger.d('SplashTrace',
          'debug mode countdown shortened to $_durationCountdown');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SafeLogger.d('SplashTrace', 'postFrame callback start');
      DurationUtils.delay(300, () async {
        SafeLogger.d('SplashTrace',
            'delayed init block start mounted=$mounted hasNavigated=$_hasNavigated');
        if (!mounted) return;
        // ValueNotifier thay cho setState — chỉ rebuild đúng widget con cần thiết
        _containerColorNotifier.value = Colors.transparent;
        SafeLogger.d('SplashTrace', 'splash animation color transparent');
        SafeLogger.d(
            'Splash', 'containerColor → transparent (animation started)');

        // ─── ATT (iOS App Tracking Transparency) ──────────────────────────
        // Phải hiện TRƯỚC UMP để IDFA được quyết định trước first ad request.
        // No-op trên Android. Yêu cầu NSUserTrackingUsageDescription trong
        // Info.plist (đã có). SDK tự xử lý lỗi → trả denied, không throw.
        try {
          SafeLogger.d('SplashTrace', 'ATT request start');
          final attResult = await AdManager().requestAtt();
          SafeLogger.d(
              'SplashTrace', 'ATT done status=${attResult.status.name}');
        } catch (e) {
          SafeLogger.w('SplashTrace', 'ATT threw -> continue error=$e');
        }
        if (!mounted || _hasNavigated) return;

        // ─── UMP consent (Q3C: Global) ────────────────────────────────────
        // Phải gọi TRƯỚC initialize() — Google policy yêu cầu form consent
        // hiện trước first ad request cho user EEA. Non-EEA trả về tức thì.
        // Q12B: KHÔNG force EEA trong debug — để geo thật quyết định.
        // Q11A: dù canRequestAds==false vẫn init bình thường, SDK đã buffer
        // AdConsent (non-personalized) qua setConsent ở bên trong.
        try {
          SafeLogger.d('SplashTrace', 'UMP request start testMode=false');
          final umpResult = await AdManager().requestUmpConsent(
            testMode: false,
          );
          SafeLogger.d('SplashTrace',
              'UMP request done canRequestAds=${umpResult.canRequestAds} status=${umpResult.status.name} formShown=${umpResult.formShown}');
          SafeLogger.d('Splash',
              'UMP done: canRequestAds=${umpResult.canRequestAds}, status=${umpResult.status.name}, formShown=${umpResult.formShown}');
        } catch (e) {
          SafeLogger.w('SplashTrace', 'UMP threw -> continue init error=$e');
          SafeLogger.w('Splash', 'UMP threw, continuing init anyway: $e');
        }
        // Phải gọi dù mounted==false hoặc _hasNavigated==true — nếu hard-cap
        // timer đã điều hướng đi trước khi ATT/UMP await xong (form GDPR
        // chậm), SDK sẽ không bao giờ init cho cả phiên app nếu return sớm ở
        // đây (không dùng context nên không cần mounted check).
        SafeLogger.d('SplashTrace',
            'AdManager.initialize proceeding mounted=$mounted hasNavigated=$_hasNavigated');

        // Khởi tạo AdManager (gọi EventBus.sendEvent khi xong)
        SafeLogger.d(
            'SplashTrace', 'AdManager.initialize start provider=appLovin');
        AdManager().initialize(
          config: AdConfig(
            provider: AdProvider.appLovin,
            appLovin: AdKey.appLovin,
            // AdMob populated for swap-readiness (currently unused — provider
            // is appLovin). See `lib/mckimquyen/common/const/ad_keys.dart`.
            admob: AdKey.adMob,
            // Q16B: keep legacy GAID list — SDK auto-migrates to VipManager
            // entries (year-2099) for the matching device only.
            vipDeviceGaids: const [
              '9ad0127d-04be-4b6c-937a-ca3ed7f650b9', // vsmart iris
              '9b6499f2-d4de-4b9e-afdf-ac2a2b127fb1', // ss a50
              'c09b2f04-e145-490c-96f9-dab620074104', // oppo f7
              'c228aa08-bedd-4e6e-adf6-ae5e95bcddae', // vivo v15
              '46259467-0ac4-49c4-a3a2-7d3db3ce4bda', // tecno spark 20 pro+
              '1b7c3e3f-c709-4e85-b26f-dd74c4df2ed7', // vivo 1906
              'adaa42e7-9cc6-4a8a-9c90-d4d87842b12c', // tecno spark go 2024
              'f5a36a2f-5add-4315-a171-0f8dddab78c7', // ss s20u
              '6fbb207d-341d-470d-bb0a-dddd79522b32', // ss a52
              '40f8e222-cf7a-4fac-9913-6809c4c58817', // mipad 5
              '932099db-d381-4b52-98dc-5b96ba8b4ff4', // oppo reno 2f
              'a1339bd1-8ea5-47cd-969e-4b5721b576b7', // redmi note 8+
              '3f2f21d2-85eb-451b-a1a5-003668ba6345', // zte blade
              '261f772c-6a10-499c-b896-4157d9ab6a25', // ss a11
              '460d3f5c-bbe2-46fc-841a-6381e3c93864', // redmi95
              '49606ad7-5cee-43b4-9af7-8aa274644737', // redmi note 13 pro
              '6cf051f8-83f5-43b7-8c1a-1d20ae1f8d93', // redmi pad pro
              'da10cb05-5458-42df-ba86-630732356b35', // vivo z9
              '8f6ccdc1-08fd-4611-abdf-f48bdadb5581', // tablet lenovo
              '66e652de-79ef-4889-8074-9b482fd81b5a', // redmi a3
              '4ed22dd8-e8fb-442e-a75e-081a3d977957', // ss s24u
            ],
            adNotReadyMessage: 'ad_not_ready'.tr,
            adLoadingMessage: 'loading'.tr,

            // Q5: production-quiet logging.
            logLevel: kDebugMode ? AdLogLevel.verbose : AdLogLevel.warning,

            // Q1A + Q9B: Cupertino consent dialog strings từ translations
            // (đồng bộ với vi/en đang chạy trong app).
            consentDialogStrings: ConsentDialogStrings(
              title: 'consent_title'.tr,
              message: 'consent_message'.tr,
              allowButton: 'consent_allow'.tr,
              rejectButton: 'consent_reject'.tr,
              privacyPolicyLabel: 'consent_privacy_label'.tr,
              privacyPolicyUrl: AdKey.privacyPolicyUrl,
            ),

            // VIP redeem dùng signed key offline (T18) qua
            // VipManager.redeemSignedKey — không cần AdConfig.vipKeyValidator.

            // Cap tổng thời gian VIP cộng dồn (stack) ở 90 ngày — chặn lạm dụng
            // (vd bấm key nhiều lần / xem ad liên tục). null = không cap.
            maxVipStackDuration: const Duration(days: 90),

            // VIP redeem Cupertino dialog strings từ translations.
            vipDialogStrings: VipDialogStrings(
              verifyingTitle: 'vip_verifying_title'.tr,
              verifyingMessage: 'vip_verifying_message'.tr,
              successTitle: 'vip_success_title'.tr,
              successMessageBuilder: (until) =>
                  'vip_success_message'.trParams({'until': until}),
              failedTitle: 'vip_failed_title'.tr,
              failedMessage: 'vip_failed_message'.tr,
              networkErrorMessage: 'vip_network_error'.tr,
              confirmButton: 'vip_confirm'.tr,
            ),

            // Q2B: keep default firstInstallVipGrace (auto = 30s debug / 24h
            // release) — well-documented retention boost. Not overridden.
          ),
          onComplete: (success, gaid) {
            SafeLogger.d('SplashTrace',
                'AdManager.initialize complete success=$success gaid=$gaid');
            SafeLogger.d('Splash',
                'AdManager init complete: success=$success, gaid=$gaid');
          },
        );
      });
    });
  }

  void _navigateToMainSafely() {
    if (_hasNavigated) {
      SafeLogger.d('SplashTrace', 'navigate ignored because already navigated');
      return;
    }
    SafeLogger.d('SplashTrace', 'navigateToMain start mounted=$mounted');
    _hasNavigated = true;
    _hardCapTimer?.cancel();
    // Remove EventBus listener to prevent memory leak
    if (_eventListener != null) {
      SimpleEventBus().remove(_eventListener!);
      _eventListener = null;
      SafeLogger.d('SplashTrace', 'EventBus listener removed');
    }
    AdManager().markSplashInactive();
    SafeLogger.d('SplashTrace', 'splash marked inactive -> go main');
    SafeLogger.d('Splash', '✅ Navigating to MainScreen');
    _goToMainScreen();
  }

  @override
  void dispose() {
    SafeLogger.d('SplashTrace', 'dispose start hasNavigated=$_hasNavigated');
    SafeLogger.d('Splash', 'dispose() — cancelling timers and subscriptions');
    _hardCapTimer?.cancel();
    // Remove EventBus listener to prevent accumulation
    if (_eventListener != null) {
      SimpleEventBus().remove(_eventListener!);
      _eventListener = null;
      SafeLogger.d('SplashTrace', 'dispose removed EventBus listener');
    }
    // Phải dispose ValueNotifier để tránh memory leak
    _containerColorNotifier.dispose();
    SafeLogger.d('SplashTrace', 'dispose done');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            "assets/images/bkg_2.webp",
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
          ValueListenableBuilder<Color>(
            valueListenable: _containerColorNotifier,
            builder: (context, containerColor, _) {
              return AnimatedContainer(
                width: double.infinity,
                height: double.infinity,
                duration: Duration(seconds: _durationCountdown - 1),
                color: containerColor,
              );
            },
          ),
          Column(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  alignment: Alignment.center,
                  child: const Text(
                    'FastNet\nSpeed Test',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 48,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // AvatarGlow(
                    //   glowColor: Colors.white,
                    //   child: SizedBox(
                    //     width: 120,
                    //     height: 120,
                    //     child: PulseContainer(
                    //       onTapRoot: () {
                    //         _goToMainScreen();
                    //       },
                    //       color: Colors.white,
                    //       alignment: Alignment.center,
                    //       child: Padding(
                    //         padding: const EdgeInsets.all(16),
                    //         child: Image.asset(
                    //           "assets/images/ic_go.webp",
                    //           width: double.infinity,
                    //           height: double.infinity,
                    //           fit: BoxFit.contain,
                    //         ),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    // const SizedBox(height: 8),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.center,
                    //   children: [
                    //     const Text(
                    //       "Auto go to homepage after ",
                    //       style: TextStyle(
                    //         fontWeight: FontWeight.bold,
                    //         fontSize: 16,
                    //         color: Colors.white,
                    //         shadows: [
                    //           Shadow(
                    //             blurRadius: 5.0,
                    //             color: Colors.black,
                    //             offset: Offset(1.0, 1.0),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //     CircularCountDownTimer(
                    //       duration: _durationCountdown,
                    //       initialDuration: 0,
                    //       controller: CountDownController(),
                    //       width: 38,
                    //       height: 38,
                    //       ringColor: Colors.transparent,
                    //       ringGradient: null,
                    //       fillColor: Colors.white,
                    //       fillGradient: null,
                    //       backgroundColor: Colors.white.withOpacity(0.8),
                    //       backgroundGradient: null,
                    //       strokeWidth: 2.0,
                    //       strokeCap: StrokeCap.round,
                    //       textStyle: const TextStyle(
                    //         fontSize: 16.0,
                    //         color: Colors.black,
                    //         fontWeight: FontWeight.bold,
                    //       ),
                    //       textFormat: CountdownTextFormat.S,
                    //       isReverse: true,
                    //       isReverseAnimation: false,
                    //       isTimerTextShown: true,
                    //       autoStart: true,
                    //       onStart: () {
                    //         // SafeLogger.d('Log', 'Countdown Started');
                    //       },
                    //       onComplete: () {
                    //         // SafeLogger.d('Log', 'Countdown Ended');
                    //         _goToMainScreen();
                    //       },
                    //       onChange: (String timeStamp) {
                    //         // SafeLogger.d('Log', 'Countdown Changed $timeStamp');
                    //       },
                    //       timeFormatterFunction: (defaultFormatterFunction, duration) {
                    //         return Function.apply(defaultFormatterFunction, [duration]);
                    //         // if (duration.inSeconds == 0) {
                    //         //   return "0";
                    //         // } else {
                    //         //   return Function.apply(defaultFormatterFunction, [duration]);
                    //         // }
                    //       },
                    //     ),
                    //     const Text(
                    //       " s.",
                    //       style: TextStyle(
                    //         fontWeight: FontWeight.bold,
                    //         fontSize: 16,
                    //         color: Colors.white,
                    //         shadows: [
                    //           Shadow(
                    //             blurRadius: 5.0,
                    //             color: Colors.black,
                    //             offset: Offset(1.0, 1.0),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ],
                    // ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Text(
                        'splash_ads_notice'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 5.0,
                              color: Colors.black,
                              offset: Offset(1.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(0, 16, 0,
                          UIUtils.getPaddingBottom(context, ratio: 1.0)),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(0),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _goToMainScreen() async {
    Get.offAll(() => const MainScreen(
          // isShowMenu: kDebugMode,
          isShowMenu: false,
        ));
  }
}
