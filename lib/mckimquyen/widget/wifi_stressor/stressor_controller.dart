import 'dart:async';

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/string_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
import 'models/test_result.dart';
import 'services/test_history_storage.dart';
import 'services/network_info_service.dart';


class StressorController extends GetxController {
  final isRunning = false.obs;
  final downloadCount = 0.obs;
  final speedMbps = 0.0.obs;
  final totalSpeedMbps = 0.0.obs;
  final parallelDownloads = 50.obs;
  // Tách speedHistory riêng để tối ưu chart updates
  final speedHistory = <double>[].obs;
  final totalDownloadedBytes = 0.obs;
  final totalBytesIncludingProgress = 0.obs; // Bao gồm cả bytes đang tải
  final testDuration = Duration.zero.obs;
  final startTime = Rx<DateTime?>(null);

  // Track xem test đã được save chưa (prevent duplicate save)
  bool _testSaved = false;

  // Throttle mechanism để giảm chart updates
  DateTime _lastChartUpdate = DateTime.now();
  static const _chartUpdateInterval = Duration(milliseconds: 250); // Giảm xuống 250ms để smooth hơn

  // Track instant speed để tránh race condition
  int _lastTotalBytes = 0;
  DateTime _lastSpeedUpdate = DateTime.now();

  // Track bytes đang download cho mỗi loop
  final Map<int, int> _loopCurrentBytes = {};

  final urls = [
    // CloudFlare Speed Test - Global CDN, MOST RELIABLE - always works
    'https://speed.cloudflare.com/__down?bytes=10485760', // 10MB
    'https://speed.cloudflare.com/__down?bytes=52428800', // 50MB
    'https://speed.cloudflare.com/__down?bytes=104857600', // 100MB

    // GitHub large files - Very reliable
    'https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe', // ~50MB

    // Cachefly CDN - Globally distributed, fast
    'https://cachefly.cachefly.net/10mb.test',
    'https://cachefly.cachefly.net/100mb.test',

    // Linode Speed Test - Multiple global locations
    'https://speedtest.newark.linode.com/100MB-newark.bin', // US East
    'https://speedtest.dallas.linode.com/100MB-dallas.bin', // US Central
    'https://speedtest.fremont.linode.com/100MB-fremont.bin', // US West
    'https://speedtest.atlanta.linode.com/100MB-atlanta.bin', // US Southeast
    'https://speedtest.tokyo2.linode.com/100MB-tokyo2.bin', // Japan
    'https://speedtest.singapore.linode.com/100MB-singapore.bin', // Singapore
    'https://speedtest.frankfurt.linode.com/100MB-frankfurt.bin', // Germany
    'https://speedtest.london.linode.com/100MB-london.bin', // UK

    // OVH Speed Test - European CDN
    'https://proof.ovh.net/files/10Mb.dat',
    'https://proof.ovh.net/files/100Mb.dat',

    // Bouygues Telecom - French provider
    'https://test-debit.free.fr/10240.rnd', // 10MB

    // Vultr Speed Test - Multiple locations
    'https://wa-us-ping.vultr.com/vultr.com.100MB.bin', // US Seattle
    'https://nj-us-ping.vultr.com/vultr.com.100MB.bin', // US New Jersey
    'https://il-us-ping.vultr.com/vultr.com.100MB.bin', // US Chicago
    'https://ga-us-ping.vultr.com/vultr.com.100MB.bin', // US Atlanta
    'https://sgp-ping.vultr.com/vultr.com.100MB.bin', // Singapore
    'https://hnd-jp-ping.vultr.com/vultr.com.100MB.bin', // Japan Tokyo
    'https://syd-au-ping.vultr.com/vultr.com.100MB.bin', // Australia Sydney
    'https://fra-de-ping.vultr.com/vultr.com.100MB.bin', // Germany Frankfurt
    'https://ams-nl-ping.vultr.com/vultr.com.100MB.bin', // Netherlands Amsterdam

    // ThinkBroadband - UK based
    'https://ipv4.download.thinkbroadband.com/10MB.zip',
    'https://ipv4.download.thinkbroadband.com/50MB.zip',
  ];

  final List<CancelToken> _cancelTokens = [];
  final Dio dio;
  Timer? _updateTimer;
  Timer? _retryTimer;

  // Storage để lưu test history - SINGLETON
  final TestHistoryStorage _storage = TestHistoryStorage.instance;

  // Network info service để lấy thông tin mạng
  final NetworkInfoService _networkInfoService = NetworkInfoService();

  // Track failed URLs để tránh retry liên tục
  final Set<String> _failedUrls = {};
  final Map<String, int> _urlErrorCount = {};
  final Map<String, DateTime> _urlLastFailTime = {};

  // Shuffled URLs để phân tán load
  List<String>? _shuffledUrls;

  StressorController() : dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: true,
      maxRedirects: 5,
      // Allow all status codes to handle them manually
      validateStatus: (status) => true,
    )) {
    // Shuffle URLs để phân tán load tốt hơn
    _shuffledUrls = List.from(urls)..shuffle();

    // Initialize storage
    _initStorage();

    // Add progress interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        SafeLogger.d('Log', '[DIO] Request: ${options.uri}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final length = response.data is List ? (response.data as List).length : 0;
        SafeLogger.d('Log', '[DIO] Response: ${response.requestOptions.uri} | Status: ${response.statusCode} | Bytes: $length');
        return handler.next(response);
      },
      onError: (error, handler) {
        SafeLogger.d('Log', '[DIO] Error: ${error.requestOptions.uri} | ${error.type}');
        return handler.next(error);
      },
    ));
  }

  /// Initialize storage
  Future<void> _initStorage() async {
    try {
      await _storage.init();
      SafeLogger.d('Log', 'Storage initialized successfully');
    } catch (e) {
      SafeLogger.d('Log', 'Failed to initialize storage: $e');
    }
  }

  @override
  void onClose() {
    SafeLogger.d('Log', 'Controller onClose called');

    // CRITICAL FIX: Save test nếu đang chạy (prevent data loss khi app closed)
    if (isRunning.value && startTime.value != null && !_testSaved) {
      SafeLogger.d('Log', 'Test was running, saving before dispose...');

      // Save bytes đang progress trước khi dispose
      final bytesInProgress = _loopCurrentBytes.values.fold<int>(0, (sum, bytes) => sum + bytes);
      if (bytesInProgress > 0) {
        SafeLogger.d('Log', '💾 Saving in-progress bytes on dispose: ${(bytesInProgress / (1024 * 1024)).toStringAsFixed(2)} MB');
        totalDownloadedBytes.value += bytesInProgress;
      }

      // Call async method but don't await (controller disposing)
      // The save will complete in background
      _saveTestResult('interrupted').catchError((e) {
        SafeLogger.d('Log', 'Failed to save on dispose: $e');
      });
      // Give it a moment to start the save operation
      Future.delayed(const Duration(milliseconds: 100), () {
        _cleanup();
      });
    } else {
      _cleanup();
    }

    super.onClose();
  }

  void _cleanup() {
    _cancelAllTasks();
    _updateTimer?.cancel();
    _retryTimer?.cancel();
    // KHÔNG close shared singleton storage
    // _storage.close();
    dio.close(); // Close Dio to prevent memory leak
  }

  void startStressTest() {
    if (isRunning.value) return;
    bool isConnected = AdManager().isConnected;
    SafeLogger.d('Log', 'Showing start confirmation dialog isConnected $isConnected');
    if (isConnected) {
      Get.defaultDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        contentPadding: const EdgeInsets.all(16),
        title: 'warning_title'.tr,
        content: Text(
          'warning_message'.tr,
          style: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SafeLogger.d('Log', 'User canceled stress test');
              Get.back();
            },
            child: Text(
              'cancel'.tr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              SafeLogger.d('Log', 'User confirmed stress test');
              Get.back();
              _startTest();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text(
              'continue'.tr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    } else {
      UIUtils.showToast(StringConstants.warning, 'no_internet'.tr);
    }
  }

  void _startTest() {
    SafeLogger.d('Log', 'Starting stress test with ${parallelDownloads.value} parallel downloads');
    isRunning.value = true;
    downloadCount.value = 0;
    speedMbps.value = 0.0;
    totalSpeedMbps.value = 0.0;
    totalDownloadedBytes.value = 0;
    speedHistory.clear();
    startTime.value = DateTime.now();
    _lastTotalBytes = 0;
    _lastSpeedUpdate = DateTime.now();
    _testSaved = false; // Reset save flag

    // Reset failed URLs tracking
    _failedUrls.clear();
    _urlErrorCount.clear();
    _urlLastFailTime.clear();

    // Reset in-progress bytes tracking
    _loopCurrentBytes.clear();

    SafeLogger.d('Log', 'Starting update timer (500ms interval)');
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateTotalSpeed();
      // Loại bỏ update() để tránh rebuild toàn bộ controller
    });

    // Start retry timer để thử lại failed URLs sau 2 phút
    SafeLogger.d('Log', 'Starting retry timer (120s interval)');
    _retryTimer = Timer.periodic(const Duration(seconds: 120), (_) {
      _retryFailedUrls();
    });

    for (int i = 0; i < parallelDownloads.value; i++) {
      SafeLogger.d('Log', 'Starting download loop #$i');
      _runDownloadLoop(i);
    }
  }

  /// Thử lại các URL đã failed sau một khoảng thời gian
  void _retryFailedUrls() {
    if (_failedUrls.isEmpty) return;

    final now = DateTime.now();
    final urlsToRetry = <String>[];

    for (final url in _failedUrls) {
      final lastFailTime = _urlLastFailTime[url];
      if (lastFailTime != null) {
        // Nếu đã failed hơn 2 phút, thử lại
        if (now.difference(lastFailTime).inMinutes >= 2) {
          urlsToRetry.add(url);
        }
      }
    }

    if (urlsToRetry.isNotEmpty) {
      SafeLogger.d('Log', 'Retrying ${urlsToRetry.length} failed URLs');
      for (final url in urlsToRetry) {
        _failedUrls.remove(url);
        _urlErrorCount.remove(url);
        _urlLastFailTime.remove(url);
      }
    }
  }

  Future<void> stopStressTest() async {
    SafeLogger.d('Log', 'Stopping stress test');

    // CRITICAL FIX: Save bytes đang progress trước khi clear
    final bytesInProgress = _loopCurrentBytes.values.fold<int>(0, (sum, bytes) => sum + bytes);
    if (bytesInProgress > 0) {
      SafeLogger.d('Log', '💾 Saving in-progress bytes: ${(bytesInProgress / (1024 * 1024)).toStringAsFixed(2)} MB');
      totalDownloadedBytes.value += bytesInProgress;
    }

    _cancelAllTasks();
    isRunning.value = false;
    _loopCurrentBytes.clear(); // Clear in-progress bytes
    _updateTotalSpeed();
    _updateTimer?.cancel();
    _retryTimer?.cancel();

    // CRITICAL FIX: AWAIT để đảm bảo save xong trước khi return
    await _saveTestResult('stopped');
  }

  /// Save test result to storage
  Future<void> _saveTestResult(String status) async {
    final start = startTime.value;
    if (start == null) {
      SafeLogger.d('Log', '❌ Cannot save: startTime is null');
      return;
    }

    // Prevent duplicate save
    if (_testSaved) {
      SafeLogger.d('Log', 'Test already saved, skipping duplicate save');
      return;
    }

    try {
      // CRITICAL FIX: Ensure storage is initialized before saving
      if (_storage.box == null) {
        SafeLogger.d('Log', '⏳ Storage not ready, waiting for init...');
        await _storage.init();
        SafeLogger.d('Log', '✅ Storage initialized on-demand');
      }

      // DEBUG: Log các giá trị trước khi save
      SafeLogger.d('Log', '💾 Saving test result...');
      SafeLogger.d('Log', '  - Status: $status');
      SafeLogger.d('Log', '  - Total Downloaded: ${(totalDownloadedBytes.value / (1024 * 1024)).toStringAsFixed(2)} MB');
      SafeLogger.d('Log', '  - Download Count: ${downloadCount.value}');
      SafeLogger.d('Log', '  - Speed History: ${speedHistory.length} points');

      // Lấy thông tin mạng thực tế
      final networkInfo = await _networkInfoService.getCurrentNetworkInfo();
      SafeLogger.d('Log', '  - Network Info: $networkInfo');

      final result = TestResult.fromControllerData(
        startTime: start,
        endTime: DateTime.now(),
        speedHistory: List.from(speedHistory),
        totalDownloadedBytes: totalDownloadedBytes.value,
        downloadCount: downloadCount.value,
        status: status,
        networkInfo: networkInfo,
      );

      await _storage.saveTestResult(result);
      _testSaved = true; // Mark as saved
      SafeLogger.d('Log', '✅ Test result saved: ${result.avgSpeed.toStringAsFixed(1)} Mbps (ID: ${result.id})');
      SafeLogger.d('Log', '📊 Total tests in storage: ${_storage.totalCount}');
    } catch (e) {
      SafeLogger.d('Log', '❌ Failed to save test result: $e');
      // Print stack trace for debugging
      if (e is Error) {
        SafeLogger.d('Log', 'Stack trace: ${e.stackTrace}');
      }
    }
  }

  void _cancelAllTasks() {
    SafeLogger.d('Log', 'Canceling all download tasks (${_cancelTokens.length} tokens)');
    for (var token in _cancelTokens) {
      token.cancel();
    }
    _cancelTokens.clear();
  }

  void _updateTotalSpeed() {
    final start = startTime.value;
    if (start == null) return;

    final now = DateTime.now();
    final duration = now.difference(start);
    testDuration.value = duration;

    if (duration.inSeconds > 0) {
      // Tính tổng bytes = bytes đã hoàn thành + bytes đang tải
      final bytesInProgress = _loopCurrentBytes.values.fold<int>(0, (sum, bytes) => sum + bytes);
      final totalBytes = totalDownloadedBytes.value + bytesInProgress;

      // Update total bytes including progress (for UI display)
      totalBytesIncludingProgress.value = totalBytes;

      totalSpeedMbps.value = (totalBytes * 8) / (duration.inSeconds * 1000000);

      // Tính instant speed dựa trên delta bytes (tránh race condition)
      final timeSinceLastUpdate = now.difference(_lastSpeedUpdate).inMilliseconds;
      if (timeSinceLastUpdate > 0) {
        final deltaBytes = totalBytes - _lastTotalBytes;
        speedMbps.value = (deltaBytes * 8) / (timeSinceLastUpdate * 1000);
        _lastTotalBytes = totalBytes;
        _lastSpeedUpdate = now;

        // Update speed history với instant speed để consistent với metric
        if (now.difference(_lastChartUpdate) >= _chartUpdateInterval) {
          _updateSpeedHistory(speedMbps.value);
          _lastChartUpdate = now;
        }
      }

      SafeLogger.d('Log', 'Updated total speed: ${totalSpeedMbps.value.toStringAsFixed(2)} Mbps (Downloaded: ${(totalDownloadedBytes.value / (1024 * 1024)).toStringAsFixed(1)}MB, In-progress: ${(bytesInProgress / (1024 * 1024)).toStringAsFixed(1)}MB)');
    }
  }

  /// Cập nhật speed history với tối ưu performance
  void _updateSpeedHistory(double mbps) {
    // Tạo list mới để batch update
    final newHistory = List<double>.from(speedHistory)..add(mbps);

    // Giới hạn data points để tối ưu chart rendering
    if (newHistory.length > 100) { // Tăng lên 100 để chart smooth hơn
      speedHistory.value = newHistory.sublist(newHistory.length - 100);
    } else {
      speedHistory.value = newHistory;
    }

    SafeLogger.d('Log', 'Speed history updated (${speedHistory.length} points)');
  }

  /// Tìm URL khả dụng (không bị failed)
  String? _getAvailableUrl(int loopId) {
    final urlList = _shuffledUrls ?? urls;

    // Nếu tất cả URLs đều failed, reset lại
    if (_failedUrls.length >= urlList.length) {
      SafeLogger.d('Log', '[Loop $loopId] All URLs failed, resetting failed list');
      _failedUrls.clear();
      _urlErrorCount.clear();
      _urlLastFailTime.clear();
    }

    // Tìm URL không bị failed từ shuffled list
    for (int i = 0; i < urlList.length; i++) {
      final index = (loopId + i) % urlList.length;
      final url = urlList[index];
      if (!_failedUrls.contains(url)) {
        return url;
      }
    }

    return null;
  }

  Future<void> _runDownloadLoop(int id) async {
    SafeLogger.d('Log', '[Loop $id] Starting download loop');
    final cancelToken = CancelToken();
    _cancelTokens.add(cancelToken);

    try {
      while (isRunning.value) {
        final url = _getAvailableUrl(id);
        if (url == null) {
          SafeLogger.d('Log', '[Loop $id] No available URLs, waiting...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final stopwatch = Stopwatch()..start();

        try {
          SafeLogger.d('Log', '[Loop $id] → Downloading from: $url');

          DateTime lastProgressTime = DateTime.now();

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
            onReceiveProgress: (received, total) {
              // Update bytes đang tải cho loop này
              _loopCurrentBytes[id] = received;

              final now = DateTime.now();
              // Log progress mỗi 2 giây hoặc khi complete
              if (now.difference(lastProgressTime).inSeconds >= 2 || received == total) {
                final speed = total > 0 ? (received / total * 100).toStringAsFixed(1) : '?';
                SafeLogger.d('Log', '[Loop $id] 📥 Progress: $received / $total bytes ($speed%)');
                lastProgressTime = now;
              }
            },
          );

          stopwatch.stop();

          // === DETAILED DEBUG LOGGING START ===
          final statusCode = response.statusCode;
          final contentLength = response.headers.value('content-length');
          final contentType = response.headers.value('content-type');
          final redirects = response.redirects;

          SafeLogger.d('Log', '[Loop $id] 📊 RESPONSE DEBUG:');
          SafeLogger.d('Log', '  URL: $url');
          SafeLogger.d('Log', '  Status: $statusCode');
          SafeLogger.d('Log', '  Content-Length header: $contentLength');
          SafeLogger.d('Log', '  Content-Type: $contentType');
          SafeLogger.d('Log', '  Redirects: ${redirects.length}');
          SafeLogger.d('Log', '  Data null: ${response.data == null}');
          SafeLogger.d('Log', '  Data type: ${response.data?.runtimeType}');
          SafeLogger.d('Log', '  Time: ${stopwatch.elapsedMilliseconds}ms');

          if (redirects.isNotEmpty) {
            SafeLogger.d('Log', '  Redirect chain:');
            for (var redirect in redirects) {
              SafeLogger.d('Log', '    → ${redirect.location}');
            }
          }
          // === DETAILED DEBUG LOGGING END ===

          // Kiểm tra HTTP status code
          if (statusCode != null && statusCode >= 400) {
            // Lỗi HTTP 4xx/5xx - mark URL as failed
            final errorCount = (_urlErrorCount[url] ?? 0) + 1;
            _urlErrorCount[url] = errorCount;
            if (errorCount >= 3) {
              _failedUrls.add(url);
              _urlLastFailTime[url] = DateTime.now();
              SafeLogger.d('Log', '[Loop $id] ❌ URL failed after $errorCount errors (Status: $statusCode)');
            }
            await Future.delayed(const Duration(milliseconds: 100));
            continue;
          }

          // Get actual bytes - handle different response types
          num actualBytes = 0;

          if (response.data != null) {
            final data = response.data;

            if (data is List<int>) {
              actualBytes = data.length;
              SafeLogger.d('Log', '[Loop $id] 📦 Data is List<int>, length: $actualBytes');
            } else if (data is List) {
              actualBytes = data.length;
              SafeLogger.d('Log', '[Loop $id] 📦 Data is List, length: $actualBytes');
            } else {
              SafeLogger.d('Log', '[Loop $id] ⚠️ UNEXPECTED data type: ${data.runtimeType}');
              // Try to get string representation
              final dataStr = data.toString();
              SafeLogger.d('Log', '[Loop $id] Data toString: ${dataStr.substring(0, dataStr.length > 100 ? 100 : dataStr.length)}...');
            }
          } else {
            SafeLogger.d('Log', '[Loop $id] ⚠️ response.data is NULL');
          }

          if (actualBytes > 0) {
            final mbps = (actualBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
            SafeLogger.d('Log', '[Loop $id] ✓ ${(actualBytes / (1024 * 1024)).toStringAsFixed(1)}MB in ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s = ${mbps.toStringAsFixed(1)} Mbps');

            // Reset error count cho URL thành công
            _urlErrorCount.remove(url);

            // Chỉ cập nhật totalDownloadedBytes, speedMbps sẽ được tính trong _updateTotalSpeed
            totalDownloadedBytes.value += actualBytes.toInt();

            // Reset bytes đang tải cho loop này (đã hoàn thành)
            _loopCurrentBytes.remove(id);

            // Chỉ tăng download count khi thực sự tải được data
            downloadCount.value++;
          } else {
            // Reset bytes đang tải khi nhận 0 bytes
            _loopCurrentBytes.remove(id);

            // Debug info khi nhận 0 bytes
            SafeLogger.d('Log', '[Loop $id] ⚠️ 0 bytes | URL: $url | Status: $statusCode | Data type: ${response.data?.runtimeType} | Data null: ${response.data == null}');

            // Mark URL as potentially problematic
            final errorCount = (_urlErrorCount[url] ?? 0) + 1;
            _urlErrorCount[url] = errorCount;
            if (errorCount >= 5) {
              _failedUrls.add(url);
              _urlLastFailTime[url] = DateTime.now();
              SafeLogger.d('Log', '[Loop $id] URL marked as failed (0 bytes) after $errorCount tries: $url');
            }
          }
        } catch (e) {
          // Xử lý lỗi network/timeout
          stopwatch.stop();

          // Reset bytes đang tải khi có lỗi
          _loopCurrentBytes.remove(id);

          SafeLogger.d('Log', '[Loop $id] 💥 EXCEPTION CAUGHT:');
          SafeLogger.d('Log', '  URL: $url');
          SafeLogger.d('Log', '  Exception type: ${e.runtimeType}');
          SafeLogger.d('Log', '  Exception: $e');

          if (e is DioException) {
            SafeLogger.d('Log', '  DioException details:');
            SafeLogger.d('Log', '    Type: ${e.type}');
            SafeLogger.d('Log', '    Message: ${e.message}');
            SafeLogger.d('Log', '    Status code: ${e.response?.statusCode}');
            SafeLogger.d('Log', '    Response data: ${e.response?.data?.runtimeType}');
          }

          final errorCount = (_urlErrorCount[url] ?? 0) + 1;
          _urlErrorCount[url] = errorCount;
          if (errorCount >= 3) {
            _failedUrls.add(url);
            _urlLastFailTime[url] = DateTime.now();
            SafeLogger.d('Log', '[Loop $id] ❌ URL marked as failed after $errorCount errors');
          } else {
            SafeLogger.d('Log', '[Loop $id] ⚠️ Error $errorCount/3 - will retry');
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      _cancelTokens.remove(cancelToken);
      SafeLogger.d('Log', '[Loop $id] Download loop exited');
    }
  }
}
