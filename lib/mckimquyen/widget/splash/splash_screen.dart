import 'dart:async';

// Removed unused dependency: animated_text_kit
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/event_bus.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/util/duration_util.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/main/main_screen.dart';

import '../../core/base_stateful_state.dart';
import '../controller_main.dart';

class SplashScreen extends StatefulWidget {
  static String screenName = "/SplashScreen";

  const SplashScreen({
    super.key,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends BaseStatefulState<SplashScreen> {
  final ControllerMain _controllerMain = Get.find();
  int _durationCountdown = 10;
  Color _containerColor = ColorConstants.appColor;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = SimpleEventBus().onBoolEvent.listen((event) {
      debugPrint("roy93~ >>>>>>>>>>>>>>onBoolEvent listen event ${event.value}");
      _goToMainScreen();
    });
    if (kDebugMode) {
      _durationCountdown = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DurationUtils.delay(300, () async {
        setState(() {
          _containerColor = Colors.transparent;
        });
        var isInitializedAdmob = await checkLogicSplashScreenIsInitializedAdmob();
        if (!isInitializedAdmob) {
          _goToMainScreen();
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
          AnimatedContainer(
            width: double.infinity,
            height: double.infinity,
            duration: Duration(seconds: _durationCountdown - 1),
            color: _containerColor,
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
                    //         // debugPrint('Countdown Started');
                    //       },
                    //       onComplete: () {
                    //         // debugPrint('Countdown Ended');
                    //         _goToMainScreen();
                    //       },
                    //       onChange: (String timeStamp) {
                    //         // debugPrint('Countdown Changed $timeStamp');
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
