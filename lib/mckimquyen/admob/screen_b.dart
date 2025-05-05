import 'package:flutter/material.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_screen.dart';

class ScreenB extends AdScreen {
  const ScreenB({super.key});

  @override
  State<ScreenB> createState() => _ScreenBState();
}

class _ScreenBState extends AdScreenState<ScreenB> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAd();
    });
  }

  Future<void> _initAd() async {
    await Future.wait([
      loadInterstitialAd(),
      loadRewardedAd(),
    ]);
    loadBannerAd();
  }

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
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: showInterstitialAd,
                  child: const Text('Show Interstitial Ad'),
                ),
                const SizedBox(height: 16),
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
