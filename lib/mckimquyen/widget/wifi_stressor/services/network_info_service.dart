import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart' as network_info_plugin;
import 'package:permission_handler/permission_handler.dart';
import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';

import '../models/network_info.dart';

/// Service để lấy thông tin mạng thực tế
class NetworkInfoService {
  final _connectivity = Connectivity();
  final _networkInfo = network_info_plugin.NetworkInfo();

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
      String? frequency = await _estimateFrequency();

      SafeLogger.d('Log', '📡 Network Info - SSID: $ssid, IP: $ipAddress, Freq: $frequency');

      return NetworkInfo(
        ssid: ssid ?? 'Unknown',
        signalStrength: null, // Không thể lấy từ Flutter, cần platform channel
        frequency: frequency,
        ipAddress: ipAddress,
        channel: null, // Không thể lấy từ Flutter, cần platform channel
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
