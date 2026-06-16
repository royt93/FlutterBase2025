// Unit tests for Wave 5 pure helpers:
//   - NetworkInfoService.isLikelyIpv4 / dnsListOf
//   - SpeedChart.downsample (bar chart bucketing)
//   - LossPieWidget.successOf
//   - NetworkDashboard.signalQuality tiers

import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/network_dashboard.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/network_info.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/test_result.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/services/network_info_service.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/speed_chart.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/widgets/loss_pie_widget.dart';

TestResult _resultWithSignal(int? dbm) => TestResult(
      id: 't',
      startTime: DateTime(2026, 1, 1),
      avgSpeed: 10,
      peakSpeed: 10,
      minSpeed: 10,
      medianSpeed: 10,
      speedHistory: const [10],
      status: 'completed',
      totalDownloadedBytes: 0,
      downloadCount: 0,
      networkInfo: dbm == null ? null : NetworkInfo(signalStrength: dbm),
    );

void main() {
  group('NetworkInfoService.isLikelyIpv4', () {
    test('valid IPv4 → true', () {
      expect(NetworkInfoService.isLikelyIpv4('192.168.1.1'), isTrue);
      expect(NetworkInfoService.isLikelyIpv4('  8.8.8.8  '), isTrue);
      expect(NetworkInfoService.isLikelyIpv4('255.255.255.255'), isTrue);
    });
    test('invalid → false', () {
      expect(NetworkInfoService.isLikelyIpv4(null), isFalse);
      expect(NetworkInfoService.isLikelyIpv4(''), isFalse);
      expect(NetworkInfoService.isLikelyIpv4('1.2.3'), isFalse);
      expect(NetworkInfoService.isLikelyIpv4('256.1.1.1'), isFalse);
      expect(NetworkInfoService.isLikelyIpv4('a.b.c.d'), isFalse);
      expect(NetworkInfoService.isLikelyIpv4('1.2.3.4.5'), isFalse);
    });
  });

  group('NetworkInfoService.dnsListOf', () {
    test('null map → empty', () {
      expect(NetworkInfoService.dnsListOf(null), isEmpty);
    });
    test('filters null/empty and dedups', () {
      expect(
        NetworkInfoService.dnsListOf({'dns1': '8.8.8.8', 'dns2': '8.8.4.4'}),
        ['8.8.8.8', '8.8.4.4'],
      );
      expect(NetworkInfoService.dnsListOf({'dns1': '1.1.1.1', 'dns2': null}), ['1.1.1.1']);
      expect(NetworkInfoService.dnsListOf({'dns1': '1.1.1.1', 'dns2': '1.1.1.1'}), ['1.1.1.1']);
      expect(NetworkInfoService.dnsListOf({'dns1': '', 'dns2': '  '}), isEmpty);
    });
  });

  group('SpeedChart.downsample', () {
    test('passthrough when within maxBars', () {
      expect(SpeedChart.downsample([1, 2, 3], 48), [1, 2, 3]);
      expect(SpeedChart.downsample(const [], 48), isEmpty);
    });
    test('buckets average when over maxBars', () {
      final input = List<double>.generate(100, (i) => i.toDouble());
      final out = SpeedChart.downsample(input, 10);
      expect(out.length, lessThanOrEqualTo(10));
      // First bucket averages 0..9 → 4.5
      expect(out.first, closeTo(4.5, 0.001));
    });
    test('maxBars <= 0 → empty', () {
      expect(SpeedChart.downsample([1, 2, 3], 0), isEmpty);
    });
  });

  group('LossPieWidget.successOf', () {
    test('100 - loss, clamped', () {
      expect(LossPieWidget.successOf(0), 100);
      expect(LossPieWidget.successOf(25), 75);
      expect(LossPieWidget.successOf(100), 0);
      expect(LossPieWidget.successOf(150), 0); // clamp
    });
  });

  group('NetworkDashboard.signalQuality', () {
    test('tiers by dBm', () {
      expect(const NetworkDashboard(signalStrength: -40).signalQuality, 'excellent');
      expect(const NetworkDashboard(signalStrength: -55).signalQuality, 'good');
      expect(const NetworkDashboard(signalStrength: -65).signalQuality, 'fair');
      expect(const NetworkDashboard(signalStrength: -80).signalQuality, 'poor');
      expect(const NetworkDashboard(signalStrength: null).signalQuality, isNull);
    });
  });

  group('TestResult.signalQuality (i18n tier keys, unified)', () {
    test('returns lowercase tier keys matching NetworkDashboard', () {
      expect(_resultWithSignal(-40).signalQuality, 'excellent');
      expect(_resultWithSignal(-55).signalQuality, 'good');
      expect(_resultWithSignal(-65).signalQuality, 'fair');
      expect(_resultWithSignal(-80).signalQuality, 'poor');
      expect(_resultWithSignal(null).signalQuality, isNull);
    });
  });

  group('NetworkInfoService.publicIpProviders', () {
    test('has multiple fallback providers incl. ipify', () {
      expect(NetworkInfoService.publicIpProviders.length, greaterThanOrEqualTo(2));
      expect(NetworkInfoService.publicIpProviders.first, contains('ipify'));
      // All entries are https URLs.
      for (final url in NetworkInfoService.publicIpProviders) {
        expect(url, startsWith('https://'));
      }
    });
  });
}
