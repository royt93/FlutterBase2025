// Widget tests for Wave 5 UI:
//   - SpeedChart type toggle: default area (LineChart) → tap bar icon → BarChart
//   - LossPieWidget renders PieChart + success/loss legends
//
// GetMaterialApp + AppTranslations so `.tr` resolves (locale forced en_US).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/speed_chart.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/loss_pie_widget.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';

Widget _app(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en', 'US'),
      fallbackLocale: const Locale('en', 'US'),
      home: Scaffold(body: home),
    );

void main() {
  testWidgets('SpeedChart toggles line/area → bar chart', (tester) async {
    await tester.pumpWidget(_app(
      SpeedChart(speeds: List<double>.generate(20, (i) => i.toDouble())),
    ));
    await tester.pumpAndSettle();

    // Default = area → a LineChart is shown, no BarChart yet.
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);

    // Tap the bar-chart toggle icon.
    await tester.tap(find.byIcon(Icons.bar_chart));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);

    // Switch back to line.
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('SpeedChart hides toggle when showTypeToggle=false', (tester) async {
    await tester.pumpWidget(_app(
      SpeedChart(speeds: const [1, 2, 3], showTypeToggle: false),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bar_chart), findsNothing);
  });

  testWidgets('LossPieWidget renders pie + legends', (tester) async {
    await tester.pumpWidget(_app(const LossPieWidget(packetLossPct: 20)));
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Successful'), findsOneWidget);
    expect(find.text('80.0%'), findsOneWidget); // success
    expect(find.text('20.0%'), findsOneWidget); // loss
  });
}
