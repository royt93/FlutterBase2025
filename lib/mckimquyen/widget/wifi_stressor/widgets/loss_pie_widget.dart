import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Pie "gói thành công vs mất gói" dựa trên packet-loss %.
/// Chỉ nên render khi packetLossPct != null.
class LossPieWidget extends StatelessWidget {
  final double packetLossPct;

  const LossPieWidget({super.key, required this.packetLossPct});

  /// % gói thành công = 100 - loss, kẹp [0,100].
  @visibleForTesting
  static double successOf(double lossPct) => (100 - lossPct).clamp(0, 100).toDouble();

  @override
  Widget build(BuildContext context) {
    final loss = packetLossPct.clamp(0, 100).toDouble();
    final success = successOf(loss);
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
              const Icon(Icons.pie_chart, color: Colors.purpleAccent),
              const SizedBox(width: 8),
              Text(
                'packet_pie_title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      PieChartSectionData(
                        value: success,
                        color: Colors.green,
                        title: '${success.toStringAsFixed(0)}%',
                        radius: 26,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (loss > 0)
                        PieChartSectionData(
                          value: loss,
                          color: Colors.red,
                          title: '${loss.toStringAsFixed(0)}%',
                          radius: 26,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legend(Colors.green, 'packet_success'.tr, '${success.toStringAsFixed(1)}%'),
                    const SizedBox(height: 12),
                    _legend(Colors.red, 'packet_loss'.tr, '${loss.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
