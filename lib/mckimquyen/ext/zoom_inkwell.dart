// Extension on InkWell to handle zoom animation when tapped
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

extension ZoomEffect on InkWell {
  InkWell zoomOnTap() {
    return InkWell(
      customBorder: const CircleBorder(),
      splashColor: Colors.transparent,
      onTap: () {}, // Disable default tap inside
      child: _ZoomAnimation(onTap: onTap, child: child!),
    );
  }
}

// Custom widget to handle zoom animation without setState
class _ZoomAnimation extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ZoomAnimation({required this.child, this.onTap});

  @override
  _ZoomAnimationState createState() => _ZoomAnimationState();
}

class _ZoomAnimationState extends State<_ZoomAnimation> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );

    // Define the animation range (scale from 1.0 to 1.5)
    if (_controller == null) {
      //do nothing
    } else {
      _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(_controller!);
    }
  }

  // Handle zoom in and zoom out animation
  Future<void> _zoomInAndOut() async {
    // Trigger the onTap after the animation completes
    if (widget.onTap != null) {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(duration: 50);
      }
      widget.onTap!();
    }

    // Start the zoom in animation
    await _controller?.forward();

    // Reverse the animation back to original scale
    await _controller?.reverse();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scaleAnimation == null) {
      return const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: _zoomInAndOut, // Trigger zoom and onTap when tapped
      child: AnimatedBuilder(
        animation: _scaleAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation?.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}
