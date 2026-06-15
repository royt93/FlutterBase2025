// Widget tests for VipScreen — the host's VIP redeem / watch-ad UI.
//
// These render the real screen with a real (mock-prefs-backed) VipManager
// injected through `AdManager().debugVipManager`, wrapped in a GetMaterialApp
// so GetX `.tr` translations resolve. They lock down the user-visible contract
// of the stacking feature:
//
//   - inactive state shows the redeem + watch-ad surfaces
//   - active state shows the active hero + the entries list
//   - the watch-ad section stays VISIBLE while VIP is active (so a VIP can
//     watch an ad to EXTEND) — the key behavioural change
//   - the fixed `REWARDED_VIP` entry renders a friendly name, not a masked key
//   - typing a key reveals the activate/clear affordances
//
// NOTE: the screen runs repeating animations + periodic timers, so we never
// call pumpAndSettle(); we pump fixed durations and unmount the screen at the
// end of each test so its timers are cancelled in dispose().

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:applovin_admob_sdk/src/utils/ad_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/vip/vip_keys.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/vip/vip_screen.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Track the injected manager so we can dispose its expiry timer in tearDown
  // (an undisposed Timer would fail the test with "a Timer is still pending").
  VipManager? mgr;

  Future<VipManager> vipWith(Map<String, Duration> grants) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AdPreferences.getInstance();
    final m = VipManager(prefs);
    await m.revokeAll();
    await m.load();
    for (final e in grants.entries) {
      await m.addVip(key: e.key, duration: e.value);
    }
    return m;
  }

  Future<void> pumpVip(WidgetTester tester) async {
    // Tall viewport so the whole ListView (hero → redeem → watch-ad → entries →
    // buy → footer) is laid out — otherwise lower sections are never built and
    // find.text() can't see them.
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('vi', 'VN'),
        fallbackLocale: const Locale('en', 'US'),
        home: const VipScreen(),
      ),
    );
    // Let the staggered entrance animation play (no pumpAndSettle — the shimmer
    // / pulse controllers repeat forever).
    await tester.pump(const Duration(milliseconds: 1200));
  }

  // Tear down INSIDE the test body (before the FakeAsync zone closes): unmount
  // the screen so its periodic timers/controllers are cancelled, then dispose
  // the manager so its one-shot expiry timer is cancelled too. Doing this in
  // tearDown() would be too late — the "timer still pending" check runs when the
  // body completes.
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

  testWidgets('inactive: shows inactive status + redeem + watch-ad sections',
      (tester) async {
    AdManager().debugVipManager = mgr = await vipWith({});
    await pumpVip(tester);

    expect(find.text('VIP đang kích hoạt'), findsNothing);
    expect(find.text('Chưa kích hoạt VIP'), findsOneWidget);
    expect(find.text('Nhập mã VIP'), findsOneWidget);
    expect(find.text('Xem quảng cáo → VIP miễn phí'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('active: shows active hero + the entries list', (tester) async {
    AdManager().debugVipManager =
        mgr = await vipWith({'MYKEY1234': const Duration(days: 5)});
    await pumpVip(tester);

    expect(find.text('VIP đang kích hoạt'), findsOneWidget);
    expect(find.text('Chưa kích hoạt VIP'), findsNothing);
    // Entries header "Mã đang hoạt động (1)".
    expect(find.textContaining('Mã đang hoạt động'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('watch-ad section stays visible while VIP is ACTIVE',
      (tester) async {
    AdManager().debugVipManager =
        mgr = await vipWith({'ACTIVEKEY': const Duration(days: 1)});
    await pumpVip(tester);

    // Both the active hero AND the watch-ad CTA are present — a VIP can still
    // watch an ad to extend (the behaviour the stacking feature unlocked).
    expect(find.text('VIP đang kích hoạt'), findsOneWidget);
    expect(find.text('Xem quảng cáo → VIP miễn phí'), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets('REWARDED_VIP entry renders a friendly name, not a masked key',
      (tester) async {
    AdManager().debugVipManager = mgr =
        await vipWith({'REWARDED_VIP': const Duration(days: 3)});
    await pumpVip(tester);

    expect(find.text('Phần thưởng xem quảng cáo'), findsOneWidget);
    // The raw/masked key must NOT be shown for the reward entry.
    expect(find.textContaining('REW*'), findsNothing);

    await disposeScreen(tester);
  });

  testWidgets('typing a key reveals the clear + activate affordances',
      (tester) async {
    AdManager().debugVipManager = mgr = await vipWith({});
    await pumpVip(tester);

    // No clear icon before typing.
    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), 'somekey');
    await tester.pump();

    expect(find.byIcon(Icons.clear), findsOneWidget);
    // Activate button label is the uppercased translation.
    expect(find.text('Kích hoạt'.toUpperCase()), findsOneWidget);

    await disposeScreen(tester);
  });

  testWidgets(
      'integration: redeeming the REAL key twice STACKS the window to ~60 days',
      (tester) async {
    AdManager().debugVipManager = mgr = await vipWith({});
    await pumpVip(tester);

    final realKey = kVipKeyMap.keys.first; // 30-day key, already normalised

    Future<void> redeemOnce() async {
      await tester.enterText(find.byType(TextField), realKey);
      await tester.pump();
      await tester.tap(find.text('Kích hoạt'.toUpperCase()));
      await tester.pump(); // kick off redeem (verifying dialog)
      await tester.pump(const Duration(milliseconds: 600)); // validator + pops
      // Success dialog → confirm.
      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300)); // confetti timer
    }

    // First redemption → ~30 days.
    await redeemOnce();
    expect(mgr!.isActive, isTrue);
    final afterFirst = mgr!.expiresAt!.difference(DateTime.now()).inDays;
    expect(afterFirst, inInclusiveRange(29, 30));
    expect(mgr!.entries.length, 1);

    // Second redemption of the SAME key → stacks to ~60 days (one entry).
    await redeemOnce();
    final afterSecond = mgr!.expiresAt!.difference(DateTime.now()).inDays;
    expect(afterSecond, inInclusiveRange(59, 60),
        reason: 'a second redeem of the same key must add +30d, not reset');
    expect(mgr!.entries.length, 1, reason: 'same key stays a single entry');

    await disposeScreen(tester);
  });
}
