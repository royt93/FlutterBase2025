import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/ad_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/screen_b.dart';
import 'package:saigonphantomlabs/mckimquyen/ad/utils/safe_logger.dart';

class ScreenA extends AdScreen {
  const ScreenA({super.key});

  @override
  State<ScreenA> createState() => _ScreenAState();
}

class _ScreenAState extends AdScreenState<ScreenA> {
  final ValueNotifier<int> _coinsNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _coinsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen A'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: _coinsNotifier,
                      builder: (context, coins, _) {
                        return Text('Coins: $coins',
                            style: const TextStyle(fontSize: 24));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildControlButtons(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            buildBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            showInterstitialAd(onDone: (value) {
              SafeLogger.d('ScreenA', 'showInterstitialAd result: $value');
              Get.to(const ScreenB());
            });
          },
          child: const Text('Go to Screen B\n (Ads may appear)'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            showRewardedAd(
              onEarnedReward: (earned) {
                if (earned) {
                  SafeLogger.d('ScreenA', '🎉 User fully watched the ad. Rewarding 10 coins!');
                  _coinsNotifier.value += 10;
                } else {
                  SafeLogger.d('ScreenA', '❌ Ad dismissed early or failed to load. No reward.');
                }
              },
            );
          },
          child: const Text('Watch Ad for 10 Coins'),
        ),

      ],
    );
  }
}
