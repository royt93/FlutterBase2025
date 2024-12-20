import 'package:gameoffline/mckimquyen/common/const/color_constants.dart';
import 'package:gameoffline/mckimquyen/ext/zoom_inkwell.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CircleButtonWithText extends StatelessWidget {
  final String text;
  final String fontFamily;
  final double sizeIcon;
  final IconData? icon;
  final VoidCallback? onPressed;

  const CircleButtonWithText({
    super.key,
    required this.text,
    required this.fontFamily,
    required this.sizeIcon,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorConstants.disabledColor,
          borderRadius: BorderRadius.circular(90),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 1,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.black,
              size: sizeIcon,
            ),
            const SizedBox(width: 16),
            fontFamily.isEmpty
                ? Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    text,
                    style: GoogleFonts.getFont(
                      fontFamily,
                      color: Colors.black,
                      fontSize: 16,
                      // fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ],
        ),
      ),
    ).zoomOnTap();
  }
}
