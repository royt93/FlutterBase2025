import 'package:shared_preferences/shared_preferences.dart';

/// Quản lý SharedPreferences cho VIP member + Ad Safety
/// Port từ AppPreferences.kt
class AppPreferences {
  static AppPreferences? _instance;
  SharedPreferences? _prefs;

  AppPreferences._();

  static Future<AppPreferences> getInstance() async {
    var instance = _instance;
    if (instance == null) {
      instance = AppPreferences._();
      instance._prefs = await SharedPreferences.getInstance();
      _instance = instance;
    }
    return instance;
  }

  /// Trả về instance nếu đã init, null nếu chưa
  static AppPreferences? get instanceOrNull => _instance;

  // ════════════════ VIP MANAGEMENT ════════════════

  static const String _keyListGAID = 'keyListGAID';
  static const String _keyAddVIPMemberFirstInitSuccess =
      'keyAddVIPMemberFirstInitSuccess';

  List<String> getGAIDList() {
    return _prefs?.getStringList(_keyListGAID) ?? [];
  }

  Future<void> saveGAIDList(List<String> list) async {
    // Chuyển qua Set để loại bỏ trùng lặp
    await _prefs?.setStringList(_keyListGAID, list.toSet().toList());
  }

  bool isAddVIPMemberFirstInitSuccess() {
    return _prefs?.getBool(_keyAddVIPMemberFirstInitSuccess) ?? false;
  }

  Future<void> addVIPMemberFirstInitSuccess() async {
    await _prefs?.setBool(_keyAddVIPMemberFirstInitSuccess, true);
  }

  // ════════════════ AD SAFETY PERSISTENCE ════════════════

  static const String _keyDailyAdCount = 'ad_safety_daily_count';
  static const String _keyDailyDate = 'ad_safety_daily_date';
  static const String _keySuspiciousCount = 'ad_safety_suspicious_count';

  /// Lấy số ad đã show trong ngày (reset nếu sang ngày mới)
  int getDailyAdCount() {
    final today = DateTime.now().toString().substring(0, 10);
    final savedDate = _prefs?.getString(_keyDailyDate) ?? '';
    // Reset nếu sang ngày mới
    if (savedDate != today) {
      _prefs?.setString(_keyDailyDate, today);
      _prefs?.setInt(_keyDailyAdCount, 0);
      _prefs?.setInt(_keySuspiciousCount, 0);
      return 0;
    }
    return _prefs?.getInt(_keyDailyAdCount) ?? 0;
  }

  Future<void> incrementDailyAdCount() async {
    final today = DateTime.now().toString().substring(0, 10);
    final current = getDailyAdCount();
    await _prefs?.setInt(_keyDailyAdCount, current + 1);
    await _prefs?.setString(_keyDailyDate, today);
  }

  int getSuspiciousCount() {
    return _prefs?.getInt(_keySuspiciousCount) ?? 0;
  }

  Future<void> incrementSuspiciousCount() async {
    final current = getSuspiciousCount();
    await _prefs?.setInt(_keySuspiciousCount, current + 1);
  }

  /// Xóa tất cả dữ liệu (dùng cho testing/reset)
  Future<void> clearAllData() async {
    await _prefs?.clear();
  }
}
