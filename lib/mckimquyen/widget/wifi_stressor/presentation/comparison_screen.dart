import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/test_result.dart';

/// Màn so sánh nhiều lần test: chart overlay speed-over-time + bảng metrics.
/// Stateless, reactive theo data truyền vào — không setState/late/force-null.
class ComparisonScreen extends StatelessWidget {
  final List<TestResult> results;

  const ComparisonScreen({super.key, required this.results});

  static const _palette = <Color>[
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // green
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFFA855F7), // purple
  ];

  Color _colorFor(int i) => _palette[i % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'comparison_title'.tr,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegend(),
            const SizedBox(height: 16),
            _buildChartCard(),
            const SizedBox(height: 16),
            _buildMetricsTable(),
          ],
        ),
      ),
    );
  }

  /// Chú thích màu cho từng test.
  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (int i = 0; i < results.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 14, color: _colorFor(i)),
              const SizedBox(width: 6),
              Text(
                _label(i),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildChartCard() {
    return Container(
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
          SizedBox(height: 280, child: LineChart(_buildChartData())),
        ],
      ),
    );
  }

  LineChartData _buildChartData() {
    final maxLen = results.fold<int>(
      0,
      (m, r) => r.speedHistory.length > m ? r.speedHistory.length : m,
    );
    final maxY = _overallMaxSpeed() * 1.2;
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY <= 0 ? 20 : maxY / 4,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: Colors.white.withValues(alpha: 0.1), strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          axisNameWidget: const Text(
            'Mbps',
            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          axisNameSize: 18,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '${value.toInt()}',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: true),
      minX: 0,
      maxX: maxLen <= 1 ? 1 : (maxLen - 1).toDouble(),
      minY: 0,
      maxY: maxY <= 0 ? 100 : maxY,
      lineBarsData: [
        for (int i = 0; i < results.length; i++)
          LineChartBarData(
            spots: _spotsFor(results[i]),
            isCurved: true,
            color: _colorFor(i),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
      ],
    );
  }

  List<FlSpot> _spotsFor(TestResult r) {
    final hist = r.speedHistory;
    return [
      for (int j = 0; j < hist.length; j++)
        FlSpot(j.toDouble(), hist[j].clamp(0.0, double.infinity).toDouble()),
    ];
  }

  double _overallMaxSpeed() {
    double max = 0;
    for (final r in results) {
      final p = r.peakSpeed.clamp(0.0, double.infinity);
      if (p > max) max = p;
    }
    return max;
  }

  /// Bảng metrics: mỗi hàng 1 chỉ số, mỗi cột 1 test. Highlight giá trị tốt nhất.
  Widget _buildMetricsTable() {
    final rows = <_MetricRow>[
      _MetricRow('cmp_avg_speed', (r) => r.avgSpeed, higherBetter: true),
      _MetricRow('cmp_peak_speed', (r) => r.peakSpeed, higherBetter: true),
      _MetricRow('cmp_min_speed', (r) => r.minSpeed, higherBetter: true),
      _MetricRow('cmp_median_speed', (r) => r.medianSpeed, higherBetter: true),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              for (int i = 0; i < results.length; i++)
                Expanded(
                  flex: 2,
                  child: Text(
                    _label(i),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _colorFor(i),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(color: Colors.white24),
          for (final row in rows) _buildMetricRow(row),
          // Duration + downloaded (neutral, no best highlight)
          _buildTextRow('cmp_duration', (r) => r.durationFormatted),
          _buildTextRow('cmp_downloaded', (r) => r.downloadedFormatted),
        ],
      ),
    );
  }

  Widget _buildMetricRow(_MetricRow row) {
    final values = results.map(row.extractor).toList();
    final best = values.isEmpty
        ? 0.0
        : values.reduce(row.higherBetter
            ? (a, b) => a > b ? a : b
            : (a, b) => a < b ? a : b);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.labelKey.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (int i = 0; i < results.length; i++)
            Expanded(
              flex: 2,
              child: Text(
                _fmt(values[i]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: values[i] == best && results.length > 1
                      ? const Color(0xFF10B981)
                      : Colors.white,
                  fontSize: 12,
                  fontWeight: values[i] == best && results.length > 1
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextRow(String labelKey, String Function(TestResult) extractor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              labelKey.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          for (final r in results)
            Expanded(
              flex: 2,
              child: Text(
                extractor(r),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) => '${v.toStringAsFixed(1)} Mbps';

  /// Nhãn cột: "#i • HH:mm dd/MM".
  String _label(int i) {
    final t = results[i].startTime;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final mo = t.month.toString().padLeft(2, '0');
    return '#${i + 1} • $hh:$mm $dd/$mo';
  }
}

class _MetricRow {
  final String labelKey;
  final double Function(TestResult) extractor;
  final bool higherBetter;

  _MetricRow(this.labelKey, this.extractor, {required this.higherBetter});
}
