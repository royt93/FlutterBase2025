import 'package:flutter/material.dart';
import 'package:get/get.dart';

void backScreen() {
  var c = Get.context;
  if (c == null) {
    return;
  }
  if (Navigator.canPop(c)) {
    // Kiểm tra nếu có màn hình để back
    Get.back(); // Chỉ back screen
  } else {
    // Nếu không có màn hình nào để back, không làm gì cả
  }
}
