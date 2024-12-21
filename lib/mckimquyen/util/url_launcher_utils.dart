import 'package:gameoffline/mckimquyen/util/shared_preferences_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherUtils {
  static String getLinkGit(String path) {
    return "https://github.com/tplloi/fullter_tutorial/tree/master/$path";
  }

  static Future<void> launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
      );
    } else {
      debugPrint("Could not launch $url");
    }
  }

  static Future<void> launchInWebViewWithJavaScript(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: true,
        forceWebView: true,
        enableJavaScript: true,
      );
    } else {
      throw 'Could not launch $url';
    }
  }

  static Future<void> makePhoneCall(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  static Future<void> rateAppInApp() async {
    var key = "keyRateAppInApp";
    var prevTimestamp = await SharedPreferencesUtil.getInt(key) ?? 0;
    var nowTimestamp = DateTime.now().millisecondsSinceEpoch;
    var limit = 1000 * 60 * 60 * 24 * 7; //7 days
    // debugPrint("prevTimestamp $prevTimestamp");
    // debugPrint("nowTimestamp $nowTimestamp");
    if (nowTimestamp - prevTimestamp > limit) {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        inAppReview.requestReview();
        SharedPreferencesUtil.setInt(key, nowTimestamp);
      }
    }
  }

  static Future<void> rateApp(
    String? appStoreId,
    String? microsoftStoreId,
  ) =>
      InAppReview.instance.openStoreListing(
        appStoreId: appStoreId,
        microsoftStoreId: microsoftStoreId,
      );

  static void moreApp() {
    UrlLauncherUtils.launchInBrowser("https://play.google.com/store/apps/developer?id=SAIGON PHANTOM LABS");
  }

  static void launchPolicy() {
    // launchInWebViewWithJavaScript("https://loitp.wordpress.com/2018/06/10/privacy-policy/");
    launchInBrowser("https://loitp.notion.site/loitp/Privacy-Policy-319b1cd8783942fa8923d2a3c9bce60f/");
    // launchInWebViewWithJavaScript("https://loitp.notion.site/loitp/Privacy-Policy-319b1cd8783942fa8923d2a3c9bce60f/");
  }

  static void launchGroupTester() {
    launchInBrowser("https://groups.google.com/g/20testersforclosedtesting");
    // launchInWebViewWithJavaScript("https://groups.google.com/g/20testersforclosedtesting");
  }
}
