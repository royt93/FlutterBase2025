import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../stressor_controller.dart';
import 'metric_tile_widget.dart';
import 'animated_number_text.dart';

/// Widget hiển thị control panel với connection selector và metrics.
/// Dark slate (đồng bộ design system History/Comparison): card #1E293B,
/// accent #3B82F6, text trắng.
class ControlPanelWidget extends StatelessWidget {
  final bool isRunning;
  final StressorController controller;

  const ControlPanelWidget({
    super.key,
    required this.isRunning,
    required this.controller,
  });

  // Design system
  static const _card = Color(0xFF1E293B);
  static const _chipBg = Color(0xFF0F172A);
  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
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
            color: Colors.white,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _chipBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButton<int>(
            value: controller.parallelDownloads.value,
            dropdownColor: _card,
            iconEnabledColor: Colors.white70,
            iconDisabledColor: Colors.white30,
            borderRadius: BorderRadius.circular(12),
            underline: const SizedBox.shrink(),
            isDense: true,
            items: connectionOptions
                .map((val) => DropdownMenuItem<int>(
                      value: val,
                      child: Text(
                        '$val',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _durationPresets)
                _durationChip(
                  label: p == null ? 'duration_unlimited'.tr : _fmtPreset(p),
                  selected: sel == p,
                  onTap: () => controller.selectedDurationSec.value = p,
                ),
              _durationChip(
                label: isCustom ? _fmtPreset(sel) : 'duration_custom'.tr,
                selected: isCustom,
                onTap: () => _showCustomDurationDialog(context),
              ),
            ],
          ),
        ],
      );
    });
  }

  /// Chip preset dark: selected = accent xanh đặc + trắng; còn lại = nền tối,
  /// viền mờ, text trắng70.
  Widget _durationChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _accent : _chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _accent : Colors.white.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
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

  /// Metrics khi đang chạy. KHÔNG lặp "current speed" — gauge hero đã hiển thị.
  List<Widget> _buildMetrics() {
    const valueStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    return [
      Obx(() => MetricTileWidget(
            icon: Icons.speed,
            title: 'average_speed'.tr,
            valueWidget: AnimatedNumberText(
              value: controller.totalSpeedMbps.value,
              decimals: 2,
              suffix: ' Mbps',
              style: valueStyle,
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
              style: valueStyle,
            ),
          )),
    ];
  }
}
