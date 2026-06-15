/// Vietnamese translations
const Map<String, String> viVN = {
  // App Title
  'app_title': 'FastNet Speed Test',

  // Splash
  'splash_ads_notice': 'Lưu ý: ứng dụng có thể hiển thị quảng cáo',

  // VIP — watch ad → 3 days (rewarded + interstitial fallback)
  'vip_watch_ad_title': 'Xem quảng cáo → VIP miễn phí',
  'vip_watch_ad_subtitle': 'Xem 1 quảng cáo ngắn để nhận ngay 3 ngày VIP miễn phí.',
  'vip_watch_ad_badge_free': 'MIỄN PHÍ',
  'vip_watch_ad_button': 'Xem quảng cáo',
  'vip_watch_ad_success': '🎉 Đã nhận 3 ngày VIP!',
  'vip_watch_ad_failed': 'Không tải được quảng cáo — vui lòng thử lại sau.',

  // VIP — buy section (placeholders, IAP chưa wire)
  'vip_buy_title': 'Mua gói VIP',
  'vip_buy_30d': 'VIP 30 ngày',
  'vip_buy_90d': 'VIP 90 ngày',
  'vip_buy_1y': 'VIP 1 năm',
  'vip_buy_lifetime': 'VIP trọn đời',
  'vip_buy_locked': 'SẮP CÓ',
  'vip_restore_locked': 'Khôi phục mua hàng — sắp có',

  // Info Dialog
  'info_dialog_title': 'Thông tin ứng dụng',
  'info_dialog_content':
      'Ứng dụng kiểm tra sức chịu tải Wi-Fi bằng cách tải file song song liên tục.\n'
      '⚠️ Lưu ý: Sử dụng lượng lớn dữ liệu mạng!',
  'close_button': 'Đóng',

  // Status
  'status_ready': 'SẴN SÀNG KIỂM TRA',
  'status_testing': 'ĐANG KIỂM TRA WI-FI - Lượt tải:',
  'collecting_data': 'Đang thu thập dữ liệu tốc độ...',

  // Metrics
  'connections_label': 'Số kết nối:',
  'current_speed': 'Tốc độ hiện tại',
  'average_speed': 'Tốc độ trung bình',
  'running_time': 'Thời gian chạy',
  'data_downloaded': 'Dữ liệu đã tải',

  // Buttons
  'start_test': 'BẮT ĐẦU KIỂM TRA',
  'stop_test': 'DỪNG KIỂM TRA',

  // Language Selector
  'select_language': 'Chọn ngôn ngữ',
  'language_vietnamese': 'Tiếng Việt',
  'language_english': 'English',

  // Warning Dialog
  'warning_title': '⚠️ Cảnh báo',
  'warning_message': 'Ứng dụng sẽ sử dụng lượng lớn dữ liệu mạng. Bạn có chắc muốn tiếp tục?',
  'cancel': 'Hủy bỏ',
  'continue': 'Tiếp tục',
  'no_internet': 'Thiết bị của bạn không kết nối internet',

  // History & Statistics
  'history_title': 'Thống kê & Lịch sử',
  'filter_title': 'Lọc',
  'total_tests': 'Tổng số lần test',
  'best_speed': 'Tốc độ tốt nhất',
  'avg_speed': 'Tốc độ TB',
  'min_speed': 'Tốc độ thấp nhất',
  'avg_duration': 'Thời lượng TB',
  'success_rate': 'Tỷ lệ thành công',
  'chart_day': 'Ngày',
  'chart_week': 'Tuần',
  'chart_month': 'Tháng',
  'chart_all': 'Tất cả',
  'today': 'Hôm nay',
  'yesterday': 'Hôm qua',
  'test_number': 'Test #',
  'export_data': 'Xuất dữ liệu',
  'clear_history': 'Xóa lịch sử',
  'confirm_clear_title': 'Xóa toàn bộ lịch sử?',
  'confirm_clear_message': 'Hành động này sẽ xóa vĩnh viễn tất cả lịch sử test. Không thể hoàn tác.',
  'delete': 'Xóa',

  // Test Detail
  'test_detail_title': 'Chi tiết Test',
  'performance_stats': 'Thống kê hiệu suất',
  'peak_speed': 'Tốc độ đỉnh',
  'median_speed': 'Tốc độ trung vị',
  'test_info': 'Thông tin Test',
  'started': 'Bắt đầu',
  'ended': 'Kết thúc',
  'duration': 'Thời lượng',
  'status': 'Trạng thái',
  'status_completed': 'Hoàn thành',
  'status_failed': 'Thất bại',
  'status_stopped': 'Đã dừng',
  'status_interrupted': 'Bị gián đoạn',
  'network_info': 'Thông tin mạng',
  'ssid': 'Tên mạng',
  'signal': 'Tín hiệu',
  'frequency': 'Tần số',
  'channel': 'Kênh',
  'ip_address': 'Địa chỉ IP',
  'signal_excellent': 'Xuất sắc',
  'signal_good': 'Tốt',
  'signal_fair': 'Trung bình',
  'signal_poor': 'Yếu',
  'speed_over_time': 'Tốc độ theo thời gian',
  'speed_chart': 'Biểu đồ tốc độ',
  'data_points': '@count điểm',
  'share': 'Chia sẻ',
  'retest': 'Test lại',
  'recent_tests': 'Các test gần đây',
  'download_count': 'Số lần tải',
  'confirm_delete_test': 'Bạn có chắc chắn muốn xóa test này?',

  // Empty States
  'no_history': 'Chưa có lịch sử test',
  'no_history_message': 'Chạy test đầu tiên để xem kết quả tại đây',
  'ad_not_ready': 'Quảng cáo chưa sẵn sàng — vui lòng chờ và thử lại sau.',
  'loading': 'Đang tải…',
  'no_data': 'Không có dữ liệu',

  // Filters
  'date_range': 'Khoảng thời gian',
  'speed_range': 'Khoảng tốc độ',
  'filter_status': 'Trạng thái',
  'filter_all': 'Tất cả',
  'filter_completed': 'Hoàn thành',
  'filter_failed': 'Thất bại',
  'reset': 'Đặt lại',
  'apply': 'Áp dụng',

  // Export
  'export_no_data': 'Không có dữ liệu để xuất',
  'export_success': 'Đã xuất @count tests vào @file',
  'export_failed': 'Xuất thất bại: @error',

  // Common
  'info': 'Thông tin',
  'error': 'Lỗi',
  'success': 'Thành công',

  // Consent dialog (auto-shown ~1s sau splash; nguồn: ConsentDialogStrings)
  'consent_title': 'Quảng cáo cá nhân hoá',
  'consent_message':
      'Ứng dụng hiển thị quảng cáo để duy trì miễn phí. Nếu bạn đồng ý, '
          'chúng tôi sẽ hiển thị quảng cáo phù hợp với sở thích của bạn '
          'thay vì quảng cáo chung. Bạn có thể thay đổi bất cứ lúc nào trong Cài đặt.',
  'consent_allow': 'Đồng ý',
  'consent_reject': 'Từ chối',
  'consent_privacy_label': 'Chính sách bảo mật',

  // VIP — màn hình quản lý
  'vip_status_active': 'VIP đang kích hoạt',
  'vip_status_inactive': 'Chưa kích hoạt VIP',
  'vip_status_inactive_tagline':
      'Trải nghiệm hoàn toàn không quảng cáo với gói VIP.',
  'vip_expires_at': 'Hiệu lực đến @date',
  'vip_remaining_days': 'Còn @days ngày',
  'vip_remaining_hours': 'Còn @hours giờ',
  'vip_remaining_extra_hours': 'thêm @hours giờ',
  'vip_redeem_title': 'Nhập mã VIP',
  'vip_redeem_subtitle':
      'Nhập mã kích hoạt để mở khoá trải nghiệm không quảng cáo.',
  'vip_key_hint': 'Nhập mã kích hoạt của bạn',
  'vip_activate_button': 'Kích hoạt',
  'vip_active_entries': 'Mã đang hoạt động (@count)',
  'vip_revoke': 'Thu hồi',
  'vip_revoke_all': 'Thu hồi tất cả',
  'vip_revoke_confirm': 'Bạn có chắc muốn thu hồi mã VIP này?',
  'vip_revoke_all_confirm':
      'Bạn có chắc muốn thu hồi toàn bộ mã VIP đang hoạt động?',
  'vip_no_entries': 'Chưa có mã VIP nào đang hoạt động.',
  'vip_first_install': 'Quà tặng cài đặt mới',
  'vip_legacy_device': 'Thiết bị QA',
  'vip_enter_key_first': 'Vui lòng nhập mã trước khi kích hoạt.',
  'vip_sdk_not_ready': 'SDK quảng cáo chưa sẵn sàng. Vui lòng thử lại sau.',
  'vip_privacy_policy': 'Chính sách bảo mật & điều khoản',

  // VIP dialog (Cupertino — SDK redeem flow)
  'vip_verifying_title': 'Đang xác thực',
  'vip_verifying_message': 'Vui lòng chờ trong giây lát…',
  'vip_success_title': 'Kích hoạt thành công',
  'vip_success_message': 'VIP của bạn có hiệu lực đến @until.',
  'vip_failed_title': 'Mã không hợp lệ',
  'vip_failed_message': 'Mã VIP bạn nhập không đúng hoặc đã hết hạn.',
  'vip_network_error': 'Lỗi mạng — vui lòng thử lại.',
  'vip_confirm': 'OK',
};
