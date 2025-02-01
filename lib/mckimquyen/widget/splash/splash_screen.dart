import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:circular_countdown_timer/circular_countdown_timer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/v/pulse_container.dart';
import 'package:saigonphantomlabs/mckimquyen/util/duration_util.dart';
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
  Color _containerColor = const Color(0xffFF1E63);

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _durationCountdown = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DurationUtils.delay(300, () {
        setState(() {
          _containerColor = Colors.transparent;
        });
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            "assets/images/bkg_1.jpg",
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
                  alignment: Alignment.center,
                  child: AnimatedTextKit(
                    animatedTexts: [
                      // ColorizeAnimatedText(
                      //   'Device',
                      //   textAlign: TextAlign.center,
                      //   textStyle: const TextStyle(
                      //     fontWeight: FontWeight.w900,
                      //     color: Colors.white,
                      //     fontSize: 70,
                      //   ),
                      //   colors: [
                      //     Colors.white,
                      //     Colors.green,
                      //     Colors.purple,
                      //     Colors.blue,
                      //     Colors.yellow,
                      //     Colors.red,
                      //   ],
                      // ),
                      // ColorizeAnimatedText(
                      //   'Mockup',
                      //   textAlign: TextAlign.center,
                      //   textStyle: const TextStyle(
                      //     fontWeight: FontWeight.w900,
                      //     color: Colors.white,
                      //     fontSize: 70,
                      //   ),
                      //   colors: [
                      //     Colors.white,
                      //     Colors.green,
                      //     Colors.purple,
                      //     Colors.blue,
                      //     Colors.yellow,
                      //     Colors.red,
                      //   ],
                      // ),
                      ColorizeAnimatedText(
                        speed: const Duration(milliseconds: 2000),
                        'Device Mockup',
                        textAlign: TextAlign.center,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontSize: 68,
                          // shadows: [
                          //   Shadow(
                          //     blurRadius: 5.0,
                          //     color: ColorConstants.disabledColor,
                          //     offset: const Offset(2.0, 2.0),
                          //   ),
                          // ],
                        ),
                        colors: [
                          Colors.white,
                          Colors.green,
                          Colors.purple,
                          Colors.blue,
                          Colors.yellow,
                          // Colors.red,
                          Colors.white,
                        ],
                      ),
                    ],
                    isRepeatingAnimation: true,
                    onTap: () {},
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    AvatarGlow(
                      glowColor: Colors.white,
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: PulseContainer(
                          onTapRoot: () {
                            _goToMainScreen();
                          },
                          color: Colors.white,
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              "assets/images/ic_go.png",
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Auto go to homepage after ",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        CircularCountDownTimer(
                          duration: _durationCountdown,
                          initialDuration: 0,
                          controller: CountDownController(),
                          width: 38,
                          height: 38,
                          ringColor: Colors.transparent,
                          ringGradient: null,
                          fillColor: Colors.white,
                          fillGradient: null,
                          backgroundColor: Colors.white.withOpacity(0.8),
                          backgroundGradient: null,
                          strokeWidth: 2.0,
                          strokeCap: StrokeCap.round,
                          textStyle: const TextStyle(
                            fontSize: 16.0,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          textFormat: CountdownTextFormat.S,
                          isReverse: true,
                          isReverseAnimation: false,
                          isTimerTextShown: true,
                          autoStart: true,
                          onStart: () {
                            // debugPrint('Countdown Started');
                          },
                          onComplete: () {
                            // debugPrint('Countdown Ended');
                            _goToMainScreen();
                          },
                          onChange: (String timeStamp) {
                            // debugPrint('Countdown Changed $timeStamp');
                          },
                          timeFormatterFunction: (defaultFormatterFunction, duration) {
                            return Function.apply(defaultFormatterFunction, [duration]);
                            // if (duration.inSeconds == 0) {
                            //   return "0";
                            // } else {
                            //   return Function.apply(defaultFormatterFunction, [duration]);
                            // }
                          },
                        ),
                        const Text(
                          " s.",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
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
    Get.offAll(() => const MainScreen());
  }
}
