// Wave 2 · Feature F tests — CSV / JSON / PDF generation from history.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/controllers/history_controller.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';

TestResult _r(String id, double avg, {double? lat, double? jit}) => TestResult(
      id: id,
      startTime: DateTime(2026, 1, 1, 10, 0),
      endTime: DateTime(2026, 1, 1, 10, 1),
      avgSpeed: avg,
      peakSpeed: avg + 10,
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

  late HistoryController c;
  setUp(() {
    c = HistoryController();
    c.allResults.value = [
      _r('1', 50, lat: 20, jit: 3),
      _r('2', 90, lat: 40, jit: 8),
    ];
  });

  test('CSV has new headers + one row per test', () {
    final csv = c.generateCsv();
    final lines = csv.trim().split('\n');
    expect(lines.length, 3); // header + 2 rows
    expect(lines.first, contains('Latency (ms)'));
    expect(lines.first, contains('Jitter (ms)'));
    expect(lines.first, contains('Quality'));
    expect(lines[1], contains('20.0')); // latency of test 1
  });

  test('JSON parses back to the same count with latency fields', () {
    final json = c.generateJson();
    final decoded = jsonDecode(json) as List;
    expect(decoded.length, 2);
    final first = decoded.first as Map<String, dynamic>;
    expect(first['avgLatencyMs'], 20);
    expect(first['jitterMs'], 3);
    // round-trips through the model
    final back = TestResult.fromJson(first);
    expect(back.id, '1');
    expect(back.avgLatencyMs, 20);
  });

  test('PDF returns a non-empty %PDF byte stream', () async {
    final bytes = await c.generatePdf();
    expect(bytes.length, greaterThan(100));
    // PDF magic header: %PDF
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
