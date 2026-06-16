import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../stressor_controller.dart';

/// Đồng hồ tốc độ realtime — phản ứng theo `controller.speedMbps` qua `Obx`.
/// Tự auto-scale max theo các mốc đẹp (50/100/200/500/1000/2000 Mbps).
class SpeedometerGaugeWidget extends StatelessWidget {
  final StressorController controller;

  const SpeedometerGaugeWidget({super.key, required this.controller});

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
      final speed = controller.speedMbps.value;
      final maxSpeed = niceMax(speed);
      final color = speedColor(speed);
      return SizedBox(
        width: 200,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(200, 160),
              painter: _GaugePainter(
                speed: speed,
                maxSpeed: maxSpeed,
                color: color,
              ),
            ),
            Positioned(
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speed.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Text(
                    'Mbps',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  static const _startAngle = math.pi * 0.75; // 135°
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = math.min(size.width, size.height) * 0.46;
    final stroke = radius * 0.16;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweep, false, bgPaint);

    // Value arc
    final fraction = (speed / maxSpeed).clamp(0.0, 1.0);
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweep * fraction, false, valuePaint);

    // Ticks
    final tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    const ticks = 5;
    for (int i = 0; i <= ticks; i++) {
      final a = _startAngle + _sweep * (i / ticks);
      final dir = Offset(math.cos(a), math.sin(a));
      final outer = center + dir * (radius - stroke / 2);
      final inner = center + dir * (radius - stroke * 1.3);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Needle
    final needleAngle = _startAngle + _sweep * fraction;
    final needleEnd =
        center + Offset(math.cos(needleAngle), math.sin(needleAngle)) * (radius - stroke);
    final needlePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needlePaint);

    // Hub
    canvas.drawCircle(center, stroke * 0.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.speed != speed || old.maxSpeed != maxSpeed || old.color != color;
}
