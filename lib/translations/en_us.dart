/// English translations
const Map<String, String> enUS = {
  // App Title
  'app_title': 'FastNet Speed Test',

  // Splash
  'splash_ads_notice': 'Please note: this action may show ads',

  // VIP — watch ad → 3 days (rewarded + interstitial fallback)
  'vip_watch_ad_title': 'Watch ad → free VIP',
  'vip_watch_ad_subtitle':
      'Watch a short ad and unlock 3 days of VIP for free.',
  'vip_watch_ad_badge_free': 'FREE',
  'vip_watch_ad_button': 'Watch ad',
  'vip_watch_ad_success': '🎉 Earned 3 days of VIP!',
  'vip_watch_ad_failed': 'Couldn\'t load ad — please try again later.',

  // VIP — buy section (placeholders, IAP not wired yet)
  'vip_buy_title': 'Buy VIP plan',
  'vip_buy_30d': '30-day VIP',
  'vip_buy_90d': '90-day VIP',
  'vip_buy_1y': '1-year VIP',
  'vip_buy_lifetime': 'Lifetime VIP',
  'vip_buy_locked': 'COMING SOON',
  'vip_restore_locked': 'Restore purchase — coming soon',

  // Info Dialog
  'info_dialog_title': 'App Information',
  'info_dialog_content':
      'This app tests Wi-Fi load capacity by continuously downloading files in parallel.\n'
          '⚠️ Warning: Uses large amounts of network data!',
  'close_button': 'Close',

  // Status
  'status_ready': 'READY TO TEST',
  'status_testing': 'TESTING WI-FI - Downloads:',
  'collecting_data': 'Collecting speed data...',

  // Metrics
  'connections_label': 'Connections:',
  'current_speed': 'Current Speed',
  'average_speed': 'Average Speed',
  'running_time': 'Running Time',
  'data_downloaded': 'Data Downloaded',
  'upload_speed': 'Upload',
  'latency': 'Latency',
  'jitter': 'Jitter',
  'dns_time': 'DNS',
  'packet_loss': 'Packet Loss',
  'quality_score': 'Quality',

  // Duration presets
  'duration_label': 'Duration:',
  'duration_unlimited': 'Unlimited',
  'duration_custom': 'Custom',
  'duration_custom_title': 'Custom Duration',
  'duration_custom_hint': 'Enter seconds',

  // Alerts
  'alert_label': 'Alert when speed below:',
  'alert_off': 'Off',
  'alert_low_speed': '⚠️ Low speed: @speed Mbps (below @threshold Mbps)',
  'test_complete': '✅ Complete',
  'test_complete_msg': 'Test finished — avg @speed Mbps',

  // Comparison
  'comparison_title': 'Comparison',
  'compare_tooltip': 'Compare tests',
  'compare_button': 'Compare',
  'compare_selected': '@count selected',
  'cmp_avg_speed': 'Avg Speed',
  'cmp_peak_speed': 'Peak Speed',
  'cmp_min_speed': 'Min Speed',
  'cmp_median_speed': 'Median',
  'cmp_duration': 'Duration',
  'cmp_downloaded': 'Downloaded',

  // Buttons
  'start_test': 'START TEST',
  'stop_test': 'STOP TEST',

  // Language Selector
  'select_language': 'Select Language',
  'language_vietnamese': 'Tiếng Việt',
  'language_english': 'English',

  // Warning Dialog
  'warning_title': '⚠️ Warning',
  'warning_message':
      'This app will use a large amount of network data. Are you sure you want to continue?',
  'cancel': 'Cancel',
  'ok': 'OK',
  'continue': 'Continue',
  'no_internet': 'It looks like your device is not connected to the internet',

  // History & Statistics
  'history_title': 'Statistics & History',
  'filter_title': 'Filter',
  'total_tests': 'Total Tests',
  'best_speed': 'Best Speed',
  'avg_speed': 'Avg Speed',
  'min_speed': 'Min Speed',
  'avg_duration': 'Avg Duration',
  'success_rate': 'Success Rate',
  'chart_day': 'Day',
  'chart_week': 'Week',
  'chart_month': 'Month',
  'chart_all': 'All',
  'today': 'Today',
  'yesterday': 'Yesterday',
  'test_number': 'Test #',
  'export_data': 'Export Data',
  'clear_history': 'Clear History',
  'confirm_clear_title': 'Clear All History?',
  'confirm_clear_message':
      'This will permanently delete all test history. This action cannot be undone.',
  'delete': 'Delete',

  // Test Detail
  'test_detail_title': 'Test Details',
  'performance_stats': 'Performance Statistics',
  'peak_speed': 'Peak Speed',
  'median_speed': 'Median Speed',
  'test_info': 'Test Information',
  'started': 'Started',
  'ended': 'Ended',
  'duration': 'Duration',
  'status': 'Status',
  'status_completed': 'Completed',
  'status_failed': 'Failed',
  'status_stopped': 'Stopped',
  'status_interrupted': 'Interrupted',
  'network_info': 'Network Information',
  'ssid': 'SSID',
  'signal': 'Signal',
  'frequency': 'Frequency',
  'channel': 'Channel',
  'ip_address': 'IP Address',
  'signal_excellent': 'Excellent',
  'signal_good': 'Good',
  'signal_fair': 'Fair',
  'signal_poor': 'Poor',
  'speed_over_time': 'Speed Over Time',
  'speed_chart': 'Speed Chart',
  'data_points': '@count data points',
  'share': 'Share',
  'retest': 'Retest',
  'recent_tests': 'Recent Tests',
  'download_count': 'Download Count',
  'confirm_delete_test': 'Are you sure you want to delete this test?',

  // Empty States
  'no_history': 'No test history yet',
  'no_history_message': 'Run your first test to see results here',
  'ad_not_ready': 'Ad not ready yet — please wait a moment and try again.',
  'loading': 'Loading…',
  'no_data': 'No data available',

  // Filters
  'date_range': 'Date Range',
  'speed_range': 'Speed Range',
  'filter_status': 'Status',
  'filter_all': 'All',
  'filter_completed': 'Completed',
  'filter_failed': 'Failed',
  'reset': 'Reset',
  'apply': 'Apply',

  // Export
  'export_no_data': 'No data to export',
  'export_choose_format': 'Choose export format',
  'export_success': 'Exported @count tests to @file',
  'export_failed': 'Export failed: @error',

  // Common
  'info': 'Info',
  'error': 'Error',
  'success': 'Success',

  // Consent dialog (auto-shown ~1s after splash; sourced via ConsentDialogStrings)
  'consent_title': 'Privacy & Personalized Ads',
  'consent_message':
      'This app shows ads to keep it free. With your permission, we '
          'can show ads matched to your interests instead of generic ones. '
          'You can change this anytime in Settings.',
  'consent_allow': 'Allow personalized ads',
  'consent_reject': 'No thanks',
  'consent_privacy_label': 'Privacy Policy',

  // VIP — management screen
  'vip_status_active': 'VIP active',
  'vip_status_inactive': 'No active VIP',
  'vip_status_inactive_tagline': 'Enjoy an ad-free experience with a VIP key.',
  'vip_expires_at': 'Valid until @date',
  'vip_remaining_days': '@days days left',
  'vip_remaining_hours': '@hours hours left',
  'vip_remaining_extra_hours': '+@hours h',
  'vip_redeem_title': 'Redeem VIP key',
  'vip_redeem_subtitle':
      'Enter your activation key to unlock an ad-free session.',
  'vip_key_hint': 'Enter your activation key',
  'vip_activate_button': 'Activate',
  'vip_active_entries': 'Active keys (@count)',
  'vip_revoke': 'Revoke',
  'vip_revoke_all': 'Revoke all',
  'vip_revoke_confirm': 'Are you sure you want to revoke this VIP key?',
  'vip_revoke_all_confirm':
      'Are you sure you want to revoke all active VIP keys?',
  'vip_no_entries': 'No active VIP keys yet.',
  'vip_first_install': 'New install gift',
  'vip_legacy_device': 'QA device',
  'vip_reward_entry': 'Watch-ad reward',
  'vip_enter_key_first': 'Please enter a key first.',
  'vip_sdk_not_ready': 'Ad SDK is not ready. Please try again later.',
  'vip_privacy_policy': 'Privacy Policy & Terms',

  // VIP dialog (Cupertino — SDK redeem flow)
  'vip_verifying_title': 'Verifying',
  'vip_verifying_message': 'Please wait a moment…',
  'vip_success_title': 'VIP Activated',
  'vip_success_message': 'VIP active until @until.',
  'vip_failed_title': 'Invalid Key',
  'vip_failed_message': 'The VIP key you entered is invalid or expired.',
  'vip_key_already_used': 'This key has already been used on this device.',
  'vip_network_error': 'Network error — please try again.',
  'vip_confirm': 'OK',
  // Network dashboard (Wave 5)
  'net_dashboard_title': 'Network Info',
  'net_refresh': 'Refresh',
  'net_connection': 'Connection',
  'net_connection_type': 'Type',
  'net_link_speed': 'Link speed',
  'net_addresses': 'Addresses',
  'net_local_ip': 'Local IP',
  'net_public_ip': 'Public IP',
  'net_gateway': 'Gateway',
  'net_bssid': 'Router MAC (BSSID)',
  'net_vendor': 'Vendor',
  'net_dns': 'DNS',
  'net_copied': 'Copied to clipboard',
  'net_type_wifi': 'WiFi',
  'net_type_mobile': 'Mobile',
  'net_type_ethernet': 'Ethernet',
  'net_type_unknown': 'Unknown',
  // Packet pie (Wave 5)
  'packet_pie_title': 'Packet success / loss',
  'packet_success': 'Successful',
  // Heatmap (Wave 5)
  'heatmap_title': 'Performance heatmap',
  'heatmap_empty': 'No test data yet',
  'heatmap_legend': 'Speed over time per test (low → high)',
};
