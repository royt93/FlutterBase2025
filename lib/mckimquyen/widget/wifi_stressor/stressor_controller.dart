import 'dart:async';

import 'package:connection_notifier/connection_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/string_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/logger.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';

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
