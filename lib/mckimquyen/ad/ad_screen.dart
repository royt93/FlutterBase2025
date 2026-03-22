import 'package:flutter/material.dart';

import 'ad_manager.dart';
import 'utils/safe_logger.dart';
import 'widget/ad_loading_dialog.dart';
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
  static const String _tag = 'roy93~AdScreen';

  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    SafeLogger.d(_tag, 'initState $runtimeType — preloading interstitial');
    AdManager().loadInterstitial(); // Luôn load ready khi mở View
  }

  /// Tiện ích hiển thị Banner — dual provider, tự quản shimmer
  Widget buildBanner() {
    SafeLogger.d(_tag, 'buildBanner $runtimeType');
    return const BannerAdWidget();
  }

  // ════════════════════════════════════════════════════
  // INTERSTITIAL — pre-check trước khi show dialog
  // ════════════════════════════════════════════════════

  /// Show interstitial ad an toàn với 300ms loading buffer.
  /// Dialog CHỈ xuất hiện khi ad đã sẵn sàng và safety cho phép.
  void showInterstitialAd({required void Function(bool) onDone}) {
    SafeLogger.d(
      _tag,
      'showInterstitialAd called from $runtimeType, '
      'isDisposed=$_isDisposed, mounted=$mounted',
    );

    if (_isDisposed || !mounted) {
      SafeLogger.d(_tag, 'showInterstitialAd ⏭️ widget disposed/unmounted');
      onDone(false);
      return;
    }

    // ── PRE-CHECK: kiểm tra trước khi show dialog ──
    // Không show dialog nếu chắc chắn ad sẽ không hiện
    final canShow = AdManager().canShowInterstitial();
    SafeLogger.d(
      _tag,
      'showInterstitialAd pre-check result: canShow=$canShow',
    );

    if (!canShow) {
      SafeLogger.d(
        _tag,
        'showInterstitialAd ⏭️ pre-check failed → skip dialog, call onDone(false)',
      );
      onDone(false);
      return;
    }

    // ── AD READY → show 300ms buffer dialog ──
    SafeLogger.d(_tag, 'showInterstitialAd ✅ pre-check passed → showing dialog buffer');
    AdLoadingDialog.showAdBuffer(context, onComplete: () {
      if (!mounted || _isDisposed) {
        SafeLogger.d(_tag, 'showInterstitialAd ⏭️ widget gone after dialog buffer');
        onDone(false);
        return;
      }
      SafeLogger.d(_tag, 'showInterstitialAd → calling AdManager.showInterstitial()');
      AdManager().showInterstitial(onDoneFlow: (result) {
        SafeLogger.d(_tag, 'showInterstitialAd onDoneFlow: result=$result');
        if (mounted && !_isDisposed) {
          onDone(result);
        }
      });
    });
  }

  // ════════════════════════════════════════════════════
  // REWARDED — pre-check trước khi show dialog
  // ════════════════════════════════════════════════════

  /// Show rewarded ad an toàn với 300ms loading buffer.
  /// Dialog CHỈ xuất hiện khi ad đã sẵn sàng và safety cho phép.
  void showRewardedAd({required void Function(bool) onEarnedReward}) {
    SafeLogger.d(
      _tag,
      'showRewardedAd called from $runtimeType, '
      'isDisposed=$_isDisposed, mounted=$mounted',
    );

    if (_isDisposed || !mounted) {
      SafeLogger.d(_tag, 'showRewardedAd ⏭️ widget disposed/unmounted');
      onEarnedReward(false);
      return;
    }

    // ── PRE-CHECK: kiểm tra trước khi show dialog ──
    final canShow = AdManager().canShowRewardedAd();
    SafeLogger.d(
      _tag,
      'showRewardedAd pre-check result: canShow=$canShow',
    );

    if (!canShow) {
      SafeLogger.d(
        _tag,
        'showRewardedAd ⏭️ pre-check failed → skip dialog, call onEarnedReward(false)',
      );
      onEarnedReward(false);
      return;
    }

    // ── VIP: auto-reward, không cần ad ──
    if (AdManager().isVIPMember()) {
      SafeLogger.d(_tag, 'showRewardedAd ✅ VIP device → auto-reward without dialog');
      onEarnedReward(true);
      return;
    }

    // ── AD READY → show 300ms buffer dialog ──
    SafeLogger.d(_tag, 'showRewardedAd ✅ pre-check passed → showing dialog buffer');
    AdLoadingDialog.showAdBuffer(context, onComplete: () {
      if (!mounted || _isDisposed) {
        SafeLogger.d(_tag, 'showRewardedAd ⏭️ widget gone after dialog buffer');
        onEarnedReward(false);
        return;
      }
      SafeLogger.d(_tag, 'showRewardedAd → calling AdManager.showRewardedAd()');
      AdManager().showRewardedAd(onEarnedReward: (result) {
        SafeLogger.d(_tag, 'showRewardedAd onEarnedReward: result=$result');
        if (mounted && !_isDisposed) {
          onEarnedReward(result);
        }
      });
    });
  }

  @override
  void dispose() {
    SafeLogger.d(_tag, 'dispose() $runtimeType');
    _isDisposed = true; // Tránh memory / logic crash khi pop route
    super.dispose();
  }
}
