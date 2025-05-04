import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';

abstract class AdScreen extends StatefulWidget {
  const AdScreen({super.key});
}

abstract class AdScreenState<T extends AdScreen> extends State<T> with WidgetsBindingObserver {
  BannerAd? bannerAd;
  InterstitialAd? interstitialAd;
  RewardedAd? rewardedAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    bannerAd?.dispose();
    interstitialAd?.dispose();
    rewardedAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AdMobManager().showAppOpenAd();
    }
  }

  Future<void> _initializeAds() async {
    await _loadBannerAd();
    await _loadInterstitialAd();
    await _loadRewardedAd();
  }

  Future<void> _loadBannerAd() async {
    bannerAd?.dispose();
    final size = await AdMobManager.getAdaptiveBannerSize(context);
    if (size != null) {
      bannerAd = AdMobManager.createBannerAd(
        size: size,
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _loadInterstitialAd() async {
    interstitialAd?.dispose();
    interstitialAd = await AdMobManager.createInterstitialAd();
    setState(() {});
  }

  Future<void> _loadRewardedAd() async {
    rewardedAd?.dispose();
    rewardedAd = await AdMobManager.createRewardedAd();
    setState(() {});
  }

  Widget buildBanner() {
    return bannerAd != null
        ? SizedBox(
            width: bannerAd!.size.width.toDouble(),
            height: bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: bannerAd!),
          )
        : const SizedBox();
  }

  void showInterstitialAd() {
    if (interstitialAd == null) return;

    interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _loadInterstitialAd();
      },
    );

    interstitialAd?.show();
  }

  void showRewardedAd({required VoidCallback onReward}) {
    if (rewardedAd == null) return;

    rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _loadRewardedAd();
      },
    );

    rewardedAd?.show(onUserEarnedReward: (_, __) => onReward());
  }
}
