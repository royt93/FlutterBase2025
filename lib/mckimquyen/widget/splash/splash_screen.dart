import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ad_sdk/ad_sdk.dart';
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
  final ValueNotifier<Color> _containerColorNotifier = ValueNotifier(ColorConstants.appColor);
  // Callback listener giữ reference để remove đúng khi dispose/navigate
  void Function(BoolEvent)? _eventListener;
  Timer? _hardCapTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    AdManager().markSplashActive();
    AdManager().incrementSplashCount();
    final count = AdManager().countInitSplashScreen;
    SafeLogger.d('Splash', 'initSplashScreen called, count=$count');

    // Giống native line 991-993: nếu splash bị gọi lại lần 2+ → navigate ngay
    if (count > 1) {
      SafeLogger.d('Splash', 'initSplashScreen ⏭️ already called before, navigating immediately');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToMainSafely();
      });
      return;
    }

    // Hard cap 8s — chống treo splash (giống native MAX_TOTAL_SPLASH_MS)
    _hardCapTimer = Timer(const Duration(seconds: 8), () {
      SafeLogger.d('Splash', '⏰ HARD CAP 8s reached, forcing navigation');
      _navigateToMainSafely();
    });

    // Listen for ad init completion (callback-based SimpleEventBus)
    _eventListener = (event) {
      SafeLogger.d('Splash', 'EventBus received: ${event.value}, hasNavigated=$_hasNavigated');
      if (event.value && !_hasNavigated) {
        SafeLogger.d('Splash', '🔄 SDK init done, loading App Open Ad...');
        // Tải App Open Ad trước (giống native line 1046-1066)
        // Sau khi load xong mới show
        AdManager().loadAppOpenAd(onAdLoaded: (result) {
          SafeLogger.d('Splash', 'loadAppOpenAd result=$result, hasNavigated=$_hasNavigated');
          if (_hasNavigated) {
            SafeLogger.d('Splash', '⏭️ already navigated by hard cap, ignoring ad result');
            return;
          }
          if (result) {
            SafeLogger.d('Splash', '🔄 Ad loaded, showing 300ms buffer then App Open Ad');
            // 300ms buffer trước khi show App Open Ad
            if (!mounted) {
              _navigateToMainSafely();
              return;
            }
            AdLoadingDialog.showAdBuffer(context, onComplete: () {
              if (!mounted) {
                _navigateToMainSafely();
                return;
              }
              AdManager().showAppOpenAd(
                onAdDismiss: (dismissed) {
                  SafeLogger.d('Splash', 'App Open Ad dismissed=$dismissed, navigating');
                  _navigateToMainSafely();
                },
                bypassSafety: true,
              );
            });
          } else {
            // Ad không load được → navigate luôn
            SafeLogger.d('Splash', '⏭️ App Open Ad not available, navigating immediately');
            _navigateToMainSafely();
          }
        });
      } else if (!event.value) {
        SafeLogger.d('Splash', '⚠️ EventBus received false — SDK init issue');
        _navigateToMainSafely();
      }
    }; // end _eventListener
    SimpleEventBus().listen(_eventListener!);


    if (kDebugMode) {
      _durationCountdown = 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      DurationUtils.delay(300, () async {
        if (!mounted) return;
        // ValueNotifier thay cho setState — chỉ rebuild đúng widget con cần thiết
        _containerColorNotifier.value = Colors.transparent;
        SafeLogger.d('Splash', 'containerColor → transparent (animation started)');
        // Khởi tạo AdManager (gọi EventBus.sendEvent khi xong)
        AdManager().initialize(
          config: const AdConfig(
            provider: AdProvider.appLovin,
            appLovin: AppLovinConfig(
              sdkKey: 'e75FnQfS9XTTqM1Kne69U7PW_MBgAnGQTFvtwVVui6kRPKs5L7ws9twr5IQWwVfzPKZ5pF2IfDa7lguMgGlCyt',
              bannerId: '55145203d74b7bb0',
              interstitialId: 'f8c4de38486cdb76',
              appOpenId: '9309d90308be99c1',
              rewardedId: 'e50710c6caa75a33',
            ),
            vipDeviceGaids: [
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
          ),
          onComplete: (success, gaid) {
            SafeLogger.d('Splash', 'AdManager init complete: success=$success, gaid=$gaid');
          },
        );

      });
    });
  }

  void _navigateToMainSafely() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _hardCapTimer?.cancel();
    // Remove EventBus listener to prevent memory leak
    if (_eventListener != null) {
      SimpleEventBus().remove(_eventListener!);
      _eventListener = null;
    }
    AdManager().markSplashInactive();
    SafeLogger.d('Splash', '✅ Navigating to MainScreen');
    _goToMainScreen();
  }

  @override
  void dispose() {
    SafeLogger.d('Splash', 'dispose() — cancelling timers and subscriptions');
    _hardCapTimer?.cancel();
    // Remove EventBus listener to prevent accumulation
    if (_eventListener != null) {
      SimpleEventBus().remove(_eventListener!);
      _eventListener = null;
    }
    // Phải dispose ValueNotifier để tránh memory leak
    _containerColorNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            "assets/images/bkg_2.jpg",
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
                    //           "assets/images/ic_go.png",
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
                      child: const Text(
                        adPlsNoteEn,
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                      padding: EdgeInsets.fromLTRB(0, 16, 0, UIUtils.getPaddingBottom(context, ratio: 1.0)),
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
