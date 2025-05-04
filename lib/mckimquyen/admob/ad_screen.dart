import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';

abstract class AdScreen extends StatefulWidget {
  const AdScreen({super.key});
}

abstract class AdScreenState<T extends AdScreen> extends State<T> {
  final ValueNotifier<BannerAd?> bannerNotifier = ValueNotifier(null);
  final ValueNotifier<InterstitialAd?> interstitialNotifier = ValueNotifier(null);
  final ValueNotifier<RewardedAd?> rewardedNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _initializeAds();
  }

  @override
  void dispose() {
    bannerNotifier.value?.dispose();
    interstitialNotifier.value?.dispose();
    rewardedNotifier.value?.dispose();
    bannerNotifier.dispose();
    interstitialNotifier.dispose();
    rewardedNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeAds() async {
    await Future.wait([
      _loadBannerAd(),
      _loadInterstitialAd(),
      _loadRewardedAd(),
    ]);
  }

  Future<void> _loadBannerAd() async {
    bannerNotifier.value?.dispose();
    final size = await AdMobManager.getAdaptiveBannerSize(context);
    if (size != null) {
      final newAd = AdMobManager.createBannerAd(
        size: size,
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      );
      bannerNotifier.value = newAd;
    }
  }

  Future<void> _loadInterstitialAd() async {
    interstitialNotifier.value?.dispose();
    interstitialNotifier.value = await AdMobManager.createInterstitialAd();
  }

  Future<void> _loadRewardedAd() async {
    rewardedNotifier.value?.dispose();
    rewardedNotifier.value = await AdMobManager.createRewardedAd();
  }

  Widget buildBanner() {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: bannerNotifier,
      builder: (context, ad, _) {
        return ad != null
            ? SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              )
            : const SizedBox();
      },
    );
  }

  void showAppOpenAd() {
    AdMobManager().showAppOpenAd();
  }

  void showInterstitialAd() {
    final ad = interstitialNotifier.value;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitialAd();
      },
    );
    ad.show();
  }

  void showRewardedAd({required VoidCallback onReward}) {
    final ad = rewardedNotifier.value;
    if (ad == null) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
      },
    );

    ad.show(onUserEarnedReward: (_, __) => onReward());
  }
}
