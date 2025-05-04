import 'package:flutter/material.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_screen.dart';

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: showInterstitialAd,
                  child: const Text('Show Interstitial Ad'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => showRewardedAd(onReward: () {}),
                  child: const Text('Show Rewarded Ad'),
                ),
              ],
            ),
          ),
          const Spacer(),
          buildBanner(),
        ],
      ),
    );
  }
}
