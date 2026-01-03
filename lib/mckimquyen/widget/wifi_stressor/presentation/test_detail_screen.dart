import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../models/test_result.dart';
import '../speed_chart.dart';
import '../controllers/history_controller.dart';

/// Màn hình chi tiết một test result
class TestDetailScreen extends StatelessWidget {
  final TestResult result;

  const TestDetailScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'test_detail_title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareResult,
            tooltip: 'share'.tr,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteResult(context),
            tooltip: 'delete'.tr,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.only(bottom: 128),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Stats Card
            _buildPerformanceCard(),

            // Test Info Card
            _buildTestInfoCard(),

            // Network Info Card (if available)
            if (result.networkInfo != null) _buildNetworkInfoCard(),

            // Speed Over Time Chart
            _buildSpeedChartCard(),
          ],
        ),
      ),
    );
  }

  /// Build performance statistics card
  Widget _buildPerformanceCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor().withValues(alpha: 0.8),
            _getStatusColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getStatusIcon(), color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'performance_stats'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Average Speed (large)
          Text(
            'average_speed'.tr,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          Text(
            '${result.avgSpeed.toStringAsFixed(1)} Mbps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          // Grid of other metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricColumn(
                  'peak_speed'.tr,
                  '${result.peakSpeed.toStringAsFixed(1)} Mbps',
                ),
              ),
              Expanded(
                child: _buildMetricColumn(
                  'min_speed'.tr,
                  '${result.minSpeed.toStringAsFixed(1)} Mbps',
                ),
              ),
              Expanded(
                child: _buildMetricColumn(
                  'median_speed'.tr,
                  '${result.medianSpeed.toStringAsFixed(1)} Mbps',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build test info card
  Widget _buildTestInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'test_info'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('started'.tr, _formatDateTime(result.startTime)),
          const SizedBox(height: 8),
          _buildInfoRow(
            'ended'.tr,
            result.endTime != null ? _formatDateTime(result.endTime!) : 'N/A',
          ),
          const SizedBox(height: 8),
          _buildInfoRow('duration'.tr, result.durationFormatted),
          const SizedBox(height: 8),
          _buildInfoRow('status'.tr, _getStatusText()),
          const SizedBox(height: 8),
          _buildInfoRow('data_downloaded'.tr, result.downloadedFormatted),
          const SizedBox(height: 8),
          _buildInfoRow('download_count'.tr, '${result.downloadCount}'),
        ],
      ),
    );
  }

  /// Build network info card
  Widget _buildNetworkInfoCard() {
    final networkInfo = result.networkInfo;
    if (networkInfo == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'network_info'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (networkInfo.ssid != null) _buildInfoRow('ssid'.tr, networkInfo.ssid ?? 'N/A'),
          if (networkInfo.signalStrength != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'signal'.tr,
              '${networkInfo.signalStrength} dBm (${result.signalQuality ?? "N/A"})',
            ),
          ],
          if (networkInfo.frequency != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('frequency'.tr, networkInfo.frequency ?? 'N/A'),
          ],
          if (networkInfo.channel != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('channel'.tr, '${networkInfo.channel}'),
          ],
          if (networkInfo.ipAddress != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('ip_address'.tr, networkInfo.ipAddress ?? 'N/A'),
          ],
        ],
      ),
    );
  }

  /// Build speed chart card
  Widget _buildSpeedChartCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'speed_over_time'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result.speedHistory.isNotEmpty)
            SizedBox(
              height: 200,
              child: SpeedChart(speeds: result.speedHistory),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'no_data'.tr,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Helper: Build metric column
  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Helper: Build info row
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Get status color
  Color _getStatusColor() {
    if (!result.isSuccessful) {
      return Colors.red;
    }
    switch (result.speedQuality) {
      case 'excellent':
        return Colors.green;
      case 'good':
        return Colors.orange;
      case 'poor':
      default:
        return Colors.red;
    }
  }

  /// Get status icon
  IconData _getStatusIcon() {
    if (result.isFailed) {
      return Icons.error;
    }
    if (!result.isSuccessful) {
      return Icons.warning;
    }
    return Icons.check_circle;
  }

  /// Get status text
  String _getStatusText() {
    if (result.status == 'completed') {
      return 'status_completed'.tr;
    } else if (result.status == 'failed') {
      return 'status_failed'.tr;
    } else if (result.status == 'stopped') {
      return 'status_stopped'.tr;
    } else if (result.status == 'interrupted') {
      return 'status_interrupted'.tr;
    }
    return result.status;
  }

  /// Format datetime
  String _formatDateTime(DateTime dateTime) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$month $day, $year $hour:$minute';
  }

  /// Share result
  void _shareResult() {
    final buffer = StringBuffer();

    // Title
    buffer.writeln('📊 WiFi Speed Test Results');
    buffer.writeln('═' * 40);
    buffer.writeln();

    // Performance Stats
    buffer.writeln('⚡ Performance Statistics:');
    buffer.writeln('• Average Speed: ${result.avgSpeed.toStringAsFixed(1)} Mbps');
    buffer.writeln('• Peak Speed: ${result.peakSpeed.toStringAsFixed(1)} Mbps');
    buffer.writeln('• Minimum Speed: ${result.minSpeed.toStringAsFixed(1)} Mbps');
    buffer.writeln('• Median Speed: ${result.medianSpeed.toStringAsFixed(1)} Mbps');
    buffer.writeln();

    // Test Info
    buffer.writeln('📋 Test Information:');
    buffer.writeln('• Started: ${_formatDateTime(result.startTime)}');
    if (result.endTime != null) {
      buffer.writeln('• Ended: ${_formatDateTime(result.endTime!)}');
    }
    buffer.writeln('• Duration: ${result.durationFormatted}');
    buffer.writeln('• Status: ${_getStatusText()}');
    buffer.writeln('• Data Downloaded: ${result.downloadedFormatted}');
    buffer.writeln('• Download Count: ${result.downloadCount}');
    buffer.writeln();

    // Network Info (if available)
    if (result.networkInfo != null) {
      final networkInfo = result.networkInfo!;
      buffer.writeln('📶 Network Information:');
      if (networkInfo.ssid != null) {
        buffer.writeln('• SSID: ${networkInfo.ssid}');
      }
      if (networkInfo.signalStrength != null) {
        buffer.writeln('• Signal Strength: ${networkInfo.signalStrength} dBm (${result.signalQuality ?? "N/A"})');
      }
      if (networkInfo.frequency != null) {
        buffer.writeln('• Frequency: ${networkInfo.frequency}');
      }
      if (networkInfo.channel != null) {
        buffer.writeln('• Channel: ${networkInfo.channel}');
      }
      if (networkInfo.ipAddress != null) {
        buffer.writeln('• IP Address: ${networkInfo.ipAddress}');
      }
      buffer.writeln();
    }

    // Footer
    buffer.writeln('═' * 40);
    buffer.writeln('Generated by WiFi Speed Tester');

    // Share the text
    Share.share(
      buffer.toString(),
      subject: 'WiFi Speed Test Results - ${_formatDateTime(result.startTime)}',
    );
  }

  /// Delete result
  void _deleteResult(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text('delete'.tr),
        content: Text('confirm_delete_test'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.back(); // Close detail screen
              // Delete will be handled by HistoryController
              final controller = Get.find<HistoryController>();
              controller.deleteResult(result.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}
