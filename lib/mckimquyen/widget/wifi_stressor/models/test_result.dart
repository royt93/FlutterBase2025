import 'network_info.dart';

/// Kết quả của một lần test WiFi
class TestResult {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double avgSpeed; // Mbps
  final double peakSpeed; // Mbps
  final double minSpeed; // Mbps
  final double medianSpeed; // Mbps
  final List<double> speedHistory; // List of speed samples
  final String status; // 'completed', 'failed', 'stopped'
  final NetworkInfo? networkInfo;
  final int totalDownloadedBytes;
  final int downloadCount;

  TestResult({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.avgSpeed,
    required this.peakSpeed,
    required this.minSpeed,
    required this.medianSpeed,
    required this.speedHistory,
    required this.status,
    this.networkInfo,
    required this.totalDownloadedBytes,
    required this.downloadCount,
  });

  /// Tính duration từ start và end time
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Format duration thành string (e.g., "2m 30s")
  String get durationFormatted {
    final d = duration;
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Format downloaded bytes thành string (e.g., "125.3 MB")
  String get downloadedFormatted {
    final mb = totalDownloadedBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(1)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Kiểm tra xem test có thành công không
  /// 'completed' = test tự kết thúc (hiện không dùng vì test chạy vô thời hạn)
  /// 'stopped' = user chủ động stop → coi là thành công
  /// 'interrupted' = app bị dispose bất thường → không thành công
  /// 'failed' = test lỗi → không thành công
  bool get isSuccessful => status == 'completed' || status == 'stopped';

  /// Kiểm tra xem test có failed không
  bool get isFailed => status == 'failed';

  /// Get signal quality từ network info
  String? get signalQuality {
    final signal = networkInfo?.signalStrength;
    if (signal == null) return null;

    // dBm scale: higher is better (less negative)
    if (signal >= -50) return 'Excellent';
    if (signal >= -60) return 'Good';
    if (signal >= -70) return 'Fair';
    return 'Poor';
  }

  /// Get speed quality (Green/Yellow/Red)
  String get speedQuality {
    if (avgSpeed >= 80) return 'excellent';
    if (avgSpeed >= 40) return 'good';
    return 'poor';
  }

  /// Copy with method
  TestResult copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    double? avgSpeed,
    double? peakSpeed,
    double? minSpeed,
    double? medianSpeed,
    List<double>? speedHistory,
    String? status,
    NetworkInfo? networkInfo,
    int? totalDownloadedBytes,
    int? downloadCount,
  }) {
    return TestResult(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      avgSpeed: avgSpeed ?? this.avgSpeed,
      peakSpeed: peakSpeed ?? this.peakSpeed,
      minSpeed: minSpeed ?? this.minSpeed,
      medianSpeed: medianSpeed ?? this.medianSpeed,
      speedHistory: speedHistory ?? this.speedHistory,
      status: status ?? this.status,
      networkInfo: networkInfo ?? this.networkInfo,
      totalDownloadedBytes: totalDownloadedBytes ?? this.totalDownloadedBytes,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }

  /// Tạo từ controller data
  factory TestResult.fromControllerData({
    required DateTime startTime,
    DateTime? endTime,
    required List<double> speedHistory,
    required int totalDownloadedBytes,
    required int downloadCount,
    required String status,
    NetworkInfo? networkInfo,
  }) {
    // Calculate statistics từ speedHistory
    // VALIDATION: Clamp all negative speeds to 0
    final speeds = speedHistory.map((s) => s.clamp(0.0, double.infinity)).toList();
    if (speeds.isEmpty) {
      speeds.add(0.0);
    }

    speeds.sort();
    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    final peakSpeed = speeds.last;
    final minSpeed = speeds.first;
    final medianSpeed = speeds[speeds.length ~/ 2];

    return TestResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startTime,
      endTime: endTime,
      avgSpeed: avgSpeed,
      peakSpeed: peakSpeed,
      minSpeed: minSpeed,
      medianSpeed: medianSpeed,
      speedHistory: speedHistory,
      status: status,
      networkInfo: networkInfo,
      totalDownloadedBytes: totalDownloadedBytes,
      downloadCount: downloadCount,
    );
  }

  /// Chuyển sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'avgSpeed': avgSpeed,
      'peakSpeed': peakSpeed,
      'minSpeed': minSpeed,
      'medianSpeed': medianSpeed,
      'speedHistory': speedHistory,
      'status': status,
      'networkInfo': networkInfo?.toJson(),
      'totalDownloadedBytes': totalDownloadedBytes,
      'downloadCount': downloadCount,
    };
  }

  /// Tạo từ JSON
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      avgSpeed: (json['avgSpeed'] as num).toDouble(),
      peakSpeed: (json['peakSpeed'] as num).toDouble(),
      minSpeed: (json['minSpeed'] as num).toDouble(),
      medianSpeed: (json['medianSpeed'] as num).toDouble(),
      speedHistory: (json['speedHistory'] as List).map((e) => (e as num).toDouble()).toList(),
      status: json['status'] as String,
      networkInfo: json['networkInfo'] != null
          ? NetworkInfo.fromJson(json['networkInfo'] as Map<String, dynamic>)
          : null,
      totalDownloadedBytes: json['totalDownloadedBytes'] as int,
      downloadCount: json['downloadCount'] as int,
    );
  }

  @override
  String toString() {
    return 'TestResult(id: $id, avg: ${avgSpeed.toStringAsFixed(1)} Mbps, status: $status, duration: $durationFormatted)';
  }
}
