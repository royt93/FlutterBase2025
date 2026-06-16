import 'package:get/get.dart';

import '../models/network_dashboard.dart';
import '../services/network_info_service.dart';

/// Controller cho Network Dashboard. Fetch snapshot mạng live (gồm public IP),
/// reactive qua GetX — không setState/late/force-null.
class NetworkDashboardController extends GetxController {
  final NetworkInfoService _service = NetworkInfoService();

  final Rx<NetworkDashboard?> data = Rx<NetworkDashboard?>(null);
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshData();
  }

  /// Tải lại toàn bộ thông tin mạng. Guard chống gọi chồng.
  Future<void> refreshData() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      data.value = await _service.getNetworkDashboard();
    } finally {
      isLoading.value = false;
    }
  }
}
