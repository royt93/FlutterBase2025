import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';

import '../controllers/history_controller.dart';
import 'widgets/summary_stats_card.dart';
import 'widgets/timeline_item.dart';
import 'widgets/history_chart.dart';
import 'test_detail_screen.dart';

/// Màn hình History & Statistics
class HistoryScreen extends AdScreen {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends AdScreenState<HistoryScreen> {
  static const String _tag = 'HistoryScreen';
  late final HistoryController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(HistoryController());
  }

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
      body: Column(
        children: [
          buildBanner(), // Banner Ad
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
                                return TimelineItem(
                                  result: result,
                                  onTap: () {
                                    SafeLogger.d(_tag, '▶️ ACTION timelineItem tap → id=${result.id}, startTime=${result.startTime}');
                                    Get.to(() => TestDetailScreen(result: result));
                                  },
                                );
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
            SafeLogger.d(_tag, '▶️ ACTION changeTimeRange → ${newSelection.first} (was ${controller.selectedTimeRange.value})');
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
