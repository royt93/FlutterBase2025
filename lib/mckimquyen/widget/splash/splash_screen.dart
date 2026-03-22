import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/ad_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/event_bus.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/widget/ad_loading_dialog.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/util/duration_util.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/utils/safe_logger.dart';
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
  StreamSubscription? _subscription;
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

    // Listen for ad init completion
    _subscription = SimpleEventBus().onBoolEvent.listen((event) {
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
    });

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
        AdManager().initialize(onComplete: (success, gaid) {
          SafeLogger.d('Splash', 'AdManager init complete: success=$success, gaid=$gaid');
        });
      });
    });
  }

  void _navigateToMainSafely() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _hardCapTimer?.cancel();
    _subscription?.cancel();
    AdManager().markSplashInactive();
    SafeLogger.d('Splash', '✅ Navigating to MainScreen');
    _goToMainScreen();
  }

  @override
  void dispose() {
    SafeLogger.d('Splash', 'dispose() — cancelling timers and subscriptions');
    _hardCapTimer?.cancel();
    _subscription?.cancel();
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
          isShowMenu: kDebugMode,
        ));
  }
}
