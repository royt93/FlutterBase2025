import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:applovin_admob_sdk/applovin_admob_sdk.dart'; // adMayAppearEn

import '../stressor_controller.dart';

/// Widget hiển thị control button (Start/Stop)
class ControlButtonWidget extends StatelessWidget {
  final bool isRunning;
  final StressorController controller;

  const ControlButtonWidget({
    super.key,
    required this.isRunning,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (isRunning) {
      return FilledButton.icon(
        onPressed: () {
          // Policy: interstitials only fire on a real screen transition
          // (opening History). Start/Stop stay on the same screen, so we run
          // the action immediately and never interrupt the core feature.
          controller.stopStressTest();
        },
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(45),
          ),
        ),
        icon: const Icon(Icons.stop),
        label: Text('stop_test'.tr, style: const TextStyle(fontSize: 16)),
      );
    }

    return FilledButton.icon(
      onPressed: () {
        // Policy: do NOT show an interstitial when the user STARTS the test —
        // that interrupts an action the user just requested (Google/AppLovin
        // "interruptive placement"). Run the feature immediately. Interstitials
        // are reserved for real screen transitions (opening History).
        controller.startStressTest();
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(45),
        ),
      ),
      icon: const Icon(Icons.play_arrow),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('start_test'.tr, style: const TextStyle(fontSize: 16)),
          Container(
            color: Colors.transparent,
            width: 120,
            alignment: Alignment.bottomCenter,
            child: const Text(
              adMayAppearEn,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
