import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart' as network_info_plugin;
import 'package:permission_handler/permission_handler.dart';
import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';

import '../models/network_info.dart';
import '../models/network_dashboard.dart';

/// Service để lấy thông tin mạng thực tế
class NetworkInfoService {
  final _connectivity = Connectivity();
  final _networkInfo = network_info_plugin.NetworkInfo();

  /// Native channel lấy RSSI (chỉ Android; iOS không có handler → null).
  static const _wifiChannel = MethodChannel('com.saigonphantomlabs.base/wifi');

  /// Lấy cường độ tín hiệu WiFi (dBm) qua platform channel.
  /// Android: WifiManager.rssi. iOS / lỗi / không WiFi → null.
  @visibleForTesting
  Future<int?> getSignalStrength() async {
    try {
      final rssi = await _wifiChannel.invokeMethod<int>('getRssi');
      if (rssi == null || rssi >= 0) return null;
      return rssi;
    } catch (e) {
      SafeLogger.d('Log', 'getRssi failed (likely non-Android): $e');
      return null;
    }
  }

  /// Lấy map WiFi info native {rssi, frequencyMhz, linkSpeedMbps}. null nếu lỗi/iOS.
  @visibleForTesting
  Future<Map<String, dynamic>?> getWifiInfoMap() async {
    try {
      return await _wifiChannel.invokeMapMethod<String, dynamic>('getWifiInfo');
    } catch (e) {
      SafeLogger.d('Log', 'getWifiInfo failed (likely non-Android): $e');
      return null;
    }
  }

  /// Band từ tần số MHz: 2.4 / 5 / 6 GHz.
  @visibleForTesting
  static String? bandOf(int? mhz) {
    if (mhz == null || mhz <= 0) return null;
    if (mhz >= 2400 && mhz < 2500) return '2.4 GHz';
    if (mhz >= 4900 && mhz < 5900) return '5 GHz';
    if (mhz >= 5925 && mhz <= 7125) return '6 GHz';
    return '$mhz MHz';
  }

  /// Số kênh (channel) từ tần số MHz.
  @visibleForTesting
  static int? channelOf(int? mhz) {
    if (mhz == null || mhz <= 0) return null;
    if (mhz == 2484) return 14; // 2.4GHz channel 14
    if (mhz >= 2412 && mhz <= 2472) return ((mhz - 2412) ~/ 5) + 1;
    if (mhz >= 5160 && mhz <= 5885) return (mhz - 5000) ~/ 5; // 5GHz
    if (mhz >= 5955 && mhz <= 7115) return (mhz - 5950) ~/ 5; // 6GHz
    return null;
  }

  /// Map chi tiết native {gatewayIp, dns1, dns2, bssid}. null nếu lỗi/iOS.
  @visibleForTesting
  Future<Map<String, dynamic>?> getNetworkDetailsMap() async {
    try {
      return await _wifiChannel.invokeMapMethod<String, dynamic>('getNetworkDetails');
    } catch (e) {
      SafeLogger.d('Log', 'getNetworkDetails failed (likely non-Android): $e');
      return null;
    }
  }

  /// Gom dns1/dns2 từ native map thành list, loại null/rỗng/trùng.
  @visibleForTesting
  static List<String> dnsListOf(Map<String, dynamic>? map) {
    if (map == null) return const [];
    final out = <String>[];
    for (final key in ['dns1', 'dns2']) {
      final v = (map[key] as String?)?.trim();
      if (v != null && v.isNotEmpty && !out.contains(v)) out.add(v);
    }
    return out;
  }

  /// IPv4 hợp lệ thô (4 octet 0-255). Dùng để lọc body public-IP API.
  @visibleForTesting
  static bool isLikelyIpv4(String? s) {
    if (s == null) return false;
    final parts = s.trim().split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// Danh sách provider public-IP (plain-text body). Thử lần lượt, dừng ở
  /// cái đầu trả IPv4 hợp lệ — fallback khi 1 provider bị chặn/timeout.
  @visibleForTesting
  static const publicIpProviders = <String>[
    'https://api.ipify.org',
    'https://ifconfig.me/ip',
    'https://icanhazip.com',
  ];

  /// Lấy public IP qua API ngoài (có fallback). null nếu mọi provider fail.
  Future<String?> getPublicIp() async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    for (final url in publicIpProviders) {
      try {
        final resp = await dio.get<String>(url);
        final ip = resp.data?.trim();
        if (isLikelyIpv4(ip)) return ip;
      } catch (e) {
        SafeLogger.d('Log', 'getPublicIp provider $url failed: $e');
      }
    }
    return null;
  }

  /// Snapshot mạng đầy đủ cho Network Dashboard (live, không persist).
  /// Các nhánh độc lập chạy song song (hot futures) → giảm trễ; public IP
  /// (tới 5s) không còn chặn các phần native nhanh.
  Future<NetworkDashboard> getNetworkDashboard() async {
    final connectionTypeF = getConnectionType();
    final baseF = getCurrentNetworkInfo();
    final wifiF = getWifiInfoMap();
    final detailsF = getNetworkDetailsMap();
    final publicIpF = getPublicIp();

    final connectionType = await connectionTypeF;
    final base = await baseF;
    final wifi = await wifiF;
    final details = await detailsF;
    final publicIp = await publicIpF;

    return NetworkDashboard(
      ssid: base.ssid,
      signalStrength: base.signalStrength,
      frequency: base.frequency,
      channel: base.channel,
      linkSpeedMbps: (wifi?['linkSpeedMbps'] as num?)?.toInt(),
      localIp: base.ipAddress,
      publicIp: publicIp,
      gatewayIp: details?['gatewayIp'] as String?,
      dnsServers: dnsListOf(details),
      bssid: details?['bssid'] as String?,
      connectionType: connectionType,
    );
  }

  /// Request location permission để lấy WiFi SSID
  Future<bool> _requestLocationPermission() async {
    try {
      final status = await Permission.location.status;

      if (status.isGranted) {
        SafeLogger.d('Log', '📍 Location permission already granted');
        return true;
      }

      if (status.isDenied) {
        SafeLogger.d('Log', '📍 Requesting location permission...');
        final result = await Permission.location.request();

        if (result.isGranted) {
          SafeLogger.d('Log', '✅ Location permission granted');
          return true;
        } else if (result.isPermanentlyDenied) {
          SafeLogger.d('Log', '❌ Location permission permanently denied');
          return false;
        } else {
          SafeLogger.d('Log', '❌ Location permission denied');
          return false;
        }
      }

      if (status.isPermanentlyDenied) {
        SafeLogger.d('Log', '⚠️ Location permission permanently denied, opening settings...');
        // User có thể mở settings để enable permission
        await openAppSettings();
        return false;
      }

      return false;
    } catch (e) {
      SafeLogger.d('Log', '❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Lấy thông tin mạng hiện tại
  Future<NetworkInfo> getCurrentNetworkInfo() async {
    try {
      // Request location permission trước
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        SafeLogger.d('Log', '⚠️ No location permission, WiFi SSID will be unavailable');
      }

      // Kiểm tra loại kết nối
      final connectivityResult = await _connectivity.checkConnectivity();

      // Chỉ lấy info khi kết nối WiFi
      if (!connectivityResult.contains(ConnectivityResult.wifi)) {
        SafeLogger.d('Log', '📡 Not connected to WiFi, using mobile/other connection');
        return NetworkInfo(
          ssid: 'Mobile/Other',
          signalStrength: null,
          frequency: null,
          ipAddress: await _getIpAddress(),
          channel: null,
        );
      }

      // Lấy các thông tin WiFi
      String? ssid = await _getWifiSSID();
      String? ipAddress = await _getIpAddress();

      // Native WiFi info (rssi + frequency MHz) → signal + band + channel thật.
      final wifi = await getWifiInfoMap();
      final rssi = (wifi?['rssi'] as num?)?.toInt();
      final freqMhz = (wifi?['frequencyMhz'] as num?)?.toInt();
      final int? signalStrength = (rssi != null && rssi < 0) ? rssi : null;
      final int? channel = channelOf(freqMhz);
      // Band thật từ native; fallback ước lượng nếu native không có.
      final String? frequency = bandOf(freqMhz) ?? await _estimateFrequency();

      SafeLogger.d('Log', '📡 Network Info - SSID: $ssid, IP: $ipAddress, Freq: $frequency, Ch: $channel, RSSI: $signalStrength dBm');

      return NetworkInfo(
        ssid: ssid ?? 'Unknown',
        signalStrength: signalStrength, // RSSI thật qua platform channel (Android)
        frequency: frequency,
        ipAddress: ipAddress,
        channel: channel, // Channel thật từ tần số (Android)
      );
    } catch (e) {
      SafeLogger.d('Log', '❌ Error getting network info: $e');
      return NetworkInfo.empty();
    }
  }

  /// Lấy WiFi SSID
  Future<String?> _getWifiSSID() async {
    try {
      final ssid = await _networkInfo.getWifiName();

      // iOS và Android >= 9 trả về null nếu không có location permission
      if (ssid == null) {
        SafeLogger.d('Log', '⚠️ WiFi SSID is null - permission may be denied or unavailable');
        return 'Unknown';
      }

      // Android thường trả về SSID với quotes, remove chúng
      return ssid.replaceAll('"', '');
    } catch (e) {
      SafeLogger.d('Log', '❌ Error getting SSID: $e');
      return 'Unknown';
    }
  }

  /// Lấy IP address
  Future<String?> _getIpAddress() async {
    try {
      final ip = await _networkInfo.getWifiIP();
      return ip;
    } catch (e) {
      SafeLogger.d('Log', '❌ Error getting IP: $e');
      return null;
    }
  }

  /// Ước tính frequency dựa vào SSID hoặc channel
  /// Note: Không thể lấy chính xác từ Flutter, chỉ có thể guess
  Future<String?> _estimateFrequency() async {
    try {
      // Không thể lấy frequency chính xác từ Flutter
      // Sẽ cần platform channel để lấy thông tin này
      // Tạm thời return null
      return null;
    } catch (e) {
      SafeLogger.d('Log', '❌ Error estimating frequency: $e');
      return null;
    }
  }

  /// Kiểm tra xem có đang kết nối WiFi không
  Future<bool> isConnectedToWifi() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi);
    } catch (e) {
      SafeLogger.d('Log', '❌ Error checking WiFi connection: $e');
      return false;
    }
  }

  /// Lấy tên loại kết nối hiện tại
  Future<String> getConnectionType() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
        return 'Mobile';
      } else if (connectivityResult.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      SafeLogger.d('Log', '❌ Error getting connection type: $e');
      return 'Unknown';
    }
  }
}
