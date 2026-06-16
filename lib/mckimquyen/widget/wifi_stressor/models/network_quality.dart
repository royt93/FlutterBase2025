import 'package:flutter/material.dart';

/// Điểm chất lượng mạng A–F gộp từ tốc độ + độ trễ + jitter.
///
/// Thang 100: speed tối đa 50đ, latency 30đ (thấp tốt), jitter 20đ (thấp tốt).
/// Nếu không có latency (record cũ / probe lỗi) → chấm theo speed quy về thang 100.
@immutable
class NetworkQuality {
  final String grade; // 'A'..'F'
  final int score; // 0..100
  final Color color;

  const NetworkQuality({
    required this.grade,
    required this.score,
    required this.color,
  });

  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);

  static NetworkQuality compute({
    required double avgSpeed,
    double? latencyMs,
    double? jitterMs,
  }) {
    // Speed: 50đ — 100 Mbps trở lên = tối đa.
    final speedPts = (avgSpeed / 100).clamp(0.0, 1.0) * 50;

    final double total;
    if (latencyMs == null) {
      // Không đo được latency → quy speed lên thang 100.
      total = speedPts / 50 * 100;
    } else {
      // Latency: 30đ — 0ms = tối đa, ≥300ms = 0.
      final latPts = ((300 - latencyMs) / 300).clamp(0.0, 1.0) * 30;
      // Jitter: 20đ — 0ms = tối đa, ≥100ms = 0.
      final jitPts = ((100 - (jitterMs ?? 0)) / 100).clamp(0.0, 1.0) * 20;
      total = speedPts + latPts + jitPts;
    }

    final s = total.round().clamp(0, 100);
    return NetworkQuality(grade: _gradeOf(s), score: s, color: _colorOf(s));
  }

  static String _gradeOf(int s) {
    if (s >= 85) return 'A';
    if (s >= 70) return 'B';
    if (s >= 55) return 'C';
    if (s >= 40) return 'D';
    return 'F';
  }

  static Color _colorOf(int s) {
    if (s >= 70) return _green;
    if (s >= 40) return _amber;
    return _red;
  }
}
