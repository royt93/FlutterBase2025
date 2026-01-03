import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import '../models/test_result.dart';
import '../models/test_statistics.dart';
import '../services/test_history_storage.dart';
import '../../../util/ui_utils.dart';
import '../../../admob/logger.dart';

/// Controller để quản lý History screen với GetX
/// Không dùng late, không force null, không memory leak
class HistoryController extends GetxController {
  // Dùng SINGLETON storage instance (cùng với StressorController)
  final TestHistoryStorage _storage = TestHistoryStorage.instance;

  // Observable state - không dùng late
  final RxList<TestResult> allResults = <TestResult>[].obs;
  final RxList<TestResult> filteredResults = <TestResult>[].obs;
  final Rx<TestStatistics?> statistics = Rx<TestStatistics?>(null);
  final RxBool isLoading = false.obs;
  final RxString selectedTimeRange = 'all'.obs; // 'day', 'week', 'month', 'all'

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initializeStorage();
    await loadHistory();
  }

  /// Khởi tạo storage
  Future<void> _initializeStorage() async {
    try {
      isLoading.value = true;
      await _storage.init();
    } catch (e) {
      UIUtils.showToast(
        'Error',
        'Failed to initialize storage: $e',
        type: ToastificationType.error,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Load history từ storage
  Future<void> loadHistory() async {
    try {
      isLoading.value = true;

      // DEBUG: Check storage state
      Logger.i('📖 Loading history...');
      Logger.i('📦 Storage box null? ${_storage.box == null}');
      Logger.i('📦 Storage total count: ${_storage.totalCount}');

      // Load all results
      final results = _storage.getAllResults();
      Logger.i('📊 Loaded ${results.length} results from storage');

      allResults.value = results;

      // Apply current filter
      _applyTimeRangeFilter();
      Logger.i('🔍 After filter: ${filteredResults.length} results');

      // Calculate statistics
      _calculateStatistics();
      Logger.i('✅ History loaded successfully');
    } catch (e) {
      Logger.i('❌ Failed to load history: $e');
      UIUtils.showToast(
        'Error',
        'Failed to load history: $e',
        type: ToastificationType.error,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Apply time range filter
  void _applyTimeRangeFilter() {
    final now = DateTime.now();

    switch (selectedTimeRange.value) {
      case 'day':
        final startDate = DateTime(now.year, now.month, now.day);
        filteredResults.value = allResults
            .where((result) => result.startTime.isAfter(startDate))
            .toList();
        break;
      case 'week':
        final startDate = now.subtract(const Duration(days: 7));
        filteredResults.value = allResults
            .where((result) => result.startTime.isAfter(startDate))
            .toList();
        break;
      case 'month':
        final startDate = now.subtract(const Duration(days: 30));
        filteredResults.value = allResults
            .where((result) => result.startTime.isAfter(startDate))
            .toList();
        break;
      case 'all':
      default:
        // No filter
        filteredResults.value = allResults;
        break;
    }
  }

  /// Calculate statistics từ filtered results
  void _calculateStatistics() {
    if (filteredResults.isEmpty) {
      statistics.value = TestStatistics.empty();
    } else {
      statistics.value = TestStatistics.fromResults(filteredResults);
    }
  }

  /// Change time range filter
  void changeTimeRange(String timeRange) {
    selectedTimeRange.value = timeRange;
    _applyTimeRangeFilter();
    _calculateStatistics();
  }

  /// Get results grouped by date for timeline
  Map<String, List<TestResult>> getGroupedResults() {
    final grouped = <String, List<TestResult>>{};

    for (final result in filteredResults) {
      final dateKey = _formatDateKey(result.startTime);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]?.add(result);
    }

    return grouped;
  }

  /// Format date key (Today, Yesterday, or date string)
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final testDate = DateTime(date.year, date.month, date.day);

    if (testDate == today) {
      return 'today'.tr;
    } else if (testDate == yesterday) {
      return 'yesterday'.tr;
    } else {
      // Format: "Jan 1, 2026"
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  /// Delete a test result
  Future<void> deleteResult(String id) async {
    try {
      await _storage.deleteResult(id);

      // CRITICAL FIX: Update lists immediately (reactive update)
      allResults.removeWhere((r) => r.id == id);
      _applyTimeRangeFilter();
      _calculateStatistics();

      UIUtils.showToast(
        'Success',
        'Test deleted successfully',
        type: ToastificationType.success,
      );
    } catch (e) {
      UIUtils.showToast(
        'Error',
        'Failed to delete test: $e',
        type: ToastificationType.error,
      );
    }
  }

  /// Clear all history với confirmation
  Future<void> clearAllHistory() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('confirm_clear_title'.tr),
        content: Text('confirm_clear_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _storage.clearAllHistory();
        await loadHistory(); // Reload after clear
        UIUtils.showToast(
          'Success',
          'All history cleared',
          type: ToastificationType.success,
        );
      } catch (e) {
        UIUtils.showToast(
          'Error',
          'Failed to clear history: $e',
          type: ToastificationType.error,
        );
      }
    }
  }

  /// Get data for chart based on time range
  List<double> getChartData() {
    // Aggregate speeds by time bucket
    if (filteredResults.isEmpty) {
      return [];
    }

    // Simple implementation: return avg speed for each test
    return filteredResults.map((r) => r.avgSpeed).toList();
  }

  /// Get chart labels based on time range
  List<String> getChartLabels() {
    if (filteredResults.isEmpty) {
      return [];
    }

    // Simple implementation: return test numbers
    return filteredResults
        .asMap()
        .entries
        .map((e) => '#${e.key + 1}')
        .toList();
  }

  /// Export history data to CSV and share
  Future<void> exportData() async {
    try {
      if (allResults.isEmpty) {
        UIUtils.showToast(
          'info'.tr,
          'export_no_data'.tr,
          type: ToastificationType.info,
        );
        return;
      }

      Logger.i('📤 Starting export of ${allResults.length} tests...');

      // Generate CSV content
      final csvContent = _generateCSV();
      Logger.i('CSV Preview:\n${csvContent.substring(0, csvContent.length > 500 ? 500 : csvContent.length)}...');

      // Create filename with timestamp
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'wifi_test_history_$timestamp.csv';

      // Get temporary directory (no permission needed)
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';

      // Write CSV to file
      final file = File(filePath);
      await file.writeAsString(csvContent);
      Logger.i('✅ File created: $filePath');

      // Share file using share_plus (user can choose where to save)
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'text/csv')],
        subject: 'WiFi Test History Export',
        text: 'Exported ${allResults.length} WiFi stress test results',
      );

      Logger.i('✅ Export completed successfully');
      UIUtils.showToast(
        'success'.tr,
        'export_success'.trParams({'count': '${allResults.length}', 'file': filename}),
        type: ToastificationType.success,
      );
    } catch (e) {
      Logger.i('❌ Export failed: $e');
      UIUtils.showToast(
        'error'.tr,
        'export_failed'.trParams({'error': e.toString()}),
        type: ToastificationType.error,
      );
    }
  }

  /// Generate CSV content from test results
  String _generateCSV() {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('ID,Start Time,End Time,Duration (s),Status,Avg Speed (Mbps),Peak Speed (Mbps),Min Speed (Mbps),Median Speed (Mbps),Downloaded (MB),Download Count,SSID,Signal (dBm),Frequency,IP Address');

    // CSV Rows
    for (final result in allResults) {
      final downloadedMB = (result.totalDownloadedBytes / (1024 * 1024)).toStringAsFixed(2);
      final durationSeconds = result.endTime != null ? result.endTime!.difference(result.startTime).inSeconds : 0;

      buffer.write('${result.id},');
      buffer.write('${_formatDateTimeForCSV(result.startTime)},');
      buffer.write('${result.endTime != null ? _formatDateTimeForCSV(result.endTime!) : ""},');
      buffer.write('$durationSeconds,');
      buffer.write('${result.status},');
      buffer.write('${result.avgSpeed.toStringAsFixed(2)},');
      buffer.write('${result.peakSpeed.toStringAsFixed(2)},');
      buffer.write('${result.minSpeed.toStringAsFixed(2)},');
      buffer.write('${result.medianSpeed.toStringAsFixed(2)},');
      buffer.write('$downloadedMB,');
      buffer.write('${result.downloadCount},');
      buffer.write('${result.networkInfo?.ssid ?? ""},');
      buffer.write('${result.networkInfo?.signalStrength ?? ""},');
      buffer.write('${result.networkInfo?.frequency ?? ""},');
      buffer.write(result.networkInfo?.ipAddress ?? "");
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Format DateTime for CSV (ISO 8601)
  String _formatDateTimeForCSV(DateTime dateTime) {
    return dateTime.toIso8601String();
  }

  @override
  void onClose() {
    // KHÔNG close shared singleton storage
    // Storage sẽ được giữ mở cho StressorController và các controllers khác
    Logger.i('HistoryController.onClose() - storage kept open');
    super.onClose();
  }
}
