// screen_a/b/c moved to packages/ad_sdk/example/lib/ — use them from the example app

import 'package:saigonphantomlabs/mckimquyen/common/const/color_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/util/ui_utils.dart';
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
    if (!widget.isShowMenu) {
      // Defer navigation to AFTER the first frame is fully built.
      // Calling Get.offAll() synchronously inside initState() triggers
      // a navigator operation while the widget tree is still being mounted,
      // causing the "markNeedsBuild during build" assertion.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Get.offAll(const WiFiStressorApp());
      });
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
          // Nền app tối -> icon status bar luôn sáng (trắng).
          statusBarIconBrightness: Brightness.light, // Android
          statusBarBrightness: Brightness.dark, // iOS
        ),
      ),
      backgroundColor: ColorConstants.appColor,
      body: _buildBodyView(context),
    );
  }

  Widget _buildBodyView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        UIUtils.getButton(
          "Ad demo (see packages/ad_sdk/example)",
          Icons.card_giftcard,
          () {
            // ScreenA moved to packages/ad_sdk/example/lib/screen_a.dart
            // Run the example app from packages/ad_sdk/example/ to test ads
          },
        ),
        UIUtils.getButton(
          "Wifi stressor",
          Icons.wifi,
              () {
            Get.to(const WiFiStressorApp());
          },
        ),
      ],
    );
  }
}
