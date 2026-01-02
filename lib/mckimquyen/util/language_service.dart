import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý language preference với SharedPreferences
class LanguageService {
  static const String _languageKey = 'app_language';

  /// Lưu language preference
  static Future<void> saveLanguage(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, '${locale.languageCode}_${locale.countryCode}');
  }

  /// Load language preference đã lưu
  /// Returns null nếu chưa có preference (sẽ dùng default)
  static Future<Locale?> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);

    if (languageCode == null) return null;

    // Parse locale string (vd: "vi_VN" -> Locale('vi', 'VN'))
    final parts = languageCode.split('_');
    if (parts.length == 2) {
      return Locale(parts[0], parts[1]);
    }

    return null;
  }

  /// Update locale và save preference
  static Future<void> changeLanguage(Locale locale) async {
    await saveLanguage(locale);
    Get.updateLocale(locale);
  }
}
