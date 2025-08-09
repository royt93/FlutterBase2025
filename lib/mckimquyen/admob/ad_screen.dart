import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/label_ad.dart';
import 'package:saigonphantomlabs/mckimquyen/core/base_stateful_state.dart';

abstract class AdScreen extends StatefulWidget {
  const AdScreen({super.key});
}

abstract class AdScreenState<T extends AdScreen> extends BaseStatefulState<T> {
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
    final size = await AdMobManager.getAdaptiveBannerSize();

    if (size != null && !_isDisposed) {
      final newAd = await AdMobManager.createBannerAdAsync(
        size: size,
        listener: BannerAdListener(
          onAdFailedToLoad: (ad, error) => ad.dispose(),
        ),
      );

      if (_isDisposed) {
        newAd?.dispose();
        return;
      }

      bannerNotifier.value = newAd;
    }
  }

  Future<void> loadInterstitialAd() async {
    if (_isDisposed || !AdMobManager().canLoadInterstitial()) {
      interstitialNotifier.value = null;
      return;
    }

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

  Widget buildBanner({
    Color? colorBkg,
    Color? colorTxt,
  }) {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: bannerNotifier,
      builder: (context, ad, _) {
        if (ad == null) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LabelAd(
                  txt: "Ad",
                  textSize: 12,
                  width: null,
                  colorBkg: colorBkg,
                  colorTxt: colorTxt,
                ),
                const Spacer(),
              ],
            ),
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.fromLTRB(0, 4, 0, 12),
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ],
        );
      },
    );
  }

  void showAppOpenAd() {
    AdMobManager().showAppOpenAd();
  }

  void showInterstitialAd(Function(bool value) onDoneFlow) {
    try {
      // debugPrint("showInterstitialAd");
      final ad = interstitialNotifier.value;
      if (ad == null || _isDisposed) {
        // debugPrint("#1");
        onDoneFlow.call(false);
        return;
      }
      AdMobManager().setLastInterstitialShowTime();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          // debugPrint("#2");
          ad.dispose();
          if (!_isDisposed) loadInterstitialAd();
          onDoneFlow.call(true);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          // debugPrint("#3");
          ad.dispose();
          if (!_isDisposed) loadInterstitialAd();
          onDoneFlow.call(false);
        },
      );
      if (!_isDisposed) {
        ad.show();
      }
      // debugPrint("#4");
    } catch (e) {
      onDoneFlow.call(false);
    }
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
