import 'package:applovin_max/applovin_max.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_route_observer.dart';
import '../k/k.dart';
import '../ad_manager.dart';
import '../utils/safe_logger.dart';
import 'shimmer_view.dart';

/// Banner Ad Widget — dual provider (AdMob / AppLovin MAX)
///
/// ## AppLovin path (kIsEnableAdmob = false)
/// Dùng MaxAdView widget với preloaded AdViewId từ AdManager:
/// - Native view được preload 1 lần trong AdManager.initialize()
/// - MaxAdView(adViewId: ...) reuse native view — KHÔNG destroy khi unmount
/// - isAutoRefreshEnabled được điều khiển bởi AdManager.bannerAutoRefreshEnabled
/// - MaxAdView.didUpdateWidget tự gọi stopAutoRefresh()/startAutoRefresh() khi giá trị thay đổi
///
/// ## AdMob path (kIsEnableAdmob = true)
/// Dùng singleton BannerAd cached trong AdManager:
/// - AdManager.loadAdmobBannerIfNeeded() gọi lần đầu khi widget mount
/// - Các lần navigate sau reuse cùng BannerAd — KHÔNG load lại
/// - bannerVisible ValueNotifier hide/show widget khi background/foreground
///
/// ## Rules
/// - Không setState, không late, không force-null
/// - Chỉ dispose AdWidget khi widget bị remove — KHÔNG dispose AdManager's notifiers
/// - Adaptive size tự động via isAdaptiveBannerEnabled: true (AppLovin) / getCurrentOrientationAnchoredAdaptiveBannerAdSize (AdMob)
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> with RouteAware {
  static const String _tag = 'roy93~Banner';

  bool _isInitStarted = false;
  bool _isBannerAllowed = false;
  bool _isRouteSubscribed = false; // Guard: subscribe RouteAware chỉ 1 lần

  /// [AdMob only] Per-widget flag: chỉ render AdWidget khi đây là top route.
  /// bannerVisible (global) chỉ dùng cho lifecycle (app background/foreground).
  /// QUAN TRỌNG: đây là LOCAL ValueNotifier — mỗi BannerAdWidget instance có riêng.
  /// Tránh crash "AdWidget already in tree" do ScreenA và ScreenB cùng render AdWidget.
  final ValueNotifier<bool> _admobIsTopRoute = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    SafeLogger.d(
      _tag,
      'initState — isEnableAdmob=$kIsEnableAdmob',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe RouteAware chỉ lần đầu — didChangeDependencies có thể gọi lại nhiều lần
    // (khi MediaQuery, Theme, hay inherited widget khác thay đổi). Subscribe() lần 2
    // sẽ không crash (idempotent) nhưng gây log spam không cần thiết.
    if (!_isRouteSubscribed) {
      final route = ModalRoute.of(context);
      if (route != null) {
        _isRouteSubscribed = true;
        adRouteObserver.subscribe(this, route);
        SafeLogger.d(
          _tag,
          'didChangeDependencies • RouteAware subscribed to '
          '${route.settings.name ?? route.runtimeType}',
        );
      }
    }
    if (!_isInitStarted) {
      _isInitStarted = true;
      SafeLogger.d(_tag, 'didChangeDependencies → _initBanner()');
      _initBanner(context);
    }
  }

  void _initBanner(BuildContext context) {
    SafeLogger.d(
      _tag,
      '_initBanner: isVIP=${AdManager().isVIPMember()}, '
      'isConnected=${AdManager().isConnected}',
    );

    // ══ VIP check ══
    if (AdManager().isVIPMember()) {
      SafeLogger.d(_tag, '_initBanner ⏭️ VIP device, skip');
      return;
    }

    // ══ Network check ══
    if (!AdManager().isConnected) {
      SafeLogger.d(_tag, '_initBanner ⏭️ no internet, skip');
      return;
    }

    // ══ Cooldown guard (navigation spam) ══
    if (!AdManager().canLoadBanner()) {
      SafeLogger.d(_tag, '_initBanner ⏭️ cooldown active, skip');
      return;
    }
    AdManager().recordBannerLoad();
    _isBannerAllowed = true;
    SafeLogger.d(_tag, '_initBanner ✅ allowed, proceeding...');

    if (kIsEnableAdmob) {
      final adWidth = MediaQuery.of(context).size.width;
      SafeLogger.d(_tag, '_initBanner [AdMob] loadAdmobBannerIfNeeded, adWidth=$adWidth');
      AdManager().loadAdmobBannerIfNeeded(adWidth);
    } else {
      SafeLogger.d(
        _tag,
        '_initBanner [AppLovin] using preloaded adViewId=${AdManager().bannerAdViewId.value}',
      );
      // AppLovin: preload đã được gọi trong AdManager.initialize()
      // Widget sẽ tự render khi bannerAdViewId.value != null
    }
  }

  // ═══ RouteAware hooks ═══

  @override
  void didPush() {
    // ⚠️ CRITICAL: didPush() được gọi SYNCHRONOUSLY bởi RouteObserver.subscribe()
    // bên trong didChangeDependencies → _firstBuild.
    // Bất kỳ ValueNotifier.value= nào ở đây sẽ trigger markNeedsBuild() DURING build → crash.
    // Fix: wrap ValueNotifier mutations trong addPostFrameCallback để defer sang frame sau.
    if (!kIsEnableAdmob) {
      // AppLovin: clear route-pause flag ngưa (chỉ là bool, không notify widget)
      AdManager().setBannerRoutePaused(false);
      if (AdManager().bannerAdViewId.value != null &&
          !AdManager().bannerAutoRefreshEnabled.value) {
        SafeLogger.d(
          _tag,
          'RouteAware.didPush() ▶️ [AppLovin] scheduling Banner RESUME via postFrameCallback',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          SafeLogger.d(_tag, 'RouteAware.didPush() postFrame ▶️ [AppLovin] bannerAutoRefreshEnabled=true');
          AdManager().bannerAutoRefreshEnabled.value = true;
        });
      } else {
        SafeLogger.d(_tag, 'RouteAware.didPush() ▶️ [AppLovin] route is now active');
      }
    } else {
      // AdMob: defer _admobIsTopRoute=true sang postFrame
      // (không cần kiểm tra current value vì đây là PER-WIDGET flag — luôn cần set)
      SafeLogger.d(
        _tag,
        'RouteAware.didPush() ▶️ [AdMob] scheduling _admobIsTopRoute=true via postFrameCallback',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SafeLogger.d(_tag, 'RouteAware.didPush() postFrame ▶️ [AdMob] _admobIsTopRoute=true (AdWidget now in tree)');
        _admobIsTopRoute.value = true;
      });
    }
    super.didPush();
  }

  @override
  void didPushNext() {
    // Người dùng push màn hình khác lên trên — banner này bị che khuất
    if (!kIsEnableAdmob && AdManager().bannerAdViewId.value != null) {
      // AppLovin: pause auto-refresh
      AdManager().setBannerRoutePaused(true);
      if (AdManager().bannerAutoRefreshEnabled.value) {
        SafeLogger.d(
          _tag,
          'RouteAware.didPushNext() ⏸️ [AppLovin] Banner PAUSED (route covered by new push)',
        );
        AdManager().bannerAutoRefreshEnabled.value = false;
      } else {
        SafeLogger.d(
          _tag,
          'RouteAware.didPushNext() ⏸️ [AppLovin] _bannerRoutePaused=true '
          '(already paused, no double-set)',
        );
      }
    } else if (kIsEnableAdmob) {
      // AdMob: ẨN AdWidget bằng per-widget flag
      // Dùng _admobIsTopRoute (LOCAL) thay vì bannerVisible (GLOBAL)
      // → chỉ có screen hiện tại bị ẩn, các screen khác không bị ảnh hưởng
      if (_admobIsTopRoute.value) {
        SafeLogger.d(
          _tag,
          'RouteAware.didPushNext() ⏸️ [AdMob] _admobIsTopRoute=false '
          '(hiding AdWidget, this screen is now covered)',
        );
        _admobIsTopRoute.value = false;
      }
    }
    super.didPushNext();
  }

  @override
  void didPopNext() {
    // Route phía trên đã pop — banner này hiện lại
    if (!kIsEnableAdmob && AdManager().bannerAdViewId.value != null) {
      // AppLovin: resume auto-refresh
      AdManager().setBannerRoutePaused(false);
      if (!AdManager().bannerAutoRefreshEnabled.value) {
        SafeLogger.d(
          _tag,
          'RouteAware.didPopNext() ▶️ [AppLovin] Banner RESUMED '
          '(top route popped, this route visible)',
        );
        AdManager().bannerAutoRefreshEnabled.value = true;
      } else {
        SafeLogger.d(
          _tag,
          'RouteAware.didPopNext() ▶️ [AppLovin] _bannerRoutePaused=false '
          '(already resumed)',
        );
      }
    } else if (kIsEnableAdmob) {
      // AdMob: hiện lại AdWidget qua per-widget flag
      // ⚠️ CRITICAL: DEFER sang postFrameCallback!
      // didPop() trên ScreenB và didPopNext() trên ScreenA fire trong cùng frame.
      // Nếu set _admobIsTopRoute=true ngưay lập tức, ScreenA render AdWidget TRONG KHI
      // ScreenB's AdWidget vẫn còn trong tree (pop animation chưa xưa) → crash.
      // với postFrameCallback: ScreenB's didPop() đã xử lý xong trong frame hiện tại,
      // AdWidget ScreenB đã được remove trước khi ScreenA mới add AdWidget.
      if (!_admobIsTopRoute.value) {
        SafeLogger.d(
          _tag,
          'RouteAware.didPopNext() ▶️ [AdMob] scheduling _admobIsTopRoute=true via postFrameCallback',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          SafeLogger.d(
            _tag,
            'RouteAware.didPopNext() postFrame ▶️ [AdMob] _admobIsTopRoute=true '
            '(top route popped, this screen now visible)',
          );
          _admobIsTopRoute.value = true;
        });
      } else {
        SafeLogger.d(
          _tag,
          'RouteAware.didPopNext() ▶️ [AdMob] already top route',
        );
      }
    }
    super.didPopNext();
  }

  @override
  void didPop() {
    // Route này đang bị pop.
    // ⚠️ [AdMob] QUAN TRỌNG: xóa AdWidget NGAY LẬP TỨC khi route bắt đầu pop.
    // didPop() trên ScreenB và didPopNext() trên ScreenA fire cùng frame.
    // Nếu ScreenB không xóa AdWidget ngưay mà đợi dispose(), AdWidget vẫn trong tree
    // trong khi ScreenA (phía dưới) đang restore AdWidget của nó → crash.
    if (kIsEnableAdmob && _admobIsTopRoute.value) {
      SafeLogger.d(
        _tag,
        'RouteAware.didPop() ⏹️ [AdMob] _admobIsTopRoute=false '
        '(removing AdWidget immediately before screen below restores its own)',
      );
      _admobIsTopRoute.value = false;
    } else {
      SafeLogger.d(_tag, 'RouteAware.didPop() ⏹️ route containing banner is popping');
    }
    super.didPop();
  }

  // ═══ dispose ═══

  @override
  void dispose() {
    // Unsubscribe RouteAware trước khi dispose
    adRouteObserver.unsubscribe(this);
    _admobIsTopRoute.dispose(); // LOCAL ValueNotifier — dispose được
    SafeLogger.d(
      _tag,
      'dispose() — isBannerAllowed=$_isBannerAllowed, '
      'isEnableAdmob=$kIsEnableAdmob',
    );
    // KHÔNG dispose AdManager's ValueNotifiers — chúng được sở hữu bửi singleton AdManager
    // KHÔNG dispose admobBannerAd — nó được cache bửi AdManager
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SafeLogger.d(
      _tag,
      'build() — isBannerAllowed=$_isBannerAllowed',
    );

    if (!_isBannerAllowed) {
      SafeLogger.d(_tag, 'build: not allowed → SizedBox.shrink()');
      return const SizedBox.shrink();
    }

    if (kIsEnableAdmob) {
      return _buildAdmobBanner();
    } else {
      return _buildAppLovinBanner();
    }
  }

  // ═══════════════════════════════════════════════════
  // ADMOB PATH — singleton BannerAd từ AdManager
  // ═══════════════════════════════════════════════════
  Widget _buildAdmobBanner() {
    // _admobIsTopRoute: PER-WIDGET flag — chỉ render AdWidget khi đây là top route.
    // bannerVisible: GLOBAL flag — chưᨏng trình lifecycle (background/foreground).
    // Cả 2 phải TRUE thì mới render AdWidget thực sự.
    return ValueListenableBuilder<bool>(
      valueListenable: _admobIsTopRoute,
      builder: (context, isTopRoute, _) {
        if (!isTopRoute) {
          // Screen này không phải top route — show placeholder, KHÔNG render AdWidget
          return ValueListenableBuilder<Size?>(
            valueListenable: AdManager().bannerAdSize,
            builder: (context, size, _) {
              return SizedBox(height: (size?.height ?? 50) + 16);
            },
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: AdManager().bannerHasError,
          builder: (context, hasError, _) {
            SafeLogger.d(_tag, '_buildAdmobBanner: hasError=$hasError');
            if (hasError) return const SizedBox.shrink();

            return ValueListenableBuilder<bool>(
              valueListenable: AdManager().bannerVisible,
              builder: (context, isVisible, _) {
                SafeLogger.d(_tag, '_buildAdmobBanner: isVisible=$isVisible');
                if (!isVisible) {
                  // Khi background: placeholder giữ chỗ height thay vì collapse
                  return ValueListenableBuilder<Size?>(
                    valueListenable: AdManager().bannerAdSize,
                    builder: (context, size, _) {
                      return SizedBox(height: (size?.height ?? 50) + 16);
                    },
                  );
                }

                return _buildBannerContainer(
                  isLoadedNotifier: AdManager().bannerIsLoaded,
                  adSizeNotifier: AdManager().bannerAdSize,
                  bannerChild: () {
                    final ad = AdManager().admobBannerAd;
                    if (ad == null) {
                      SafeLogger.d(_tag, '_buildAdmobBanner: admobBannerAd is null');
                      return const SizedBox.shrink();
                    }
                    SafeLogger.d(
                      _tag,
                      '_buildAdmobBanner: rendering AdWidget, '
                      'size=${ad.size.width}x${ad.size.height}',
                    );
                    return SizedBox(
                      width: ad.size.width.toDouble(),
                      height: ad.size.height.toDouble(),
                      child: AdWidget(ad: ad),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // APPLOVIN PATH — MaxAdView với preloaded adViewId
  // ═══════════════════════════════════════════════════
  Widget _buildAppLovinBanner() {
    return ValueListenableBuilder<bool>(
      valueListenable: AdManager().bannerHasError,
      builder: (context, hasError, _) {
        SafeLogger.d(_tag, '_buildAppLovinBanner: hasError=$hasError');
        if (hasError) return const SizedBox.shrink();

        return ValueListenableBuilder<AdViewId?>(
          valueListenable: AdManager().bannerAdViewId,
          builder: (context, adViewId, _) {
            SafeLogger.d(
              _tag,
              '_buildAppLovinBanner: adViewId=$adViewId, '
              'autoRefresh=${AdManager().bannerAutoRefreshEnabled.value}',
            );

            if (adViewId == null) {
              // Preload chưa xong → shimmer placeholder
              SafeLogger.d(_tag, '_buildAppLovinBanner: waiting for preload...');
              return _buildShimmerContainer();
            }

            return _buildBannerContainer(
              isLoadedNotifier: AdManager().bannerIsLoaded,
              adSizeNotifier: AdManager().bannerAdSize,
              bannerChild: () {
                return ValueListenableBuilder<bool>(
                  valueListenable: AdManager().bannerAutoRefreshEnabled,
                  builder: (context, autoRefresh, _) {
                    SafeLogger.d(
                      _tag,
                      '_buildAppLovinBanner MaxAdView: adViewId=$adViewId, '
                      'isAutoRefreshEnabled=$autoRefresh',
                    );
                    return MaxAdView(
                      adUnitId: kAppLovinBannerId,
                      adFormat: AdFormat.banner,
                      adViewId: adViewId,
                      // true = Adaptive banner (default sdk 4.2.0+)
                      isAdaptiveBannerEnabled: true,
                      // Điều khiển pause/resume qua ValueNotifier
                      // MaxAdView.didUpdateWidget sẽ gọi stopAutoRefresh()/startAutoRefresh() native
                      isAutoRefreshEnabled: autoRefresh,
                      listener: AdViewAdListener(
                        onAdLoadedCallback: (ad) {
                          SafeLogger.d(
                            _tag,
                            '✅ [AppLovin] MaxAdView onAdLoaded, '
                            'network=${ad.networkName}, '
                            'size=${ad.size?.width}x${ad.size?.height}',
                          );
                          // Không update bannerIsLoaded ở đây — đã được update từ
                          // WidgetAdViewAdListener trong AdManager._preloadAppLovinBanner()
                          // Tránh fire 2 lần
                        },
                        onAdLoadFailedCallback: (id, err) {
                          SafeLogger.d(
                            _tag,
                            '❌ [AppLovin] MaxAdView onAdLoadFailed: '
                            'code=${err.code}, message=${err.message}',
                          );
                        },
                        onAdClickedCallback: (ad) {
                          SafeLogger.d(_tag, '🎯 [AppLovin] MaxAdView clicked');
                        },
                        onAdExpandedCallback: (ad) {
                          SafeLogger.d(_tag, '📀 [AppLovin] MaxAdView expanded');
                        },
                        onAdCollapsedCallback: (ad) {
                          SafeLogger.d(_tag, '📁 [AppLovin] MaxAdView collapsed');
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // SHARED BANNER CONTAINER — shimmer + label + banner
  // ═══════════════════════════════════════════════════
  Widget _buildBannerContainer({
    required ValueNotifier<bool> isLoadedNotifier,
    required ValueNotifier<Size?> adSizeNotifier,
    required Widget Function() bannerChild,
  }) {
    return ValueListenableBuilder<bool>(
      valueListenable: isLoadedNotifier,
      builder: (context, isLoaded, _) {
        return ValueListenableBuilder<Size?>(
          valueListenable: adSizeNotifier,
          builder: (context, adSize, _) {
            final bannerHeight = adSize?.height ?? 50;
            SafeLogger.d(
              _tag,
              '_buildBannerContainer: isLoaded=$isLoaded, '
              'bannerHeight=$bannerHeight',
            );

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Ad" label — shimmer khi loading
                  if (!isLoaded)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: const ShimmerView(
                        cornerRadius: 2,
                        width: 20,
                        height: 13,
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCCC3C),
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
                  // Banner area
                  SizedBox(
                    width: double.infinity,
                    height: bannerHeight,
                    child: !isLoaded
                        ? ShimmerView(
                            cornerRadius: 0,
                            width: double.infinity,
                            height: bannerHeight,
                          )
                        : bannerChild(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerContainer() {
    SafeLogger.d(_tag, '_buildShimmerContainer: preload pending');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: const ShimmerView(cornerRadius: 2, width: 20, height: 13),
          ),
          const ShimmerView(
            cornerRadius: 0,
            width: double.infinity,
            height: 50,
          ),
        ],
      ),
    );
  }
}
