//https://admob.google.com/v2/apps/9731053733/adunits/list
import 'package:flutter/foundation.dart';

// ═══════ PROVIDER SWITCH ═══════
const bool kIsEnableAdmob = false; // false = AppLovin MAX, true = AdMob

// ═══════ APPLOVIN CONFIG ═══════
const String kAppLovinSdkKey = "e75FnQfS9XTTqM1Kne69U7PW_MBgAnGQTFvtwVVui6kRPKs5L7ws9twr5IQWwVfzPKZ5pF2IfDa7lguMgGlCyt";
const String kAppLovinBannerId = "55145203d74b7bb0";
const String kAppLovinInterstitialId = "f8c4de38486cdb76";
const String kAppLovinAppOpenId = "9309d90308be99c1";
const String kAppLovinRewardedId = ""; // Chưa có trong Android native config

// ═══════ ADMOB CONFIG (auto-switch debug/release) ═══════
const String kAdmobBannerAdUnitId =
    kDebugMode ? "ca-app-pub-3940256099942544/6300978111" : "ca-app-pub-3612191981543807/1996868091";
const String kAdmobInterstitialAdUnitId =
    kDebugMode ? "ca-app-pub-3940256099942544/1033173712" : "ca-app-pub-3612191981543807/3270405402";
const String kAdmobAppOpenAdUnitId =
    kDebugMode ? "ca-app-pub-3940256099942544/9257395921" : "ca-app-pub-3612191981543807/9683786426";
const String kAdmobRewardedAdUnitId = kDebugMode ? "ca-app-pub-3940256099942544/5224354917" : "";

// ═══════ TEST DEVICES (AdMob dùng GAID hash) ═══════
const List<String> kTestDeviceIds = [
  "884670AFCACDD337E31BB6153C6DB17E", // Vsmart Iris
  "05B522309BC31052952BBCD5CC85ACA8", // Vivo Z9
];

// ═══════ VIP MEMBER GAID LIST ═══════
// Các thiết bị trong list => KHÔNG thấy quảng cáo
const List<String> kVipDeviceGaids = [
  "9ad0127d-04be-4b6c-937a-ca3ed7f650b9", //vsmart iris
  "9b6499f2-d4de-4b9e-afdf-ac2a2b127fb1", //ss a50
  "c09b2f04-e145-490c-96f9-dab620074104", //oppo f7
  "c228aa08-bedd-4e6e-adf6-ae5e95bcddae", //vivo v15
  "46259467-0ac4-49c4-a3a2-7d3db3ce4bda", //tecno spark 20 pro+
  "1b7c3e3f-c709-4e85-b26f-dd74c4df2ed7", //vivo 1906
  "adaa42e7-9cc6-4a8a-9c90-d4d87842b12c", //tecno spark go 2024
  "f5a36a2f-5add-4315-a171-0f8dddab78c7", //ss s20u
  "6fbb207d-341d-470d-bb0a-dddd79522b32", //ss a52
  "40f8e222-cf7a-4fac-9913-6809c4c58817", //mipad 5
  "932099db-d381-4b52-98dc-5b96ba8b4ff4", //oppo reno 2f
  "a1339bd1-8ea5-47cd-969e-4b5721b576b7", //redmi note 8+
  "3f2f21d2-85eb-451b-a1a5-003668ba6345", //zte blade
  "261f772c-6a10-499c-b896-4157d9ab6a25", //ss a11
  "460d3f5c-bbe2-46fc-841a-6381e3c93864", //redmi95
  "49606ad7-5cee-43b4-9af7-8aa274644737", //redmi note 13 pro
  "6cf051f8-83f5-43b7-8c1a-1d20ae1f8d93", //redmi pad pro
  "da10cb05-5458-42df-ba86-630732356b35", //vivo z9
  "8f6ccdc1-08fd-4611-abdf-f48bdadb5581", //tablet lenovo
  "66e652de-79ef-4889-8074-9b482fd81b5a", //redmi a3
  "4ed22dd8-e8fb-442e-a75e-081a3d977957", //ss s24u
];
