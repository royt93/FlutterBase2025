import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:applovin_max/applovin_max.dart';

import '../k/k.dart';
import '../ad_manager.dart';
import '../utils/safe_logger.dart';
import '../ad_safety_config.dart';
import 'shimmer_view.dart';

/// Banner Ad Widget — dual provider (AdMob / AppLovin MAX)
/// Dùng ValueNotifier thay cho setState
/// Tự dispose tất cả resources (zero memory leak)
///
/// Port logic từ loadBanner(), loadBannerAdMob(), loadBannerAppLovin()
/// trong AdManager.kt (dòng 313–484)
///
/// Edge cases handled:
/// - VIP device → ẩn hoàn toàn (BUG FIX #2)
/// - No internet → ẩn hoàn toàn (BUG FIX #3)
/// - Ad failed → ẩn hoàn toàn (giống native container.isVisible = false)
/// - Widget disposed trước khi callback → check mounted
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  static const String _tag = 'roy93~Banner';

  final ValueNotifier<bool> _isLoaded = ValueNotifier(false);
  final ValueNotifier<bool> _hasError = ValueNotifier(false);
  BannerAd? _bannerAd;
  bool _isDisposed = false;
  bool _isInitStarted = false;

  @override
  void initState() {
    super.initState();
    SafeLogger.d(_tag, 'initState called, isEnableAdmob=$kIsEnableAdmob');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitStarted) {
      _isInitStarted = true;
      _initBanner(context);
    }
  }

  void _initBanner(BuildContext context) {
    // ══ BUG FIX #2: VIP check (giống native loadBanner line 329-336) ══
    if (AdManager().isVIPMember()) {
      SafeLogger.d(_tag, 'loadBanner ⏭️ skipped due to whitelist device');
      _hasError.value = true; // Ẩn widget hoàn toàn
      return;
    }

    // ══ BUG FIX #3: Network check (giống native loadBanner line 337-344) ══
    if (!AdManager().isConnected) {
      SafeLogger.d(_tag, 'loadBanner ⏭️ no internet connection');
      _hasError.value = true; // Ẩn widget hoàn toàn
      return;
    }

    SafeLogger.d(_tag, 'loadBanner 🔄 creating ad view and loading...');

    if (kIsEnableAdmob) {
      _loadAdmobBanner(context);
    }
    // AppLovin banner tự load qua MaxAdView widget
  }

  Future<void> _loadAdmobBanner(BuildContext context) async {
    final adWidth = MediaQuery.of(context).size.width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(adWidth) ?? AdSize.banner;
    SafeLogger.d(_tag, 'loadBanner [AdMob] creating BannerAd, adUnitId=$kAdmobBannerAdUnitId, size=${size.width}x${size.height}');
    
    _bannerAd = BannerAd(
      adUnitId: kAdmobBannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          SafeLogger.d(_tag, '✅ Banner Ad Loaded successfully');
          if (_isDisposed) {
            SafeLogger.d(_tag, '⚠️ Widget already disposed, disposing loaded ad');
            ad.dispose();
            return;
          }
          _isLoaded.value = true;
          _hasError.value = false;
        },
        onAdFailedToLoad: (ad, error) {
          SafeLogger.d(
            _tag,
            '❌ Banner Ad Failed to load: code=${error.code}, '
            'message=${error.message}, domain=${error.domain}',
          );
          ad.dispose();
          _bannerAd = null;
          if (_isDisposed) return;
          _isLoaded.value = false;
          _hasError.value = true;
        },
        onAdOpened: (ad) {
          SafeLogger.d(_tag, '🎯 Banner Ad Clicked/Opened');
          AdSafetyConfig.recordAdClick();
        },
        onAdClosed: (ad) {
          SafeLogger.d(_tag, '📝 Banner Ad Closed');
        },
        onAdImpression: (ad) {
          SafeLogger.d(_tag, '👁️ Banner Ad Impression recorded');
        },
      ),
    )..load();
    SafeLogger.d(_tag, 'loadBanner [AdMob] loadAd() called');
  }

  @override
  void dispose() {
    SafeLogger.d(_tag, 'dispose() called — cleaning up banner resources');
    _isDisposed = true;
    _isLoaded.dispose();
    _hasError.dispose();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasError,
      builder: (context, hasError, _) {
        // Nếu lỗi/VIP/no internet → ẩn hoàn toàn (giống native: container.isVisible = false)
        if (hasError) {
          SafeLogger.d(_tag, 'build: hasError=true, returning empty');
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          alignment: Alignment.center,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoaded,
            builder: (context, isLoaded, _) {
              SafeLogger.d(_tag, 'BannerAd UI rendering: isLoaded=$isLoaded');
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, // Label is top-left aligned relative to the ad
                children: [
                  // ════════ LABEL AD AREA ════════
                  !isLoaded
                      // Shimmer label matching the native badge
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          child: const ShimmerView(
                            cornerRadius: 2,
                            width: 20,
                            height: 13,
                          ),
                        )
                      // Real Native Android "Ad" badge
                      : Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCCC3C), // Màu vàng đặc trưng Native AdMob
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Text(
                            'Ad',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),

                  // ════════ BANNER AD AREA (ADAPTIVE FULL WIDTH) ════════
                  SizedBox(
                    width: double.infinity,
                    height: isLoaded && _bannerAd != null ? _bannerAd!.size.height.toDouble() : 50,
                    child: !isLoaded
                        // Banner shimmer Full Width
                        ? const ShimmerView(
                            cornerRadius: 0,
                            width: double.infinity,
                            height: 50,
                          )
                        // Real Ad Widget adaptive size
                        : _buildAdWidget(),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAdWidget() {
    if (kIsEnableAdmob) {
      final ad = _bannerAd;
      if (ad != null) {
        return SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
      }
      SafeLogger.d(_tag, '_buildAdWidget: _bannerAd is null, returning empty');
      return const SizedBox.shrink();
    }

    // ════════ APPLOVIN MAX BANNER ════════
    SafeLogger.d(_tag, '_buildAdWidget: creating MaxAdView, id=$kAppLovinBannerId');
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: MaxAdView(
        adUnitId: kAppLovinBannerId,
        adFormat: AdFormat.banner,
        listener: AdViewAdListener(
          onAdLoadedCallback: (ad) {
            SafeLogger.d(_tag, '✅ [AppLovin] Banner Ad Loaded');
            if (_isDisposed) return;
            _isLoaded.value = true;
            _hasError.value = false;
          },
          onAdLoadFailedCallback: (id, err) {
            SafeLogger.d(
              _tag,
              '❌ [AppLovin] Banner Ad Failed: code=${err.code}, '
              'message=${err.message}',
            );
            if (_isDisposed) return;
            _isLoaded.value = false;
            _hasError.value = true;
          },
          onAdClickedCallback: (ad) {
            SafeLogger.d(_tag, '🎯 [AppLovin] Banner Ad Clicked');
            AdSafetyConfig.recordAdClick();
          },
          onAdExpandedCallback: (ad) {
            SafeLogger.d(_tag, '📐 [AppLovin] Banner Ad Expanded');
          },
          onAdCollapsedCallback: (ad) {
            SafeLogger.d(_tag, '📐 [AppLovin] Banner Ad Collapsed');
          },
        ),
      ),
    );
  }
}
