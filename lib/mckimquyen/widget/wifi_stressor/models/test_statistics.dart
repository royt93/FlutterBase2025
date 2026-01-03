import 'test_result.dart';

/// Thống kê tổng hợp từ nhiều test results
class TestStatistics {
  final int totalTests;
  final TestResult? bestTest; // Test với avg speed cao nhất
  final double avgSpeed; // Average của tất cả avg speeds
  final double minSpeed; // Min speed across all tests
  final Duration avgDuration; // Average duration
  final double successRate; // Percentage of successful tests

  TestStatistics({
    required this.totalTests,
    this.bestTest,
    required this.avgSpeed,
    required this.minSpeed,
    required this.avgDuration,
    required this.successRate,
  });

  /// Tạo statistics rỗng khi chưa có test nào
  factory TestStatistics.empty() {
    return TestStatistics(
      totalTests: 0,
      bestTest: null,
      avgSpeed: 0.0,
      minSpeed: 0.0,
      avgDuration: Duration.zero,
      successRate: 0.0,
    );
  }

  /// Tính statistics từ list of test results
  factory TestStatistics.fromResults(List<TestResult> results) {
    if (results.isEmpty) {
      return TestStatistics.empty();
    }

    // Find best test (highest avg speed)
    TestResult? bestTest;
    double maxAvgSpeed = 0.0;
    for (final result in results) {
      if (result.avgSpeed > maxAvgSpeed) {
        maxAvgSpeed = result.avgSpeed;
        bestTest = result;
      }
    }

    // Calculate average speed (average of all avgSpeeds)
    final avgSpeed = results.map((r) => r.avgSpeed).reduce((a, b) => a + b) / results.length;

    // Find minimum speed across all tests
    final minSpeed = results.map((r) => r.minSpeed).reduce((a, b) => a < b ? a : b);

    // Calculate average duration
    final totalDurationSeconds = results.map((r) => r.duration.inSeconds).reduce((a, b) => a + b);
    final avgDuration = Duration(seconds: totalDurationSeconds ~/ results.length);

    // Calculate success rate
    final successCount = results.where((r) => r.isSuccessful).length;
    final successRate = (successCount / results.length) * 100;

    return TestStatistics(
      totalTests: results.length,
      bestTest: bestTest,
      avgSpeed: avgSpeed,
      minSpeed: minSpeed,
      avgDuration: avgDuration,
      successRate: successRate,
    );
  }

  /// Format average duration (e.g., "2m 15s")
  String get avgDurationFormatted {
    final minutes = avgDuration.inMinutes;
    final seconds = avgDuration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  /// Format success rate (e.g., "95.8%")
  String get successRateFormatted {
    return '${successRate.toStringAsFixed(1)}%';
  }

  @override
  String toString() {
    return 'TestStatistics(total: $totalTests, avg: ${avgSpeed.toStringAsFixed(1)} Mbps, success: $successRateFormatted)';
  }
}
