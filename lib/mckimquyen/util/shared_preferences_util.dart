import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesUtil {
  static String keyTimestampDismissBottomSheetNotification = "keyTimestampDismissBottomSheetNotification";
  static String keyHasConfigNotificationForAndroidBelow33 = "keyHasConfigNotificationForAndroidBelow33";

  static void resetAllData() async {
    // SafeLogger.d('Log', "resetAllData");
    var valueTimestampDismissBottomSheetNotification =
        await SharedPreferencesUtil.getInt(SharedPreferencesUtil.keyTimestampDismissBottomSheetNotification) ?? 0;
    var valueHasConfigNotificationForAndroidBelow33 =
        await SharedPreferencesUtil.getBool(SharedPreferencesUtil.keyHasConfigNotificationForAndroidBelow33) ?? true;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // SafeLogger.d('Log', "valueTimestampDismissBottomSheetNotification $valueTimestampDismissBottomSheetNotification");
    // SafeLogger.d('Log', "valueHasConfigNotificationForAndroidBelow33 $valueHasConfigNotificationForAndroidBelow33");
    SharedPreferencesUtil.setInt(
        SharedPreferencesUtil.keyTimestampDismissBottomSheetNotification, valueTimestampDismissBottomSheetNotification);
    await SharedPreferencesUtil.setBool(
        SharedPreferencesUtil.keyHasConfigNotificationForAndroidBelow33, valueHasConfigNotificationForAndroidBelow33);
  }

  static Future<void> setInt(String key, int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(key, value);
  }

  static Future<int?> getInt(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  static Future<void> setBool(String key, bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(key, value);
  }

  static Future<bool?> getBool(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key);
  }

  static Future<void> setString(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value);
  }

  static Future<String?> getString(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> saveIntList(List<int> intList, String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> stringList = intList.map((i) => i.toString()).toList();
    await prefs.setStringList(key, stringList);
  }

  static Future<List<int>> getIntList(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? stringList = prefs.getStringList(key);
    if (stringList != null) {
      return stringList.map((s) => int.parse(s)).toList();
    } else {
      return [];
    }
  }
}
