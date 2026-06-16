// Integration test for the Wave 1 comparison flow:
//   HistoryController multi-select  →  selectedResults  →  ComparisonScreen render.
//
// Exercises the controller's selection state machine end-to-end into the screen
// that consumes it, asserting the right tests flow through and render together.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/controllers/history_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/presentation/comparison_screen.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: home,
    );

TestResult _result({required String id, required double avg, required List<double> hist}) {
  return TestResult(
    id: id,
    startTime: DateTime(2026, 1, 1, 10, 0),
    endTime: DateTime(2026, 1, 1, 10, 1),
    avgSpeed: avg,
    peakSpeed: hist.reduce((a, b) => a > b ? a : b),
    minSpeed: hist.reduce((a, b) => a < b ? a : b),
    medianSpeed: avg,
    speedHistory: hist,
    status: 'completed',
    totalDownloadedBytes: 1024 * 1024,
    downloadCount: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('select two of three tests → comparison renders both', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = HistoryController();
    c.allResults.value = [
      _result(id: '1', avg: 30, hist: [10, 30, 50]),
      _result(id: '2', avg: 70, hist: [20, 70, 100]),
      _result(id: '3', avg: 50, hist: [30, 50, 60]),
    ];

    // Enter selection mode and pick tests #1 and #2.
    c.toggleSelectionMode();
    c.toggleSelect('1');
    c.toggleSelect('2');

    expect(c.selectionMode.value, isTrue);
    expect(c.selectedResults.map((r) => r.id).toList(), ['1', '2']);

    await tester.pumpWidget(_app(ComparisonScreen(results: c.selectedResults)));
    await tester.pump();

    expect(find.text('Comparison'), findsOneWidget);
    expect(find.text('Avg Speed'), findsOneWidget);
    // Both selected tests labelled; the excluded #3 must not appear.
    expect(find.textContaining('#1'), findsWidgets);
    expect(find.textContaining('#2'), findsWidgets);
    expect(find.textContaining('#3'), findsNothing);
  });
}
