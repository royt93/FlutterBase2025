// Wave 2 · Feature D tests — latency/jitter math + TestResult latency fields.

import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/services/latency_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LatencyService.jitter', () {
    test('returns 0 for < 2 samples', () {
      expect(LatencyService.jitter([]), 0);
      expect(LatencyService.jitter([42]), 0);
    });

    test('mean absolute difference of consecutive samples', () {
      // |20-10| + |10-20| = 20 over 2 gaps → 10
      expect(LatencyService.jitter([10, 20, 10]), 10);
      // stable samples → 0 jitter
      expect(LatencyService.jitter([5, 5, 5]), 0);
      // |10-30|+|30-20| = 30 over 2 → 15
      expect(LatencyService.jitter([10, 30, 20]), 15);
    });
  });

  group('LatencyService.average', () {
    test('returns 0 for empty', () => expect(LatencyService.average([]), 0));
    test('mean of samples', () {
      expect(LatencyService.average([10, 20, 30]), 20);
    });
  });

  group('TestResult latency fields', () {
    TestResult base({double? lat, double? jit}) => TestResult(
          id: '1',
          startTime: DateTime(2026, 1, 1),
          endTime: DateTime(2026, 1, 1, 0, 1),
          avgSpeed: 50,
          peakSpeed: 60,
          minSpeed: 40,
          medianSpeed: 50,
          speedHistory: const [40, 50, 60],
          status: 'completed',
          totalDownloadedBytes: 1024,
          downloadCount: 1,
          avgLatencyMs: lat,
          jitterMs: jit,
        );

    test('toJson/fromJson round-trips latency + jitter', () {
      final r = base(lat: 23.4, jit: 5.6);
      final back = TestResult.fromJson(r.toJson());
      expect(back.avgLatencyMs, 23.4);
      expect(back.jitterMs, 5.6);
    });

    test('null latency stays null through json (backward-compat)', () {
      final back = TestResult.fromJson(base().toJson());
      expect(back.avgLatencyMs, isNull);
      expect(back.jitterMs, isNull);
    });

    test('formatted getters round + handle null', () {
      expect(base(lat: 22.7, jit: 4.2).latencyFormatted, '23 ms');
      expect(base(lat: 22.7, jit: 4.2).jitterFormatted, '4 ms');
      expect(base().latencyFormatted, 'N/A');
      expect(base().jitterFormatted, 'N/A');
    });

    test('fromControllerData carries latency + jitter', () {
      final r = TestResult.fromControllerData(
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 1),
        speedHistory: const [10, 20, 30],
        totalDownloadedBytes: 1024,
        downloadCount: 1,
        status: 'stopped',
        avgLatencyMs: 30.0,
        jitterMs: 8.0,
      );
      expect(r.avgLatencyMs, 30.0);
      expect(r.jitterMs, 8.0);
    });
  });
}
