import 'package:flutter/services.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/string_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/controller_main.dart';
import 'package:toastification/toastification.dart';

class ExitApp {
  static DateTime? currentBackPressTime;

  static Future<void> handlePop(ControllerMain controller) async {
    DateTime now = DateTime.now();
    if (currentBackPressTime == null || now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
      currentBackPressTime = now;
      UIUtils.showToast(
        StringConstants.warning,
        "Please click BACK again to exit",
        type: ToastificationType.info,
      );
    } else {
      SystemNavigator.pop();
    }
  }
}
