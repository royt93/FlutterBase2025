import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/network_dashboard_controller.dart';
import '../models/network_dashboard.dart';
import '../../../util/ui_utils.dart';

/// Màn hình Network Dashboard — thông tin mạng hiện tại đầy đủ (live).
/// SSID/signal/freq/channel/link speed + local/public IP + gateway + DNS + BSSID.
class NetworkDashboardScreen extends StatelessWidget {
  const NetworkDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Field-initializer Get.put (đồng bộ) thay cho late, giống History/Comparison.
    final controller = Get.put(NetworkDashboardController());
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'net_dashboard_title'.tr,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Obx(() => IconButton(
                icon: controller.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'net_refresh'.tr,
                onPressed: controller.isLoading.value ? null : controller.refreshData,
              )),
        ],
      ),
      body: Obx(() {
        final data = controller.data.value;
        if (data == null && controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data == null) {
          return Center(
            child: Text('no_data'.tr, style: const TextStyle(color: Colors.white54)),
          );
        }
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _connectionCard(data),
              _addressesCard(data),
              _dnsCard(data),
            ],
          ),
        );
      }),
    );
  }

  Widget _connectionCard(NetworkDashboard d) {
    return _card(
      icon: Icons.wifi,
      iconColor: Colors.green,
      title: 'net_connection'.tr,
      rows: [
        _RowData('ssid'.tr, d.ssid ?? 'N/A'),
        _RowData('net_connection_type'.tr, d.connectionType),
        if (d.signalStrength != null)
          _RowData('signal'.tr,
              '${d.signalStrength} dBm${d.signalQuality != null ? ' (${('signal_${d.signalQuality}').tr})' : ''}'),
        if (d.frequency != null) _RowData('frequency'.tr, d.frequency ?? 'N/A'),
        if (d.channel != null) _RowData('channel'.tr, '${d.channel}'),
        if (d.linkSpeedMbps != null) _RowData('net_link_speed'.tr, '${d.linkSpeedMbps} Mbps'),
      ],
    );
  }

  Widget _addressesCard(NetworkDashboard d) {
    return _card(
      icon: Icons.lan,
      iconColor: Colors.blue,
      title: 'net_addresses'.tr,
      rows: [
        _RowData('net_local_ip'.tr, d.localIp ?? 'N/A', copyable: d.localIp != null),
        _RowData('net_public_ip'.tr, d.publicIp ?? 'N/A', copyable: d.publicIp != null),
        _RowData('net_gateway'.tr, d.gatewayIp ?? 'N/A', copyable: d.gatewayIp != null),
        _RowData('net_bssid'.tr, d.bssid ?? 'N/A', copyable: d.bssid != null),
      ],
    );
  }

  Widget _dnsCard(NetworkDashboard d) {
    final dns = d.dnsServers;
    return _card(
      icon: Icons.dns,
      iconColor: Colors.orange,
      title: 'net_dns'.tr,
      rows: dns.isEmpty
          ? [_RowData('net_dns'.tr, 'N/A')]
          : List.generate(
              dns.length,
              (i) => _RowData('DNS ${i + 1}', dns[i], copyable: true),
            ),
    );
  }

  Widget _card({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<_RowData> rows,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _infoRow(rows[i]),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(_RowData r) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(r.label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  r.value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (r.copyable) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.value));
                    UIUtils.showToast('net_dashboard_title'.tr, 'net_copied'.tr);
                  },
                  child: const Icon(Icons.copy, size: 14, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Dữ liệu một dòng info trong dashboard.
class _RowData {
  final String label;
  final String value;
  final bool copyable;
  const _RowData(this.label, this.value, {this.copyable = false});
}
