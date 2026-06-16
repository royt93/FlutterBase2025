// Wave 4 · Upload speed — model field round-trip + formatting.

import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';

TestResult _r({double? up}) => TestResult(
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
      uploadMbps: up,
    );

void main() {
  test('uploadFormatted 1-decimal Mbps + null', () {
    expect(_r(up: 12.34).uploadFormatted, '12.3 Mbps');
    expect(_r().uploadFormatted, 'N/A');
  });

  test('toJson/fromJson round-trips uploadMbps', () {
    expect(TestResult.fromJson(_r(up: 12.3).toJson()).uploadMbps, 12.3);
    expect(TestResult.fromJson(_r().toJson()).uploadMbps, isNull);
  });

  test('fromControllerData carries uploadMbps', () {
    final r = TestResult.fromControllerData(
      startTime: DateTime(2026, 1, 1),
      speedHistory: const [10],
      totalDownloadedBytes: 1024,
      downloadCount: 1,
      status: 'stopped',
      uploadMbps: 8.5,
    );
    expect(r.uploadMbps, 8.5);
  });
}
