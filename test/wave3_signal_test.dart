// Wave 3 · Feature G tests — signal strength platform-channel handling (Dart side).
// Mocks the 'com.saigonphantomlabs.base/wifi' MethodChannel.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/services/network_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.saigonphantomlabs.base/wifi');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final svc = NetworkInfoService();

  void mockRssi(Object? Function() value) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getRssi') return value();
      return null;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('valid negative RSSI is returned as-is', () async {
    mockRssi(() => -45);
    expect(await svc.getSignalStrength(), -45);
  });

  test('0 or positive RSSI → null (not connected to WiFi)', () async {
    mockRssi(() => 0);
    expect(await svc.getSignalStrength(), isNull);
    mockRssi(() => 7);
    expect(await svc.getSignalStrength(), isNull);
  });

  test('null from native → null', () async {
    mockRssi(() => null);
    expect(await svc.getSignalStrength(), isNull);
  });

  test('platform error (e.g. iOS no handler) → null, no throw', () async {
    mockRssi(() => throw PlatformException(code: 'unavailable'));
    expect(await svc.getSignalStrength(), isNull);
  });

  group('bandOf', () {
    test('maps frequency MHz → band', () {
      expect(NetworkInfoService.bandOf(2412), '2.4 GHz');
      expect(NetworkInfoService.bandOf(2484), '2.4 GHz');
      expect(NetworkInfoService.bandOf(5180), '5 GHz');
      expect(NetworkInfoService.bandOf(5955), '6 GHz');
      expect(NetworkInfoService.bandOf(null), isNull);
      expect(NetworkInfoService.bandOf(0), isNull);
    });
  });

  group('channelOf', () {
    test('derives channel from frequency MHz', () {
      expect(NetworkInfoService.channelOf(2412), 1);
      expect(NetworkInfoService.channelOf(2437), 6);
      expect(NetworkInfoService.channelOf(2472), 13);
      expect(NetworkInfoService.channelOf(2484), 14);
      expect(NetworkInfoService.channelOf(5180), 36);
      expect(NetworkInfoService.channelOf(5955), 1); // 6GHz
      expect(NetworkInfoService.channelOf(null), isNull);
    });
  });

  test('getWifiInfoMap returns native map; error → null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getWifiInfo') {
        return {'rssi': -50, 'frequencyMhz': 5180, 'linkSpeedMbps': 433};
      }
      return null;
    });
    final m = await svc.getWifiInfoMap();
    expect(m?['frequencyMhz'], 5180);
    expect(m?['rssi'], -50);
  });
}
