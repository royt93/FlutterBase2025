// Wave 2 integration test — end-to-end across model + scorer + UI:
//   HistoryController select 2 → ComparisonScreen shows latency/jitter rows and
//   the A–F quality grade computed from speed+latency+jitter for each test.

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

TestResult _r(String id, double avg, double lat, double jit) => TestResult(
      id: id,
      startTime: DateTime(2026, 1, 1, 10, 0),
      endTime: DateTime(2026, 1, 1, 10, 1),
      avgSpeed: avg,
      peakSpeed: avg + 5,
      minSpeed: avg - 5,
      medianSpeed: avg,
      speedHistory: [avg],
      status: 'completed',
      totalDownloadedBytes: 1024 * 1024,
      downloadCount: 1,
      avgLatencyMs: lat,
      jitterMs: jit,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('select 2 → comparison shows latency/jitter + A–F grades',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = HistoryController();
    c.allResults.value = [
      _r('good', 120, 10, 2), // → A · 99
      _r('poor', 15, 250, 70), // → F · 19
    ];
    c.toggleSelectionMode();
    c.toggleSelect('good');
    c.toggleSelect('poor');
    expect(c.selectedResults.length, 2);

    await tester.pumpWidget(_app(ComparisonScreen(results: c.selectedResults)));
    await tester.pump();

    // Latency + jitter + quality rows present
    expect(find.text('Latency'), findsOneWidget);
    expect(find.text('Jitter'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);

    // Per-test latency values
    expect(find.text('10 ms'), findsOneWidget);
    expect(find.text('250 ms'), findsOneWidget);

    // Computed grades from the full speed+latency+jitter pipeline
    expect(find.text('A · 99'), findsOneWidget);
    expect(find.text('F · 19'), findsOneWidget);
  });
}
