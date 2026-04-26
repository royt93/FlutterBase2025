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
import 'presentation/history_screen.dart';
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

  // Cache cacheWidth để tránh tính toán lại mỗi lần rebuild
  late final int _cachedImageWidth;

  @override
  void initState() {
    super.initState();
    // Cache image width calculation
    _cachedImageWidth = (Get.width * 2).round();
    // Sử dụng addPostFrameCallback để tránh blocking UI render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAdsAsync();
    });
  }

  /// Khởi tạo quảng cáo bất đồng bộ để không block UI
  /// AdScreenState.initState() đã tự load interstitial.
  /// Không cần gọi loadInterstitialAd(), loadBannerAd() nữa.
  Future<void> _initializeAdsAsync() async {
    // Ads được tự động load bởi AdScreenState
  }

  @override
  void dispose() {
    // Cleanup controller để tránh memory leak
    Get.delete<StressorController>();
    super.dispose();
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
          buildBanner(),
          Expanded(
            child: Obx(() {
              final isRunning = controller.isRunning.value;
              return _buildMainContent(context, isRunning);
            }),
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

  static const String _tag = 'StressorHome';

  /// Navigate to history screen with interstitial
  void _navigateToHistory() {
    SafeLogger.d(_tag, '▶️ ACTION navigateToHistory — requesting interstitial');
    showInterstitialAd(onDone: (shown) {
      SafeLogger.d(_tag, '▶️ ACTION navigateToHistory — interstitialShown=$shown → navigating');
      Get.to(() => const HistoryScreen());
    });
  }

  /// Hiển thị dialog chọn ngôn ngữ
  void _showLanguageDialog() {
    SafeLogger.d(_tag, '▶️ ACTION showLanguageDialog — current locale=${Get.locale}');
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
        SafeLogger.d(_tag, '▶️ ACTION changeLanguage → locale=$locale (was ${Get.locale})');
        await LanguageService.changeLanguage(locale);
        SafeLogger.d(_tag, '▶️ ACTION changeLanguage DONE → new locale=${Get.locale}');
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
          // Status indicator với animation tối ưu
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
          const SizedBox(height: 16),
          // Control button
          ControlButtonWidget(
            isRunning: isRunning,
            controller: controller,
            showInterstitialAd: (Function(bool) callback) {
              SafeLogger.d(_tag, '▶️ ACTION ControlButton → showInterstitialAd, isRunning=$isRunning');
              showInterstitialAd(onDone: (shown) {
                SafeLogger.d(_tag, '▶️ ACTION ControlButton interstitialShown=$shown');
                callback(shown);
              });
            },
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
              const CircularProgressIndicator(color: Colors.green),
              const SizedBox(height: 16),
              Text(
                'collecting_data'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }
      // RepaintBoundary để tránh repaint toàn bộ widget tree
      return RepaintBoundary(
        child: SpeedChart(speeds: controller.speedHistory),
      );
    });
  }
}
