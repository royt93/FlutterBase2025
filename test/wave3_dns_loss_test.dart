// Wave 3 · Feature H tests — DNS time + packet loss model fields + formatting.

import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';

TestResult _r({double? dns, double? loss}) => TestResult(
      id: '1',
      startTime: DateTime(2026, 1, 1),
      endTime: DateTime(2026, 1, 1, 0, 1),
      avgSpeed: 50,
      peakSpeed: 60,
      minSpeed: 40,
      medianSpeed: 50,
      speedHistory: const [50],
      status: 'completed',
      totalDownloadedBytes: 1024,
      downloadCount: 1,
      dnsMs: dns,
      packetLossPct: loss,
    );

void main() {
  group('DNS + packet loss formatting', () {
    test('dnsFormatted rounds + handles null', () {
      expect(_r(dns: 12.6).dnsFormatted, '13 ms');
      expect(_r().dnsFormatted, 'N/A');
    });

    test('packetLossFormatted 1-decimal % + handles null', () {
      expect(_r(loss: 2.5).packetLossFormatted, '2.5%');
      expect(_r(loss: 0).packetLossFormatted, '0.0%');
      expect(_r().packetLossFormatted, 'N/A');
    });
  });

  group('DNS + packet loss serialization', () {
    test('toJson/fromJson round-trips', () {
      final back = TestResult.fromJson(_r(dns: 12.6, loss: 2.5).toJson());
      expect(back.dnsMs, 12.6);
      expect(back.packetLossPct, 2.5);
    });

    test('null stays null (backward-compat)', () {
      final back = TestResult.fromJson(_r().toJson());
      expect(back.dnsMs, isNull);
      expect(back.packetLossPct, isNull);
    });

    test('fromControllerData carries dns + packet loss', () {
      final r = TestResult.fromControllerData(
        startTime: DateTime(2026, 1, 1),
        speedHistory: const [10, 20],
        totalDownloadedBytes: 1024,
        downloadCount: 1,
        status: 'stopped',
        dnsMs: 9.0,
        packetLossPct: 12.5,
      );
      expect(r.dnsMs, 9.0);
      expect(r.packetLossPct, 12.5);
    });
  });
}
