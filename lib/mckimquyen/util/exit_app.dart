import 'package:saigonphantomlabs/mckimquyen/common/const/string_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/controller_main.dart';
import 'package:flutter/services.dart';

class ExitApp {
  static DateTime? currentBackPressTime;

  static Future<void> handlePop(ControllerMain controller) async {
    DateTime now = DateTime.now();
    if (currentBackPressTime == null || now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
      currentBackPressTime = now;
      controller.showFullWidthSnackBar(
        StringConstants.warning,
        "Please click BACK again to exit",
      );
    } else {
      SystemNavigator.pop();
    }
  }
}
