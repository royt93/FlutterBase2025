import 'dart:convert';
import 'dart:io';

// Removed unused dependencies: app_settings, bottom_sheet
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// Removed unused dependencies: lottie, modal_bottom_sheet
import 'package:permission_handler/permission_handler.dart';
// Removed daily notification imports - feature removed
import 'package:toastification/toastification.dart';

import '../common/const/color_constants.dart';
import '../common/const/dimen_constants.dart';

class UIUtils {
  static AppBar getAppBar(
    String text,
    VoidCallback? onPressed,
    VoidCallback? onPressCodeViewer, {
    Color backgroundColor = ColorConstants.appColor,
    IconData iconData = Icons.code,
  }) {
    // ignore: no_leading_underscores_for_local_identifiers
    Widget _buildActionCodeWidget() {
      if (onPressCodeViewer == null) {
        return Container();
      } else {
        return Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(45),
            boxShadow: const [
              BoxShadow(
                color: Colors.grey,
                blurRadius: 4,
                offset: Offset(4, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              iconData,
              color: Colors.black,
            ),
            onPressed: onPressCodeViewer,
          ),
        );
      }
    }

    return AppBar(
      title: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
          shadows: [
            Shadow(
              blurRadius: 5.0,
              color: Colors.black,
              offset: Offset(2.0, 2.0),
            ),
          ],
        ),
      ),
      centerTitle: true,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(45),
          boxShadow: const [
            BoxShadow(
              color: Colors.grey,
              blurRadius: 4,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: onPressed,
        ),
      ),
      //add action on appbar
      actions: [
        _buildActionCodeWidget(),
      ],
      backgroundColor: backgroundColor,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  static Widget getButton(
    String text,
    IconData? iconData,
    VoidCallback? onPressed, {
    double marginTop = DimenConstants.marginPaddingMedium,
    String description = "",
  }) {
    return Container(
      margin: EdgeInsets.only(top: marginTop),
      // height: DimenConstants.buttonHeight * 1.5,
      // padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          minimumSize: const Size(double.infinity, DimenConstants.buttonHeight * 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DimenConstants.radiusRound),
            side: BorderSide(
              color: const Color(0xFF8C98A8).withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: DimenConstants.txtMedium,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty == true)
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: DimenConstants.txtSmall,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(width: DimenConstants.marginPaddingMedium),
            Icon(iconData),
          ],
        ),
      ),
    );
  }

  static OutlinedButton getOutlineButton(
    String text,
    VoidCallback? onPressed,
  ) {
    return OutlinedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        side: const BorderSide(
          width: 2.0,
          color: Colors.red,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DimenConstants.radiusRound),
        ),
      ),
      child: Text(text),
    );
  }

  static Text getText(String text) {
    return Text(
      text,
      style: UIUtils.getStyleText(),
    );
  }

  static TextStyle getStyleText() {
    return const TextStyle(
      color: Colors.black,
      fontSize: DimenConstants.txtMedium,
    );
  }

  static TextStyle getCustomFontTextStyle() {
    return const TextStyle(
      color: Colors.blueAccent,
      fontFamily: 'Pacifico',
      fontWeight: FontWeight.w400,
      fontSize: 36.0,
    );
  }

  static LinearGradient getCustomGradient() {
    return const LinearGradient(
      colors: [Colors.pink, Colors.blueAccent],
      begin: FractionalOffset(0.0, 0.0),
      end: FractionalOffset(0.6, 0.0),
      stops: [0.0, 0.6],
      tileMode: TileMode.clamp,
    );
  }

  static CircularProgressIndicator getCircularProgressIndicator(Color color) {
    return CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(color),
    );
  }

  static Future sleep(int timeInSecond, Function? function) {
    return Future.delayed(
      Duration(seconds: timeInSecond),
      () => function?.call(),
    );
  }

  static void showAlertDialog(
    BuildContext context,
    String title,
    String message,
    String? cancelTitle,
    VoidCallback? cancelAction,
    String okTitle,
    VoidCallback? okAction,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Color(0xff232426),
          ),
        ),
        title: Text(title),
        actions: [
          if (cancelTitle != null)
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Get.back();
                cancelAction?.call();
              },
              child: Text(
                cancelTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xff0A79F8),
                ),
              ),
            ),
          CupertinoDialogAction(
            child: Text(
              okTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xffFF0000),
              ),
            ),
            onPressed: () {
              Get.back();
              okAction?.call();
            },
          ),
        ],
      ),
    );
  }

  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
    String okTitle,
    VoidCallback? okCallback,
  ) {
    showAlertDialog(
      context,
      title,
      message,
      null,
      null,
      okTitle,
      okCallback,
    );
  }

  static Widget buildHorizontalDivider(Color color, double width, double height) {
    return Container(
      margin: const EdgeInsets.all(0.0),
      height: height,
      width: width,
      color: color,
    );
  }

  static Widget buildVerticalDivider(Color color, double height) {
    return Container(
      margin: const EdgeInsets.all(0.0),
      height: height,
      width: 1,
      color: color,
    );
  }

// static void showBottomSheetSingleChoice(
//     BuildContext context,
//     String title,
//     List<String> list,
//     Function(int) selectedPosition,
//     int firstSelectedPosition,
//     ) {
//   List<Widget> _buildListWidget() {
//     var listWidget = <Widget>[];
//
//     listWidget.add(
//       Container(
//         alignment: Alignment.center,
//         padding: EdgeInsets.fromLTRB(
//           0,
//           DimenConstants.marginPaddingSmall,
//           0,
//           0,
//         ),
//         child: Image.asset(
//           "resources/images/ic_slide_controller.png",
//           width: 45,
//           height: 5,
//         ),
//       ),
//     );
//     listWidget.add(
//       Container(
//         padding: EdgeInsets.fromLTRB(
//           DimenConstants.marginPaddingMedium,
//           0,
//           0,
//           0,
//         ),
//         child: Row(
//           children: [
//             Expanded(
//               child: Text(
//                 title,
//                 textAlign: TextAlign.start,
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w500,
//                   color: Color(0xff232426),
//                 ),
//               ),
//             ),
//             Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 customBorder: new CircleBorder(),
//                 child: Container(
//                   padding: EdgeInsets.all(15),
//                   child: Image.asset(
//                     "resources/images/ic_slide_down.png",
//                     width: 34,
//                     height: 34,
//                   ),
//                 ),
//                 onTap: () {
//                   Get.back();
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//     for (int i = 0; i < list.length; i++) {
//       listWidget.add(
//         Material(
//           color: Colors.transparent,
//           child: InkWell(
//             highlightColor: Colors.transparent,
//             child: Container(
//               alignment: Alignment.centerLeft,
//               padding: EdgeInsets.fromLTRB(
//                 DimenConstants.marginPaddingMedium,
//                 0,
//                 DimenConstants.marginPaddingMedium,
//                 0,
//               ),
//               height: DimenConstants.buttonHeight * 2 / 3,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Image.asset(
//                     i == firstSelectedPosition
//                         ? "resources/images/ic_checkbox_select_circle.png"
//                         : "resources/images/ic_checkbox_unselect_circle.png",
//                     width: 18,
//                     height: 18,
//                   ),
//                   SizedBox(width: DimenConstants.marginPaddingMedium),
//                   Expanded(
//                     child: Text(
//                       list[i],
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                         color: Color(0xff232426),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             onTap: () {
//               Get.back();
//               selectedPosition.call(i);
//             },
//           ),
//         ),
//       );
//     }
//
//     return listWidget;
//   }
//
//   showMaterialModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.transparent,
//     builder: (builder) {
//       return Container(
//         padding: EdgeInsets.only(bottom: DimenConstants.marginPaddingMedium),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(25),
//             topRight: Radius.circular(25),
//           ),
//         ),
//         child: Wrap(
//           children: _buildListWidget(),
//         ),
//       );
//     },
//   );
// }
//
// static void showBottomSheetSingleChoiceWithLargeData(
//     BuildContext context,
//     String title,
//     List<String> list,
//     Function(int) selectedPosition,
//     int firstSelectedPosition,
//     ) {
//   if (list == null || list.isEmpty) {
//     return;
//   }
//
//   List<Widget> _buildListWidget() {
//     var listWidget = <Widget>[];
//     for (int i = 0; i < list.length; i++) {
//       listWidget.add(
//         Material(
//           color: Colors.transparent,
//           child: InkWell(
//             child: Container(
//               alignment: Alignment.centerLeft,
//               padding: EdgeInsets.fromLTRB(
//                 DimenConstants.marginPaddingMedium,
//                 0,
//                 DimenConstants.marginPaddingMedium,
//                 0,
//               ),
//               height: DimenConstants.buttonHeight * 2 / 3,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Image.asset(
//                     i == firstSelectedPosition
//                         ? "resources/images/ic_checkbox_select_circle.png"
//                         : "resources/images/ic_checkbox_unselect_circle.png",
//                     width: 18,
//                     height: 18,
//                   ),
//                   SizedBox(width: DimenConstants.marginPaddingMedium),
//                   Expanded(
//                     child: Text(
//                       list[i],
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w500,
//                         color: Color(0xff232426),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             onTap: () {
//               Get.back();
//               selectedPosition.call(i);
//             },
//           ),
//         ),
//       );
//     }
//     return listWidget;
//   }
//
//   double _height = (list.length > 10) ? Get.height / 2 : Get.height / 3;
//   showMaterialModalBottomSheet(
//     context: context,
//     backgroundColor: Colors.transparent,
//     enableDrag: false,
//     builder: (builder) {
//       return Container(
//         height: _height,
//         margin: EdgeInsets.only(top: DimenConstants.marginPaddingLarge),
//         padding: EdgeInsets.only(bottom: DimenConstants.marginPaddingMedium),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(25),
//             topRight: Radius.circular(25),
//           ),
//         ),
//         child: Column(
//           children: [
//             Container(
//               alignment: Alignment.center,
//               padding: EdgeInsets.fromLTRB(
//                 0,
//                 DimenConstants.marginPaddingSmall,
//                 0,
//                 0,
//               ),
//               child: Image.asset(
//                 "resources/images/ic_slide_controller.png",
//                 width: 45,
//                 height: 5,
//               ),
//             ),
//             Container(
//               padding: EdgeInsets.fromLTRB(
//                 DimenConstants.marginPaddingMedium,
//                 0,
//                 0,
//                 0,
//               ),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       title,
//                       textAlign: TextAlign.start,
//                       style: TextStyle(
//                         fontSize: 20,
//                         fontWeight: FontWeight.w500,
//                         color: Color(0xff232426),
//                       ),
//                     ),
//                   ),
//                   Material(
//                     color: Colors.transparent,
//                     child: InkWell(
//                       customBorder: new CircleBorder(),
//                       child: Container(
//                         padding: EdgeInsets.all(15),
//                         child: Image.asset(
//                           "resources/images/ic_slide_down.png",
//                           width: 34,
//                           height: 34,
//                         ),
//                       ),
//                       onTap: () {
//                         Get.back();
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: ListView(
//                 padding: EdgeInsets.all(0),
//                 physics: BouncingScrollPhysics(),
//                 children: _buildListWidget(),
//               ),
//             ),
//           ],
//         ),
//       );
//     },
//   );
// }

  static void showBottomSheetNotification(Function onDismiss) {
    Permission.notification.isGranted.then((isGrantedPermissionNotification) {
      // SafeLogger.d('Log', "isGrantedPermissionNotification $isGrantedPermissionNotification");

      void show() {
        var c = Get.context;
        if (c == null) {
          return;
        }
        showModalBottomSheet(
          enableDrag: false,
          context: c,
          builder: (context) => Container(
            width: Get.width,
            padding: const EdgeInsets.all(16),
            height: Get.height * 65 / 100,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Notification setting",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    InkWell(
                      customBorder: const CircleBorder(),
                      splashColor: Colors.red,
                      onTap: () {
                        Get.back();
                      },
                      child: const Icon(
                        Icons.clear,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    cacheExtent: double.maxFinite,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const Text(
                        'Notification settings removed to reduce APK size',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ).then((value) {
          // SafeLogger.d('Log', "then value $value");
          onDismiss.call();
        });
      }

      if (isGrantedPermissionNotification == true) {
        show();
      } else {
        Permission.notification.request().then((value) {
          // SafeLogger.d('Log', "request value $value");
          if (value == PermissionStatus.granted) {
            show();
          } else if (value == PermissionStatus.permanentlyDenied) {
            // AppSettings removed - using basic permission request
          }
        });
      }
    });
  }

  static Widget getImageBase64(String base64) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Image.memory(
          base64Decode(base64),
          gaplessPlayback: true,
          fit: BoxFit.cover,
        ));
  }

  static void showBottomSheet(
    BuildContext context,
    dynamic builder,
    VoidCallback onStart,
    VoidCallback onDismiss,
    double maxHeight,
    List<double>? anchors,
  ) {
    onStart.call();
    showModalBottomSheet(
      context: context,
      builder: builder,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
    ).then((value) {
      onDismiss.call();
    });
  }

  static void showDialogSuccess(
    BuildContext context,
    Widget textCenter,
    String confirmText,
    String cancelText,
    String lottiePath,
    bool barrierDismissible,
    Function onClickConfirm,
    Function onClickCancel,
    Function onDismiss,
  ) {
    showGeneralDialog(
      barrierLabel: "",
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      context: context,
      pageBuilder: (_, __, ___) {
        return Center(
          child: Container(
            width: Get.width,
            margin: const EdgeInsets.all(DimenConstants.marginPaddingMedium),
            padding: const EdgeInsets.fromLTRB(
              DimenConstants.marginPaddingMedium,
              DimenConstants.marginPaddingMedium,
              DimenConstants.marginPaddingMedium,
              0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(DimenConstants.radiusMedium),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 25,
                    height: 25,
                    child: CircleAvatar(
                      backgroundColor: Colors.grey,
                      radius: 45,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 155,
                  height: 155,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(75),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: DimenConstants.marginPaddingMedium),
                textCenter,
                const SizedBox(height: DimenConstants.marginPaddingMedium),
                Row(
                  children: [
                    if (cancelText.isNotEmpty) ...[
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xff2B67F6),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                0,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15)),
                                side: BorderSide(color: Color(0xffDEE1EB), width: 1.0),
                              ),
                            ),
                            onPressed: () {
                              Get.back();
                              onClickCancel.call();
                            },
                            child: Text(
                              cancelText,
                              style: TextStyle(
                                color: ColorConstants.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xff2B67F6),
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              0,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(15)),
                              side: BorderSide(color: Color(0xffDEE1EB), width: 1.0),
                            ),
                          ),
                          onPressed: () {
                            Get.back();
                            onClickConfirm.call();
                          },
                          child: Text(
                            confirmText,
                            style: TextStyle(
                              color: ColorConstants.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DimenConstants.marginPaddingMedium),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: anim,
            curve: Curves.bounceIn,
            reverseCurve: Curves.bounceIn,
          ),
          child: child,
        );
      },
    ).then((value) {
      // SafeLogger.d('Log', "then $value");
      onDismiss.call();
    });
  }

  static void showToast(
    String title,
    String message, {
    int durationInS = 2,
    ToastificationType type = ToastificationType.success,
    ToastificationStyle style = ToastificationStyle.minimal,
    bool showIcon = true,
    bool showProgressBar = false,
  }) {
    toastification.dismissAll();
    toastification.show(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
      ),
      description: Text(
        message,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        maxLines: 10,
        overflow: TextOverflow.ellipsis,
      ),
      autoCloseDuration: Duration(seconds: durationInS),
      type: type,
      style: style,
      showIcon: showIcon,
      showProgressBar: showProgressBar,
      // padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      // margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      // closeButtonShowType: CloseButtonShowType.none,
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
      applyBlurEffect: false,
      // callbacks: ToastificationCallbacks(
      //   onTap: (toastItem) => print('Toast ${toastItem.id} tapped'),
      //   onCloseButtonTap: (toastItem) => print('Toast ${toastItem.id} close button tapped'),
      //   onAutoCompleteCompleted: (toastItem) => print('Toast ${toastItem.id} auto complete completed'),
      //   onDismissed: (toastItem) => print('Toast ${toastItem.id} dismissed'),
      // ),
    );
  }

  static Future<void> initEdgeToEdge() async {
    if (!Platform.isAndroid) return;
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    if (sdkInt >= 29) {
      // Android 10+ hỗ trợ edge-to-edge
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    } else {
      // Android cũ: fallback
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      );
    }
  }

  static double getPaddingBottom(BuildContext context, {double ratio = 2}) {
    final padding = MediaQuery.of(context).padding;
    return padding.bottom * ratio;
  }
}

// Convert HSVColor to HexColor (Color)
// Color hsvToHex(HSVColor hsvColor) {
//   return hsvColor.toColor();
// }

// Convert HexColor (Color) to HSVColor
// HSVColor hexToHsv(Color hexColor) {
//   return HSVColor.fromColor(hexColor);
// }
