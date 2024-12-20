import 'dart:io';

import 'package:gameoffline/mckimquyen/core/base_stateful_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'mckimquyen/common/const/color_constants.dart';
import 'mckimquyen/widget/controller_main.dart';
import 'mckimquyen/widget/splash/splash_screen.dart';

//TODO roy93~ multi language
//TODO roy93~ ad applovin
//TODO roy93~ add more device frame, maybe custom the library

//TODO roy93~ save template
//TODO roy93~ update more device
//TODO roy93~ watermark
//https://developer.apple.com/design/resources/#product-bezels
//https://mockuphone.com/type/all/

//screenOrientation
//review in app
//120hz
//add button reset default
//shadow text header + body
//touch element thi show bottom sheet tuong ung => bad practise ko nen lam
//visible text header + body
//keystore mckimquyen
//ic_launcher, flutter native splash, splash change bkg
//fix noti daily setting cai scrollbar ki ki
//ad id manifest
//app name
//pkg name
//splash screen

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();

  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
  await initializePlugin();
  runApp(
    GetMaterialApp(
      enableLog: true,
      debugShowCheckedModeBanner: true,
      // defaultTransition: Transition.noTransition,
      defaultTransition: Transition.cupertino,
      // defaultTransition: Transition.circularReveal,
      // defaultTransition: Transition.size,
      // transitionDuration: const Duration(milliseconds: 1000),
      transitionDuration: const Duration(milliseconds: 700),
      home: const MyApp(),
      // builder: EasyLoading.init(),

      //prevent breaking UI when change device font settings
      builder: (context, child) {
        return EasyLoading.init()(
          context,
          MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          ),
        );
      },

      navigatorKey: navigatorKey,
      theme: ThemeData.light().copyWith(
        primaryColor: ColorConstants.appColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        splashColor: ColorConstants.appColor,
        highlightColor: ColorConstants.appColor,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.light,
    ),
  );
  // _configLoading();
}

// void _configLoading() {
//   EasyLoading.instance
//     ..displayDuration = const Duration(milliseconds: 2000)
//     ..indicatorType = EasyLoadingIndicatorType.fadingCircle
//     ..loadingStyle = EasyLoadingStyle.dark
//     ..indicatorSize = 45.0
//     ..radius = 10.0
//     ..progressColor = Colors.yellow
//     ..backgroundColor = Colors.green
//     ..indicatorColor = Colors.yellow
//     ..textColor = Colors.yellow
//     ..maskColor = Colors.blue.withOpacity(0.5)
//     ..userInteractions = true
//     ..dismissOnTap = false
//     ..customAnimation = CustomAnimation();
// }

Future<void> initializePlugin() async {
  Get.put(ControllerMain());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends BaseStatefulState<MyApp> {
  final ControllerMain _controllerMain = Get.find();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Mockup',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const Scaffold(
        body: SplashScreen(),
      ),
    );
  }
}
