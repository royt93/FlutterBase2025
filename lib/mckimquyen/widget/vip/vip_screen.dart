import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../common/const/ad_keys.dart';
import 'vip_keys.dart';

/// Host VIP screen — a thin wrapper over the SDK's reusable [VipRedeemScreen]
/// (T18). The whole UI lives in the SDK so the host and the SDK example render
/// the IDENTICAL screen; here we only inject localized strings (GetX `.tr`), the
/// signing public key, and the privacy-policy launcher.
class VipScreen extends StatelessWidget {
  static const String screenName = '/VipScreen';

  const VipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return VipRedeemScreen(
      publicKeyBase64: kVipPublicKeyBase64,
      onPrivacyPolicyTap: _openPrivacyPolicy,
      onPrivacyOptionsTap: () => AdManager().showPrivacyOptions(),
      strings: VipRedeemStrings(
        sdkNotReady: 'vip_sdk_not_ready'.tr,
        enterKeyFirst: 'vip_enter_key_first'.tr,
        successTitle: 'vip_success_title'.tr,
        keyAlreadyUsed: 'vip_key_already_used'.tr,
        failedMessage: 'vip_failed_message'.tr,
        watchAdSuccess: 'vip_watch_ad_success'.tr,
        watchAdFailed: 'vip_watch_ad_failed'.tr,
        revoke: 'vip_revoke'.tr,
        revokeConfirm: 'vip_revoke_confirm'.tr,
        revokeAll: 'vip_revoke_all'.tr,
        revokeAllConfirm: 'vip_revoke_all_confirm'.tr,
        cancel: 'cancel'.tr,
        delete: 'delete'.tr,
        error: 'error'.tr,
        statusActive: 'vip_status_active'.tr,
        statusInactive: 'vip_status_inactive'.tr,
        statusInactiveTagline: 'vip_status_inactive_tagline'.tr,
        redeemTitle: 'vip_redeem_title'.tr,
        redeemSubtitle: 'vip_redeem_subtitle'.tr,
        keyHint: 'vip_key_hint'.tr,
        activateButton: 'vip_activate_button'.tr,
        noEntries: 'vip_no_entries'.tr,
        firstInstall: 'vip_first_install'.tr,
        legacyDevice: 'vip_legacy_device'.tr,
        rewardEntry: 'vip_reward_entry'.tr,
        watchAdTitle: 'vip_watch_ad_title'.tr,
        watchAdBadgeFree: 'vip_watch_ad_badge_free'.tr,
        watchAdSubtitle: 'vip_watch_ad_subtitle'.tr,
        watchAdButton: 'vip_watch_ad_button'.tr,
        buyTitle: 'vip_buy_title'.tr,
        buy30d: 'vip_buy_30d'.tr,
        buy90d: 'vip_buy_90d'.tr,
        buy1y: 'vip_buy_1y'.tr,
        buyLifetime: 'vip_buy_lifetime'.tr,
        buyLocked: 'vip_buy_locked'.tr,
        restoreLocked: 'vip_restore_locked'.tr,
        privacyPolicy: 'vip_privacy_policy'.tr,
        privacyOptions: 'vip_privacy_options'.tr,
        expiresAt: (date) => 'vip_expires_at'.trParams({'date': date}),
        remainingDays: (days) =>
            'vip_remaining_days'.trParams({'days': '$days'}),
        remainingHours: (hours) =>
            'vip_remaining_hours'.trParams({'hours': '$hours'}),
        remainingExtraHours: (hours) =>
            'vip_remaining_extra_hours'.trParams({'hours': '$hours'}),
        activeEntries: (count) =>
            'vip_active_entries'.trParams({'count': '$count'}),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(AdKey.privacyPolicyUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
