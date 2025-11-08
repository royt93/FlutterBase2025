import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:marquee/marquee.dart';

import '../../core/base_stateful_state.dart';

class TextMarquee extends StatefulWidget {
  const TextMarquee(
    this.text, {
    super.key,
  });

  final String text;

  @override
  State<StatefulWidget> createState() {
    return _TextMarqueeState();
  }
}

class _TextMarqueeState extends BaseStatefulState<TextMarquee> {
  // final ControllerMain _controllerMain = Get.find();

  // @override
  // void initState() {
  //   super.initState();
  // }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      var onOffTextOverflow = true;
      if (onOffTextOverflow == true) {
        return Marquee(
          text: widget.text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
          blankSpace: 50.0,
          velocity: 5,
        );
      } else {
        return Text(
          widget.text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
          overflow: TextOverflow.ellipsis,
        );
      }
    });
  }
}
