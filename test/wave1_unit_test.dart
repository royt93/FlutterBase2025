// Unit tests for Wave 1 features (pure logic, no UI):
//   - SpeedometerGaugeWidget.niceMax / speedColor (auto-scale + colour bands)
//   - StressorController duration-preset auto-stop decision
//   - HistoryController comparison multi-select logic
//
// These avoid Hive/timers by exercising public/`@visibleForTesting` seams only.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/controllers/history_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/stressor_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/speedometer_gauge_widget.dart';

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

  group('SpeedometerGaugeWidget.niceMax', () {
    test('scales to smallest tier >= speed', () {
      expect(SpeedometerGaugeWidget.niceMax(0), 50);
      expect(SpeedometerGaugeWidget.niceMax(49), 50);
      expect(SpeedometerGaugeWidget.niceMax(50), 50);
      expect(SpeedometerGaugeWidget.niceMax(51), 100);
      expect(SpeedometerGaugeWidget.niceMax(150), 200);
      expect(SpeedometerGaugeWidget.niceMax(9999), 2000);
    });
  });

  group('SpeedometerGaugeWidget.speedColor', () {
    test('green/amber/red thresholds at 80 and 40', () {
      expect(SpeedometerGaugeWidget.speedColor(100), const Color(0xFF10B981));
      expect(SpeedometerGaugeWidget.speedColor(80), const Color(0xFF10B981));
      expect(SpeedometerGaugeWidget.speedColor(60), const Color(0xFFF59E0B));
      expect(SpeedometerGaugeWidget.speedColor(40), const Color(0xFFF59E0B));
      expect(SpeedometerGaugeWidget.speedColor(10), const Color(0xFFEF4444));
    });
  });

  group('StressorController duration preset', () {
    test('default null (unlimited) and settable', () {
      final c = StressorController();
      expect(c.selectedDurationSec.value, isNull);
      c.selectedDurationSec.value = 30;
      expect(c.selectedDurationSec.value, 30);
      c.onClose();
    });

    test('shouldAutoStop only when limit set and elapsed >= limit', () {
      final c = StressorController();
      expect(c.shouldAutoStop(const Duration(seconds: 999)), isFalse); // no limit
      c.selectedDurationSec.value = 30;
      expect(c.shouldAutoStop(const Duration(seconds: 29)), isFalse);
      expect(c.shouldAutoStop(const Duration(seconds: 30)), isTrue);
      expect(c.shouldAutoStop(const Duration(seconds: 31)), isTrue);
      c.onClose();
    });
  });

  group('HistoryController comparison selection', () {
    test('toggleSelectionMode toggles and clears selection on exit', () {
      final c = HistoryController();
      expect(c.selectionMode.value, isFalse);
      c.toggleSelectionMode();
      expect(c.selectionMode.value, isTrue);
      c.toggleSelect('a');
      expect(c.selectedIds, contains('a'));
      c.toggleSelectionMode(); // exit → clears
      expect(c.selectionMode.value, isFalse);
      expect(c.selectedIds, isEmpty);
    });

    test('toggleSelect adds then removes', () {
      final c = HistoryController();
      c.toggleSelect('x');
      expect(c.selectedIds, ['x']);
      c.toggleSelect('x');
      expect(c.selectedIds, isEmpty);
    });

    test('selectedResults filters allResults preserving list order', () {
      final c = HistoryController();
      c.allResults.value = [
        _result(id: '1', avg: 10),
        _result(id: '2', avg: 20),
        _result(id: '3', avg: 30),
      ];
      c.toggleSelect('3'); // selected out of order
      c.toggleSelect('1');
      expect(c.selectedResults.map((r) => r.id).toList(), ['1', '3']);
    });
  });
}
