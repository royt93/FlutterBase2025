import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
// Removed unused dependency: lottie

import '../common/const/dimen_constants.dart';

abstract class BaseStatefulState<T extends StatefulWidget> extends State<T> {
  BaseStatefulState();

  @override
  void initState() {
    // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    //   statusBarColor: Colors.transparent,
    //   statusBarIconBrightness: Brightness.light,
    //   statusBarBrightness: Brightness.dark,
    //   systemNavigationBarColor: Colors.white,
    //   systemNavigationBarIconBrightness: Brightness.dark,
    // ));
    super.initState();
  }

  void showAlertDialogWidget(
    bool barrierDismissible,
    String title,
    Widget widgetMessage,
    String cancelTitle,
    VoidCallback cancelAction,
    String okTitle,
    VoidCallback okAction,
  ) {
    showGeneralDialog(
      barrierColor: Colors.black.withOpacity(0.7),
      context: context,
      pageBuilder: (_, __, ___) {
        return WillPopScope(
          onWillPop: () async => barrierDismissible,
          child: Center(
            child: Container(
              width: Get.width,
              margin: const EdgeInsets.all(DimenConstants.marginPaddingMedium),
              padding: const EdgeInsets.fromLTRB(
                DimenConstants.marginPaddingMedium,
                DimenConstants.marginPaddingMedium,
                DimenConstants.marginPaddingMedium,
                DimenConstants.marginPaddingMedium,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff232426),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: DimenConstants.marginPaddingMedium),
                  widgetMessage,
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Visibility(
                        visible: cancelTitle.isNotEmpty == true,
                        child: (okTitle.isNotEmpty == true)
                            ? (Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xff0A79F8),
                                    padding: const EdgeInsets.fromLTRB(
                                      DimenConstants.marginPaddingMedium,
                                      DimenConstants.marginPaddingMedium * 2 / 3,
                                      DimenConstants.marginPaddingMedium,
                                      DimenConstants.marginPaddingMedium * 2 / 3,
                                    ),
                                    backgroundColor: const Color(0xffffffff),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(15)),
                                      side: BorderSide(color: Color(0xffDEE1EB), width: 1.0),
                                    ),
                                  ),
                                  onPressed: () {
                                    Get.back();
                                    cancelAction.call();
                                  },
                                  child: Text(
                                    cancelTitle,
                                  ),
                                ),
                              ))
                            : (TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xff0A79F8),
                                  padding: const EdgeInsets.fromLTRB(
                                    DimenConstants.marginPaddingMedium,
                                    DimenConstants.marginPaddingMedium * 2 / 3,
                                    DimenConstants.marginPaddingMedium,
                                    DimenConstants.marginPaddingMedium * 2 / 3,
                                  ),
                                  backgroundColor: const Color(0xffffffff),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(15)),
                                    side: BorderSide(color: Color(0xffDEE1EB), width: 1.0),
                                  ),
                                ),
                                onPressed: () {
                                  Get.back();
                                  cancelAction.call();
                                },
                                child: Text(
                                  cancelTitle,
                                ),
                              )),
                      ),
                      Visibility(
                        visible: okTitle.isNotEmpty == true,
                        child: const SizedBox(width: DimenConstants.marginPaddingSmall),
                      ),
                      Visibility(
                        visible: okTitle.isNotEmpty == true,
                        child: Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xffffffff),
                              padding: const EdgeInsets.fromLTRB(
                                DimenConstants.marginPaddingMedium,
                                DimenConstants.marginPaddingMedium * 2 / 3,
                                DimenConstants.marginPaddingMedium,
                                DimenConstants.marginPaddingMedium * 2 / 3,
                              ),
                              backgroundColor: const Color(0xff2B67F6),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(DimenConstants.radiusRound)),
                                side: BorderSide(color: Color(0xff2B67F6), width: 1.0),
                              ),
                            ),
                            onPressed: () {
                              Get.back();
                              okAction.call();
                            },
                            child: Text(
                              okTitle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
    );
  }

  void showAlertDialog(
    bool barrierDismissible,
    String title,
    String message,
    String? cancelTitle,
    VoidCallback? cancelAction,
    String? okTitle,
    VoidCallback? okAction,
  ) {
    showGeneralDialog(
      barrierDismissible: barrierDismissible,
      barrierLabel: "",
      barrierColor: Colors.black.withOpacity(0.7),
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
              DimenConstants.marginPaddingMedium,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff232426),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: DimenConstants.marginPaddingMedium),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xff232426),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Visibility(
                      visible: cancelTitle != null && cancelTitle.isNotEmpty == true,
                      child: (okTitle != null && okTitle.isNotEmpty == true)
                          ? (Expanded(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xff0A79F8),
                                  padding: const EdgeInsets.fromLTRB(
                                    DimenConstants.marginPaddingMedium,
                                    DimenConstants.marginPaddingMedium * 2 / 3,
                                    DimenConstants.marginPaddingMedium,
                                    DimenConstants.marginPaddingMedium * 2 / 3,
                                  ),
                                  backgroundColor: const Color(0xffffffff),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(15)),
                                    side: BorderSide(color: Color(0xffDEE1EB), width: 1.0),
                                  ),
                                ),
                                onPressed: () {
                                  Get.back();
                                  cancelAction?.call();
                                },
                                child: Text(
                                  cancelTitle ?? "",
                                ),
                              ),
                            ))
                          : (TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xff0A79F8),
                                padding: const EdgeInsets.fromLTRB(
                                  DimenConstants.marginPaddingMedium,
                                  DimenConstants.marginPaddingMedium * 2 / 3,
                                  DimenConstants.marginPaddingMedium,
                                  DimenConstants.marginPaddingMedium * 2 / 3,
                                ),
                                backgroundColor: const Color(0xffffffff),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(15)),
                                  side: BorderSide(color: Color(0xffDEE1EB), width: 1.0),
                                ),
                              ),
                              onPressed: () {
                                Get.back();
                                cancelAction?.call();
                              },
                              child: Text(
                                cancelTitle ?? "",
                              ),
                            )),
                    ),
                    Visibility(
                      visible: okTitle != null && okTitle.isNotEmpty == true,
                      child: const SizedBox(width: DimenConstants.marginPaddingSmall),
                    ),
                    Visibility(
                      visible: okTitle != null && okTitle.isNotEmpty == true,
                      child: Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xffffffff),
                            padding: const EdgeInsets.fromLTRB(
                              DimenConstants.marginPaddingMedium,
                              DimenConstants.marginPaddingMedium * 2 / 3,
                              DimenConstants.marginPaddingMedium,
                              DimenConstants.marginPaddingMedium * 2 / 3,
                            ),
                            backgroundColor: const Color(0xff2B67F6),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(Radius.circular(15)),
                              side: BorderSide(color: Color(0xff2B67F6), width: 1.0),
                            ),
                          ),
                          onPressed: () {
                            Get.back();
                            okAction?.call();
                          },
                          child: Text(
                            okTitle ?? "",
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    );
  }

}
