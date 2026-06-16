import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/history_controller.dart';
import 'comparison_screen.dart';
import 'heatmap_screen.dart';
import 'test_detail_screen.dart';
import 'widgets/history_chart.dart';
import 'widgets/summary_stats_card.dart';
import 'widgets/timeline_item.dart';

/// Màn hình History & Statistics
class HistoryScreen extends AdScreen {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends AdScreenState<HistoryScreen> {
  static const String _tag = 'HistoryScreen';

  // Field initializer (chạy trước initState) thay cho `late` — Get.put trả
  // instance đồng bộ, giống pattern ở StressorHomePage.
  final HistoryController controller = Get.put(HistoryController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'history_title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_on),
            tooltip: 'heatmap_title'.tr,
            onPressed: () {
              SafeLogger.d(_tag, '▶️ ACTION openHeatmap');
              Get.to(() => const HeatmapScreen());
            },
          ),
          // Toggle chế độ chọn nhiều để so sánh
          Obx(() => IconButton(
                icon: Icon(controller.selectionMode.value ? Icons.close : Icons.compare_arrows),
                tooltip: 'compare_tooltip'.tr,
                onPressed: () {
                  SafeLogger.d(_tag, '▶️ ACTION toggleSelectionMode');
                  controller.toggleSelectionMode();
                },
              )),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'export_data'.tr,
            onPressed: () {
              SafeLogger.d(_tag, '▶️ ACTION exportData — requesting rewarded ad');
              showRewardedAd(onEarnedReward: (earned) {
                SafeLogger.d(_tag, '▶️ ACTION exportData — earned=$earned');
                if (earned) {
                  controller.exportData();
                }
                // else: SDK already showed TopToast automatically
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              SafeLogger.d(_tag, '▶️ ACTION popupMenu selected: $value');
              if (value == 'clear') {
                SafeLogger.d(_tag, '▶️ ACTION clearAllHistory');
                controller.clearAllHistory();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'clear_history'.tr,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildCompareBar(),
      body: Column(
        children: [
          // Banner edge-to-edge: bottom: false vì banner nằm trên cùng (dưới
          // AppBar), chỉ cần SafeArea ngang để né cutout/notch hai bên.
          SafeArea(
            top: false,
            bottom: false,
            child: buildBanner(),
          ), // Banner Ad
          Expanded(
            child: Obx(() {
              // Loading & Empty State
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                );
              }

              if (controller.allResults.isEmpty) {
                return _buildEmptyState();
              }

              // Main content - scrollable
              return SingleChildScrollView(
                physics: BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.only(bottom: 128),
                child: Column(
                  children: [
                    // Summary Stats Card
                    Obx(() {
                      final stats = controller.statistics.value;
                      if (stats == null) return const SizedBox();
                      return SummaryStatsCard(statistics: stats);
                    }),

                    // Time Range Selector
                    _buildTimeRangeSelector(controller),

                    // Chart
                    Obx(() {
                      return HistoryChart(results: controller.filteredResults.toList());
                    }),

                    // Timeline Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.history, color: Colors.white70, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'recent_tests'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Timeline List
                    Obx(() {
                      final grouped = controller.getGroupedResults();
                      if (grouped.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'no_data'.tr,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final dateKey = grouped.keys.elementAt(index);
                          final results = grouped[dateKey] ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: Text(
                                  dateKey,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Items for this date
                              ...results.map((result) {
                                return Obx(() {
                                  final selecting = controller.selectionMode.value;
                                  final selected = controller.selectedIds.contains(result.id);
                                  return TimelineItem(
                                    result: result,
                                    selectionMode: selecting,
                                    selected: selected,
                                    onTap: () {
                                      if (selecting) {
                                        controller.toggleSelect(result.id);
                                      } else {
                                        SafeLogger.d(_tag, '▶️ ACTION timelineItem tap → id=${result.id}');
                                        Get.to(() => TestDetailScreen(result: result));
                                      }
                                    },
                                  );
                                });
                              }),
                            ],
                          );
                        },
                      );
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            }),
          ), // Expanded
        ],
      ), // Column
    );
  }

  /// Thanh dưới hiện khi đang chọn để so sánh; bật "So sánh" khi chọn ≥ 2.
  Widget _buildCompareBar() {
    return Obx(() {
      if (!controller.selectionMode.value) return const SizedBox.shrink();
      final count = controller.selectedIds.length;
      final canCompare = count >= 2;
      return Container(
        color: const Color(0xFF1E293B),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'compare_selected'.trParams({'count': '$count'}),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                FilledButton.icon(
                  onPressed: canCompare
                      ? () {
                          SafeLogger.d(_tag, '▶️ ACTION compare → ${controller.selectedIds.length} tests');
                          Get.to(() => ComparisonScreen(results: controller.selectedResults));
                        }
                      : null,
                  icon: const Icon(Icons.compare_arrows),
                  label: Text('compare_button'.tr),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Build time range selector
  Widget _buildTimeRangeSelector(HistoryController controller) {
    return Container(
      width: Get.width,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() {
        final selected = controller.selectedTimeRange.value;
        return SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'day',
              label: Text('chart_day'.tr),
            ),
            ButtonSegment(
              value: 'week',
              label: Text('chart_week'.tr),
            ),
            ButtonSegment(
              value: 'month',
              label: Text('chart_month'.tr),
            ),
            ButtonSegment(
              value: 'all',
              label: Text('chart_all'.tr),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (Set<String> newSelection) {
            SafeLogger.d(
                _tag, '▶️ ACTION changeTimeRange → ${newSelection.first} (was ${controller.selectedTimeRange.value})');
            controller.changeTimeRange(newSelection.first);
          },
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF3B82F6);
                }
                return const Color(0xFF1E293B);
              },
            ),
            foregroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                return Colors.white;
              },
            ),
          ),
        );
      }),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'no_history'.tr,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'no_history_message'.tr,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
