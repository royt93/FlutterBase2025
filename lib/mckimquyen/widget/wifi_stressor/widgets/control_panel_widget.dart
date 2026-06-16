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
          if (!isRunning) const SizedBox(height: 16),
          if (!isRunning) _buildAlertSelector(),
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

  /// Ngưỡng cảnh báo tốc độ thấp (Mbps). 0 = tắt.
  static const _alertPresets = <int>[0, 5, 10, 20, 50];

  /// Selector ngưỡng cảnh báo realtime khi tốc độ tụt dưới mốc.
  Widget _buildAlertSelector() {
    return Obx(() {
      final sel = controller.alertThresholdMbps.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'alert_label'.tr,
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
              for (final p in _alertPresets)
                _durationChip(
                  label: p == 0 ? 'alert_off'.tr : '$p Mbps',
                  selected: sel == p,
                  onTap: () => controller.alertThresholdMbps.value = p,
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

  /// Dialog nhập thời lượng custom (giây). Dùng StatefulWidget để
  /// `TextEditingController` được dispose ĐÚNG vòng đời (trong State.dispose,
  /// sau khi widget unmount) — tránh assert `_dependents.isEmpty` do dispose
  /// controller khi TextField còn mounted.
  void _showCustomDurationDialog(BuildContext context) {
    Get.dialog(
      _CustomDurationDialog(
        initialSec: controller.selectedDurationSec.value,
        onSubmit: (v) => controller.selectedDurationSec.value = v,
      ),
    );
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
            icon: Icons.download,
            title: 'average_speed'.tr,
            valueWidget: AnimatedNumberText(
              value: controller.totalSpeedMbps.value,
              decimals: 2,
              suffix: ' Mbps',
              style: valueStyle,
            ),
          )),
      Obx(() {
        final u = controller.uploadMbps.value;
        return MetricTileWidget.text(
          icon: Icons.upload,
          title: 'upload_speed'.tr,
          value: u == null ? '—' : '${u.toStringAsFixed(1)} Mbps',
        );
      }),
      Obx(() {
        final l = controller.latencyMs.value;
        return MetricTileWidget.text(
          icon: Icons.network_ping,
          title: 'latency'.tr,
          value: l == null ? '—' : '${l.round()} ms',
        );
      }),
      Obx(() {
        final j = controller.jitterMs.value;
        return MetricTileWidget.text(
          icon: Icons.multiline_chart,
          title: 'jitter'.tr,
          value: j == null ? '—' : '${j.round()} ms',
        );
      }),
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

/// Dialog nhập thời lượng custom (giây) — StatefulWidget tự quản controller.
class _CustomDurationDialog extends StatefulWidget {
  final int? initialSec;
  final ValueChanged<int> onSubmit;

  const _CustomDurationDialog({required this.initialSec, required this.onSubmit});

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  TextEditingController? _textCtrl;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSec;
    _textCtrl = TextEditingController(text: init == null ? '' : '$init');
  }

  @override
  void dispose() {
    _textCtrl?.dispose();
    super.dispose();
  }

  void _submit() {
    final c = _textCtrl;
    if (c != null) {
      final v = int.tryParse(c.text.trim());
      if (v != null && v > 0) widget.onSubmit(v);
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final c = _textCtrl;
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        'duration_custom_title'.tr,
        style: const TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: Colors.white),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'duration_custom_hint'.tr,
          labelStyle: const TextStyle(color: Colors.white70),
          suffixText: 's',
          suffixStyle: const TextStyle(color: Colors.white70),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('cancel'.tr),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text('ok'.tr),
        ),
      ],
    );
  }
}
