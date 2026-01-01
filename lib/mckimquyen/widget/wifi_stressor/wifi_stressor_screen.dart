import 'dart:async';

import 'package:connection_notifier/connection_notifier.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/string_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/logger.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';

import '../../admob/ad_mob_manager.dart';
import '../../admob/ad_screen.dart';

class StressorController extends GetxController {
  final isRunning = false.obs;
  final downloadCount = 0.obs;
  final speedMbps = 0.0.obs;
  final totalSpeedMbps = 0.0.obs;
  final parallelDownloads = 50.obs;
  // Tách speedHistory riêng để tối ưu chart updates
  final speedHistory = <double>[].obs;
  final totalDownloadedBytes = 0.obs;
  final testDuration = Duration.zero.obs;
  final startTime = Rx<DateTime?>(null);

  // Throttle mechanism để giảm chart updates
  DateTime _lastChartUpdate = DateTime.now();
  static const _chartUpdateInterval = Duration(milliseconds: 500);

  // Track instant speed để tránh race condition
  int _lastTotalBytes = 0;
  DateTime _lastSpeedUpdate = DateTime.now();

  final urls = [
    'https://proof.ovh.net/files/1GB.dat',
    'https://proof.ovh.net/files/10Mb.dat',
    'https://speedtest.fremont.linode.com/10MB-fremont.bin',
    'https://speed.cloudflare.com/__down?bytes=10485760', // 10MB
    'https://storage.googleapis.com/speedtest/10mb.bin', // Google Cloud
    'https://s3.amazonaws.com/speedtest/10mb.bin', // AWS S3
    'https://mirror.internet.asn.au/speedtest/10MB.bin', // AU Internet Association
  ];

  final List<CancelToken> _cancelTokens = [];
  late final Dio dio;
  Timer? _updateTimer;

  StressorController() {
    // Configure Dio with proper settings
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
    ));
  }

  @override
  void onClose() {
    Logger.i('Controller onClose called');
    _cancelAllTasks();
    _updateTimer?.cancel();
    dio.close(); // Close Dio to prevent memory leak
    super.onClose();
  }

  void startStressTest() {
    if (isRunning.value) return;
    bool isConnected = ConnectionNotifierTools.isConnected;
    Logger.i('Showing start confirmation dialog isConnected $isConnected');
    if (isConnected) {
      Get.defaultDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.all(16),
        title: '⚠️ Cảnh báo',
        content: const Text(
          'Ứng dụng sẽ sử dụng lượng lớn dữ liệu mạng. Bạn có chắc muốn tiếp tục?',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: ColorConstants.appColor,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Logger.i('User canceled stress test');
              Get.back();
            },
            child: const Text(
              'Hủy bỏ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorConstants.appColor,
                fontSize: 16,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Logger.i('User confirmed stress test');
              Get.back();
              _startTest();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text(
              'Tiếp tục',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    } else {
      UIUtils.showToast(StringConstants.warning, "It looks like your device is not connected to the internet");
    }
  }

  void _startTest() {
    Logger.i('Starting stress test with ${parallelDownloads.value} parallel downloads');
    isRunning.value = true;
    downloadCount.value = 0;
    speedMbps.value = 0.0;
    totalSpeedMbps.value = 0.0;
    totalDownloadedBytes.value = 0;
    speedHistory.clear();
    startTime.value = DateTime.now();
    _lastTotalBytes = 0;
    _lastSpeedUpdate = DateTime.now();

    Logger.i('Starting update timer (500ms interval)');
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateTotalSpeed();
      // Loại bỏ update() để tránh rebuild toàn bộ controller
    });

    for (int i = 0; i < parallelDownloads.value; i++) {
      Logger.i('Starting download loop #$i');
      _runDownloadLoop(i);
    }
  }

  void stopStressTest() {
    Logger.i('Stopping stress test');
    _cancelAllTasks();
    isRunning.value = false;
    _updateTotalSpeed();
    _updateTimer?.cancel();
  }

  void _cancelAllTasks() {
    Logger.i('Canceling all download tasks (${_cancelTokens.length} tokens)');
    for (var token in _cancelTokens) {
      token.cancel();
    }
    _cancelTokens.clear();
  }

  void _updateTotalSpeed() {
    if (startTime.value == null) return;

    final now = DateTime.now();
    final duration = now.difference(startTime.value!);
    testDuration.value = duration;

    if (duration.inSeconds > 0) {
      totalSpeedMbps.value = (totalDownloadedBytes.value * 8) / (duration.inSeconds * 1000000);

      // Tính instant speed dựa trên delta bytes (tránh race condition)
      final timeSinceLastUpdate = now.difference(_lastSpeedUpdate).inMilliseconds;
      if (timeSinceLastUpdate > 0) {
        final deltaBytes = totalDownloadedBytes.value - _lastTotalBytes;
        speedMbps.value = (deltaBytes * 8) / (timeSinceLastUpdate * 1000);
        _lastTotalBytes = totalDownloadedBytes.value;
        _lastSpeedUpdate = now;

        // Update speed history với instant speed để consistent với metric
        if (now.difference(_lastChartUpdate) >= _chartUpdateInterval) {
          _updateSpeedHistory(speedMbps.value);
          _lastChartUpdate = now;
        }
      }

      Logger.i('Updated total speed: ${totalSpeedMbps.value.toStringAsFixed(2)} Mbps');
    }
  }

  /// Cập nhật speed history với tối ưu performance
  void _updateSpeedHistory(double mbps) {
    // Tạo list mới để batch update
    final newHistory = List<double>.from(speedHistory)..add(mbps);

    // Giới hạn data points để tối ưu chart rendering
    if (newHistory.length > 50) { // Giảm từ 100 xuống 50
      speedHistory.value = newHistory.sublist(newHistory.length - 50);
    } else {
      speedHistory.value = newHistory;
    }

    Logger.i('Speed history updated (${speedHistory.length} points)');
  }

  Future<void> _runDownloadLoop(int id) async {
    Logger.i('[Loop $id] Starting download loop');
    final cancelToken = CancelToken();
    _cancelTokens.add(cancelToken);

    try {
      while (isRunning.value) {
        final url = urls[id % urls.length];
        Logger.i('[Loop $id] Selected URL: $url');

        final stopwatch = Stopwatch()..start();

        try {
          Logger.i('[Loop $id] Starting download from: $url');

          final response = await dio.get(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
              },
            ),
            cancelToken: cancelToken,
          );

          stopwatch.stop();

          num actualBytes = response.data.length;

          if (actualBytes > 0) {
            final mbps = (actualBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
            Logger.i('[Loop $id] Download completed: '
                '${(actualBytes / (1024 * 1024)).toStringAsFixed(2)} MB in '
                '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s = '
                '${mbps.toStringAsFixed(2)} Mbps');

            // Chỉ cập nhật totalDownloadedBytes, speedMbps sẽ được tính trong _updateTotalSpeed
            totalDownloadedBytes.value += actualBytes.toInt();

            // Chỉ tăng download count khi thực sự tải được data
            downloadCount.value++;
            Logger.i('[Loop $id] Total downloads: ${downloadCount.value}');
          } else {
            Logger.i('[Loop $id] Warning: Received 0 bytes!');
          }
        } catch (e) {
          Logger.i('[Loop $id] Download error: ${e.toString()}');
          if (e is DioException) {
            Logger.i('[Loop $id] Dio error type: ${e.type}');
            Logger.i('[Loop $id] Dio error message: ${e.message}');
            if (e.response != null) {
              Logger.i('[Loop $id] Response status: ${e.response!.statusCode}');
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _cancelTokens.remove(cancelToken);
      Logger.i('[Loop $id] Download loop exited');
    }
  }
}

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
      Logger.i('Lỗi khởi tạo quảng cáo: $e');
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
            color: ColorConstants.appColor,
          ),
        ),
        content: const Text(
          'Ứng dụng kiểm tra sức chịu tải Wi-Fi bằng cách tải file song song liên tục.\n'
          '⚠️ Lưu ý: Sử dụng lượng lớn dữ liệu mạng!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Colors.grey,
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
                color: ColorConstants.appColor,
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
          _buildStatusIndicator(isRunning),
          const SizedBox(height: 16),
          // Status text
          _buildStatusText(isRunning),
          const SizedBox(height: 16),
          // Control panel
          _buildControlPanel(isRunning),
          const SizedBox(height: 16),
          // Chart hiển thị nếu đang chạy
          if (isRunning) _buildSpeedChart(),
          const SizedBox(height: 16),
          // Control button
          _buildControlButton(isRunning),
        ],
      ),
    );
  }

  /// Tạo status indicator với animation mượt
  Widget _buildStatusIndicator(bool isRunning) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: CircleAvatar(
        key: ValueKey(isRunning),
        radius: 64,
        backgroundColor: isRunning ? Colors.green : Colors.grey,
        child: Icon(
          isRunning ? Icons.wifi : Icons.wifi_find,
          size: 56,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Tạo status text với performance tối ưu
  Widget _buildStatusText(bool isRunning) {
    if (!isRunning) {
      return const Text(
        'SẴN SÀNG KIỂM TRA',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Wrap chỉ phần dynamic trong Obx riêng
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ĐANG KIỂM TRA WI-FI - Lượt tải: ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Obx(() => Text(
          '${controller.downloadCount.value}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )),
      ],
    );
  }

  /// Xây dựng control panel với UI tối ưu
  Widget _buildControlPanel(bool isRunning) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Connection count selector
            _buildConnectionSelector(isRunning),
            const SizedBox(height: 16),
            // Metrics display khi đang chạy
            if (isRunning) ..._buildMetrics(),
          ],
        ),
      ),
    );
  }

  /// Tạo connection selector với performance tối ưu
  Widget _buildConnectionSelector(bool isRunning) {
    const connectionOptions = [1, 5, 10, 15, 30, 50, 100, 200, 500];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Số kết nối:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        DropdownButton<int>(
          value: controller.parallelDownloads.value,
          items: connectionOptions
              .map((val) => DropdownMenuItem<int>(
                    value: val,
                    child: Text(
                      '$val',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: isRunning
              ? null
              : (val) {
                  if (val != null) {
                    controller.parallelDownloads.value = val;
                  }
                },
        ),
      ],
    );
  }

  /// Tạo danh sách metrics với performance tối ưu
  List<Widget> _buildMetrics() {
    return [
      Obx(() => _buildMetricTile(
        Icons.speed,
        'Tốc độ hiện tại',
        '${controller.speedMbps.value.toStringAsFixed(2)} Mbps',
      )),
      Obx(() => _buildMetricTile(
        Icons.speed,
        'Tốc độ trung bình',
        '${controller.totalSpeedMbps.value.toStringAsFixed(2)} Mbps',
      )),
      Obx(() => _buildMetricTile(
        Icons.timer,
        'Thời gian chạy',
        '${controller.testDuration.value.inMinutes}:'
            '${(controller.testDuration.value.inSeconds % 60).toString().padLeft(2, '0')}',
      )),
      Obx(() => _buildMetricTile(
        Icons.data_usage,
        'Dữ liệu đã tải',
        '${(controller.totalDownloadedBytes.value / (1024 * 1024)).toStringAsFixed(2)} MB',
      )),
    ];
  }

  /// Xây dựng speed chart với tối ưu rendering
  Widget _buildSpeedChart() {
    return Obx(() {
      if (controller.speedHistory.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Đang thu thập dữ liệu tốc độ...',
                style: TextStyle(
                  color: Colors.grey,
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

  /// Tạo control button với performance tối ưu
  Widget _buildControlButton(bool isRunning) {
    if (isRunning) {
      return FilledButton.icon(
        onPressed: controller.stopStressTest,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(45),
          ),
        ),
        icon: const Icon(Icons.stop),
        label: const Text('DỪNG KIỂM TRA', style: TextStyle(fontSize: 16)),
      );
    }

    return FilledButton.icon(
      onPressed: () {
        showInterstitialAd((value) {
          controller.startStressTest();
        });
      },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(45),
        ),
      ),
      icon: const Icon(Icons.play_arrow),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('BẮT ĐẦU KIỂM TRA', style: TextStyle(fontSize: 16)),
          Container(
            color: Colors.transparent,
            width: 120,
            alignment: Alignment.bottomCenter,
            child: const Text(
              adMayAppearEn,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Tạo metric tile với performance tối ưu
  Widget _buildMetricTile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: Icon(icon, color: Colors.green),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: ColorConstants.appColor,
          fontWeight: FontWeight.normal,
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ColorConstants.appColor,
        ),
      ),
    );
  }
}

/// Chart tối ưu performance với caching và reduced complexity
class SpeedChart extends StatelessWidget {
  final List<double> speeds;

  const SpeedChart({super.key, required this.speeds});

  double get maxSpeed {
    if (speeds.isEmpty) return 100;
    final max = speeds.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    // Loại bỏ debug print để tối ưu performance
    return Card(
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biểu đồ tốc độ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColorConstants.appColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${speeds.length} điểm',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 360,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: LineChart(
                LineChartData(
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxSpeed,
                  lineBarsData: [
                    LineChartBarData(
                      spots: speeds.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [Colors.green.withValues(alpha: 0.5), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
