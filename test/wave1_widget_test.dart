// Widget tests for Wave 1 UI:
//   - ControlPanelWidget duration preset chips (idle) + tap updates controller
//   - SpeedometerGaugeWidget renders the live speed value + a CustomPaint
//   - ComparisonScreen renders metric rows + the overlaid LineChart
//
// GetMaterialApp + AppTranslations so `.tr` resolves (locale forced en_US).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/presentation/comparison_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/stressor_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/control_panel_widget.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/speedometer_gauge_widget.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: home,
    );

TestResult _result({
  required String id,
  required double avg,
  double? peak,
  List<double>? hist,
}) {
  return TestResult(
    id: id,
    startTime: DateTime(2026, 1, 1, 10, 0),
    endTime: DateTime(2026, 1, 1, 10, 1),
    avgSpeed: avg,
    peakSpeed: peak ?? avg,
    minSpeed: 0,
    medianSpeed: avg,
    speedHistory: hist ?? [avg],
    status: 'completed',
    totalDownloadedBytes: 1024 * 1024,
    downloadCount: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('control panel shows duration presets when idle + tap updates controller',
      (tester) async {
    final c = Get.put(StressorController());
    await tester.pumpWidget(
      _app(Scaffold(body: ControlPanelWidget(isRunning: false, controller: c))),
    );
    await tester.pump();

    expect(find.text('Unlimited'), findsOneWidget);
    expect(find.text('15s'), findsOneWidget);
    expect(find.text('30s'), findsOneWidget);
    expect(find.text('1m'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('30s'));
    await tester.pump();
    expect(c.selectedDurationSec.value, 30);
  });

  testWidgets('control panel hides duration presets while running', (tester) async {
    final c = Get.put(StressorController());
    await tester.pumpWidget(
      _app(Scaffold(body: ControlPanelWidget(isRunning: true, controller: c))),
    );
    await tester.pump();
    expect(find.text('Unlimited'), findsNothing);
  });

  testWidgets('speedometer gauge renders live speed value + CustomPaint',
      (tester) async {
    final c = Get.put(StressorController());
    c.speedMbps.value = 123.4;
    await tester.pumpWidget(
      _app(Scaffold(body: Center(child: SpeedometerGaugeWidget(controller: c)))),
    );
    await tester.pump();

    expect(find.text('123.4'), findsOneWidget);
    expect(find.text('Mbps'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('comparison screen shows metric rows + chart for two tests',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final results = [
      _result(id: '1', avg: 50, peak: 80, hist: [10, 50, 80]),
      _result(id: '2', avg: 90, peak: 120, hist: [20, 90, 120]),
    ];
    await tester.pumpWidget(_app(ComparisonScreen(results: results)));
    await tester.pump();

    expect(find.text('Comparison'), findsOneWidget);
    expect(find.text('Avg Speed'), findsOneWidget);
    expect(find.text('Peak Speed'), findsOneWidget);
    expect(find.text('Min Speed'), findsOneWidget);
    expect(find.text('Median'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    // Both test columns labelled.
    expect(find.textContaining('#1'), findsWidgets);
    expect(find.textContaining('#2'), findsWidgets);
  });
}
