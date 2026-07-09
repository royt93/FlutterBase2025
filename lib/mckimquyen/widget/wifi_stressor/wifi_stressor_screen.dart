import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
import 'package:saigonphantomlabs/mckimquyen/util/language_service.dart';

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'stressor_controller.dart';
import 'speed_chart.dart';
import 'widgets/status_indicator_widget.dart';
import 'widgets/status_text_widget.dart';
import 'widgets/control_panel_widget.dart';
import 'widgets/control_button_widget.dart';
import 'widgets/speedometer_gauge_widget.dart';
import 'presentation/history_screen.dart';
import 'presentation/network_dashboard_screen.dart';
import '../vip/vip_screen.dart';

/// Widget chính cho ứng dụng kiểm tra sức chịu tải WiFi
/// Sử dụng StatelessWidget để tối ưu hiệu suất
class WiFiStressorApp extends StatelessWidget {
  const WiFiStressorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Trả về màn hình chính để giảm widget tree depth
    return const StressorHomePage();
  }
}

/// Màn hình chính của ứng dụng stress test
/// Kế thừa AdScreen để tích hợp quảng cáo
class StressorHomePage extends AdScreen {
  const StressorHomePage({super.key});

  @override
  State<StressorHomePage> createState() => _StressorHomePageState();
}

/// State class cho StressorHomePage
/// Quản lý lifecycle và tối ưu performance
class _StressorHomePageState extends AdScreenState<StressorHomePage> {
  // Sử dụng Get.put() để đảm bảo singleton controller
  final controller = Get.put(StressorController());

  // Cache cacheWidth để tránh tính toán lại mỗi lần rebuild.
  // Plain field + default thay cho `late` (gán trong initState trước build).
  int _cachedImageWidth = 0;

  // Banner là `const BannerAdWidget()`; cache để `buildBanner()` (và log của nó)
  // chỉ chạy 1 lần (trong initState) thay vì mỗi lần State.build() — tránh spam
  // khi route churn (push/pop VipScreen liên tục làm build() chạy hàng trăm
  // lần / frame). Nullable thay cho `late` theo quy ước doc/init.md.
  Widget? _bannerSlot;

  @override
  void initState() {
    super.initState();
    // Cache image width calculation
    _cachedImageWidth = (Get.width * 2).round();
    // Build banner một lần ở đây thay vì trong build() (tránh side-effect gán
    // field trong cây widget).
    _bannerSlot = buildBanner();
    // Sử dụng addPostFrameCallback để tránh blocking UI render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAdsAsync();
    });
    AdManager().vip?.graceNudgeDueListenable.addListener(_onGraceNudgeChanged);
  }

  /// Khởi tạo quảng cáo bất đồng bộ để không block UI
  /// AdScreenState.initState() đã tự load interstitial.
  /// Không cần gọi loadInterstitialAd(), loadBannerAd() nữa.
  Future<void> _initializeAdsAsync() async {
    // Ads được tự động load bởi AdScreenState
  }

  @override
  void dispose() {
    AdManager()
        .vip
        ?.graceNudgeDueListenable
        .removeListener(_onGraceNudgeChanged);
    // Cleanup controller để tránh memory leak
    Get.delete<StressorController>();
    super.dispose();
  }

  /// VIP sắp hết hạn (còn dưới threshold) → nhắc 1 lần qua SnackBar, trỏ
  /// tới VipScreen để gia hạn. `acknowledgeGraceNudge()` đánh dấu đã nhắc
  /// cho đúng `expiresAt` hiện tại — stack/redeem mới sẽ tự nhắc lại.
  void _onGraceNudgeChanged() {
    final vip = AdManager().vip;
    if (vip == null || !vip.graceNudgeDueListenable.value || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('vip_grace_nudge_message'.tr),
        action: SnackBarAction(
          label: 'vip_grace_nudge_action'.tr,
          onPressed: _navigateToVip,
        ),
      ),
    );
    vip.acknowledgeGraceNudge();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image với tối ưu performance
        _buildBackgroundImage(),
        // Overlay tối để tăng độ tương phản
        _buildDarkOverlay(),
        // Main scaffold với content
        _buildMainScaffold(context),
      ],
    );
  }

  /// Xây dựng background image với cache tối ưu
  Widget _buildBackgroundImage() {
    return Image.asset(
      "assets/images/bkg_2.webp",
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      // Tối ưu memory cho large images
      filterQuality: FilterQuality.medium,
      // Cache để tránh reload không cần thiết
      cacheWidth: _cachedImageWidth,
    );
  }

  /// Tạo overlay tối với alpha tối ưu
  Widget _buildDarkOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      width: double.infinity,
      height: double.infinity,
    );
  }

  /// Xây dựng main scaffold với performance tối ưu
  Widget _buildMainScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // AppBar với theme tối ưu
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Banner sits below the AppBar; we wrap the bottom in SafeArea so
          // the main content doesn't overlap the gesture nav bar in
          // edge-to-edge mode (`UIUtils.initEdgeToEdge()` is called from
          // `main.dart`). Đã build sẵn ở initState; `?? SizedBox` chỉ là
          // null-safe fallback (không bao giờ chạy) để khỏi dùng `!`.
          _bannerSlot ?? const SizedBox.shrink(),
          Expanded(
            child: SafeArea(
              top: false,
              child: Obx(() {
                final isRunning = controller.isRunning.value;
                return _buildMainContent(context, isRunning);
              }),
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng AppBar với tối ưu performance
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      title: Text(
        'app_title'.tr,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.router, color: Colors.white),
          onPressed: _navigateToNetworkDashboard,
          tooltip: 'net_dashboard_title'.tr,
        ),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: _navigateToHistory,
          tooltip: 'History & Statistics',
        ),
        _buildVipAction(),
        IconButton(
          icon: const Icon(Icons.language, color: Colors.white),
          onPressed: _showLanguageDialog,
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  /// VIP icon — màu vàng nếu user đang VIP active, trắng nếu inactive.
  /// Reactive qua `AdManager().vip!.activeListenable`. Tap → push VipScreen
  /// (không show interstitial — VIP nav phải mượt, không quảng cáo chen vào).
  Widget _buildVipAction() {
    final vip = AdManager().vip;
    if (vip == null) {
      return IconButton(
        icon: const Icon(Icons.workspace_premium_outlined, color: Colors.white),
        tooltip: 'VIP',
        onPressed: _navigateToVip,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: vip.activeListenable,
      builder: (context, active, _) {
        return IconButton(
          icon: Icon(
            active ? Icons.workspace_premium : Icons.workspace_premium_outlined,
            color: active ? const Color(0xFFFFD60A) : Colors.white,
          ),
          tooltip: 'VIP',
          onPressed: _navigateToVip,
        );
      },
    );
  }

  void _navigateToVip() {
    SafeLogger.d(_tag, '▶️ ACTION navigateToVip');
    Get.to(() => const VipScreen());
  }

  /// Network Dashboard — không show interstitial (chỉ là màn thông tin).
  void _navigateToNetworkDashboard() {
    SafeLogger.d(_tag, '▶️ ACTION navigateToNetworkDashboard');
    Get.to(() => const NetworkDashboardScreen());
  }

  static const String _tag = 'StressorHome';

  /// Navigate to history screen with interstitial
  void _navigateToHistory() {
    SafeLogger.d(_tag, '▶️ ACTION navigateToHistory — requesting interstitial');
    showInterstitialAd(onDone: (shown) {
      SafeLogger.d(_tag,
          '▶️ ACTION navigateToHistory — interstitialShown=$shown → navigating');
      Get.to(() => const HistoryScreen());
    });
  }

  /// Hiển thị dialog chọn ngôn ngữ
  void _showLanguageDialog() {
    SafeLogger.d(
        _tag, '▶️ ACTION showLanguageDialog — current locale=${Get.locale}');
    Get.dialog(
      AlertDialog(
        title: Text(
          'select_language'.tr,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              language: 'language_vietnamese'.tr,
              locale: const Locale('vi', 'VN'),
              flag: '🇻🇳',
            ),
            const SizedBox(height: 8),
            _buildLanguageOption(
              language: 'language_english'.tr,
              locale: const Locale('en', 'US'),
              flag: '🇺🇸',
            ),
          ],
        ),
      ),
    );
  }

  /// Tạo option cho từng ngôn ngữ
  Widget _buildLanguageOption({
    required String language,
    required Locale locale,
    required String flag,
  }) {
    final isSelected = Get.locale == locale;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(
        language,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () async {
        SafeLogger.d(_tag,
            '▶️ ACTION changeLanguage → locale=$locale (was ${Get.locale})');
        await LanguageService.changeLanguage(locale);
        SafeLogger.d(
            _tag, '▶️ ACTION changeLanguage DONE → new locale=${Get.locale}');
        Get.back();
      },
    );
  }

  /// Hiển thị dialog thông tin với tối ưu performance
  void _showInfoDialog() {
    SafeLogger.d(_tag, '▶️ ACTION showInfoDialog');
    Get.dialog(
      AlertDialog(
        title: Text(
          'info_dialog_title'.tr,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'info_dialog_content'.tr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SafeLogger.d(_tag, '▶️ ACTION infoDialog → close');
              Get.back();
            },
            child: Text(
              'close_button'.tr,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng nội dung chính với performance tối ưu
  Widget _buildMainContent(BuildContext context, bool isRunning) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        UIUtils.getPaddingBottom(context, ratio: 3.0),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero: gauge tốc độ realtime khi đang chạy, status icon khi idle.
          if (isRunning)
            SpeedometerGaugeWidget(controller: controller, size: 260)
          else
            StatusIndicatorWidget(isRunning: isRunning),
          const SizedBox(height: 16),
          // Status text
          StatusTextWidget(isRunning: isRunning, controller: controller),
          const SizedBox(height: 16),
          // Control panel
          ControlPanelWidget(isRunning: isRunning, controller: controller),
          const SizedBox(height: 16),
          // Chart hiển thị nếu đang chạy
          if (isRunning) _buildSpeedChart(),
          if (isRunning) const SizedBox(height: 16),
          // Control button
          ControlButtonWidget(
            isRunning: isRunning,
            controller: controller,
          ),
        ],
      ),
    );
  }

  /// Xây dựng speed chart với tối ưu rendering
  Widget _buildSpeedChart() {
    return Obx(() {
      if (controller.speedHistory.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              const CircularProgressIndicator(color: Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              Text(
                'collecting_data'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      }
      // RepaintBoundary để tránh repaint toàn bộ widget tree
      return RepaintBoundary(
        // Chart live khi đang chạy: ẩn toggle, giữ bộ đếm data_points.
        child:
            SpeedChart(speeds: controller.speedHistory, showTypeToggle: false),
      );
    });
  }
}
