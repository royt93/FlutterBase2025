import 'package:tracuuphatnguoi/mckimquyen/ext/zoom_inkwell.dart';
import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  final double size;
  final double sizeIcon;
  final IconData? icon;
  final VoidCallback? onPressed;

  const CircleButton({
    super.key,
    required this.size,
    required this.sizeIcon,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: Colors.transparent,
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Container(
            margin: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(45),
              boxShadow: const [
                BoxShadow(
                  color: Colors.grey,
                  blurRadius: 8,
                  offset: Offset(4, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: sizeIcon,
            ),
          ),
        ),
      ).zoomOnTap(),
    );
  }
}
