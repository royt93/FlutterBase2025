import 'utils/safe_logger.dart';
import 'utils/app_preferences.dart';

/// Kết quả kiểm tra an toàn quảng cáo
/// Thay thế Dart records (bool, String) để tương thích SDK < 3.0
class AdSafetyResult {
  final bool canShow;
  final String reason;
  const AdSafetyResult(this.canShow, this.reason);
}

/// Cấu hình và quản lý an toàn quảng cáo để tránh Invalid Traffic
/// Port 100% từ AdSafetyConfig trong AdManager.kt (dòng 1360–1648)
///
/// 12 biện pháp bảo vệ:
/// === BASIC ===
/// 1. Throttle fullscreen ads (min 60s giữa các ads)
/// 2. Session ad limit (max 6 fullscreen ads / session)
/// 3. Click rate monitoring (detect click bất thường)
/// 4. First launch skip (không show App Open lần đầu cold start)
/// 5. Resume cooldown (không show khi resume quá nhanh)
///
/// === ADVANCED ===
/// 6. Daily ad limit (max 5 fullscreen ads / ngày - persistent)
/// 7. Hourly frequency cap (max 3 fullscreen ads / giờ)
/// 8. CTR anomaly detection (CTR > 30% → tạm ngưng)
/// 9. Progressive cooldown (vi phạm nhiều lần → pause lâu hơn)
/// 10. Minimum session duration (không show trong 10s đầu)
/// 11. Rapid resume detection (background/foreground liên tục → skip)
/// 12. Impression tracking (đếm impression để tính CTR)
class AdSafetyConfig {
  static const String _tag = 'roy93~AdSafety';

  // ════════════════ CONSTANTS BASIC ════════════════
  /// Thời gian tối thiểu giữa các fullscreen ads
  static const int _minTimeBetweenFullscreenAds = 60000; // 60s

  /// Số fullscreen ads tối đa trong 1 session
  static const int _maxFullscreenAdsPerSession = 6;

  /// Thời gian tối thiểu app phải ở background trước khi show App Open
  static const int _minTimeAppOpenResume = 5000; // 5s

  /// Số click tối đa trong 1 phút
  static const int _maxClicksPerMinute = 3;

  // ════════════════ CONSTANTS ADVANCED ════════════════
  /// Số fullscreen ads tối đa trong 1 ngày (persistent)
  static const int _maxFullscreenAdsPerDay = 5;

  /// Số fullscreen ads tối đa trong 1 giờ
  static const int _maxFullscreenAdsPerHour = 3;

  /// Thời gian tối thiểu session trước khi show fullscreen ad đầu tiên
  static const int _minSessionDurationBeforeAd = 10000; // 10s

  /// Ngưỡng CTR bất thường (> 30% khi có >= 5 impressions)
  static const double _suspiciousCtrThreshold = 0.30;

  /// Số lần tối đa resume nhanh trong 1 phút trước khi skip App Open
  static const int _maxRapidResumesPerMinute = 3;

  /// Thời gian pause cơ bản (nhân đôi mỗi lần vi phạm)
  static const int _baseSuspiciousPause = 30 * 60 * 1000; // 30 phút

  /// Thời gian pause tối đa (cap)
  static const int _maxSuspiciousPause = 24 * 60 * 60 * 1000; // 24 giờ

  // ════════════════ STATE (không dùng late) ════════════════
  static int _lastFullscreenAdTime = 0;
  static int _fullscreenAdsShownInSession = 0;
  static int _lastBackgroundTime = 0;
  static bool _isColdStart = true;
  static final List<int> _clickTimestamps = [];
  static int _suspiciousPauseUntil = 0;
  static int _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
  static final List<int> _hourlyAdTimestamps = [];
  static final List<int> _resumeTimestamps = [];
  static int _totalImpressions = 0;
  static int _totalClicks = 0;
  static int _suspiciousViolationCount = 0;
  static AppPreferences? _appPreferences;

  /// Khởi tạo với AppPreferences để persist daily limit
  static Future<void> init(AppPreferences prefs) async {
    _appPreferences = prefs;
    _suspiciousViolationCount = prefs.getSuspiciousCount();
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
    SafeLogger.d(
      _tag,
      '🔄 init, dailyAds=${prefs.getDailyAdCount()}/$_maxFullscreenAdsPerDay, '
      'suspiciousCount=$_suspiciousViolationCount',
    );
  }

  // ════════════════ CORE CHECK 1 ════════════════

  /// Kiểm tra có được show fullscreen ad không
  /// 7 checks ĐÚNG THỨ TỰ từ Kotlin (dòng 1466–1523)
  /// @return (bool canShow, String reason)
  static AdSafetyResult canShowFullscreenAd() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // ① Suspicious pause đang active? (progressive cooldown)
    if (now < _suspiciousPauseUntil) {
      final remaining = (_suspiciousPauseUntil - now) ~/ 1000;
      SafeLogger.d(_tag, '🛡️ Ads paused, remaining=${remaining}s');
      return AdSafetyResult(false, 'Suspended: ${remaining}s remaining');
    }

    // ② Minimum session duration (10s đầu skip)
    final sessionDuration = now - _sessionStartTime;
    if (sessionDuration < _minSessionDurationBeforeAd) {
      final waitSec = (_minSessionDurationBeforeAd - sessionDuration) ~/ 1000;
      SafeLogger.d(
        _tag,
        '🛡️ Session too young (${sessionDuration ~/ 1000}s), wait ${waitSec}s',
      );
      return AdSafetyResult(false, 'Session too young: wait ${waitSec}s');
    }

    // ③ Session limit (max 6)
    if (_fullscreenAdsShownInSession >= _maxFullscreenAdsPerSession) {
      SafeLogger.d(
        _tag,
        '🛡️ Session limit: $_fullscreenAdsShownInSession/$_maxFullscreenAdsPerSession',
      );
      return AdSafetyResult(false, 'Session limit: $_fullscreenAdsShownInSession ads');
    }

    // ④ Hourly cap (max 3) – xóa entries cũ hơn 1 giờ
    _hourlyAdTimestamps.removeWhere((t) => now - t > 3600000);
    if (_hourlyAdTimestamps.length >= _maxFullscreenAdsPerHour) {
      SafeLogger.d(
        _tag,
        '🛡️ Hourly cap: ${_hourlyAdTimestamps.length}/$_maxFullscreenAdsPerHour',
      );
      return AdSafetyResult(false, 'Hourly cap: ${_hourlyAdTimestamps.length} ads');
    }

    // ⑤ Daily limit (max 5, persistent SharedPreferences)
    final dailyCount = _appPreferences?.getDailyAdCount() ?? 0;
    if (dailyCount >= _maxFullscreenAdsPerDay) {
      SafeLogger.d(
        _tag,
        '🛡️ Daily limit: $dailyCount/$_maxFullscreenAdsPerDay',
      );
      return AdSafetyResult(false, 'Daily limit: $dailyCount ads');
    }

    // ⑥ Throttle (min 60s giữa 2 fullscreen ads)
    if (_lastFullscreenAdTime > 0) {
      final timeSinceLastAd = now - _lastFullscreenAdTime;
      if (timeSinceLastAd < _minTimeBetweenFullscreenAds) {
        final remainingSec =
            (_minTimeBetweenFullscreenAds - timeSinceLastAd) ~/ 1000;
        SafeLogger.d(_tag, '🛡️ Throttle: wait ${remainingSec}s');
        return AdSafetyResult(false, 'Throttle: ${remainingSec}s');
      }
    }

    // ⑦ CTR anomaly (> 30% khi ≥ 5 impressions) → trigger suspicious pause
    if (_totalImpressions >= 5) {
      final ctr = _totalClicks.toDouble() / _totalImpressions.toDouble();
      if (ctr > _suspiciousCtrThreshold) {
        _triggerSuspiciousPause(
          'CTR anomaly: ${(ctr * 100).toInt()}% '
          '(threshold: ${(_suspiciousCtrThreshold * 100).toInt()}%)',
        );
        return AdSafetyResult(false, 'CTR too high: ${(ctr * 100).toInt()}%');
      }
    }

    return AdSafetyResult(true, 'OK');
  }

  // ════════════════ CORE CHECK 2 ════════════════

  /// Kiểm tra có được show App Open Ad khi resume không
  /// 3 checks từ Kotlin (dòng 1529–1560)
  static bool canShowAppOpenOnResume() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // ① Cold start → skip (chỉ show App Open từ Splash)
    if (_isColdStart) {
      _isColdStart = false;
      SafeLogger.d(_tag, '🛡️ Skipping App Open on cold start');
      return false;
    }

    // ② Background quá ngắn (< 5s)
    if (_lastBackgroundTime > 0) {
      final timeInBackground = now - _lastBackgroundTime;
      if (timeInBackground < _minTimeAppOpenResume) {
        SafeLogger.d(
          _tag,
          '🛡️ Resume too fast (${timeInBackground}ms)',
        );
        return false;
      }
    }

    // ③ Rapid resume detection (> 3 lần resume/phút → skip)
    _resumeTimestamps.add(now);
    _resumeTimestamps.removeWhere((t) => now - t > 60000);
    if (_resumeTimestamps.length > _maxRapidResumesPerMinute) {
      SafeLogger.d(
        _tag,
        '🛡️ Rapid resume detected: ${_resumeTimestamps.length} resumes/min',
      );
      _resumeTimestamps.clear();
      return false;
    }

    return true;
  }

  // ════════════════ RECORDING ════════════════

  /// Ghi nhận fullscreen ad đã SHOW thật sự
  static void recordFullscreenAdShown() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastFullscreenAdTime = now;
    _fullscreenAdsShownInSession++;
    _totalImpressions++;
    _hourlyAdTimestamps.add(now);
    _appPreferences?.incrementDailyAdCount();

    final dailyCount =
        _appPreferences?.getDailyAdCount() ?? _fullscreenAdsShownInSession;
    SafeLogger.d(
      _tag,
      '📊 Ad SHOWN | session=$_fullscreenAdsShownInSession/$_maxFullscreenAdsPerSession '
      '| hourly=${_hourlyAdTimestamps.length}/$_maxFullscreenAdsPerHour '
      '| daily=$dailyCount/$_maxFullscreenAdsPerDay '
      '| impressions=$_totalImpressions',
    );
  }

  /// Ghi nhận user click ad → >3 clicks/min → trigger suspicious pause
  static void recordAdClick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _totalClicks++;
    _clickTimestamps.add(now);

    // Xóa clicks cũ hơn 1 phút
    _clickTimestamps.removeWhere((t) => now - t > 60000);

    final ctr = _totalImpressions > 0
        ? (_totalClicks.toDouble() / _totalImpressions * 100).toInt()
        : 0;
    SafeLogger.d(
      _tag,
      '📊 Click | clicks/min=${_clickTimestamps.length}/$_maxClicksPerMinute '
      '| CTR=$ctr% | total=$_totalClicks/$_totalImpressions',
    );

    // Kiểm tra click rate per minute
    if (_clickTimestamps.length > _maxClicksPerMinute) {
      _triggerSuspiciousPause(
        'Click spam: ${_clickTimestamps.length} clicks/min',
      );
      _clickTimestamps.clear();
    }
  }

  /// Ghi nhận app vào background (gọi từ WidgetsBindingObserver.paused)
  static void recordAppWentBackground() {
    _lastBackgroundTime = DateTime.now().millisecondsSinceEpoch;
    SafeLogger.d(_tag, '📊 App went to background');
  }

  // ════════════════ PROGRESSIVE COOLDOWN ════════════════
  // Kotlin: Math.pow(2.0, (count-1).coerceAtMost(4)) * BASE
  // → 30p → 1h → 2h → 4h → 8h (cap 24h)
  static void _triggerSuspiciousPause(String reason) {
    _suspiciousViolationCount++;
    _appPreferences?.incrementSuspiciousCount();

    final exponent = (_suspiciousViolationCount - 1).clamp(0, 4);
    int multiplier = 1;
    for (int i = 0; i < exponent; i++) {
      multiplier *= 2;
    }

    int pauseDuration = _baseSuspiciousPause * multiplier;
    if (pauseDuration > _maxSuspiciousPause) {
      pauseDuration = _maxSuspiciousPause;
    }

    _suspiciousPauseUntil =
        DateTime.now().millisecondsSinceEpoch + pauseDuration;
    SafeLogger.w(
      _tag,
      '⚠️ SUSPICIOUS: $reason | violation #$_suspiciousViolationCount '
      '| paused ${pauseDuration ~/ 60000} min',
    );
  }

  // ════════════════ PUBLIC API ════════════════

  static int getSessionAdCount() => _fullscreenAdsShownInSession;

  static void resetSession() {
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
    _fullscreenAdsShownInSession = 0;
    _hourlyAdTimestamps.clear();
    _resumeTimestamps.clear();
    _totalImpressions = 0;
    _totalClicks = 0;
    SafeLogger.d(_tag, '🔄 Session reset');
  }

  static String getStatus() {
    final ctr = _totalImpressions > 0
        ? (_totalClicks.toDouble() / _totalImpressions * 100).toInt()
        : 0;
    final dailyCount = _appPreferences?.getDailyAdCount() ?? 0;
    return 'AdSafety['
        'session=$_fullscreenAdsShownInSession/$_maxFullscreenAdsPerSession, '
        'hourly=${_hourlyAdTimestamps.length}/$_maxFullscreenAdsPerHour, '
        'daily=$dailyCount/$_maxFullscreenAdsPerDay, '
        'CTR=$ctr%, '
        'clicks/min=${_clickTimestamps.length}, '
        'violations=$_suspiciousViolationCount, '
        'suspended=${DateTime.now().millisecondsSinceEpoch < _suspiciousPauseUntil}]';
  }
}
