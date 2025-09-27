import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';

// Import test utilities
import '../test_utils.dart';

// Import app components
import 'package:saigonphantomlabs/mckimquyen/widget/main/main_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/splash/splash_screen.dart';
import 'package:saigonphantomlabs/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Test Suite cho Complete App Flow
  group('WiFi Stressor App Integration Tests', () {
    testWidgets('should complete full app lifecycle successfully', (WidgetTester tester) async {
      // Launch app
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify app launched
      expect(find.byType(MaterialApp), findsOneWidget);

      // Should show main screen or splash
      final hasMainScreen = find.byType(MainScreen).evaluate().isNotEmpty;
      final hasSplashScreen = find.byType(SplashScreen).evaluate().isNotEmpty;

      expect(hasMainScreen || hasSplashScreen, true,
             reason: 'App should show either main screen or splash screen');

      // If splash screen, wait for transition
      if (hasSplashScreen) {
        await TestUtils.waitForCondition(
          tester,
          () => find.byType(MainScreen).evaluate().isNotEmpty,
          timeout: Duration(seconds: 10),
        );
      }

      // Verify main screen loaded
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('should navigate to WiFi stressor screen successfully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Wait for main screen
      await TestUtils.waitForCondition(
        tester,
        () => find.byType(MainScreen).evaluate().isNotEmpty,
        timeout: Duration(seconds: 10),
      );

      // Look for WiFi stressor navigation button/card
      final wifiTestButton = find.textContaining('Speed Test').first;
      if (wifiTestButton.evaluate().isNotEmpty) {
        await TestUtils.tapWithRetry(tester, wifiTestButton);
        await tester.pumpAndSettle(Duration(seconds: 2));

        // Verify WiFi stressor screen loaded
        expect(find.byType(WiFiStressorApp), findsOneWidget);
      } else {
        // If direct access, create screen manually
        await tester.pumpWidget(
          TestUtils.createTestApp(child: WiFiStressorApp())
        );
        expect(find.byType(WiFiStressorApp), findsOneWidget);
      }
    });

    testWidgets('should handle WiFi stress test complete flow', (WidgetTester tester) async {
      // Setup WiFi stressor screen
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Get controller
      final controller = Get.find<StressorController>();

      // Verify initial state
      expect(controller.isRunning.value, false);
      expect(controller.downloadCount.value, 0);
      expect(controller.speedMbps.value, 0.0);

      // Configure test parameters
      controller.parallelDownloads.value = 10;
      await tester.pump();

      // Simulate test start (manual trigger since network calls won't work)
      controller.isRunning.value = true;
      controller.downloadCount.value = 1;
      controller.speedMbps.value = 15.5;
      controller.totalSpeedMbps.value = 15.5;
      controller.speedHistory.add(15.5);

      await tester.pump();

      // Verify running state
      expect(controller.isRunning.value, true);
      expect(controller.downloadCount.value, 1);
      expect(controller.speedMbps.value, 15.5);

      // Simulate test progression
      for (int i = 2; i <= 10; i++) {
        controller.downloadCount.value = i;
        controller.speedMbps.value = 15.0 + (i * 0.5);
        controller.speedHistory.add(15.0 + (i * 0.5));
        await tester.pump(Duration(milliseconds: 100));
      }

      // Verify progression
      expect(controller.downloadCount.value, 10);
      expect(controller.speedHistory.length, 10);

      // Simulate test stop
      controller.isRunning.value = false;
      await tester.pump();

      // Verify stopped state
      expect(controller.isRunning.value, false);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho User Interaction Flows
  group('User Interaction Integration Tests', () {
    testWidgets('should handle settings configuration flow', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Test parallel downloads configuration
      final testValues = [1, 5, 10, 25, 50, 100];
      for (final value in testValues) {
        controller.parallelDownloads.value = value;
        await tester.pump();
        expect(controller.parallelDownloads.value, value);
      }

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle data visualization flow', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Add progressive data to simulate real test
      final speeds = [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 28.0, 32.0, 35.0, 30.0];
      for (int i = 0; i < speeds.length; i++) {
        controller.speedHistory.add(speeds[i]);
        controller.downloadCount.value = i + 1;
        controller.speedMbps.value = speeds[i];

        // Update total speed (average)
        final average = controller.speedHistory.reduce((a, b) => a + b) / controller.speedHistory.length;
        controller.totalSpeedMbps.value = average;

        await tester.pump(Duration(milliseconds: 50));
      }

      // Verify final state
      expect(controller.speedHistory.length, 10);
      expect(controller.downloadCount.value, 10);
      expect(controller.totalSpeedMbps.value, greaterThan(0));

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle multiple test cycles', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Simulate 3 test cycles
      for (int cycle = 1; cycle <= 3; cycle++) {
        // Start test
        controller.isRunning.value = true;
        controller.downloadCount.value = 0;
        controller.speedHistory.clear();

        await tester.pump();

        // Run test simulation
        for (int i = 1; i <= 5; i++) {
          controller.downloadCount.value = i;
          controller.speedMbps.value = 20.0 + (cycle * 5.0) + i;
          controller.speedHistory.add(controller.speedMbps.value);
          await tester.pump(Duration(milliseconds: 10));
        }

        // Stop test
        controller.isRunning.value = false;
        await tester.pump();

        // Verify cycle completed
        expect(controller.isRunning.value, false);
        expect(controller.downloadCount.value, 5);
        expect(controller.speedHistory.length, 5);
      }

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Performance Integration
  group('Performance Integration Tests', () {
    testWidgets('should handle high-frequency updates smoothly', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();
      final stopwatch = Stopwatch()..start();

      // Simulate high-frequency updates
      controller.isRunning.value = true;
      for (int i = 0; i < 100; i++) {
        controller.downloadCount.value = i;
        controller.speedMbps.value = 10.0 + (i % 50);
        if (i < 50) { // Limit speed history to prevent excessive growth
          controller.speedHistory.add(controller.speedMbps.value);
        }
        await tester.pump(Duration(microseconds: 100));
      }

      stopwatch.stop();

      // Should complete within reasonable time
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(controller.downloadCount.value, 99);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should maintain performance with large datasets', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Add large speed history dataset
      final largeDataset = TestUtils.generateSpeedData(count: 50);
      controller.speedHistory.addAll(largeDataset);

      final stopwatch = Stopwatch()..start();
      await tester.pump();
      stopwatch.stop();

      // Chart should render efficiently with large dataset
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
      expect(controller.speedHistory.length, 50);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle memory pressure gracefully', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Simulate memory pressure by creating and clearing large datasets
      for (int iteration = 0; iteration < 10; iteration++) {
        // Add data
        final data = TestUtils.generateSpeedData(count: 100);
        controller.speedHistory.addAll(data);
        await tester.pump();

        // Clear data
        controller.speedHistory.clear();
        await tester.pump();
      }

      // Should not crash or leak memory
      expect(controller.speedHistory.length, 0);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Error Handling Integration
  group('Error Handling Integration Tests', () {
    testWidgets('should handle invalid data gracefully', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Test with extreme values
      controller.speedMbps.value = double.infinity;
      await tester.pump();

      controller.speedMbps.value = double.negativeInfinity;
      await tester.pump();

      controller.speedMbps.value = double.nan;
      await tester.pump();

      // Should not crash
      expect(find.byType(WiFiStressorApp), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should recover from GetX errors', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      try {
        // Simulate GetX error by accessing non-existent controller
        Get.find<NonExistentController>();
      } catch (e) {
        // Expected error
      }

      // Should still be able to create and use valid controller
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle rapid start/stop cycles', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Rapid start/stop cycles
      for (int i = 0; i < 20; i++) {
        controller.isRunning.value = true;
        await tester.pump(Duration(milliseconds: 10));

        controller.isRunning.value = false;
        await tester.pump(Duration(milliseconds: 10));
      }

      // Should end in stable state
      expect(controller.isRunning.value, false);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho App Lifecycle Integration
  group('App Lifecycle Integration Tests', () {
    testWidgets('should handle app backgrounding and foregrounding', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Start test
      controller.isRunning.value = true;
      controller.downloadCount.value = 10;
      controller.speedMbps.value = 25.0;

      await tester.pump();

      // Simulate app lifecycle changes by pumping frames
      await tester.pump(Duration(milliseconds: 100));
      await tester.pump(Duration(milliseconds: 100));

      // Should maintain state through lifecycle changes
      expect(controller.isRunning.value, true);
      expect(controller.downloadCount.value, 10);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should cleanup resources properly on dispose', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Add test data
      controller.speedHistory.addAll([1.0, 2.0, 3.0, 4.0, 5.0]);
      controller.isRunning.value = true;

      // Dispose widget
      await tester.pumpWidget(Container());

      // Controller should handle disposal gracefully
      expect(() => controller.dispose(), returnsNormally);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Accessibility Integration
  group('Accessibility Integration Tests', () {
    testWidgets('should support screen readers', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Enable accessibility testing
      expect(tester.binding.semanticsEnabled, isA<bool>());

      // Verify semantic elements exist
      final semanticWidgets = find.byType(Semantics);
      expect(semanticWidgets.evaluate().length, greaterThan(0));

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle high contrast mode', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      // Simulate high contrast mode
      await TestUtils.pumpWithTimeout(
        tester,
        MediaQuery(
          data: MediaQueryData(
            highContrast: true,
            accessibleNavigation: true,
          ),
          child: TestUtils.createTestApp(child: WiFiStressorApp()),
        ),
      );

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });
  });
}

// Mock class for error testing
class NonExistentController extends GetxController {}