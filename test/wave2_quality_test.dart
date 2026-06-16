// Wave 2 · Feature E tests — Network Quality Score A–F scorer.

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/models/network_quality.dart';

const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);

void main() {
  group('NetworkQuality.compute', () {
    test('excellent (fast + low latency/jitter) → A green', () {
      final q = NetworkQuality.compute(avgSpeed: 150, latencyMs: 10, jitterMs: 2);
      expect(q.score, 99); // 50 + 29 + 19.6
      expect(q.grade, 'A');
      expect(q.color, _green);
    });

    test('mid → D amber', () {
      final q = NetworkQuality.compute(avgSpeed: 50, latencyMs: 150, jitterMs: 50);
      expect(q.score, 50); // 25 + 15 + 10
      expect(q.grade, 'D');
      expect(q.color, _amber);
    });

    test('poor (slow + high latency/jitter) → F red', () {
      final q = NetworkQuality.compute(avgSpeed: 10, latencyMs: 250, jitterMs: 80);
      expect(q.score, 14); // 5 + 5 + 4
      expect(q.grade, 'F');
      expect(q.color, _red);
    });

    test('null latency → score from speed only', () {
      // speedPts 40 → 40/50*100 = 80 → B
      expect(NetworkQuality.compute(avgSpeed: 80).grade, 'B');
      // speedPts 50 → 100 → A
      expect(NetworkQuality.compute(avgSpeed: 100).grade, 'A');
      // speedPts 20 → 40 → D
      expect(NetworkQuality.compute(avgSpeed: 40).grade, 'D');
    });

    test('clamps and caps speed at 100 Mbps', () {
      final q = NetworkQuality.compute(avgSpeed: 9999, latencyMs: 0, jitterMs: 0);
      expect(q.score, 100); // 50 + 30 + 20
      expect(q.grade, 'A');
    });

    test('jitter defaults to 0 when null', () {
      final q = NetworkQuality.compute(avgSpeed: 100, latencyMs: 0);
      expect(q.score, 100); // 50 + 30 + 20(jitter null→0 → full pts)
    });
  });
}
