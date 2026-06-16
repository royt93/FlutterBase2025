// Wave 4 · Real-time alerts — threshold logic (unit) + selector (widget).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/stressor_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/control_panel_widget.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('shouldAlertLowSpeed', () {
    test('off by default (threshold 0) → never alerts', () {
      final c = StressorController();
      expect(c.alertThresholdMbps.value, 0);
      expect(c.shouldAlertLowSpeed(0), isFalse);
      expect(c.shouldAlertLowSpeed(5), isFalse);
      c.onClose();
    });

    test('alerts only when avg strictly below threshold', () {
      final c = StressorController();
      c.alertThresholdMbps.value = 10;
      expect(c.shouldAlertLowSpeed(5), isTrue);
      expect(c.shouldAlertLowSpeed(9.9), isTrue);
      expect(c.shouldAlertLowSpeed(10), isFalse);
      expect(c.shouldAlertLowSpeed(20), isFalse);
      c.onClose();
    });
  });

  testWidgets('alert selector shows presets + tap sets threshold', (tester) async {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = Get.put(StressorController());
    await tester.pumpWidget(
      _app(Scaffold(body: ControlPanelWidget(isRunning: false, controller: c))),
    );
    await tester.pump();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('10 Mbps'), findsOneWidget);

    await tester.tap(find.text('10 Mbps'));
    await tester.pump();
    expect(c.alertThresholdMbps.value, 10);
  });
}
