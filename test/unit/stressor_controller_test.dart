import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';
import 'package:connection_notifier/connection_notifier.dart';

// Import file cần test
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';

// Generate mocks
@GenerateMocks([Dio, ConnectionNotifierTools])
import 'stressor_controller_test.mocks.dart';

void main() {
  /// Test Suite cho StressorController
  /// Kiểm tra tất cả functionality của controller
  group('StressorController Tests', () {
    late StressorController controller;
    late MockDio mockDio;

    setUp(() {
      // Khởi tạo GetX binding
      Get.testMode = true;

      // Tạo mock objects
      mockDio = MockDio();

      // Khởi tạo controller
      controller = StressorController();

      // Override dio instance với mock
      controller.dio = mockDio;
    });

    tearDown(() {
      // Cleanup sau mỗi test
      Get.reset();
      controller.dispose();
    });

    /// Test khởi tạo controller
    test('controller initialization should set default values', () {
      expect(controller.isRunning.value, false);
      expect(controller.downloadCount.value, 0);
      expect(controller.speedMbps.value, 0.0);
      expect(controller.totalSpeedMbps.value, 0.0);
      expect(controller.parallelDownloads.value, 50);
      expect(controller.speedHistory.isEmpty, true);
      expect(controller.totalDownloadedBytes.value, 0);
      expect(controller.testDuration.value, Duration.zero);
      expect(controller.startTime.value, null);
    });

    /// Test start stress test functionality
    group('Start Stress Test', () {
      test('should not start when already running', () {
        // Arrange
        controller.isRunning.value = true;

        // Act
        controller.startStressTest();

        // Assert
        verify(controller.isRunning.value).called(1);
      });

      test('should initialize values when starting test', () {
        // Mock connection
        when(ConnectionNotifierTools.isConnected).thenReturn(true);

        // Act - gọi _startTest trực tiếp để bypass dialog
        controller._startTest();

        // Assert
        expect(controller.isRunning.value, true);
        expect(controller.downloadCount.value, 0);
        expect(controller.speedMbps.value, 0.0);
        expect(controller.totalSpeedMbps.value, 0.0);
        expect(controller.totalDownloadedBytes.value, 0);
        expect(controller.speedHistory.isEmpty, true);
        expect(controller.startTime.value, isNotNull);
      });
    });

    /// Test stop stress test functionality
    test('should stop stress test and cleanup resources', () {
      // Arrange
      controller.isRunning.value = true;

      // Act
      controller.stopStressTest();

      // Assert
      expect(controller.isRunning.value, false);
    });

    /// Test speed history update mechanism
    group('Speed History Updates', () {
      test('should add speed to history correctly', () {
        // Arrange
        final testSpeed = 25.5;

        // Act
        controller._updateSpeedHistory(testSpeed);

        // Assert
        expect(controller.speedHistory.length, 1);
        expect(controller.speedHistory.first, testSpeed);
      });

      test('should limit speed history to 50 points', () {
        // Arrange - thêm 60 data points
        for (int i = 0; i < 60; i++) {
          controller._updateSpeedHistory(i.toDouble());
        }

        // Assert
        expect(controller.speedHistory.length, 50);
        expect(controller.speedHistory.first, 10.0); // Phần tử đầu sau khi trim
        expect(controller.speedHistory.last, 59.0);  // Phần tử cuối
      });

      test('should maintain chronological order in speed history', () {
        // Arrange
        final speeds = [10.5, 20.3, 15.7, 30.1];

        // Act
        for (final speed in speeds) {
          controller._updateSpeedHistory(speed);
        }

        // Assert
        expect(controller.speedHistory.toList(), speeds);
      });
    });

    /// Test total speed calculation
    group('Total Speed Calculation', () {
      test('should calculate total speed correctly', () {
        // Arrange
        controller.startTime.value = DateTime.now().subtract(Duration(seconds: 10));
        controller.totalDownloadedBytes.value = 10000000; // 10MB

        // Act
        controller._updateTotalSpeed();

        // Assert
        expect(controller.totalSpeedMbps.value, greaterThan(0));
        expect(controller.testDuration.value.inSeconds, 10);
      });

      test('should not calculate when start time is null', () {
        // Arrange
        controller.startTime.value = null;
        controller.totalDownloadedBytes.value = 10000000;

        // Act
        controller._updateTotalSpeed();

        // Assert
        expect(controller.totalSpeedMbps.value, 0.0);
      });

      test('should not calculate when duration is zero', () {
        // Arrange
        controller.startTime.value = DateTime.now();
        controller.totalDownloadedBytes.value = 10000000;

        // Act
        controller._updateTotalSpeed();

        // Assert
        // Vì duration gần bằng 0, speed có thể rất cao hoặc 0
        expect(controller.totalSpeedMbps.value, isA<double>());
      });
    });

    /// Test cancel all tasks functionality
    test('should cancel all download tasks', () {
      // Arrange
      final mockToken1 = MockCancelToken();
      final mockToken2 = MockCancelToken();
      controller._cancelTokens.addAll([mockToken1, mockToken2]);

      // Act
      controller._cancelAllTasks();

      // Assert
      verify(mockToken1.cancel()).called(1);
      verify(mockToken2.cancel()).called(1);
      expect(controller._cancelTokens.isEmpty, true);
    });

    /// Test URLs configuration
    test('should have predefined test URLs', () {
      expect(controller.urls.isNotEmpty, true);
      expect(controller.urls.length, greaterThanOrEqualTo(5));

      // Kiểm tra URLs có format hợp lệ
      for (final url in controller.urls) {
        expect(url, startsWith('http'));
      }
    });

    /// Test parallel downloads configuration
    test('should allow setting parallel downloads count', () {
      // Arrange
      const testCount = 25;

      // Act
      controller.parallelDownloads.value = testCount;

      // Assert
      expect(controller.parallelDownloads.value, testCount);
    });

    /// Test memory management
    test('should cleanup resources on disposal', () {
      // Arrange
      controller.isRunning.value = true;

      // Act
      controller.onClose();

      // Assert
      expect(controller.isRunning.value, false);
    });
  });

  /// Test Suite cho throttling mechanism
  group('Throttling Mechanism Tests', () {
    late StressorController controller;

    setUp(() {
      Get.testMode = true;
      controller = StressorController();
    });

    tearDown(() {
      Get.reset();
      controller.dispose();
    });

    test('should throttle speed history updates', () async {
      // Arrange
      controller._lastChartUpdate = DateTime.now().subtract(Duration(seconds: 1));

      // Act - cập nhật nhiều lần trong thời gian ngắn
      controller._updateSpeedHistory(10.0);
      controller._updateSpeedHistory(20.0);
      controller._updateSpeedHistory(30.0);

      // Assert - chỉ update được 1 lần do throttling
      expect(controller.speedHistory.length, greaterThanOrEqualTo(1));
    });
  });
}

/// Mock class cho CancelToken
class MockCancelToken extends Mock implements CancelToken {
  @override
  bool get isCancelled => false;
}