import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../stressor_controller.dart';

/// Đồng hồ tốc độ realtime — phản ứng theo `controller.speedMbps` qua `Obx`.
/// Tự auto-scale max theo các mốc đẹp (50/100/200/500/1000/2000 Mbps).
///
/// Layout: cung bán nguyệt 180° ở trên, **giá trị số đặt ngay dưới cung**
/// (Column, không Stack) → số đo không bao giờ đè lên kim/cung/nền.
class SpeedometerGaugeWidget extends StatelessWidget {
  final StressorController controller;

  /// Đường kính gauge. Mặc định 200; dùng lớn hơn (vd 260) khi làm hero.
  final double size;

  const SpeedometerGaugeWidget({
    super.key,
    required this.controller,
    this.size = 200,
  });

  static const _tiers = <double>[50, 100, 200, 500, 1000, 2000];

  /// Mốc max đẹp gần nhất ≥ speed (auto-scale). Public để unit-test.
  static double niceMax(double speed) {
    for (final t in _tiers) {
      if (speed <= t) return t;
    }
    return _tiers.last;
  }

  /// Màu theo chất lượng tốc độ (đồng bộ với history color coding). Public để test.
  static Color speedColor(double s) {
    if (s >= 80) return const Color(0xFF10B981); // green
    if (s >= 40) return const Color(0xFFF59E0B); // amber
    return const Color(0xFFEF4444); // red
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Target từ controller; scale max khoá theo target để không nhảy thang khi
      // animate. Kim/cung/số/màu nội suy mượt qua TweenAnimationBuilder.
      final target = controller.speedMbps.value;
      final maxSpeed = niceMax(target);
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(end: target),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, speed, _) {
          final color = speedColor(speed);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size * 0.52,
                child: CustomPaint(
                  size: Size(size, size * 0.52),
                  painter: _GaugePainter(
                    speed: speed,
                    maxSpeed: maxSpeed,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                speed.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
              const Text(
                'Mbps',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          );
        },
      );
    });
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;

  _GaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
  });

  static const _start = math.pi; // 180° (mép trái)
  static const _sweep = math.pi; // quét 180° qua đỉnh sang mép phải

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 2);
    final radius = size.width * 0.42;
    final stroke = radius * 0.16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, bgPaint);

    // Value arc
    final fraction = (speed / maxSpeed).clamp(0.0, 1.0);
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * fraction, false, valuePaint);

    // Ticks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    const ticks = 5;
    for (int i = 0; i <= ticks; i++) {
      final a = _start + _sweep * (i / ticks);
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = center + dir * (radius - stroke / 2);
      final inner = center + dir * (radius - stroke * 1.3);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Needle
    final needleAngle = _start + _sweep * fraction;
    final needleEnd = center +
        Offset(math.cos(needleAngle), math.sin(needleAngle)) * (radius - stroke);
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Hub
    canvas.drawCircle(center, stroke * 0.6, Paint()..color = color);
    canvas.drawCircle(
      center,
      stroke * 0.28,
      Paint()..color = const Color(0xFF0F172A),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.speed != speed || old.maxSpeed != maxSpeed || old.color != color;
}
