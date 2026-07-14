import 'dart:io';

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';

/// Centralised ad-related constants for the FastNet host app.
///
/// One single key per project (no per-flavor switch) — see
/// `doc/AD_PROMPT_FLUTTER.MD` Q25A.
///
/// Both `AppLovinConfig` and `AdMobConfig` are populated even though the
/// runtime provider is fixed to `AdProvider.appLovin` (Q5A): keeping both
/// sets non-null lets us swap providers by flipping a single line in
/// `AdConfig.provider` without re-touching this file.
class AdKey {
  AdKey._();

  // ─── AppLovin (active runtime) ────────────────────────────────────────
  // Source: AppLovin Dashboard → MAX → Account → Keys.
  static AppLovinConfig get appLovin {
    return Platform.isIOS ? appLovinIos : appLovinAndroid;
  }

  // Android units. These are the existing IDs that were already working on
  // Android before the iOS-specific unit IDs were provided.
  static const AppLovinConfig appLovinAndroid = AppLovinConfig(
    sdkKey:
        'e75FnQfS9XTTqM1Kne69U7PW_MBgAnGQTFvtwVVui6kRPKs5L7ws9twr5IQWwVfzPKZ5pF2IfDa7lguMgGlCyt',
    bannerId: '55145203d74b7bb0',
    interstitialId: 'f8c4de38486cdb76',
    appOpenId: '9309d90308be99c1',
    rewardedId: 'e50710c6caa75a33',
  );

  // iOS units for com.saigonphantomlabs.base.
  static const AppLovinConfig appLovinIos = AppLovinConfig(
    sdkKey:
        'e75FnQfS9XTTqM1Kne69U7PW_MBgAnGQTFvtwVVui6kRPKs5L7ws9twr5IQWwVfzPKZ5pF2IfDa7lguMgGlCyt',
    bannerId: 'e68fecfb83a971b0',
    interstitialId: 'a440723b64a3fcab',
    appOpenId: '2fb86ee58ecea62d',
    rewardedId: '37c26ff0ce531e75',
  );

  // ─── AdMob (fallback / swap-ready) ────────────────────────────────────
  // The App ID is wired in `android/app/src/main/AndroidManifest.xml`
  // (`com.google.android.gms.ads.APPLICATION_ID`) and `ios/Runner/Info.plist`
  // (`GADApplicationIdentifier`). Both currently hold Google's official TEST
  // App IDs (T32, 2026-07-14) — the old production value was duplicated
  // across both platforms, which is invalid (AdMob console issues a
  // distinct App ID per platform app entry). Replace with the real,
  // per-platform production App IDs from https://admob.google.com before
  // flipping `AdConfig.provider` to `AdProvider.adMob`.
  //
  // The ad unit IDs below are Google's public test IDs — safe to ship
  // because the runtime provider is `AdProvider.appLovin`, so AdMob is
  // never actually called. Replace with production unit IDs from
  // https://admob.google.com when you decide to swap providers.
  // TODO(host-app): replace with production AdMob ad unit IDs before
  //                 flipping `AdConfig.provider` to `AdProvider.adMob`.
  static const AdMobConfig adMob = AdMobConfig(
    bannerId: 'ca-app-pub-3940256099942544/6300978111',
    interstitialId: 'ca-app-pub-3940256099942544/1033173712',
    appOpenId: 'ca-app-pub-3940256099942544/9257395921',
    rewardedId: 'ca-app-pub-3940256099942544/5224354917',
  );

  // ─── Privacy / legal ──────────────────────────────────────────────────
  static const String privacyPolicyUrl =
      'https://loitp.notion.site/Term-Privacy-Policy-Disclaimer-319b1cd8783942fa8923d2a3c9bce60';
}
