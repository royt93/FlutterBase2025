import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/screen_b.dart';

class ScreenA extends AdScreen {
  const ScreenA({super.key});

  @override
  State<ScreenA> createState() => _ScreenAState();
}

class _ScreenAState extends AdScreenState<ScreenA> {
  int _coins = 0;

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
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen A'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ads_click),
            onPressed: showAppOpenAd,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text('Coins: $_coins', style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 16),
                  _buildControlButtons(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Get.to(const ScreenB());
                    },
                    child: const Text('Go to Screen B'),
                  ),
                ],
              ),
            ),
          ),
          buildBanner(),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: showInterstitialAd,
          child: const Text('Show Interstitial Ad'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => showRewardedAd(
            onReward: () => setState(() => _coins += 10),
          ),
          child: const Text('Watch Video for 10 Coins'),
        ),
      ],
    );
  }
}
