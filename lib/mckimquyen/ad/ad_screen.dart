import 'package:flutter/material.dart';

import 'ad_manager.dart';
import 'widget/banner_ad_widget.dart';
import '../core/base_stateful_state.dart';

/// Base class cho các screen có quảng cáo
/// Port từ AdScreen pattern trong Kotlin
///
/// Sử dụng:
/// `class MyScreen extends AdScreen { ... }`
/// `class MyScreenState extends AdScreenState<MyScreen> { ... }`
abstract class AdScreen extends StatefulWidget {
  const AdScreen({super.key});
}

abstract class AdScreenState<T extends AdScreen> extends BaseStatefulState<T> {
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    AdManager().loadInterstitial(); // Luôn load ready khi mở View
  }

  /// Tiện ích hiển thị Banner — dual provider, tự quản shimmer
  Widget buildBanner() {
    return const BannerAdWidget();
  }

  /// Show interstitial ad an toàn
  /// Tự check mounted, disposed, và AdSafetyConfig
  void showInterstitialAd({required void Function(bool) onDone}) {
    if (_isDisposed) {
      onDone(false);
      return;
    }
    AdManager().showInterstitial(onDoneFlow: (result) {
      if (mounted && !_isDisposed) {
        onDone(result);
      }
    });
  }

  /// Show rewarded ad an toàn
  /// Tự check mounted, disposed, và AdSafetyConfig
  void showRewardedAd({required void Function(bool) onEarnedReward}) {
    if (_isDisposed) {
      onEarnedReward(false);
      return;
    }
    AdManager().showRewardedAd(onEarnedReward: (result) {
      if (mounted && !_isDisposed) {
        onEarnedReward(result);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true; // Tránh memory / logic crash khi pop route
    super.dispose();
  }
}
