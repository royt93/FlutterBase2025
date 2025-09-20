import 'package:flutter/material.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';

class LabelAd extends StatelessWidget {
  const LabelAd({
    super.key,
    required this.txt,
    required this.textSize,
    this.width,
    this.colorBkg,
    this.colorTxt,
  });

  final String txt;
  final double textSize;
  final double? width;
  final Color? colorBkg;
  final Color? colorTxt;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
    Color mColorBkg;
    Color mColorTxt;
    if (colorBkg == null) {
      mColorBkg = ColorConstants.appColor;
    } else {
      mColorBkg = colorBkg ?? ColorConstants.appColor;
    }
    if (colorTxt == null) {
      mColorTxt = Colors.white;
    } else {
      mColorTxt = colorTxt ?? Colors.white;
    }
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      margin: const EdgeInsets.fromLTRB(8, 1, 8, 0),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(
          color: mColorTxt,
          style: BorderStyle.solid,
          width: 1.0,
        ),
        color: mColorBkg,
        borderRadius: BorderRadius.circular(45.0),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: textSize,
          fontWeight: FontWeight.bold,
          color: mColorTxt,
        ),
      ),
    );
  }
}
