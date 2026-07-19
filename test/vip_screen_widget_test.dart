// Widget tests for the host's VipScreen — now a thin wrapper around the SDK's
// shared VipRedeemScreen (T18). The redeem UI itself (inactive/active
// rendering, watch-ad visibility, entry masking, stacking behaviour) is
// already covered at the SDK level in
// packages/ad_sdk/test/vip_redeem_screen_test.dart and
// packages/ad_sdk/test/signed_vip_key_test.dart — duplicating those here would
// just re-test the SDK through an extra layer of indirection.
//
// What's actually host-specific and worth locking down:
//   - VipScreen builds without error and renders a VipRedeemScreen under the
//     hood, wired with the host's public key.
//   - The host's localized strings (GetX `.tr`) actually resolve — not raw
//     translation keys — proving the string plumbing didn't drift.
//   - kVipPublicKeyBase64 in vip_keys.dart truly matches the private key that
//     signed kVipDemoKeys — the one thing that can silently break if someone
//     regenerates one but not the other. One real end-to-end redeem proves it.
//
// NOTE: VipRedeemScreen runs repeating animations + periodic timers, so we
// never call pumpAndSettle(); pump fixed durations and unmount at the end of
// each test so timers are cancelled in dispose().

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:applovin_admob_sdk/src/utils/ad_preferences.dart';
import 'package:applovin_admob_sdk/src/vip/_vip_entries_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/vip/vip_keys.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/vip/vip_screen.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory fake so VIP tests don't hit the real (unavailable-in-test)
/// flutter_secure_storage platform channel — it hangs instead of throwing,
/// same pattern as packages/ad_sdk/test/vip_manager_robustness_test.dart.
class _FakeVipEntriesStore extends VipEntriesStore {
  _FakeVipEntriesStore(super.prefs);
  String? _raw;
  @override
  Future<String?> getRaw() async => _raw;
  @override
  Future<void> setRaw(String json) async => _raw = json;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VipManager? mgr;

  Future<VipManager> freshVip() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AdPreferences.getInstance();
    final m = VipManager(prefs, vipEntriesStore: _FakeVipEntriesStore(prefs));
    await m.revokeAll();
    await m.load();
    return m;
  }

  Future<void> pumpVip(WidgetTester tester) async {
    // Tall viewport so the whole ListView (hero → redeem → watch-ad → entries →
    // buy → footer) is laid out.
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('vi', 'VN'),
        fallbackLocale: const Locale('en', 'US'),
        home: VipScreen(),
      ),
    );
    // Let the staggered entrance animation play (no pumpAndSettle — shimmer /
    // pulse controllers repeat forever).
    await tester.pump(const Duration(milliseconds: 1200));
  }

  // Unmount before the test body ends so periodic timers/controllers are
  // cancelled in dispose() while still inside the test's FakeAsync zone.
  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    mgr?.dispose();
    mgr = null;
  }

  tearDown(() {
    AdManager().debugVipManager = null;
    mgr?.dispose();
    mgr = null;
  });

  testWidgets('builds without error and renders the SDK VipRedeemScreen',
      (tester) async {
    AdManager().debugVipManager = mgr = await freshVip();
    await pumpVip(tester);

    expect(find.byType(VipRedeemScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeScreen(tester);
  });

  testWidgets('wires localized strings, not raw translation keys',
      (tester) async {
    AdManager().debugVipManager = mgr = await freshVip();
    await pumpVip(tester);

    // Vietnamese locale is active — the vi_vn.dart translation, not the raw
    // key, should be on screen.
    expect(find.text('Chưa kích hoạt VIP'), findsOneWidget);
    expect(find.text('vip_status_inactive'), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets(
      'kVipPublicKeyBase64 matches the key that signed kVipDemoKeys (real redeem)',
      (tester) async {
    AdManager().debugVipManager = mgr = await freshVip();
    await pumpVip(tester);

    final demoKey = kVipDemoKeys.values.first; // "1 ngày" signed demo key
    await tester.enterText(find.byType(TextField), demoKey);
    await tester.pump();
    await tester.tap(find.text('Kích hoạt'.toUpperCase()));
    await tester.pump(); // kick off redeem
    await tester.pump(const Duration(milliseconds: 300)); // async verify

    expect(mgr!.isActive, isTrue,
        reason: 'kVipPublicKeyBase64 must verify kVipDemoKeys signatures');

    await disposeScreen(tester);
  });
}
