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
  static const AppLovinConfig appLovin = AppLovinConfig(
    sdkKey:
        'e75FnQfS9XTTqM1Kne69U7PW_MBgAnGQTFvtwVVui6kRPKs5L7ws9twr5IQWwVfzPKZ5pF2IfDa7lguMgGlCyt',
    bannerId: '55145203d74b7bb0',
    interstitialId: 'f8c4de38486cdb76',
    appOpenId: '9309d90308be99c1',
    rewardedId: 'e50710c6caa75a33',
  );

  // ─── AdMob (fallback / swap-ready) ────────────────────────────────────
  // The App ID is wired in `android/app/src/main/AndroidManifest.xml`
  // as `com.google.android.gms.ads.APPLICATION_ID` meta-data — production
  // value `ca-app-pub-3612191981543807~9731053733`.
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
