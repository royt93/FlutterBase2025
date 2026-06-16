import 'package:flutter/material.dart';

class PulseContainer extends StatefulWidget {
  final Widget child;
  final Function onTapRoot;
  final Color color;
  final AlignmentGeometry alignment;

  const PulseContainer({
    super.key,
    required this.child,
    required this.onTapRoot,
    required this.color,
    required this.alignment,
  });

  @override
  State<PulseContainer> createState() => _PulseContainerState();
}

class _PulseContainerState extends State<PulseContainer> with SingleTickerProviderStateMixin {
  // Nullable thay cho `late` theo quy ước doc/init.md — gán trong initState,
  // dispose null-safe, build guard để không force-null.
  AnimationController? _controller;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _controller = controller;
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _animation;
    if (animation == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return InkWell(
          child: Transform.scale(
            scale: animation.value,
            child: Stack(
              alignment: widget.alignment,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(90.0)),
                    color: widget.color,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: widget.child,
                ),
                // Container(
                //   alignment: Alignment.topRight,
                //   child: AvatarGlow(
                //     glowColor: widget.color,
                //     child: const Icon(
                //       Icons.clear,
                //       color: Colors.black,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          onTap: () {
            widget.onTapRoot.call();
          },
        );
      },
    );
  }
}
