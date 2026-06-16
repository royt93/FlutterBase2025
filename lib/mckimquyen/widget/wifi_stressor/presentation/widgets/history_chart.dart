import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/test_result.dart';

/// Chart widget để hiển thị speed history
class HistoryChart extends StatelessWidget {
  final List<TestResult> results;

  const HistoryChart({
    super.key,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'speed_over_time'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(_buildChartData()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.show_chart,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 8),
            Text(
              'no_data'.tr,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData() {
    final spots = <FlSpot>[];

    // Limit to last 20 tests để chart không quá crowded
    final limitedResults = results.length > 20 ? results.sublist(results.length - 20) : results;

    for (int i = 0; i < limitedResults.length; i++) {
      // Clamp negative values to 0 để tránh chart lỗi
      final speed = limitedResults[i].avgSpeed.clamp(0.0, double.infinity);
      spots.add(FlSpot(i.toDouble(), speed));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.white.withValues(alpha: 0.1),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 5,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= limitedResults.length) {
                return const SizedBox();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '#${value.toInt() + 1}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text(
              'Mbps',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          axisNameSize: 20,
          sideTitles: SideTitles(
            showTitles: true,
            interval: 40,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              // Chỉ hiển thị label khi chia hết cho interval (0, 40, 80, 120...)
              // Tránh hiển thị label lẻ do fl_chart tự sinh
              if (value % 40 != 0) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${value.toInt()}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      minX: 0,
      maxX: (limitedResults.length - 1).toDouble(),
      minY: 0,
      maxY: _getMaxSpeed() * 1.2,
      // Add 20% padding to top
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
          ),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF3B82F6),
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF3B82F6).withValues(alpha: 0.3),
                const Color(0xFF10B981).withValues(alpha: 0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  /// Get max speed để set chart bounds
  double _getMaxSpeed() {
    if (results.isEmpty) return 100;
    double max = 0;
    for (final result in results) {
      // Clamp negative values to 0
      final speed = result.avgSpeed.clamp(0.0, double.infinity);
      if (speed > max) {
        max = speed;
      }
    }
    return max > 0 ? max : 100;
  }
}
