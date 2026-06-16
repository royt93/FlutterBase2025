import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/history_controller.dart';
import '../models/test_result.dart';
import '../speed_chart.dart';

/// Heatmap hiệu suất theo thời gian: mỗi lần test là 1 hàng ô màu (speedHistory
/// downsample thành N ô), màu theo tốc độ (đỏ thấp → xanh cao) chuẩn hoá theo
/// đỉnh toàn cục để so sánh giữa các lần. Stateless, reactive theo history.
class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  /// Số ô mỗi hàng (downsample speedHistory về đây).
  static const int cols = 24;

  /// Số lần test tối đa hiển thị (mới nhất trước).
  static const int maxRows = 40;

  /// Màu ô theo tỉ lệ speed/max: 0→đỏ, 0.5→hổ phách, 1→xanh.
  @visibleForTesting
  static Color heatmapColor(double speed, double max) {
    if (max <= 0) return const Color(0xFF334155);
    final r = (speed / max).clamp(0.0, 1.0);
    if (r < 0.5) {
      return Color.lerp(const Color(0xFFEF4444), const Color(0xFFF59E0B), r * 2)!;
    }
    return Color.lerp(const Color(0xFFF59E0B), const Color(0xFF22C55E), (r - 0.5) * 2)!;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<HistoryController>()
        ? Get.find<HistoryController>()
        : Get.put(HistoryController());
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'heatmap_title'.tr,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        // Chỉ lấy test có dữ liệu tốc độ, mới nhất trước, tối đa maxRows.
        final all = controller.allResults
            .where((t) => t.speedHistory.isNotEmpty)
            .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
        final rows = all.take(maxRows).toList();
        if (rows.isEmpty) {
          return Center(
            child: Text('heatmap_empty'.tr,
                style: const TextStyle(color: Colors.white54)),
          );
        }
        final globalMax = rows
            .expand((t) => t.speedHistory)
            .fold<double>(0, (m, s) => s > m ? s : m);
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legend(globalMax),
              const SizedBox(height: 16),
              for (final t in rows) _row(t, globalMax),
            ],
          ),
        );
      }),
    );
  }

  Widget _legend(double globalMax) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('heatmap_legend'.tr,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('0', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(colors: [
                      Color(0xFFEF4444),
                      Color(0xFFF59E0B),
                      Color(0xFF22C55E),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('${globalMax.toStringAsFixed(0)} Mbps',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(TestResult t, double globalMax) {
    final cells = SpeedChart.downsample(t.speedHistory, cols);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_time(t.startTime)} · ${t.avgSpeed.toStringAsFixed(0)} Mbps',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 22,
            child: Row(
              children: [
                for (final s in cells)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: heatmapColor(s, globalMax),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
