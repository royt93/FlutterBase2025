import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../stressor_controller.dart';
import 'metric_tile_widget.dart';

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
        const Text(
          'Số kết nối:',
          style: TextStyle(
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

  /// Tạo danh sách metrics với performance tối ưu
  List<Widget> _buildMetrics() {
    return [
      Obx(() => MetricTileWidget(
        icon: Icons.speed,
        title: 'Tốc độ hiện tại',
        value: '${controller.speedMbps.value.toStringAsFixed(2)} Mbps',
      )),
      Obx(() => MetricTileWidget(
        icon: Icons.speed,
        title: 'Tốc độ trung bình',
        value: '${controller.totalSpeedMbps.value.toStringAsFixed(2)} Mbps',
      )),
      Obx(() => MetricTileWidget(
        icon: Icons.timer,
        title: 'Thời gian chạy',
        value: '${controller.testDuration.value.inMinutes}:'
            '${(controller.testDuration.value.inSeconds % 60).toString().padLeft(2, '0')}',
      )),
      Obx(() => MetricTileWidget(
        icon: Icons.data_usage,
        title: 'Dữ liệu đã tải',
        value: '${(controller.totalDownloadedBytes.value / (1024 * 1024)).toStringAsFixed(2)} MB',
      )),
    ];
  }
}
