// File: admob_manager.dart
//https://developers.google.com/admob/flutter/mediation/applovin?hl=en

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/k/k.dart';

import 'event_bus.dart';

//version 20250529
class AdMobManager {
  static final AdMobManager _instance = AdMobManager._internal();

  factory AdMobManager() => _instance;

  AdMobManager._internal();

  static String bannerAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/6300978111";
    } else {
      return kBannerAdUnitId;
    }
  }

  static String interstitialAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/1033173712";
    } else {
      return kInterstitialAdUnitId;
    }
  }

  static String rewardedAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/5224354917";
    } else {
      return kRewardedAdUnitId;
    }
  }

  static String appOpenAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/9257395921";
    } else {
      return kAppOpenAdUnitId;
    }
  }

  bool _isInitialized = false;
  AppOpenAd? _appOpenAd;
  DateTime _appOpenAdLoadTime = DateTime(0);

  // Thêm biến quản lý thời gian
  DateTime _lastInterstitialShowTime = DateTime(0);
  DateTime _lastRewardedShowTime = DateTime(0);

  Future<void> initialize() async {
    if (_isInitialized) return;
    // await MobileAds.instance.initialize();
    MobileAds.instance.initialize().then((InitializationStatus status) {
      debugPrint('roy93~ initialize Google Mobile Ads SDK initialized: ${status.adapterStatuses}');
      // Bạn có thể kiểm tra trạng thái của các adapter tại đây.
      // AppLovin adapter sẽ được liệt kê nếu nó được tích hợp đúng cách.
      status.adapterStatuses.forEach((key, value) {
        debugPrint('roy93~ initialize Adapter $key: ${value.description}');
      });
      _loadAppOpenAd();
      _isInitialized = true;
    });
  }

  // region App Open Ad (Global management)
  Future<void> _loadAppOpenAd() async {
    try {
      await AppOpenAd.load(
        adUnitId: appOpenAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) async {
            debugPrint('roy93~ AppOpenAd onAdLoaded');
            _appOpenAd = ad;
            _appOpenAdLoadTime = DateTime.now();
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                debugPrint("roy93~ onAdDismissedFullScreenContent");
                ad.dispose();
                _appOpenAd = null;
                // _loadAppOpenAd();
                // await Future.delayed(const Duration(milliseconds: 500));
                SimpleEventBus().fire(BoolEvent(true));
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint("roy93~ onAdFailedToShowFullScreenContent");
                ad.dispose();
                _appOpenAd = null;
                // _loadAppOpenAd();
                // await Future.delayed(const Duration(milliseconds: 500));
                SimpleEventBus().fire(BoolEvent(true));
              },
            );
            showAppOpenAd();
          },
          onAdFailedToLoad: (error) async {
            debugPrint('roy93~ AppOpenAd failed to load: $error');
            _appOpenAd = null;
            // Future.delayed(const Duration(seconds: 30), _loadAppOpenAd);
            await Future.delayed(const Duration(milliseconds: 1000));
            SimpleEventBus().fire(BoolEvent(false));
          },
        ),
      );
    } catch (e) {
      debugPrint("roy93~ e _loadAppOpenAd $e");
      await Future.delayed(const Duration(milliseconds: 1000));
      SimpleEventBus().fire(BoolEvent(false));
    }
  }

  void showAppOpenAd() {
    if (_appOpenAd == null || DateTime.now().difference(_appOpenAdLoadTime).inHours >= 4) {
      debugPrint("roy93~ showAppOpenAd return");
      return;
    }
    _appOpenAd?.show();
  }

  // endregion

  // region Timing control methods
  void setLastInterstitialShowTime() {
    _lastInterstitialShowTime = DateTime.now();
  }

  void setLastRewardedShowTime() {
    _lastRewardedShowTime = DateTime.now();
  }

  bool canLoadInterstitial() {
    var isValid = DateTime.now().difference(_lastInterstitialShowTime).inMinutes >= 15;
    debugPrint("roy93~ canLoadInterstitial isValid $isValid");
    return isValid;
  }

  bool canLoadRewarded() {
    var isValid = DateTime.now().difference(_lastRewardedShowTime).inMinutes >= 15;
    debugPrint("roy93~ canLoadRewarded isValid $isValid");
    return isValid;
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
