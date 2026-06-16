import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Kiểu hiển thị biểu đồ speed-over-time.
enum SpeedChartType { line, area, bar }

/// Chart speed-over-time với toggle line / area / bar.
///
/// State kiểu chart giữ qua `ValueNotifier` (không setState theo quy ước
/// doc/init.md). Dữ liệu `speeds` truyền vào, reactive theo length.
class SpeedChart extends StatefulWidget {
  final List<double> speeds;

  /// Chiều cao vùng vẽ chart. Mặc định 360 (màn chạy); detail dùng nhỏ hơn.
  final double chartHeight;

  /// Cho phép đổi kiểu chart. Tắt (false) → ẩn toggle (vd chart live đang chạy).
  final bool showTypeToggle;

  const SpeedChart({
    super.key,
    required this.speeds,
    this.chartHeight = 360,
    this.showTypeToggle = true,
  });

  /// Số cột tối đa cho bar chart — gộp bucket trung bình nếu nhiều mẫu hơn.
  static const int maxBars = 48;

  /// Gộp `speeds` về tối đa `maxBars` cột bằng trung bình từng bucket.
  /// Dùng cho bar chart để không quá dày khi có hàng trăm mẫu.
  @visibleForTesting
  static List<double> downsample(List<double> speeds, int maxBars) {
    if (maxBars <= 0) return const [];
    if (speeds.length <= maxBars) return List<double>.from(speeds);
    final bucketSize = (speeds.length / maxBars).ceil();
    final out = <double>[];
    for (int i = 0; i < speeds.length; i += bucketSize) {
      final end = (i + bucketSize) > speeds.length ? speeds.length : i + bucketSize;
      double sum = 0;
      for (int j = i; j < end; j++) {
        sum += speeds[j];
      }
      out.add(sum / (end - i));
    }
    return out;
  }

  @override
  State<SpeedChart> createState() => _SpeedChartState();
}

class _SpeedChartState extends State<SpeedChart> {
  final ValueNotifier<SpeedChartType> _type =
      ValueNotifier<SpeedChartType>(SpeedChartType.area);

  @override
  void dispose() {
    _type.dispose();
    super.dispose();
  }

  double get _maxSpeed {
    if (widget.speeds.isEmpty) return 100;
    final max = widget.speeds.reduce((a, b) => a > b ? a : b);
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
                if (widget.showTypeToggle)
                  _buildToggle()
                else
                  Text(
                    'data_points'.trParams({'count': '${widget.speeds.length}'}),
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
            height: widget.chartHeight,
            child: ValueListenableBuilder<SpeedChartType>(
              valueListenable: _type,
              builder: (context, type, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey('${type.name}_${widget.speeds.length}'),
                    child: type == SpeedChartType.bar ? _buildBarChart() : _buildLineChart(type),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 3 nút chọn kiểu chart, gọn trong header.
  Widget _buildToggle() {
    return ValueListenableBuilder<SpeedChartType>(
      valueListenable: _type,
      builder: (context, current, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _toggleButton(SpeedChartType.line, Icons.show_chart, current),
            _toggleButton(SpeedChartType.area, Icons.area_chart, current),
            _toggleButton(SpeedChartType.bar, Icons.bar_chart, current),
          ],
        );
      },
    );
  }

  Widget _toggleButton(SpeedChartType type, IconData icon, SpeedChartType current) {
    final selected = type == current;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => _type.value = type,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(SpeedChartType type) {
    final filled = type == SpeedChartType.area;
    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: _maxSpeed,
        lineBarsData: [
          LineChartBarData(
            spots: widget.speeds
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.4,
            color: Colors.green,
            barWidth: 2,
            belowBarData: BarAreaData(
              show: filled,
              gradient: LinearGradient(
                colors: [
                  Colors.green.withValues(alpha: 0.8),
                  Colors.green.withValues(alpha: 0.5),
                  Colors.green.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _buildBarChart() {
    final bars = SpeedChart.downsample(widget.speeds, SpeedChart.maxBars);
    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(enabled: false),
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: _maxSpeed,
        barGroups: bars
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value,
                    color: Colors.green,
                    width: 4,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
