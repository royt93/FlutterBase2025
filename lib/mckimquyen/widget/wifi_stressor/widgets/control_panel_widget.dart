import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../stressor_controller.dart';
import 'metric_tile_widget.dart';
import 'animated_number_text.dart';

/// Widget hiển thị control panel với connection selector và metrics
class ControlPanelWidget extends StatelessWidget {
  final bool isRunning;
  final StressorController controller;

  const ControlPanelWidget({
    super.key,
    required this.isRunning,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Connection count selector
            _buildConnectionSelector(),
            const SizedBox(height: 16),
            // Duration preset selector (ẩn khi đang chạy)
            if (!isRunning) _buildDurationSelector(context),
            // Metrics display khi đang chạy
            if (isRunning) ..._buildMetrics(),
          ],
        ),
      ),
    );
  }

  /// Tạo connection selector với performance tối ưu
  Widget _buildConnectionSelector() {
    const connectionOptions = [1, 5, 10, 15, 30, 50, 100, 200, 500];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'connections_label'.tr,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        DropdownButton<int>(
          value: controller.parallelDownloads.value,
          items: connectionOptions
              .map((val) => DropdownMenuItem<int>(
                    value: val,
                    child: Text(
                      '$val',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: isRunning
              ? null
              : (val) {
                  if (val != null) {
                    controller.parallelDownloads.value = val;
                  }
                },
        ),
      ],
    );
  }

  /// Preset thời lượng test. `null` = không giới hạn (dừng thủ công).
  static const _durationPresets = <int?>[null, 15, 30, 60, 300];

  /// Selector preset thời lượng — chips chọn nhanh + 1 chip "custom".
  Widget _buildDurationSelector(BuildContext context) {
    return Obx(() {
      final sel = controller.selectedDurationSec.value;
      final isCustom = sel != null && !_durationPresets.contains(sel);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'duration_label'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _durationPresets)
                ChoiceChip(
                  label: Text(p == null ? 'duration_unlimited'.tr : _fmtPreset(p)),
                  selected: sel == p,
                  onSelected: (_) => controller.selectedDurationSec.value = p,
                ),
              ChoiceChip(
                label: Text(isCustom ? _fmtPreset(sel) : 'duration_custom'.tr),
                selected: isCustom,
                onSelected: (_) => _showCustomDurationDialog(context),
              ),
            ],
          ),
        ],
      );
    });
  }

  /// Dialog nhập thời lượng custom (giây). Quản lý controller cục bộ + dispose.
  void _showCustomDurationDialog(BuildContext context) {
    final current = controller.selectedDurationSec.value;
    final textCtrl = TextEditingController(
      text: current == null ? '' : '$current',
    );
    Get.defaultDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      contentPadding: const EdgeInsets.all(16),
      title: 'duration_custom_title'.tr,
      content: TextField(
        controller: textCtrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: 'duration_custom_hint'.tr,
          suffixText: 's',
          border: const OutlineInputBorder(),
        ),
      ),
      textCancel: 'cancel'.tr,
      textConfirm: 'ok'.tr,
      onConfirm: () {
        final v = int.tryParse(textCtrl.text.trim());
        if (v != null && v > 0) {
          controller.selectedDurationSec.value = v;
        }
        Get.back();
      },
    ).then((_) => textCtrl.dispose());
  }

  /// Định dạng preset: 15s / 1m / 1m30s.
  String _fmtPreset(int sec) {
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60;
    final s = sec % 60;
    return s == 0 ? '${m}m' : '${m}m${s}s';
  }

  /// Đồng hồ m:ss.
  String _fmtClock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Tạo danh sách metrics với performance tối ưu
  List<Widget> _buildMetrics() {
    return [
      Obx(() => MetricTileWidget(
        icon: Icons.speed,
        title: 'current_speed'.tr,
        valueWidget: AnimatedNumberText(
          value: controller.speedMbps.value,
          decimals: 2,
          suffix: ' Mbps',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
      Obx(() => MetricTileWidget(
        icon: Icons.speed,
        title: 'average_speed'.tr,
        valueWidget: AnimatedNumberText(
          value: controller.totalSpeedMbps.value,
          decimals: 2,
          suffix: ' Mbps',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
      Obx(() {
        final elapsed = _fmtClock(controller.testDuration.value);
        final limit = controller.selectedDurationSec.value;
        // Có preset → hiển thị "đã chạy / tổng" để user thấy còn bao lâu.
        final value = limit == null
            ? elapsed
            : '$elapsed / ${_fmtClock(Duration(seconds: limit))}';
        return MetricTileWidget.text(
          icon: Icons.timer,
          title: 'running_time'.tr,
          value: value,
        );
      }),
      Obx(() => MetricTileWidget(
        icon: Icons.data_usage,
        title: 'data_downloaded'.tr,
        valueWidget: AnimatedNumberText(
          value: controller.totalBytesIncludingProgress.value / (1024 * 1024),
          decimals: 2,
          suffix: ' MB',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      )),
    ];
  }
}
