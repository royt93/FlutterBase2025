import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Utilities cho testing
/// Chứa các helper functions và setup common cho tests

class TestUtils {
  /// Setup GetX cho testing
  static void setupGetX() {
    Get.testMode = true;
  }

  /// Cleanup GetX sau testing
  static void cleanupGetX() {
    Get.reset();
  }

  /// Tạo MaterialApp wrapper cho widget testing
  static Widget createTestApp({required Widget child}) {
    return GetMaterialApp(
      home: Scaffold(body: child),
    );
  }

  /// Pump widget với timeout
  static Future<void> pumpWithTimeout(
    WidgetTester tester,
    Widget widget, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle(timeout);
  }

  /// Wait for condition với timeout
  static Future<void> waitForCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      if (condition()) return;

      await tester.pump(interval);
    }

    throw TimeoutException('Condition not met within timeout', timeout);
  }

  /// Tap widget với retry logic
  static Future<void> tapWithRetry(
    WidgetTester tester,
    Finder finder, {
    int maxRetries = 3,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        await tester.tap(finder);
        await tester.pumpAndSettle();
        return;
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await tester.pump(Duration(milliseconds: 500));
      }
    }
  }

  /// Verify text xuất hiện với timeout
  static Future<void> expectTextWithTimeout(
    WidgetTester tester,
    String text, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await waitForCondition(
      tester,
      () => find.text(text).evaluate().isNotEmpty,
      timeout: timeout,
    );
    expect(find.text(text), findsOneWidget);
  }

  /// Generate test data cho speed history
  static List<double> generateSpeedData({
    int count = 10,
    double min = 5.0,
    double max = 50.0,
  }) {
    final data = <double>[];
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < count; i++) {
      final value = min + (max - min) * ((random + i) % 1000) / 1000;
      data.add(double.parse(value.toStringAsFixed(2)));
    }

    return data;
  }

  /// Tạo mock download response
  static List<int> createMockResponse({int sizeKB = 100}) {
    return List.filled(sizeKB * 1024, 1);
  }

  /// Setup test environment
  static void setupTestEnvironment() {
    setupGetX();

    // Disable animations cho testing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsApp.debugAllowBannerOverride = false;
    });
  }

  /// Cleanup test environment
  static void cleanupTestEnvironment() {
    cleanupGetX();
  }

  /// Verify widget hierarchy
  static void verifyWidgetHierarchy(
    WidgetTester tester,
    List<Type> expectedTypes,
  ) {
    for (final type in expectedTypes) {
      expect(find.byType(type), findsOneWidget);
    }
  }

  /// Simulate network delay
  static Future<void> simulateNetworkDelay({
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    await Future.delayed(delay);
  }

  /// Check if widget is visible on screen
  static bool isWidgetVisible(WidgetTester tester, Finder finder) {
    try {
      final widget = tester.widget(finder);
      final renderObject = tester.renderObject(finder);
      return widget != null && renderObject != null;
    } catch (e) {
      return false;
    }
  }

  /// Scroll to widget nếu cần
  static Future<void> scrollToWidget(
    WidgetTester tester,
    Finder finder, {
    Finder? scrollable,
  }) async {
    if (!isWidgetVisible(tester, finder)) {
      await tester.scrollUntilVisible(
        finder,
        500.0,
        scrollable: scrollable,
      );
    }
  }

  /// Generate test constants
  static const Duration shortTimeout = Duration(seconds: 1);
  static const Duration mediumTimeout = Duration(seconds: 3);
  static const Duration longTimeout = Duration(seconds: 10);

  static const List<int> testConnectionCounts = [1, 5, 10, 25, 50];
  static const List<String> testUrls = [
    'https://httpbin.org/bytes/1024',
    'https://httpbin.org/bytes/2048',
  ];

  static const Map<String, dynamic> mockMetrics = {
    'downloadCount': 5,
    'speedMbps': 25.5,
    'totalSpeedMbps': 22.3,
    'totalDownloadedBytes': 1048576, // 1MB
  };
}

/// Custom matcher cho testing
class CustomMatchers {
  /// Matcher kiểm tra speed value trong range hợp lý
  static Matcher isValidSpeed = predicate<double>(
    (value) => value >= 0 && value <= 1000, // 0-1000 Mbps
    'is valid speed value',
  );

  /// Matcher kiểm tra download count
  static Matcher isValidDownloadCount = predicate<int>(
    (value) => value >= 0,
    'is valid download count',
  );

  /// Matcher kiểm tra duration
  static Matcher isValidDuration = predicate<Duration>(
    (value) => value.inMilliseconds >= 0,
    'is valid duration',
  );
}

/// Exception cho timeout
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message (timeout: $timeout)';
}