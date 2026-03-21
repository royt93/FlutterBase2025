import 'package:flutter/material.dart';

/// Custom Shimmer animation — port từ ShimmerView.kt
/// Dùng AnimationController + ShaderMask, không cần thư viện bên ngoài
/// Tự dispose AnimationController khi widget bị huỷ (zero memory leak)
class ShimmerView extends StatefulWidget {
  final double cornerRadius;
  final double width;
  final double height;

  const ShimmerView({
    super.key,
    required this.cornerRadius,
    required this.width,
    required this.height,
  });

  @override
  State<ShimmerView> createState() => _ShimmerViewState();
}

class _ShimmerViewState extends State<ShimmerView>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller; // Nullable safe — không dùng late

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose(); // TRÁNH MEMORY LEAK
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final value = controller.value;
            return LinearGradient(
              begin: Alignment(-1.0 + (value * 3), -0.3),
              end: Alignment(1.0 + (value * 3), 0.3),
              colors: const [
                Color(0xFFE0E0E0), // baseColor
                Color(0xFFF8F8F8), // highlightColor
                Color(0xFFE0E0E0), // baseColor
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.cornerRadius),
            ),
          ),
        );
      },
    );
  }
}
