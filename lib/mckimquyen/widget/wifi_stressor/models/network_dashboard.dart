/// Thông tin mạng đầy đủ cho màn Network Dashboard (live, KHÔNG persist).
///
/// Khác `NetworkInfo` (lưu theo từng test, qua Hive adapter): đây là snapshot
/// hiện tại fetch on-demand, có thêm public IP / gateway / DNS / BSSID / link
/// speed nên không đụng schema Hive.
class NetworkDashboard {
  final String? ssid;
  final int? signalStrength; // dBm
  final String? frequency; // '2.4 GHz' / '5 GHz' / '6 GHz'
  final int? channel;
  final int? linkSpeedMbps;
  final String? localIp;
  final String? publicIp;
  final String? gatewayIp;
  final List<String> dnsServers;
  final String? bssid; // router MAC
  final String? vendor; // hãng router suy từ OUI (null nếu randomized/unknown)
  final String connectionType; // 'WiFi' / 'Mobile' / ...

  const NetworkDashboard({
    this.ssid,
    this.signalStrength,
    this.frequency,
    this.channel,
    this.linkSpeedMbps,
    this.localIp,
    this.publicIp,
    this.gatewayIp,
    this.dnsServers = const [],
    this.bssid,
    this.vendor,
    this.connectionType = 'Unknown',
  });

  /// Chất lượng tín hiệu theo dBm (giống logic trong TestResult.signalQuality).
  String? get signalQuality {
    final s = signalStrength;
    if (s == null) return null;
    if (s >= -50) return 'excellent';
    if (s >= -60) return 'good';
    if (s >= -70) return 'fair';
    return 'poor';
  }
}
