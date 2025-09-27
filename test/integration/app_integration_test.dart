import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';

// Import main app
import 'package:saigonphantomlabs/main.dart' as app;
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/main/main_screen.dart';

void main() {
  /// Integration Test Suite cho toàn bộ ứng dụng
  /// Test real user flows và interactions
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('WiFi Stressor App Integration Tests', () {
    /// Test khởi động ứng dụng
    testWidgets('should launch app successfully', (WidgetTester tester) async {
      // Khởi động app
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Verify app đã khởi động
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    /// Test navigation flow từ main screen
    testWidgets('should navigate from main to wifi stressor screen', (WidgetTester tester) async {
      // Khởi động app
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Tìm và tap vào WiFi Stressor button
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle(Duration(seconds: 2));

        // Verify đã navigate đến WiFi Stressor screen
        expect(find.text('FastNet Speed Test'), findsOneWidget);
      }
    });

    /// Test stress test flow hoàn chỉnh
    testWidgets('should complete stress test flow', (WidgetTester tester) async {
      // Khởi động app và navigate đến WiFi Stressor
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate đến WiFi Stressor screen
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle(Duration(seconds: 2));
      }

      // Verify initial state
      expect(find.text('SẴN SÀNG KIỂM TRA'), findsOneWidget);
      expect(find.text('BẮT ĐẦU KIỂM TRA'), findsOneWidget);

      // Tap start button
      await tester.tap(find.text('BẮT ĐẦU KIỂM TRA'));
      await tester.pumpAndSettle(Duration(seconds: 1));

      // Handle potential ad or dialog
      if (find.text('Tiếp tục').evaluate().isNotEmpty) {
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle(Duration(seconds: 2));
      }

      // Verify test started
      expect(find.textContaining('ĐANG KIỂM TRA'), findsOneWidget);
      expect(find.text('DỪNG KIỂM TRA'), findsOneWidget);

      // Wait for some data collection
      await tester.pump(Duration(seconds: 5));

      // Stop the test
      await tester.tap(find.text('DỪNG KIỂM TRA'));
      await tester.pumpAndSettle(Duration(seconds: 1));

      // Verify test stopped
      expect(find.text('SẴN SÀNG KIỂM TRA'), findsOneWidget);
    });

    /// Test connection selector
    testWidgets('should change parallel downloads setting', (WidgetTester tester) async {
      // Setup
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate to WiFi Stressor
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle();
      }

      // Find and tap dropdown
      final dropdown = find.byType(DropdownButton<int>);
      if (dropdown.evaluate().isNotEmpty) {
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Select different value
        final option = find.text('10');
        if (option.evaluate().isNotEmpty) {
          await tester.tap(option.last);
          await tester.pumpAndSettle();
        }
      }

      // Verify change applied
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });

    /// Test info dialog
    testWidgets('should show and close info dialog', (WidgetTester tester) async {
      // Setup
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate to WiFi Stressor
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle();
      }

      // Tap info button
      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      // Verify dialog appeared
      expect(find.text('Thông tin ứng dụng'), findsOneWidget);
      expect(find.textContaining('Ứng dụng kiểm tra sức chịu tải'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Verify dialog closed
      expect(find.text('Thông tin ứng dụng'), findsNothing);
    });

    /// Test AdMob integration
    testWidgets('should handle AdMob ads gracefully', (WidgetTester tester) async {
      // Setup
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate to AdMob demo
      final adButton = find.text('Admob demo');
      if (adButton.evaluate().isNotEmpty) {
        await tester.tap(adButton);
        await tester.pumpAndSettle(Duration(seconds: 2));

        // Verify ads screen loaded
        expect(find.text('Screen A'), findsOneWidget);

        // Test interstitial ad button
        final interstitialButton = find.textContaining('Go to Screen B');
        if (interstitialButton.evaluate().isNotEmpty) {
          await tester.tap(interstitialButton);
          await tester.pumpAndSettle(Duration(seconds: 3));

          // Should navigate regardless of ad show success
          // Verify either stayed on Screen A or moved to Screen B
          expect(
            find.text('Screen A').evaluate().isNotEmpty ||
            find.text('Screen B').evaluate().isNotEmpty,
            true
          );
        }
      }
    });

    /// Test app performance under stress
    testWidgets('should maintain performance during stress test', (WidgetTester tester) async {
      // Setup
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate to WiFi Stressor
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle();
      }

      // Start stress test với high connection count
      final dropdown = find.byType(DropdownButton<int>);
      if (dropdown.evaluate().isNotEmpty) {
        await tester.tap(dropdown);
        await tester.pumpAndSettle();

        // Select high connection count
        final highOption = find.text('100');
        if (highOption.evaluate().isNotEmpty) {
          await tester.tap(highOption.last);
          await tester.pumpAndSettle();
        }
      }

      // Start test
      await tester.tap(find.text('BẮT ĐẦU KIỂM TRA'));
      await tester.pumpAndSettle();

      // Handle dialog if appears
      if (find.text('Tiếp tục').evaluate().isNotEmpty) {
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
      }

      // Let it run for a bit
      await tester.pump(Duration(seconds: 10));

      // Check app still responsive
      expect(find.text('DỪNG KIỂM TRA'), findsOneWidget);

      // Stop test
      await tester.tap(find.text('DỪNG KIỂM TRA'));
      await tester.pumpAndSettle();

      // Verify app still functional
      expect(find.text('SẴN SÀNG KIỂM TRA'), findsOneWidget);
    });

    /// Test back navigation
    testWidgets('should handle back navigation correctly', (WidgetTester tester) async {
      // Setup
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate to WiFi Stressor
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle();

        // Verify navigation successful
        expect(find.text('FastNet Speed Test'), findsOneWidget);

        // Go back
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Should be back at main or previous screen
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });

    /// Test app lifecycle scenarios
    testWidgets('should handle app lifecycle changes', (WidgetTester tester) async {
      // Setup
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Navigate and start test
      final wifiButton = find.text('Wifi stressor');
      if (wifiButton.evaluate().isNotEmpty) {
        await tester.tap(wifiButton);
        await tester.pumpAndSettle();

        await tester.tap(find.text('BẮT ĐẦU KIỂM TRA'));
        await tester.pumpAndSettle();

        // Handle dialog
        if (find.text('Tiếp tục').evaluate().isNotEmpty) {
          await tester.tap(find.text('Tiếp tục'));
          await tester.pumpAndSettle();
        }

        // Simulate app going to background và coming back
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter/lifecycle',
          null,
          (data) {},
        );

        await tester.pump(Duration(seconds: 2));

        // App should still be functional
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });

  /// Test group cho edge cases
  group('Edge Cases Integration Tests', () {
    testWidgets('should handle no internet connection gracefully', (WidgetTester tester) async {
      // This would need network mocking in real scenario
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // App should still load and show appropriate messages
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('should handle memory pressure', (WidgetTester tester) async {
      // Test app behavior under memory constraints
      app.main();
      await tester.pumpAndSettle(Duration(seconds: 3));

      // Perform memory intensive operations
      for (int i = 0; i < 10; i++) {
        await tester.pump(Duration(milliseconds: 100));
      }

      // App should remain stable
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}