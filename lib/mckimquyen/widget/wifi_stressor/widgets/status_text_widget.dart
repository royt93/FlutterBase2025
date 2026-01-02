import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../stressor_controller.dart';

/// Widget hiển thị text trạng thái test
class StatusTextWidget extends StatelessWidget {
  final bool isRunning;
  final StressorController controller;

  const StatusTextWidget({
    super.key,
    required this.isRunning,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRunning) {
      return Text(
        'status_ready'.tr,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Wrap chỉ phần dynamic trong Obx riêng
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${'status_testing'.tr} ',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Obx(() => Text(
          '${controller.downloadCount.value}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )),
      ],
    );
  }
}
