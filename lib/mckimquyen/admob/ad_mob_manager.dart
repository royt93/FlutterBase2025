// File: admob_manager.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'event_bus.dart';

class AdMobManager {
  static final AdMobManager _instance = AdMobManager._internal();

  factory AdMobManager() => _instance;

  AdMobManager._internal();

  //TODO roy93~ update ad ID
  static const String _bannerAdUnitId = "";
  static const String _interstitialAdUnitId = "";
  static const String _rewardedAdUnitId = "";
  static const String _appOpenAdUnitId = "";

  static String bannerAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/6300978111";
    } else {
      return _bannerAdUnitId;
    }
  }

  static String interstitialAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/1033173712";
    } else {
      return _interstitialAdUnitId;
    }
  }

  static String rewardedAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/5224354917";
    } else {
      return _rewardedAdUnitId;
    }
  }

  static String appOpenAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/9257395921";
    } else {
      return _appOpenAdUnitId;
    }
  }

  bool _isInitialized = false;
  AppOpenAd? _appOpenAd;
  DateTime _appOpenAdLoadTime = DateTime(0);

  Future<void> initialize() async {
    if (_isInitialized) return;
    await MobileAds.instance.initialize();
    _loadAppOpenAd();
    _isInitialized = true;
  }

  // region App Open Ad (Global management)
  var hasFireEvent = false;

  Future<void> _loadAppOpenAd() async {
    try {
      await AppOpenAd.load(
        adUnitId: appOpenAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('roy93~ AppOpenAd onAdLoaded');
            _appOpenAd = ad;
            _appOpenAdLoadTime = DateTime.now();
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _appOpenAd = null;
                _loadAppOpenAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                _appOpenAd = null;
                _loadAppOpenAd();
              },
            );
            if (!hasFireEvent) {
              SimpleEventBus().fire(BoolEvent(true));
              hasFireEvent = true;
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint('roy93~ AppOpenAd failed to load: $error');
            _appOpenAd = null;
            // Future.delayed(const Duration(seconds: 30), _loadAppOpenAd);
          },
        ),
      );
    } catch (e) {
      debugPrint("roy93~ e _loadAppOpenAd $e");
    }
  }

  void showAppOpenAd() {
    if (_appOpenAd == null || DateTime.now().difference(_appOpenAdLoadTime).inHours >= 4) return;
    _appOpenAd?.show();
  }

  // endregion

  // region Ad Factories
  static BannerAd createBannerAd({
    required AdSize size,
    required BannerAdListener listener,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId(),
      size: size,
      request: const AdRequest(),
      listener: listener,
    )..load();
  }

  static Future<InterstitialAd?> createInterstitialAd() async {
    Completer<InterstitialAd?> completer = Completer();

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId(),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _setupInterstitialCallbacks(ad);
          completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed: $error');
          completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  static void _setupInterstitialCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
      },
    );
  }

  static Future<RewardedAd?> createRewardedAd() async {
    Completer<RewardedAd?> completer = Completer();

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _setupRewardedCallbacks(ad);
          completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed: $error');
          completer.complete(null);
        },
      ),
    );
    return completer.future;
  }

  static void _setupRewardedCallbacks(RewardedAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
      },
    );
  }

  // endregion

  static Future<AdSize?> getAdaptiveBannerSize(BuildContext context) {
    return AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(MediaQuery.of(context).size.width.truncate());
  }
}
