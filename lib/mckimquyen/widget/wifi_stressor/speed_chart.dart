import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Chart tối ưu performance với caching và reduced complexity
class SpeedChart extends StatelessWidget {
  final List<double> speeds;

  /// Chiều cao vùng vẽ chart. Mặc định 360 (màn chạy); detail dùng nhỏ hơn.
  final double chartHeight;

  const SpeedChart({super.key, required this.speeds, this.chartHeight = 360});

  double get maxSpeed {
    if (speeds.isEmpty) return 100;
    final max = speeds.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'speed_chart'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'data_points'.trParams({'count': '${speeds.length}'}),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: chartHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: LineChart(
                  key: ValueKey(speeds.length),
                  LineChartData(
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: const FlGridData(show: true),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: maxSpeed,
                    lineBarsData: [
                      LineChartBarData(
                        spots: speeds.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value);
                        }).toList(),
                        isCurved: true,
                        curveSmoothness: 0.4,
                        // Thêm độ smooth
                        color: Colors.green,
                        barWidth: 2,
                        // Tăng độ dày line
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.withValues(alpha: 0.8),
                              Colors.green.withValues(alpha: 0.5),
                              Colors.green.withValues(alpha: 0.3),
                              Colors.transparent
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        dotData: const FlDotData(show: false),
                        // Thêm shadow effect
                        // shadow: const Shadow(
                        //   color: Colors.green,
                        //   blurRadius: 4,
                        // ),
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeInOutCubic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
