import 'dart:async';

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
  bool _isDisposed = false;

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
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Dispose ads
    bannerNotifier.value?.dispose();
    interstitialNotifier.value?.dispose();
    rewardedNotifier.value?.dispose();

    // Dispose notifiers
    bannerNotifier.dispose();
    interstitialNotifier.dispose();
    rewardedNotifier.dispose();

    super.dispose();
  }

  Future<void> loadBannerAd() async {
    if (_isDisposed) return;

    bannerNotifier.value?.dispose();
    final size = await AdMobManager.getAdaptiveBannerSize(context);

    if (size != null && !_isDisposed) {
      final newAd = AdMobManager.createBannerAd(
        size: size,
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      );

      if (_isDisposed) {
        newAd.dispose();
        return;
      }

      bannerNotifier.value = newAd;
    }
  }

  Future<void> loadInterstitialAd() async {
    if (_isDisposed || !AdMobManager().canLoadInterstitial()) return;

    interstitialNotifier.value?.dispose();
    final newAd = await AdMobManager.createInterstitialAd();

    if (_isDisposed) {
      newAd?.dispose();
      return;
    }

    interstitialNotifier.value = newAd;
  }

  Future<void> loadRewardedAd() async {
    if (_isDisposed || !AdMobManager().canLoadRewarded()) return;

    rewardedNotifier.value?.dispose();
    final newAd = await AdMobManager.createRewardedAd();

    if (_isDisposed) {
      newAd?.dispose();
      return;
    }

    rewardedNotifier.value = newAd;
  }

  Widget buildBanner() {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: bannerNotifier,
      builder: (context, ad, _) {
        if (ad == null) return const SizedBox();
        return Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.fromLTRB(0, 16, 0, 16),
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
      },
    );
  }

  void showAppOpenAd() {
    AdMobManager().showAppOpenAd();
  }

  void showInterstitialAd() {
    final ad = interstitialNotifier.value;
    if (ad == null || _isDisposed) return;

    AdMobManager().setLastInterstitialShowTime();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!_isDisposed) loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!_isDisposed) loadInterstitialAd();
      },
    );
    ad.show();
  }

  void showRewardedAd({required VoidCallback onReward}) {
    final ad = rewardedNotifier.value;
    if (ad == null || _isDisposed) return;

    AdMobManager().setLastRewardedShowTime();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!_isDisposed) loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!_isDisposed) loadRewardedAd();
      },
    );

    ad.show(onUserEarnedReward: (_, __) => onReward());
  }
}
