import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';

import '../../core/base_stateful_state.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    this.title,
    required this.isShowMenu,
  });

  final String? title;
  final bool isShowMenu;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends BaseStatefulState<MainScreen> with SingleTickerProviderStateMixin {
  // final ControllerMain _controllerMain = Get.find();

  @override
  void initState() {
    super.initState();
    if (widget.isShowMenu) {
      //do nothing
    } else {
      Get.offAll(() => const WiFiStressorApp());
    }
  }

  // @override
  // void dispose() {
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          systemNavigationBarColor: Colors.transparent,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      backgroundColor: ColorConstants.appColor,
      body: _buildBodyView(context),
    );
  }

  Widget _buildBodyView(BuildContext context) {
    return Container();
  }
}
