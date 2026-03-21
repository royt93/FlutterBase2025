import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/ad_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/screen_c.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/utils/safe_logger.dart';

class ScreenB extends AdScreen {
  const ScreenB({super.key});

  @override
  State<ScreenB> createState() => _ScreenBState();
}

class _ScreenBState extends AdScreenState<ScreenB> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen B'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      showInterstitialAd(onDone: (value) {
                        SafeLogger.d(
                            'ScreenB', 'showInterstitialAd result: $value');
                        Get.to(const ScreenC());
                      });
                    },
                    child: const Text(
                        'Show Interstitial Ad\n(Ads may appear)'),
                  ),
                ],
              ),
            ),
            const Spacer(),
            buildBanner(),
          ],
        ),
      ),
    );
  }
}
