import 'dart:async';

import 'package:connection_notifier/connection_notifier.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/string_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';

import '../../admob/ad_mob_manager.dart';
import '../../admob/ad_screen.dart';

class StressorController extends GetxController {
  final isRunning = false.obs;
  final downloadCount = 0.obs;
  final speedMbps = 0.0.obs;
  final totalSpeedMbps = 0.0.obs;
  final parallelDownloads = 50.obs;
  final speedHistory = <double>[].obs;
  final totalDownloadedBytes = 0.obs;
  final testDuration = Duration.zero.obs;
  final startTime = Rx<DateTime?>(null);

  final urls = [
    'https://proof.ovh.net/files/1GB.dat',
    'https://proof.ovh.net/files/10Mb.dat',
    'https://speedtest.fremont.linode.com/10MB-fremont.bin',
    'https://speed.cloudflare.com/__down?bytes=100000000000000000',
    'https://storage.googleapis.com/speedtest/10mb.bin', // Google Cloud
    'https://s3.amazonaws.com/speedtest/10mb.bin', // AWS S3
    'https://mirror.internet.asn.au/speedtest/10MB.bin', // AU Internet Association
    'https://github.com/sivel/speedtest-cli/raw/master/speedtest.py', // File 10MB
  ];

  final List<CancelToken> _cancelTokens = [];
  final dio = Dio();
  Timer? _updateTimer;

  @override
  void onClose() {
    debugPrint('roy93~ Controller onClose called');
    _cancelAllTasks();
    _updateTimer?.cancel();
    super.onClose();
  }

  void startStressTest() {
    if (isRunning.value) return;
    bool isConnected = ConnectionNotifierTools.isConnected;
    debugPrint('roy93~ Showing start confirmation dialog isConnected $isConnected');
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
              debugPrint('roy93~ User canceled stress test');
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
              debugPrint('roy93~ User confirmed stress test');
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
    debugPrint('roy93~ Starting stress test with ${parallelDownloads.value} parallel downloads');
    isRunning.value = true;
    downloadCount.value = 0;
    speedMbps.value = 0.0;
    totalSpeedMbps.value = 0.0;
    totalDownloadedBytes.value = 0;
    speedHistory.clear();
    startTime.value = DateTime.now();

    debugPrint('roy93~ Starting update timer (1s interval)');
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      debugPrint('roy93~ Update timer tick - total downloaded: ${totalDownloadedBytes.value} bytes');
      _updateTotalSpeed();
      update();
    });

    for (int i = 0; i < parallelDownloads.value; i++) {
      debugPrint('roy93~ Starting download loop #$i');
      _runDownloadLoop(i);
    }
  }

  void stopStressTest() {
    debugPrint('roy93~ Stopping stress test');
    _cancelAllTasks();
    isRunning.value = false;
    _updateTotalSpeed();
    _updateTimer?.cancel();
  }

  void _cancelAllTasks() {
    debugPrint('roy93~ Canceling all download tasks (${_cancelTokens.length} tokens)');
    for (var token in _cancelTokens) {
      token.cancel();
    }
    _cancelTokens.clear();
  }

  void _updateTotalSpeed() {
    if (startTime.value == null) return;

    final duration = DateTime.now().difference(startTime.value!);
    testDuration.value = duration;

    if (duration.inSeconds > 0) {
      totalSpeedMbps.value = (totalDownloadedBytes.value * 8) / (duration.inSeconds * 1000000);
      debugPrint('roy93~ Updated total speed: ${totalSpeedMbps.value.toStringAsFixed(2)} Mbps');
    }
  }

  Future<void> _runDownloadLoop(int id) async {
    debugPrint('roy93~ [Loop $id] Starting download loop');
    final cancelToken = CancelToken();
    _cancelTokens.add(cancelToken);

    try {
      while (isRunning.value) {
        final url = urls[id % urls.length];
        debugPrint('roy93~ [Loop $id] Selected URL: $url');

        final stopwatch = Stopwatch()..start();

        try {
          debugPrint('roy93~ [Loop $id] Starting download from: $url');

          final response = await dio.get(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36'
              },
            ),
            cancelToken: cancelToken,
            onReceiveProgress: (received, total) {
              if (cancelToken.isCancelled) return;
              debugPrint('roy93~ [Loop $id] Progress: $received/$total bytes => ${received * 100 / total}');
            },
          );

          stopwatch.stop();

          num actualBytes = response.data.length;

          if (actualBytes > 0) {
            final mbps = (actualBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
            debugPrint('roy93~ [Loop $id] Download completed: '
                '${(actualBytes / (1024 * 1024)).toStringAsFixed(2)} MB in '
                '${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s = '
                '${mbps.toStringAsFixed(2)} Mbps');

            speedMbps.value = mbps;
            totalDownloadedBytes.value += actualBytes.toInt();

            speedHistory.add(mbps);
            if (speedHistory.length > 100) {
              speedHistory.removeAt(0);
            }
            debugPrint('roy93~ [Loop $id] Speed history updated (${speedHistory.length} points)');
          } else {
            debugPrint('roy93~ [Loop $id] Warning: Received 0 bytes!');
          }

          downloadCount.value++;
          debugPrint('roy93~ [Loop $id] Total downloads: ${downloadCount.value}');
        } catch (e) {
          debugPrint('roy93~ [Loop $id] Download error: ${e.toString()}');
          if (e is DioException) {
            debugPrint('roy93~ [Loop $id] Dio error type: ${e.type}');
            debugPrint('roy93~ [Loop $id] Dio error message: ${e.message}');
            if (e.response != null) {
              debugPrint('roy93~ [Loop $id] Response status: ${e.response!.statusCode}');
            }
          }
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      _cancelTokens.remove(cancelToken);
      debugPrint('roy93~ [Loop $id] Download loop exited');
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

  @override
  void initState() {
    super.initState();
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
    // Cleanup controller nếu cần thiết
    // Get.delete<StressorController>(); // Uncomment nếu muốn cleanup
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
      cacheWidth: (Get.width * 2).round(),
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
    return Text(
      isRunning
          ? 'ĐANG KIỂM TRA WI-FI - Lượt tải: ${controller.downloadCount}'
          : 'SẴN SÀNG KIỂM TRA',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
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
          items: const [1, 5, 10, 15, 30, 50, 100, 200, 500]
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
      _buildMetricTile(
        Icons.speed,
        'Tốc độ hiện tại',
        '${controller.speedMbps.value.toStringAsFixed(2)} Mbps',
      ),
      _buildMetricTile(
        Icons.speed,
        'Tốc độ trung bình',
        '${controller.totalSpeedMbps.value.toStringAsFixed(2)} Mbps',
      ),
      _buildMetricTile(
        Icons.timer,
        'Thời gian chạy',
        '${controller.testDuration.value.inMinutes}:'
            '${(controller.testDuration.value.inSeconds % 60).toString().padLeft(2, '0')}',
      ),
      _buildMetricTile(
        Icons.data_usage,
        'Dữ liệu đã tải',
        '${(controller.totalDownloadedBytes.value / (1024 * 1024)).toStringAsFixed(2)} MB',
      ),
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
      return SpeedChart(speeds: controller.speedHistory);
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
      contentPadding: EdgeInsets.zero,
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
    debugPrint('roy93~ Rendering chart with ${speeds.length} data points');
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                  '${speeds.length} điểm dữ liệu',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            height: 360,
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
                    barWidth: 4,
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
        ],
      ),
    );
  }
}
