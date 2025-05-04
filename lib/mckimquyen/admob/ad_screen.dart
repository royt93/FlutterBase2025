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
  }

  Future<void> initializeAds() async {
    await Future.wait([
      loadInterstitialAd(),
      loadRewardedAd(),
    ]);
    loadBannerAd();
    // showAppOpenAd();
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

  Future<void> loadBannerAd() async {
    bannerNotifier.value?.dispose();
    final size = await AdMobManager.getAdaptiveBannerSize(context);
    // debugPrint("roy93~ _loadBannerAd ${size?.width}x${size?.height}");
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

  Future<void> loadInterstitialAd() async {
    interstitialNotifier.value?.dispose();
    interstitialNotifier.value = await AdMobManager.createInterstitialAd();
  }

  Future<void> loadRewardedAd() async {
    rewardedNotifier.value?.dispose();
    rewardedNotifier.value = await AdMobManager.createRewardedAd();
  }

  Widget buildBanner() {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: bannerNotifier,
      builder: (context, ad, _) {
        if (ad == null) {
          // debugPrint("roy93~ buildBanner #1");
          return const SizedBox();
        } else {
          // debugPrint("roy93~ buildBanner #2");
          return SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          );
        }
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
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadInterstitialAd();
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
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadRewardedAd();
      },
    );

    ad.show(onUserEarnedReward: (_, __) => onReward());
  }
}
