import 'package:flutter/material.dart';

class LabelAd extends StatelessWidget {
  const LabelAd({
    super.key,
    required this.txt,
    required this.textSize,
    required this.width,
  });

  final String txt;
  final double textSize;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      margin: const EdgeInsets.fromLTRB(8, 1, 8, 0),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.blue,
          style: BorderStyle.solid,
          width: 1.0,
        ),
        color: Colors.blue,
        borderRadius: BorderRadius.circular(45.0),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: textSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
