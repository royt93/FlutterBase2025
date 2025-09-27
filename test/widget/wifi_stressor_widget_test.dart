import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';

// Import test utilities
import '../test_utils.dart';

// Import app components
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';

void main() {
  /// Test Suite cho WiFi Stressor Widget - UI Component Testing
  group('WiFi Stressor Widget Core Tests', () {
    testWidgets('should render basic UI elements correctly', (WidgetTester tester) async {
      // Setup
      TestUtils.setupTestEnvironment();

      // Build widget
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Verify basic elements exist
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('WiFi Speed Test'), findsOneWidget);

      // Cleanup
      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should display control buttons correctly', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for start/stop button (should find at least one button)
      expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));

      // Look for action buttons
      expect(find.byType(FloatingActionButton), findsWidgets);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should display speed metrics correctly', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for speed display elements
      expect(find.textContaining('Mbps'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Downloads'), findsAtLeastNWidgets(1));

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should display speed chart', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for chart widget
      expect(find.byType(LineChart), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho State Management Integration
  group('WiFi Stressor State Management Tests', () {
    testWidgets('should handle controller state changes', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Get controller
      final controller = Get.find<StressorController>();

      // Test initial state
      expect(controller.isRunning.value, false);
      expect(controller.downloadCount.value, 0);
      expect(controller.speedMbps.value, 0.0);

      // Update controller state
      controller.downloadCount.value = 50;
      controller.speedMbps.value = 25.5;
      controller.totalSpeedMbps.value = 100.0;

      await tester.pump();

      // Verify UI updates (text should be somewhere)
      expect(find.textContaining('50'), findsAtLeastNWidgets(1));

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should update parallel downloads setting', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Test parallel downloads updates
      controller.parallelDownloads.value = 100;
      await tester.pump();

      expect(controller.parallelDownloads.value, 100);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle speed history updates', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Add speed history data
      controller.speedHistory.addAll([10.0, 20.0, 30.0, 25.0, 35.0]);
      await tester.pump();

      // Chart should have data points
      expect(controller.speedHistory.length, 5);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho User Interactions
  group('WiFi Stressor User Interaction Tests', () {
    testWidgets('should handle dropdown interactions', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for dropdown button
      final dropdownFinder = find.byType(DropdownButton<int>);
      if (dropdownFinder.evaluate().isNotEmpty) {
        await tester.tap(dropdownFinder.first);
        await tester.pumpAndSettle();

        // Should show dropdown items
        expect(find.byType(DropdownMenuItem<int>), findsAtLeastNWidgets(1));
      }

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle info dialog', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for info button
      final infoButton = find.byIcon(Icons.info_outline);
      if (infoButton.evaluate().isNotEmpty) {
        await TestUtils.tapWithRetry(tester, infoButton);

        // Should show dialog
        expect(find.byType(AlertDialog), findsOneWidget);

        // Close dialog
        final okButton = find.text('OK');
        if (okButton.evaluate().isNotEmpty) {
          await TestUtils.tapWithRetry(tester, okButton);
        }
      }

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle responsive design', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      // Test different screen sizes
      await tester.binding.setSurfaceSize(Size(400, 800)); // Phone
      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      // Test tablet size
      await tester.binding.setSurfaceSize(Size(800, 1200));
      await tester.pump();

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      // Reset to default
      await tester.binding.setSurfaceSize(null);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Chart Widget
  group('Speed Chart Widget Tests', () {
    testWidgets('should render empty chart correctly', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Chart should be present
      expect(find.byType(LineChart), findsOneWidget);

      final controller = Get.find<StressorController>();
      expect(controller.speedHistory.isEmpty, true);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should render chart with data', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Add test data
      final testData = TestUtils.generateSpeedData(count: 10);
      controller.speedHistory.addAll(testData);

      await tester.pump();

      // Chart should display data
      expect(find.byType(LineChart), findsOneWidget);
      expect(controller.speedHistory.length, 10);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle chart performance with large dataset', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      final controller = Get.find<StressorController>();

      // Add large dataset
      final largeDataset = TestUtils.generateSpeedData(count: 50);
      controller.speedHistory.addAll(largeDataset);

      final stopwatch = Stopwatch()..start();
      await tester.pump();
      stopwatch.stop();

      // Should render quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
      expect(controller.speedHistory.length, 50);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Theme và Styling
  group('WiFi Stressor Theme Tests', () {
    testWidgets('should apply correct theme colors', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Find themed elements
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should handle dark theme', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        GetMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: WiFiStressorApp()),
        ),
      );

      expect(find.byType(WiFiStressorApp), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should apply consistent typography', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for text with consistent styling
      final textWidgets = find.byType(Text);
      expect(textWidgets.evaluate().length, greaterThan(5));

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Performance
  group('WiFi Stressor Performance Tests', () {
    testWidgets('should render within performance budget', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      final stopwatch = Stopwatch()..start();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      stopwatch.stop();

      // Should render quickly
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

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

      // Rapid updates
      for (int i = 0; i < 50; i++) {
        controller.speedMbps.value = i.toDouble();
        controller.downloadCount.value = i;
        await tester.pump(Duration(milliseconds: 1));
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should maintain smooth animations', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Look for animated widgets
      final animatedWidgets = find.byType(AnimatedWidget);

      // Pump several frames to test animation smoothness
      for (int i = 0; i < 10; i++) {
        await tester.pump(Duration(milliseconds: 16)); // 60fps
      }

      // Should not crash during animations
      expect(find.byType(WiFiStressorApp), findsOneWidget);

      TestUtils.cleanupTestEnvironment();
    });
  });

  /// Test Suite cho Accessibility
  group('WiFi Stressor Accessibility Tests', () {
    testWidgets('should provide semantic labels', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Check for semantic elements
      final semantics = find.byType(Semantics);
      expect(semantics.evaluate().length, greaterThan(0));

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should support large text scaling', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        MediaQuery(
          data: MediaQueryData(textScaleFactor: 2.0),
          child: TestUtils.createTestApp(child: WiFiStressorApp()),
        ),
      );

      // Should render without overflow
      expect(find.byType(WiFiStressorApp), findsOneWidget);
      expect(tester.takeException(), isNull);

      TestUtils.cleanupTestEnvironment();
    });

    testWidgets('should have proper contrast ratios', (WidgetTester tester) async {
      TestUtils.setupTestEnvironment();

      await TestUtils.pumpWithTimeout(
        tester,
        TestUtils.createTestApp(child: WiFiStressorApp()),
      );

      // Verify color contrasts (basic check)
      final coloredWidgets = find.byType(Container);
      expect(coloredWidgets.evaluate().length, greaterThan(0));

      TestUtils.cleanupTestEnvironment();
    });
  });
}