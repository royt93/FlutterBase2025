import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
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

    debugPrint('roy93~ Showing start confirmation dialog');
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

class WiFiStressorApp extends StatelessWidget {
  const WiFiStressorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const StressorHomePage();
  }
}

class StressorHomePage extends AdScreen {
  const StressorHomePage({super.key});

  @override
  State<StressorHomePage> createState() => _StressorHomePageState();
}

class _StressorHomePageState extends AdScreenState<StressorHomePage> {
  final controller = Get.put(StressorController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAd();
    });
  }

  Future<void> _initAd() async {
    await Future.wait([
      loadInterstitialAd(),
      // loadRewardedAd(),
    ]);
    loadBannerAd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Image.asset(
          "assets/images/bkg_2.jpg",
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black.withValues(alpha: 0.8),
          width: Get.width,
          height: Get.height,
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            iconTheme: const IconThemeData(
              color: Colors.white,
            ),
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
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                ),
                onPressed: () {
                  debugPrint('roy93~ Info button pressed');
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
                          onPressed: () {
                            debugPrint('roy93~ Info dialog closed');
                            Get.back();
                          },
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
                },
              ),
            ],
          ),
          body: Column(
            children: [
              buildBanner(),
              Expanded(
                child: Obx(() {
                  debugPrint('roy93~ Building UI (isRunning: ${controller.isRunning.value})');
                  final isRunning = controller.isRunning.value;
                  return SingleChildScrollView(
                    // physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.fromLTRB(16, 16, 16, UIUtils.getPaddingBottom(context, ratio: 3.0)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isRunning
                              ? const CircleAvatar(
                                  key: ValueKey('running'),
                                  radius: 64,
                                  backgroundColor: Colors.green,
                                  child: Icon(Icons.wifi, size: 56, color: Colors.white),
                                )
                              : const CircleAvatar(
                                  key: ValueKey('idle'),
                                  radius: 64,
                                  backgroundColor: Colors.grey,
                                  child: Icon(Icons.wifi_find, size: 56, color: Colors.white),
                                ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          isRunning
                              ? 'ĐANG KIỂM TRA WI-FI - Lượt tải: ${controller.downloadCount}'
                              : 'SẴN SÀNG KIỂM TRA',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
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
                                      items: [1, 5, 10, 15, 30, 50, 100, 200, 500]
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
                                              debugPrint('roy93~ Parallel downloads changed to: $val');
                                              controller.parallelDownloads.value = val!;
                                            },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (isRunning) ...[
                                  _buildMetricTile(Icons.speed, 'Tốc độ hiện tại',
                                      '${controller.speedMbps.value.toStringAsFixed(2)} Mbps'),
                                  _buildMetricTile(Icons.speed, 'Tốc độ trung bình',
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

                        const SizedBox(height: 16),

                        // Biểu đồ với cơ chế cập nhật mạnh mẽ
                        if (isRunning)
                          Obx(() {
                            debugPrint('roy93~ Building chart (data points: ${controller.speedHistory.length})');
                            if (controller.speedHistory.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Column(
                                  children: [
                                    CircularProgressIndicator(
                                      color: Colors.grey,
                                    ),
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
                          }),

                        const SizedBox(height: 16),

                        isRunning
                            ? FilledButton.icon(
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
                              )
                            : FilledButton.icon(
                                onPressed: () {
                                  showInterstitialAd((value) {
                                    debugPrint("roy93~ showInterstitialAd value $value");
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
                              ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(1, 16, 1, 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
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
            const SizedBox(height: 16),
            SizedBox(
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
      ),
    );
  }
}
