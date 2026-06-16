// Wave 2 widget tests:
//   - control panel shows latency + jitter tiles while running
//   - test-detail screen shows the quality badge + latency/jitter rows
//   - export bottom-sheet offers CSV / JSON / PDF

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/controllers/history_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/presentation/test_detail_screen.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/stressor_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/control_panel_widget.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: home,
    );

TestResult _result({double? lat, double? jit, double avg = 90}) => TestResult(
      id: '1',
      startTime: DateTime(2026, 1, 1, 10, 0),
      endTime: DateTime(2026, 1, 1, 10, 1),
      avgSpeed: avg,
      peakSpeed: avg + 20,
      minSpeed: avg - 10,
      medianSpeed: avg,
      speedHistory: const [10, 50, 90],
      status: 'completed',
      totalDownloadedBytes: 5 * 1024 * 1024,
      downloadCount: 3,
      avgLatencyMs: lat,
      jitterMs: jit,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('control panel shows latency + jitter tiles while running',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = Get.put(StressorController());
    c.latencyMs.value = 23.0;
    c.jitterMs.value = 5.0;
    await tester.pumpWidget(
      _app(Scaffold(body: ControlPanelWidget(isRunning: true, controller: c))),
    );
    await tester.pump();

    expect(find.text('Latency'), findsOneWidget);
    expect(find.text('23 ms'), findsOneWidget);
    expect(find.text('Jitter'), findsOneWidget);
    expect(find.text('5 ms'), findsOneWidget);
  });

  testWidgets('test-detail shows quality grade badge + latency/jitter rows',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // speed 90 → 45pts, latency 20 → 28pts, jitter 3 → 19.4pts ⇒ 92 → grade A
    await tester.pumpWidget(_app(TestDetailScreen(result: _result(lat: 20, jit: 3))));
    await tester.pump();

    expect(find.text('Quality'), findsWidgets); // badge label + info row label
    expect(find.text('A'), findsOneWidget); // grade letter in badge
    expect(find.text('92/100'), findsOneWidget); // score
    expect(find.text('20 ms'), findsOneWidget); // latency row value
    expect(find.text('3 ms'), findsOneWidget); // jitter row value
  });

  testWidgets('export bottom-sheet offers CSV / JSON / PDF', (tester) async {
    final c = Get.put(HistoryController());
    c.allResults.value = [_result(lat: 20, jit: 3)];
    await tester.pumpWidget(
      _app(Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: c.exportData,
            child: const Text('go'),
          ),
        ),
      )),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('JSON'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
  });
}
