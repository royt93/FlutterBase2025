import 'package:hive_flutter/hive_flutter.dart';
import '../models/test_result.dart';
import '../models/network_info_adapter.dart';
import '../models/test_result_adapter.dart';
import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';


/// Service để quản lý lưu trữ test history với Hive
/// SINGLETON pattern để đảm bảo chỉ có 1 instance và 1 box
class TestHistoryStorage {
  static const String _boxName = 'test_history';
  static const int _maxHistoryItems = 100; // Giới hạn 100 tests để tránh memory issues

  // Singleton instance
  static TestHistoryStorage? _instance;
  static TestHistoryStorage get instance {
    final existing = _instance;
    if (existing != null) return existing;
    final created = TestHistoryStorage._internal();
    _instance = created;
    return created;
  }

  // Private constructor
  TestHistoryStorage._internal();

  Box<TestResult>? _box;
  bool _isInitialized = false;

  /// Khởi tạo Hive và register adapters
  Future<void> init() async {
    // Nếu đã init rồi, skip
    if (_isInitialized && _box != null) {
      SafeLogger.d('Log', '✅ Storage already initialized, skipping...');
      return;
    }

    try {
      SafeLogger.d('Log', '🔧 Initializing TestHistoryStorage...');

      // Init Hive (chỉ init một lần)
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.initFlutter();
        SafeLogger.d('Log', '✅ Hive.initFlutter() completed');
      }

      // Register adapters nếu chưa register
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(NetworkInfoAdapter());
        SafeLogger.d('Log', '✅ NetworkInfoAdapter registered');
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(TestResultAdapter());
        SafeLogger.d('Log', '✅ TestResultAdapter registered');
      }

      // Open box (hoặc get existing box nếu đã mở)
      if (Hive.isBoxOpen(_boxName)) {
        _box = Hive.box<TestResult>(_boxName);
        SafeLogger.d('Log', '✅ Reusing existing box');
      } else {
        _box = await Hive.openBox<TestResult>(_boxName);
        SafeLogger.d('Log', '✅ Box opened: $_boxName');
      }

      _isInitialized = true;
      SafeLogger.d('Log', '✅ Storage initialized successfully. Total items: ${_box?.length ?? 0}');
    } catch (e) {
      SafeLogger.d('Log', '❌ Failed to initialize TestHistoryStorage: $e');
      throw Exception('Failed to initialize TestHistoryStorage: $e');
    }
  }

  /// Get box instance
  Box<TestResult>? get box => _box;

  /// Lưu test result
  Future<void> saveTestResult(TestResult result) async {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    try {
      // Thêm result mới
      await _box?.put(result.id, result);

      // Cleanup old results nếu vượt quá giới hạn
      await _cleanupOldResults();
    } catch (e) {
      throw Exception('Failed to save test result: $e');
    }
  }

  /// Get tất cả test results, sorted by startTime (newest first)
  List<TestResult> getAllResults() {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    final results = _box?.values.toList() ?? [];
    results.sort((a, b) => b.startTime.compareTo(a.startTime));
    return results;
  }

  /// Get test result by ID
  TestResult? getResultById(String id) {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    return _box?.get(id);
  }

  /// Delete test result by ID
  Future<void> deleteResult(String id) async {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    try {
      await _box?.delete(id);
    } catch (e) {
      throw Exception('Failed to delete test result: $e');
    }
  }

  /// Clear toàn bộ history
  Future<void> clearAllHistory() async {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    try {
      await _box?.clear();
    } catch (e) {
      throw Exception('Failed to clear history: $e');
    }
  }

  /// Get results filtered by date range
  List<TestResult> getResultsByDateRange(DateTime start, DateTime end) {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    final allResults = getAllResults();
    return allResults.where((result) {
      return result.startTime.isAfter(start) && result.startTime.isBefore(end);
    }).toList();
  }

  /// Get results filtered by status
  List<TestResult> getResultsByStatus(String status) {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    final allResults = getAllResults();
    return allResults.where((result) => result.status == status).toList();
  }

  /// Get results grouped by date (for timeline)
  Map<String, List<TestResult>> getResultsGroupedByDate() {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    final allResults = getAllResults();
    final Map<String, List<TestResult>> grouped = {};

    for (final result in allResults) {
      final dateKey = _formatDateKey(result.startTime);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]?.add(result);
    }

    return grouped;
  }

  /// Format date key cho grouping (e.g., "Today", "Yesterday", "Jan 1, 2026")
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final testDate = DateTime(date.year, date.month, date.day);

    if (testDate == today) {
      return 'Today';
    } else if (testDate == yesterday) {
      return 'Yesterday';
    } else {
      // Format: "Jan 1, 2026"
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  /// Cleanup old results để giữ tối đa _maxHistoryItems
  Future<void> _cleanupOldResults() async {
    if (_box == null) return;

    final allResults = getAllResults();
    if (allResults.length > _maxHistoryItems) {
      // Sort by oldest first
      allResults.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Delete oldest items
      final itemsToDelete = allResults.length - _maxHistoryItems;
      for (int i = 0; i < itemsToDelete; i++) {
        await _box?.delete(allResults[i].id);
      }
    }
  }

  /// Get total count
  int get totalCount => _box?.length ?? 0;

  /// Check if storage is empty
  bool get isEmpty => _box?.isEmpty ?? true;

  /// Close storage (call in app dispose)
  /// NOTE: Vì dùng singleton, không nên close trừ khi app shutdown hoàn toàn
  Future<void> close() async {
    // KHÔNG close box vì có thể controller khác đang dùng
    // Box sẽ tự động close khi app shutdown
    SafeLogger.d('Log', '⚠️ Storage.close() called - box will remain open for other controllers');
  }

  /// Compact database để giảm file size
  Future<void> compact() async {
    if (_box == null) {
      throw Exception('Storage not initialized. Call init() first.');
    }

    try {
      await _box?.compact();
    } catch (e) {
      throw Exception('Failed to compact database: $e');
    }
  }
}
