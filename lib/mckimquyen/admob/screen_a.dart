import 'package:flutter/material.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_screen.dart';

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
    showAppOpenAd();
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Coins: $_coins', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 20),
                _buildControlButtons(),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/screenB'),
                  child: const Text('Go to Screen B'),
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

  Widget _buildControlButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: showInterstitialAd,
          child: const Text('Show Interstitial Ad'),
        ),
        const SizedBox(height: 10),
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
