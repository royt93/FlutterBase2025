import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/core/base_stateful_state.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
import 'package:toastification/toastification.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'mckimquyen/common/const/color_constants.dart';
import 'mckimquyen/ad/ad_route_observer.dart';
import 'mckimquyen/widget/controller_main.dart';
import 'mckimquyen/widget/splash/splash_screen.dart';
import 'mckimquyen/util/language_service.dart';
import 'translations/app_translations.dart';

//TODO roy93~ multi language
//TODO roy93~ admob
//ic_launcher, flutter native splash, splash change bkg

//done
//Please note: this action may show ads
//screenOrientation
//review in app
//120hz
//keystore mckimquyen
//ad id manifest
//app name
//pkg name

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // AdManager init is now handled in SplashScreen
  WakelockPlus.enable();
  UIUtils.initEdgeToEdge();
  if (Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
  await initializePlugin();

  // Load saved language preference
  final savedLocale = await LanguageService.getSavedLanguage();

  runApp(
    ToastificationWrapper(
      child: GetMaterialApp(
        enableLog: true,
        debugShowCheckedModeBanner: true,
        // defaultTransition: Transition.noTransition,
        defaultTransition: Transition.cupertino,
        // defaultTransition: Transition.circularReveal,
        // defaultTransition: Transition.size,
        // transitionDuration: const Duration(milliseconds: 1000),
        transitionDuration: const Duration(milliseconds: 700),

        // Multi-language configuration
        translations: AppTranslations(),
        locale: savedLocale ?? const Locale('vi', 'VN'), // Use saved or default to Vietnamese
        fallbackLocale: const Locale('en', 'US'),

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
        navigatorObservers: [
          adRouteObserver, // RouteAware cho BannerAdWidget pause/resume
          AdScreenRouteLogger(), // Log mọi route push/pop để track navigation
        ],
        theme: ThemeData.light().copyWith(
          primaryColor: ColorConstants.appColor,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          splashColor: ColorConstants.appColor,
          highlightColor: ColorConstants.appColor,
        ),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.light,
      ),
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
  // final ControllerMain _controllerMain = Get.find();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RoyApp',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const Scaffold(
        body: SplashScreen(),
      ),
    );
  }
}
