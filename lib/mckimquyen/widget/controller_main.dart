import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';

import '../core/base_controller.dart';

class ControllerMain extends BaseController {
  void showFullWidthSnackBar(
      String title,
      String message, {
        bool isTop = true,
        int durationInS = 2,
      }) {
    Get.snackbar(
      title,
      message,
      isDismissible: true,
      duration: Duration(seconds: durationInS),
      titleText: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xff232426),
        ),
      ),
      icon: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 0, 0),
        child: const Image(
          image: AssetImage('assets/images/ic_check_mark_green.png'),
          width: 56,
          height: 56,
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 212, 245, 217),
      snackStyle: SnackStyle.GROUNDED,
      margin: EdgeInsets.zero,
      colorText: const Color.fromARGB(255, 35, 36, 38),
      snackPosition: isTop ? SnackPosition.TOP : SnackPosition.BOTTOM,
    );
  }

  void showFullWidthSnackBarError(String title, String message, {bool isTop = true}) {
    Get.snackbar(
      title,
      message,
      isDismissible: true,
      duration: const Duration(seconds: 2),
      titleText: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xff232426),
        ),
      ),
      icon: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 0, 0),
        child: const Image(
          image: AssetImage('assets/images/ic_x.png'),
          width: 56,
          height: 56,
        ),
      ),
      backgroundColor: const Color(0xffFFDFDF),
      snackStyle: SnackStyle.GROUNDED,
      margin: EdgeInsets.zero,
      colorText: const Color(0xff232426),
      snackPosition: isTop ? SnackPosition.TOP : SnackPosition.BOTTOM,
    );
  }
}
