import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WiFiStressorApp extends StatelessWidget {
  const WiFiStressorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StressorHomePage();
  }
}

class StressorController extends GetxController {
  final isRunning = false.obs;
  final downloadCount = 0.obs;
  final speedMbps = 0.0.obs;
  final totalSpeedMbps = 0.0.obs;
  final parallelDownloads = 3.obs;
  final List<double> speedHistory = <double>[].obs;
  final totalDownloadedBytes = 0.obs;
  final testDuration = Duration.zero.obs;
  final startTime = Rx<DateTime?>(null);

  final urls = [
    'http://speedtest.tele2.net/100MB.zip',
    'http://ipv4.download.thinkbroadband.com/100MB.zip',
    'http://speed.hetzner.de/100MB.bin',
  ];

  final List<CancelToken> _cancelTokens = [];
  final dio = Dio();
  Timer? _updateTimer;

  @override
  void onClose() {
    _cancelAllTasks();
    _updateTimer?.cancel();
    super.onClose();
  }

  void startStressTest() {
    if (isRunning.value) return;

    Get.defaultDialog(
      title: '⚠️ Cảnh báo',
      content: const Text('Ứng dụng sẽ sử dụng lượng lớn dữ liệu mạng. Bạn có chắc muốn tiếp tục?'),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            Get.back();
            _startTest();
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Tiếp tục'),
        ),
      ],
    );
  }

  void _startTest() {
    isRunning.value = true;
    downloadCount.value = 0;
    speedMbps.value = 0.0;
    totalSpeedMbps.value = 0.0;
    totalDownloadedBytes.value = 0;
    speedHistory.clear();
    startTime.value = DateTime.now();

    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTotalSpeed();
    });

    for (int i = 0; i < parallelDownloads.value; i++) {
      _runDownloadLoop(i);
    }
  }

  void stopStressTest() {
    _cancelAllTasks();
    isRunning.value = false;
    _updateTotalSpeed();
    _updateTimer?.cancel();
  }

  void _cancelAllTasks() {
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
    }
  }

  Future<void> _runDownloadLoop(int id) async {
    final cancelToken = CancelToken();
    _cancelTokens.add(cancelToken);

    try {
      while (isRunning.value) {
        final url = urls[DateTime.now().millisecondsSinceEpoch % urls.length];
        final stopwatch = Stopwatch()..start();
        int bytesDownloaded = 0;

        try {
          final response = await dio.get(
            url,
            options: Options(responseType: ResponseType.stream),
            cancelToken: cancelToken,
          );

          final chunks = <Uint8List>[];
          await for (var chunk in response.data.stream) {
            if (cancelToken.isCancelled) break;
            chunks.add(chunk);
            // bytesDownloaded += chunk.length;
            bytesDownloaded += (chunk as List<int>).length;
          }

          chunks.clear();
          stopwatch.stop();

          if (stopwatch.elapsedMilliseconds > 0) {
            final mbps = (bytesDownloaded * 8) / (stopwatch.elapsedMilliseconds * 1000);
            speedMbps.value = mbps;
            totalDownloadedBytes.value += bytesDownloaded;

            speedHistory.add(mbps);
            if (speedHistory.length > 100) {
              speedHistory.removeRange(0, speedHistory.length - 100);
            }
          }

          downloadCount.value++;
        } catch (e) {
          if (e is DioException && e.type != DioExceptionType.cancel) {
            debugPrint('Download error: ${e.message}');
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } finally {
      _cancelTokens.remove(cancelToken);
    }
  }
}

class StressorHomePage extends StatelessWidget {
  const StressorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StressorController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Stressor Pro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Get.dialog(
              AlertDialog(
                title: const Text('Thông tin ứng dụng'),
                content: const Text(
                  'Ứng dụng kiểm tra sức chịu tải Wi-Fi bằng cách tải file song song liên tục.\n'
                  '⚠️ Lưu ý: Sử dụng lượng lớn dữ liệu mạng!',
                ),
                actions: [
                  TextButton(
                    onPressed: Get.back,
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Obx(() {
          final isRunning = controller.isRunning.value;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Biểu tượng trạng thái
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isRunning
                      ? const CircleAvatar(
                          radius: 64,
                          backgroundColor: Colors.blueAccent,
                          child: Icon(Icons.wifi, size: 56, color: Colors.white),
                        )
                      : const CircleAvatar(
                          radius: 64,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.wifi_find, size: 56, color: Colors.white),
                        ),
                ),

                const SizedBox(height: 24),

                // Thông tin trạng thái
                Text(
                  isRunning ? 'ĐANG KIỂM TRA WI-FI - Lượt tải: ${controller.downloadCount}' : 'SẴN SÀNG KIỂM TRA',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Card điều khiển
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Điều khiển song song
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Số kết nối:', style: TextStyle(fontSize: 16)),
                            DropdownButton<int>(
                              value: controller.parallelDownloads.value,
                              items: [1, 2, 3, 4, 5, 6, 8, 10]
                                  .map((val) => DropdownMenuItem<int>(
                                        value: val,
                                        child: Text('$val'),
                                      ))
                                  .toList(),
                              onChanged: isRunning ? null : (val) => controller.parallelDownloads.value = val!,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Thông số tốc độ
                        if (isRunning) ...[
                          _buildMetricTile(
                              Icons.speed, 'Tốc độ hiện tại', '${controller.speedMbps.value.toStringAsFixed(2)} Mbps'),
                          _buildMetricTile(Icons.av_timer, 'Tốc độ trung bình',
                              '${controller.totalSpeedMbps.value.toStringAsFixed(2)} Mbps'),
                          _buildMetricTile(
                              Icons.timer,
                              'Thời gian chạy',
                              '${controller.testDuration.value.inMinutes}'
                                  ':${(controller.testDuration.value.inSeconds % 60).toString().padLeft(2, '0')}'),
                          _buildMetricTile(Icons.data_usage, 'Dữ liệu đã tải',
                              '${(controller.totalDownloadedBytes.value / (1024 * 1024)).toStringAsFixed(2)} MB'),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Biểu đồ tốc độ
                if (isRunning && controller.speedHistory.isNotEmpty) SpeedChart(speeds: controller.speedHistory),

                const SizedBox(height: 32),

                // Nút điều khiển với FilledButton và Icon
                isRunning
                    ? FilledButton.icon(
                        onPressed: controller.stopStressTest,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.stop),
                        label: const Text('DỪNG KIỂM TRA', style: TextStyle(fontSize: 16)),
                      )
                    : FilledButton.icon(
                        onPressed: controller.startStressTest,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('BẮT ĐẦU KIỂM TRA', style: TextStyle(fontSize: 16)),
                      ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Biểu đồ tốc độ', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: const FlGridData(show: false),
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
                      color: Colors.blueAccent,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent.withOpacity(0.2), Colors.transparent],
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
      ),
    );
  }
}
