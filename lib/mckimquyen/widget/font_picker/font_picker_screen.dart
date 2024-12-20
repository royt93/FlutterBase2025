import 'package:gameoffline/mckimquyen/util/ui_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/const/color_constants.dart';
import '../../core/base_stateful_state.dart';

class FontPickerScreen extends StatefulWidget {
  static String screenName = "/FontPickerScreen";

  const FontPickerScreen({
    required this.onFontChange,
    super.key,
  });

  final Function(String fontName) onFontChange;

  @override
  State<FontPickerScreen> createState() => _FontPickerScreenState();
}

class _FontPickerScreenState extends BaseStatefulState<FontPickerScreen> {
  // final ControllerMain _controllerMain = Get.find();

  final List<String> fontNames = [];

  @override
  void initState() {
    _initFont(false);
    super.initState();
  }

  void _initFont(bool needRebuild) {
    //https://fonts.google.com/
    var map = GoogleFonts.asMap();
    var list = map.keys.toList();
    // list.addAll(listGGFont);
    var tmpList = list.toSet().toList();
    fontNames.clear();
    fontNames.addAll(tmpList);
    // fontNames.sort();
    if (needRebuild) {
      setState(() {
        fontNames;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UIUtils.getAppBar(
        backgroundColor: ColorConstants.appColor,
        "Font setting",
        () {
          Navigator.pop(context);
        },
        null,
      ),
      body: Container(
        alignment: Alignment.center,
        color: ColorConstants.backgroundColor,
        child: RefreshIndicator(
          onRefresh: () async {
            _initFont(true);
          },
          child: CupertinoScrollbar(
            thumbVisibility: true,
            thickness: 8,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: fontNames.length,
              itemBuilder: (context, index) {
                var fontName = fontNames[index];
                return _buildItem(
                  fontNames[index],
                  () {
                    widget.onFontChange.call(fontName);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(String fontName, GestureTapCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            fontName,
            style: GoogleFonts.getFont(fontName, fontSize: 22),
          ),
        ),
      ),
    );
  }
}
