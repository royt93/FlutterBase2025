import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import '../models/network_quality.dart';
import '../models/test_result.dart';
import '../models/test_statistics.dart';
import '../services/test_history_storage.dart';
import '../../../util/ui_utils.dart';
import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';

/// Định dạng export lịch sử test.
enum ExportFormat {
  csv('csv', 'text/csv'),
  json('json', 'application/json'),
  pdf('pdf', 'application/pdf');

  final String ext;
  final String mime;
  const ExportFormat(this.ext, this.mime);
}


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

  // --- Comparison multi-select ---
  final RxBool selectionMode = false.obs;
  final RxList<String> selectedIds = <String>[].obs;

  /// Bật/tắt chế độ chọn nhiều để so sánh; tắt thì clear lựa chọn.
  void toggleSelectionMode() {
    selectionMode.value = !selectionMode.value;
    if (!selectionMode.value) selectedIds.clear();
  }

  /// Toggle chọn 1 test theo id.
  void toggleSelect(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  /// Các test đang được chọn (giữ thứ tự theo allResults — mới nhất trước).
  List<TestResult> get selectedResults =>
      allResults.where((r) => selectedIds.contains(r.id)).toList();

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
      SafeLogger.d('Log', '📖 Loading history...');
      SafeLogger.d('Log', '📦 Storage box null? ${_storage.box == null}');
      SafeLogger.d('Log', '📦 Storage total count: ${_storage.totalCount}');

      // Load all results
      final results = _storage.getAllResults();
      SafeLogger.d('Log', '📊 Loaded ${results.length} results from storage');

      allResults.value = results;

      // Apply current filter
      _applyTimeRangeFilter();
      SafeLogger.d('Log', '🔍 After filter: ${filteredResults.length} results');

      // Calculate statistics
      _calculateStatistics();
      SafeLogger.d('Log', '✅ History loaded successfully');
    } catch (e) {
      SafeLogger.d('Log', '❌ Failed to load history: $e');
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
      selectedIds.remove(id);
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

  /// Mở picker chọn định dạng (CSV / JSON / PDF) rồi export.
  Future<void> exportData() async {
    if (allResults.isEmpty) {
      UIUtils.showToast(
        'info'.tr,
        'export_no_data'.tr,
        type: ToastificationType.info,
      );
      return;
    }
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'export_choose_format'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _exportTile(Icons.table_chart, 'CSV', ExportFormat.csv),
            _exportTile(Icons.data_object, 'JSON', ExportFormat.json),
            _exportTile(Icons.picture_as_pdf, 'PDF', ExportFormat.pdf),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _exportTile(IconData icon, String label, ExportFormat fmt) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3B82F6)),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Get.back();
        _exportAs(fmt);
      },
    );
  }

  /// Sinh file theo định dạng + share.
  Future<void> _exportAs(ExportFormat fmt) async {
    try {
      SafeLogger.d('Log', '📤 Export ${allResults.length} tests as ${fmt.ext}...');
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final filename = 'wifi_test_history_$timestamp.${fmt.ext}';

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);

      if (fmt == ExportFormat.csv) {
        await file.writeAsString(generateCsv());
      } else if (fmt == ExportFormat.json) {
        await file.writeAsString(generateJson());
      } else {
        await file.writeAsBytes(await generatePdf());
      }
      SafeLogger.d('Log', '✅ File created: $filePath');

      await Share.shareXFiles(
        [XFile(filePath, mimeType: fmt.mime)],
        subject: 'WiFi Test History Export',
        text: 'Exported ${allResults.length} WiFi stress test results',
      );

      UIUtils.showToast(
        'success'.tr,
        'export_success'.trParams({'count': '${allResults.length}', 'file': filename}),
        type: ToastificationType.success,
      );
    } catch (e) {
      SafeLogger.d('Log', '❌ Export failed: $e');
      UIUtils.showToast(
        'error'.tr,
        'export_failed'.trParams({'error': e.toString()}),
        type: ToastificationType.error,
      );
    }
  }

  /// JSON: mảng các test (kèm latency/jitter qua toJson).
  String generateJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(allResults.map((r) => r.toJson()).toList());
  }

  /// PDF: bảng tóm tắt các lần test.
  Future<Uint8List> generatePdf() async {
    final doc = pw.Document();
    final headers = [
      '#',
      'Time',
      'Avg',
      'Peak',
      'Latency',
      'Jitter',
      'Grade',
      'Status',
    ];
    final rows = <List<String>>[];
    for (int i = 0; i < allResults.length; i++) {
      final r = allResults[i];
      final q = NetworkQuality.compute(
        avgSpeed: r.avgSpeed,
        latencyMs: r.avgLatencyMs,
        jitterMs: r.jitterMs,
      );
      rows.add([
        '${i + 1}',
        _formatDateTimeForCSV(r.startTime),
        r.avgSpeed.toStringAsFixed(1),
        r.peakSpeed.toStringAsFixed(1),
        r.latencyFormatted,
        r.jitterFormatted,
        '${q.grade} (${q.score})',
        r.status,
      ]);
    }
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'WiFi Test History (${allResults.length})',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Generate CSV content from test results
  String generateCsv() {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln('ID,Start Time,End Time,Duration (s),Status,Avg Speed (Mbps),Peak Speed (Mbps),Min Speed (Mbps),Median Speed (Mbps),Upload (Mbps),Latency (ms),Jitter (ms),DNS (ms),Packet Loss (%),Quality,Downloaded (MB),Download Count,SSID,Signal (dBm),Frequency,IP Address');

    // CSV Rows
    for (final result in allResults) {
      final downloadedMB = (result.totalDownloadedBytes / (1024 * 1024)).toStringAsFixed(2);
      final end = result.endTime;
      final durationSeconds = end != null ? end.difference(result.startTime).inSeconds : 0;
      final q = NetworkQuality.compute(
        avgSpeed: result.avgSpeed,
        latencyMs: result.avgLatencyMs,
        jitterMs: result.jitterMs,
      );

      buffer.write('${result.id},');
      buffer.write('${_formatDateTimeForCSV(result.startTime)},');
      buffer.write('${end != null ? _formatDateTimeForCSV(end) : ""},');
      buffer.write('$durationSeconds,');
      buffer.write('${result.status},');
      buffer.write('${result.avgSpeed.toStringAsFixed(2)},');
      buffer.write('${result.peakSpeed.toStringAsFixed(2)},');
      buffer.write('${result.minSpeed.toStringAsFixed(2)},');
      buffer.write('${result.medianSpeed.toStringAsFixed(2)},');
      buffer.write('${result.uploadMbps?.toStringAsFixed(2) ?? ""},');
      buffer.write('${result.avgLatencyMs?.toStringAsFixed(1) ?? ""},');
      buffer.write('${result.jitterMs?.toStringAsFixed(1) ?? ""},');
      buffer.write('${result.dnsMs?.toStringAsFixed(1) ?? ""},');
      buffer.write('${result.packetLossPct?.toStringAsFixed(1) ?? ""},');
      buffer.write('${q.grade} (${q.score}),');
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
    SafeLogger.d('Log', 'HistoryController.onClose() - storage kept open');
    super.onClose();
  }
}
