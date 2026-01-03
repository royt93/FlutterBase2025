/// Thông tin mạng tại thời điểm test
class NetworkInfo {
  final String? ssid;
  final int? signalStrength; // dBm
  final String? frequency; // '2.4 GHz' or '5 GHz'
  final String? ipAddress;
  final int? channel;

  NetworkInfo({
    this.ssid,
    this.signalStrength,
    this.frequency,
    this.ipAddress,
    this.channel,
  });

  /// Tạo instance rỗng khi không có network info
  factory NetworkInfo.empty() {
    return NetworkInfo(
      ssid: 'Unknown',
      signalStrength: null,
      frequency: null,
      ipAddress: null,
      channel: null,
    );
  }

  /// Copy with method để tạo instance mới với một số field thay đổi
  NetworkInfo copyWith({
    String? ssid,
    int? signalStrength,
    String? frequency,
    String? ipAddress,
    int? channel,
  }) {
    return NetworkInfo(
      ssid: ssid ?? this.ssid,
      signalStrength: signalStrength ?? this.signalStrength,
      frequency: frequency ?? this.frequency,
      ipAddress: ipAddress ?? this.ipAddress,
      channel: channel ?? this.channel,
    );
  }

  /// Chuyển sang JSON để debug
  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'signalStrength': signalStrength,
      'frequency': frequency,
      'ipAddress': ipAddress,
      'channel': channel,
    };
  }

  /// Tạo từ JSON
  factory NetworkInfo.fromJson(Map<String, dynamic> json) {
    return NetworkInfo(
      ssid: json['ssid'] as String?,
      signalStrength: json['signalStrength'] as int?,
      frequency: json['frequency'] as String?,
      ipAddress: json['ipAddress'] as String?,
      channel: json['channel'] as int?,
    );
  }

  @override
  String toString() {
    return 'NetworkInfo(ssid: $ssid, signal: $signalStrength dBm, freq: $frequency, ip: $ipAddress, channel: $channel)';
  }
}
