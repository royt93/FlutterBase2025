import 'package:flutter/material.dart';

/// Widget hiển thị số với animation smooth khi value thay đổi
class AnimatedNumberText extends StatelessWidget {
  final double value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedNumberText({
    super.key,
    required this.value,
    this.decimals = 2,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '${animatedValue.toStringAsFixed(decimals)}$suffix',
          style: style,
        );
      },
    );
  }
}

/// Widget hiển thị số nguyên với animation
class AnimatedIntText extends StatelessWidget {
  final int value;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedIntText({
    super.key,
    required this.value,
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '${animatedValue.round()}$suffix',
          style: style,
        );
      },
    );
  }
}
