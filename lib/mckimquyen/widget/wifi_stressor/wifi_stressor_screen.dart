import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';

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
  final parallelDownloads = 3.obs;
  final List<double> speedHistory = <double>[].obs;
  final urls = [
    'http://speedtest.tele2.net/100MB.zip',
    'http://ipv4.download.thinkbroadband.com/100MB.zip',
    'http://speed.hetzner.de/100MB.bin',
  ];
  final List<Future<void>> _tasks = [];
  bool _cancelled = false;
  final dio = Dio();

  void startStressTest() {
    if (isRunning.value) return;
    isRunning.value = true;
    _cancelled = false;
    downloadCount.value = 0;
    speedMbps.value = 0.0;
    speedHistory.clear();

    for (int i = 0; i < parallelDownloads.value; i++) {
      _tasks.add(_runDownloadLoop(i));
    }
  }

  void stopStressTest() {
    _cancelled = true;
    isRunning.value = false;
  }

  Future<void> _runDownloadLoop(int id) async {
    while (!_cancelled) {
      try {
        final url = urls[DateTime.now().millisecondsSinceEpoch % urls.length];
        final stopwatch = Stopwatch()..start();

        final response = await dio.get(
          url,
          options: Options(responseType: ResponseType.stream),
        );

        int totalBytes = 0;
        final stream = response.data.stream;
        await for (var chunk in stream) {
          totalBytes += (chunk as List<int>).length;
        }

        stopwatch.stop();
        final seconds = stopwatch.elapsedMilliseconds / 1000.0;
        if (seconds > 0) {
          double mbps = (totalBytes * 8) / (seconds * 1000 * 1000);
          speedMbps.value = mbps;
          speedHistory.add(mbps);
          if (speedHistory.length > 20) {
            speedHistory.removeAt(0);
          }
        }

        downloadCount.value++;
      } catch (_) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }
}

class StressorHomePage extends StatelessWidget {
  const StressorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(StressorController());

    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Stressor v5')),
      body: Center(
        child: Obx(() => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                controller.isRunning.value
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  controller.isRunning.value
                      ? 'Running... Downloads: ${controller.downloadCount.value}'
                      : 'Tap Start to stress Wi-Fi',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Parallel downloads: ', style: TextStyle(fontSize: 16)),
                    DropdownButton<int>(
                      value: controller.parallelDownloads.value,
                      items: [1, 2, 3, 4, 5, 6, 8, 10]
                          .map((val) => DropdownMenuItem<int>(
                                value: val,
                                child: Text(val.toString()),
                              ))
                          .toList(),
                      onChanged: controller.isRunning.value ? null : (val) => controller.parallelDownloads.value = val!,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                controller.isRunning.value
                    ? Text(
                        'Speed: ${controller.speedMbps.value.toStringAsFixed(2)} Mbps',
                        style: const TextStyle(fontSize: 16, color: Colors.lightGreenAccent),
                      )
                    : const SizedBox.shrink(),
                const SizedBox(height: 16),
                if (controller.isRunning.value && controller.speedHistory.isNotEmpty)
                  SizedBox(
                    height: 200,
                    width: 350,
                    child: LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              controller.speedHistory.length,
                              (index) => FlSpot(index.toDouble(), controller.speedHistory[index]),
                            ),
                            isCurved: true,
                            color: Colors.cyanAccent,
                            belowBarData: BarAreaData(show: false),
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                        titlesData: const FlTitlesData(show: false),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                controller.isRunning.value
                    ? ElevatedButton(
                        onPressed: controller.stopStressTest,
                        child: const Text('Stop'),
                      )
                    : ElevatedButton(
                        onPressed: controller.startStressTest,
                        child: const Text('Start'),
                      ),
              ],
            )),
      ),
    );
  }
}
