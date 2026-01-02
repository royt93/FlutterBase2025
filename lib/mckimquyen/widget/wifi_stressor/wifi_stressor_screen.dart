import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';

import '../../admob/ad_screen.dart';
import 'stressor_controller.dart';
import 'speed_chart.dart';
import 'widgets/status_indicator_widget.dart';
import 'widgets/status_text_widget.dart';
import 'widgets/control_panel_widget.dart';
import 'widgets/control_button_widget.dart';

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
  Future<void> _initializeAdsAsync() async {
    try {
      // Load song song các loại quảng cáo để tối ưu thời gian
      await Future.wait([
        loadInterstitialAd(),
        // loadRewardedAd(), // Tạm thời disable để giảm memory usage
      ]);
      // Load banner cuối cùng vì ít quan trọng nhất
      loadBannerAd();
    } catch (e) {
      debugPrint('Lỗi khởi tạo quảng cáo: $e');
    }
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
      "assets/images/bkg_2.jpg",
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
      title: const Text(
        'FastNet Speed Test',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  /// Hiển thị dialog thông tin với tối ưu performance
  void _showInfoDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text(
          'Thông tin ứng dụng',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Ứng dụng kiểm tra sức chịu tải Wi-Fi bằng cách tải file song song liên tục.\n'
          '⚠️ Lưu ý: Sử dụng lượng lớn dữ liệu mạng!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Đóng',
              style: TextStyle(
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
            showInterstitialAd: showInterstitialAd,
          ),
        ],
      ),
    );
  }

  /// Xây dựng speed chart với tối ưu rendering
  Widget _buildSpeedChart() {
    return Obx(() {
      if (controller.speedHistory.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Đang thu thập dữ liệu tốc độ...',
                style: TextStyle(
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
