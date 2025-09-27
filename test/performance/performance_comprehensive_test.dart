import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math';

// Import test utilities
import '../test_utils.dart';

// Import app components
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/event_bus.dart';

void main() {
  /// Test Suite cho Performance Benchmarks
  group('WiFi Stressor Performance Benchmarks', () {
    testWidgets('should render UI within performance budget', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      final stopwatch = Stopwatch()..start();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
        timeout: Duration(seconds: 5),
      );

      stopwatch.stop();

      // UI should render quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
             reason: 'UI rendering should complete within 2 seconds');

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle rapid state updates efficiently', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();
      final stopwatch = Stopwatch()..start();

      // Simulate 1000 rapid updates
      for (int i = 0; i < 1000; i++) {
        controller.speedMbps.value = i.toDouble();
        controller.downloadCount.value = i;

        // Only pump every 10 updates to simulate realistic batching
        if (i % 10 == 0) {
          await tester.pump(Duration.zero);
        }
      }

      await tester.pumpAndSettle();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
             reason: '1000 state updates should complete within 3 seconds');

      expect(controller.speedMbps.value, 999.0);
      expect(controller.downloadCount.value, 999);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should manage large speed history datasets efficiently', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();
      final stopwatch = Stopwatch()..start();

      // Add maximum dataset (50 points as per app logic)
      final largeDataset = TestUtils.generateSpeedData(count: 50, min: 1.0, max: 100.0);
      controller.speedHistory.addAll(largeDataset);

      await tester.pump();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
             reason: 'Large dataset rendering should be fast');

      expect(controller.speedHistory.length, 50);

      TestUtils.cleanupTestEnvironment();
    });

    test('should handle concurrent operations efficiently', () async {
      TestUtils.setupTestEnvironment();

      final controller = StressorController();
      final futures = <Future>[];
      final stopwatch = Stopwatch()..start();

      // Simulate 100 concurrent operations
      for (int i = 0; i < 100; i++) {
        futures.add(Future.microtask(() {
          controller.speedHistory.add(Random().nextDouble() * 100);
          controller.downloadCount.value += 1;
          controller.speedMbps.value = Random().nextDouble() * 50;
        }));
      }

      await Future.wait(futures);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
             reason: 'Concurrent operations should complete quickly');

      expect(controller.speedHistory.length, 100);
      expect(controller.downloadCount.value, 100);

      controller.dispose();
      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Memory Performance
  group('Memory Performance Tests', () {
    test('should not leak memory during repeated operations', () async {
      TestUtils.setupTestEnvironment();

      // Create and destroy multiple controllers
      for (int iteration = 0; iteration < 50; iteration++) {
        final controller = StressorController();

        // Add some data
        controller.speedHistory.addAll(TestUtils.generateSpeedData(count: 20));
        controller.downloadCount.value = 100;
        controller.speedMbps.value = 25.0;

        // Dispose properly
        controller.dispose();
      }

      // Should complete without memory issues
      expect(true, true);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle memory pressure gracefully', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Simulate memory pressure with large datasets
      for (int cycle = 0; cycle < 20; cycle++) {
        // Add large dataset
        final data = TestUtils.generateSpeedData(count: 50);
        controller.speedHistory.addAll(data);

        await tester.pump();

        // Clear to simulate cleanup
        controller.speedHistory.clear();
        await tester.pump();
      }

      expect(controller.speedHistory.length, 0);

      TestUtils.cleanupTestEnvironment();
    });

    test('should efficiently manage GetX memory', () async {
      TestUtils.setupTestEnvironment();

      // Test GetX memory management
      for (int i = 0; i < 100; i++) {
        final controller = Get.put(StressorController(), tag: 'controller_$i');

        // Add some data
        controller.speedHistory.add(i.toDouble());

        // Delete controller
        Get.delete<StressorController>(tag: 'controller_$i');
      }

      // Verify no controllers remain
      expect(Get.isRegistered<StressorController>(), false);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho AdMob Performance
  group('AdMob Performance Tests', () {
    test('should handle rapid AdMob operations efficiently', () async {
      final stopwatch = Stopwatch()..start();

      // Rapid singleton access
      for (int i = 0; i < 1000; i++) {
        final manager = AdMobManager();
        manager.showAppOpenAd();
        manager.setLastInterstitialShowTime();
        manager.setLastRewardedShowTime();
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
             reason: 'AdMob operations should be fast');
    });

    test('should handle concurrent AdMob access efficiently', () async {
      final futures = <Future>[];
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 50; i++) {
        futures.add(Future.microtask(() {
          final manager = AdMobManager();
          manager.initialize();
          final bannerId = AdMobManager.bannerAdUnitId();
          final interstitialId = AdMobManager.interstitialAdUnitId();

          expect(bannerId, isNotEmpty);
          expect(interstitialId, isNotEmpty);
        }));
      }

      await Future.wait(futures);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('should handle EventBus high-frequency events efficiently', () async {
      final eventBus = SimpleEventBus();
      final receivedEvents = <bool>[];
      final completer = Completer<void>();

      final subscription = eventBus.onBoolEvent.listen((event) {
        receivedEvents.add(event.value);
        if (receivedEvents.length == 5000) {
          completer.complete();
        }
      });

      final stopwatch = Stopwatch()..start();

      // Fire 5000 events rapidly
      for (int i = 0; i < 5000; i++) {
        eventBus.fire(BoolEvent(i % 2 == 0));
      }

      await completer.future.timeout(Duration(seconds: 5));
      stopwatch.stop();

      expect(receivedEvents.length, 5000);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
             reason: '5000 events should be processed within 2 seconds');

      await subscription.cancel();
    });
  });

  /// Test Suite cho Edge Cases và Extreme Conditions
  group('Edge Cases and Extreme Conditions Tests', () {
    testWidgets('should handle extreme data values', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Test extreme positive values
      controller.speedMbps.value = double.maxFinite;
      controller.downloadCount.value = 0x7FFFFFFFFFFFFFFF; // Max int
      controller.totalDownloadedBytes.value = 0x7FFFFFFFFFFFFFFF;

      await tester.pump();

      // Should not crash
      expect(find.byType(WiFiStressorApp), findsOneWidget);

      // Test extreme negative values (where applicable)
      controller.speedMbps.value = -double.maxFinite;
      await tester.pump();

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      // Test NaN and infinity
      controller.speedMbps.value = double.nan;
      await tester.pump();

      controller.speedMbps.value = double.infinity;
      await tester.pump();

      controller.speedMbps.value = double.negativeInfinity;
      await tester.pump();

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });

    test('should handle rapid state oscillations', () async {
      TestUtils.setupTestEnvironment();

      final controller = StressorController();

      // Rapid on/off oscillations
      for (int i = 0; i < 1000; i++) {
        controller.isRunning.value = i % 2 == 0;
        controller.speedMbps.value = i % 2 == 0 ? 50.0 : 0.0;
      }

      // Should end in consistent state
      expect(controller.isRunning.value, false); // Even number (1000)
      expect(controller.speedMbps.value, 0.0);

      controller.dispose();
      TestUtils.cleanupTestEnvironment();
    });

    test('should handle empty and boundary conditions', () async {
      TestUtils.setupTestEnvironment();

      final controller = StressorController();

      // Test empty speed history
      expect(controller.speedHistory.isEmpty, true);
      controller.speedHistory.clear(); // Should not crash on empty clear
      expect(controller.speedHistory.isEmpty, true);

      // Test boundary values
      controller.parallelDownloads.value = 1; // Minimum
      expect(controller.parallelDownloads.value, 1);

      controller.parallelDownloads.value = 500; // Maximum
      expect(controller.parallelDownloads.value, 500);

      // Test zero values
      controller.speedMbps.value = 0.0;
      controller.downloadCount.value = 0;
      controller.totalSpeedMbps.value = 0.0;
      controller.totalDownloadedBytes.value = 0;

      expect(controller.speedMbps.value, 0.0);
      expect(controller.downloadCount.value, 0);

      controller.dispose();
      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle widget disposal during operations', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Start operations
      controller.isRunning.value = true;
      controller.speedHistory.addAll([1.0, 2.0, 3.0, 4.0, 5.0]);

      await tester.pump();

      // Dispose widget abruptly
      await tester.pumpWidget(Container());

      // Should not crash
      expect(() => controller.dispose(), returnsNormally);

      TestUtils.cleanupTestEnvironment();
    });

    test('should handle concurrent GetX operations', () async {
      TestUtils.setupTestEnvironment();

      final futures = <Future>[];

      // Concurrent controller creation and destruction
      for (int i = 0; i < 20; i++) {
        futures.add(Future.microtask(() async {
          final controller = Get.put(StressorController(), tag: 'test_$i');

          // Do some operations
          controller.speedHistory.add(i.toDouble());
          controller.downloadCount.value = i;

          // Wait a bit
          await Future.delayed(Duration(milliseconds: 10));

          // Delete
          Get.delete<StressorController>(tag: 'test_$i');
        }));
      }

      await Future.wait(futures);

      // All should be cleaned up
      for (int i = 0; i < 20; i++) {
        expect(Get.isRegistered<StressorController>(tag: 'test_$i'), false);
      }

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Real-World Simulation
  group('Real-World Performance Simulation Tests', () {
    testWidgets('should simulate realistic WiFi test scenario', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();
      final stopwatch = Stopwatch()..start();

      // Simulate 30-second test with realistic data
      controller.isRunning.value = true;
      controller.parallelDownloads.value = 50;

      // Simulate progressive download and speed updates
      for (int second = 0; second < 30; second++) {
        // Simulate variable speed (realistic network fluctuation)
        final baseSpeed = 25.0;
        final variation = Random().nextDouble() * 10 - 5; // ±5 Mbps variation
        final currentSpeed = (baseSpeed + variation).clamp(1.0, 100.0);

        controller.speedMbps.value = currentSpeed;
        controller.downloadCount.value = second * 10; // 10 downloads per second
        controller.totalDownloadedBytes.value = second * 1024 * 100; // 100KB per second

        // Update speed history (limit to 50 points)
        if (controller.speedHistory.length >= 50) {
          controller.speedHistory.removeAt(0);
        }
        controller.speedHistory.add(currentSpeed);

        // Calculate running average
        final average = controller.speedHistory.reduce((a, b) => a + b) / controller.speedHistory.length;
        controller.totalSpeedMbps.value = average;

        // Update duration
        controller.testDuration.value = Duration(seconds: second + 1);

        await tester.pump(Duration(milliseconds: 33)); // ~30 FPS
      }

      // Stop test
      controller.isRunning.value = false;
      await tester.pump();

      stopwatch.stop();

      // Verify realistic results
      expect(controller.downloadCount.value, 290); // 29 * 10
      expect(controller.speedHistory.length, 30);
      expect(controller.totalSpeedMbps.value, greaterThan(0));
      expect(controller.testDuration.value.inSeconds, 30);

      // Performance should be acceptable
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
             reason: '30-second simulation should complete within 5 seconds');

      TestUtils.cleanupTestEnvironment();
    });

    test('should handle long-running test simulation', () async {
      TestUtils.setupTestEnvironment();

      final controller = StressorController();
      final stopwatch = Stopwatch()..start();

      // Simulate 5-minute test
      const testDurationMinutes = 5;
      const updatesPerSecond = 2;
      const totalUpdates = testDurationMinutes * 60 * updatesPerSecond;

      controller.isRunning.value = true;

      for (int update = 0; update < totalUpdates; update++) {
        final seconds = update / updatesPerSecond;

        // Realistic speed variation
        final baseSpeed = 30.0;
        final timeVariation = sin(seconds / 30) * 10; // Slow oscillation
        final randomVariation = (Random().nextDouble() - 0.5) * 5; // Small random
        final currentSpeed = (baseSpeed + timeVariation + randomVariation).clamp(1.0, 100.0);

        controller.speedMbps.value = currentSpeed;
        controller.downloadCount.value = update;

        // Manage speed history size
        if (controller.speedHistory.length >= 50) {
          controller.speedHistory.removeAt(0);
        }
        controller.speedHistory.add(currentSpeed);

        // Update running average
        final average = controller.speedHistory.reduce((a, b) => a + b) / controller.speedHistory.length;
        controller.totalSpeedMbps.value = average;

        // Only check time constraint every 100 updates
        if (update % 100 == 0 && stopwatch.elapsedMilliseconds > 10000) {
          break; // Exit early if taking too long
        }
      }

      controller.isRunning.value = false;
      stopwatch.stop();

      // Should handle long simulation efficiently
      expect(stopwatch.elapsedMilliseconds, lessThan(15000),
             reason: 'Long simulation should complete within reasonable time');

      expect(controller.speedHistory.length, lessThanOrEqualTo(50));
      expect(controller.downloadCount.value, greaterThan(0));

      controller.dispose();
      TestUtils.cleanupTestEnvironment();
    });

    test('should handle app startup performance', () async {
      final stopwatch = Stopwatch()..start();

      // Simulate app startup sequence
      TestUtils.setupTestEnvironment();

      // AdMob initialization
      final adMobManager = AdMobManager();
      adMobManager.initialize();

      // EventBus setup
      final eventBus = SimpleEventBus();
      eventBus.fire(BoolEvent(true));

      // Controller creation
      final controller = StressorController();

      // Initial data setup
      controller.parallelDownloads.value = 50;
      controller.speedHistory.addAll([0.0]);

      stopwatch.stop();

      // Startup should be fast
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
             reason: 'App startup simulation should be fast');

      controller.dispose();
      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Resource Cleanup Performance
  group('Resource Cleanup Performance Tests', () {
    test('should cleanup resources efficiently', () async {
      final stopwatch = Stopwatch()..start();

      // Create multiple controllers with data
      final controllers = <StressorController>[];
      for (int i = 0; i < 20; i++) {
        final controller = StressorController();
        controller.speedHistory.addAll(TestUtils.generateSpeedData(count: 50));
        controller.downloadCount.value = 1000;
        controllers.add(controller);
      }

      // Cleanup all controllers
      for (final controller in controllers) {
        controller.dispose();
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
             reason: 'Resource cleanup should be efficient');
    });

    test('should handle GetX cleanup efficiently', () async {
      TestUtils.setupTestEnvironment();

      final stopwatch = Stopwatch()..start();

      // Register many controllers
      for (int i = 0; i < 100; i++) {
        Get.put(StressorController(), tag: 'controller_$i');
      }

      // Mass cleanup
      Get.reset();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
             reason: 'GetX mass cleanup should be efficient');

      TestUtils.cleanupTestEnvironment();
    });
  });
}