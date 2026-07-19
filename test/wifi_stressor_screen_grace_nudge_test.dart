// Widget tests cho audit finding 1.2 (grace-nudge listener race,
// wifi_stressor_screen.dart:67): `AdManager().vip` là null cho tới khi SDK
// init xong; SplashScreen có hard-cap timer 8s có thể navigate sang màn hình
// này trước khi init hoàn tất → nếu initState() attach listener 1 lần duy
// nhất lúc vip còn null, tính năng nhắc VIP sắp hết hạn bị tắt âm thầm cả
// session. Fix: subscribe `AdManager().initRevision` để retry-attach mỗi khi
// SDK (re)init xong.
//
// NOTE: VipManager đọc wall-clock DateTime.now() thật, không phải fake-async
// clock của testWidgets. Để tránh chờ elapsed time thật, chọn
// graceNudgeThreshold rất lớn (999 ngày) sao cho addVip() với duration ngắn
// đã thoả điều kiện "due" ngay lập tức, đồng bộ (xem
// VipManager._refreshActive() luôn gọi _refreshGraceNudge() làm bước cuối).
//
// Không pumpAndSettle() — StressorHomePage/AdScreenState có timer/animation
// lặp; pump duration cố định rồi unmount trước khi test kết thúc.

import 'package:applovin_admob_sdk/applovin_admob_sdk.dart';
import 'package:applovin_admob_sdk/src/utils/ad_preferences.dart';
import 'package:applovin_admob_sdk/src/vip/_vip_entries_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:saigonphantomlabs/mckimquyen/widget/wifi_stressor/wifi_stressor_screen.dart';
import 'package:saigonphantomlabs/translations/app_translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _graceNudgeMessageVi =
    'VIP của bạn sắp hết hạn — gia hạn ngay trước khi quảng cáo quay lại.';

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

  Future<VipManager> freshVip({required Duration graceNudgeThreshold}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AdPreferences.getInstance();
    final m = VipManager(
      prefs,
      graceNudgeThreshold: graceNudgeThreshold,
      vipEntriesStore: _FakeVipEntriesStore(prefs),
    );
    await m.revokeAll();
    await m.load();
    return m;
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('vi', 'VN'),
        fallbackLocale: const Locale('en', 'US'),
        home: const WiFiStressorApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

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

  testWidgets(
      'vip == null at initState (splash race) does not crash the screen',
      (tester) async {
    AdManager().debugVipManager = null;

    await pumpScreen(tester);

    expect(tester.takeException(), isNull);

    await disposeScreen(tester);
  });

  testWidgets(
      'attaches grace-nudge listener via initRevision after vip becomes ready, and fires the SnackBar',
      (tester) async {
    // 1. Screen builds while vip is still null (simulates splash navigating
    //    away before AdManager().initialize() completes).
    AdManager().debugVipManager = null;
    await pumpScreen(tester);
    expect(tester.takeException(), isNull);

    // 2. SDK init "completes" — vip instance becomes available and
    //    AdManager bumps initRevision, same as the real initialize() path.
    mgr = await freshVip(graceNudgeThreshold: const Duration(days: 999));
    AdManager().debugVipManager = mgr;
    AdManager().initRevision.value = AdManager().initRevision.value + 1;
    await tester.pump();

    // 3. Grant a short-lived VIP window. graceNudgeThreshold (999d) already
    //    exceeds the remaining duration, so `graceNudgeDueListenable` flips
    //    to true synchronously inside addVip() — no real-time wait needed.
    //    The attached listener fires synchronously too, shows the SnackBar,
    //    then calls acknowledgeGraceNudge() which flips the flag back to
    //    false in the same call stack — so we only assert the SnackBar
    //    itself, not the (already-consumed) notifier value.
    await mgr!.addVip(key: 'SOON', duration: const Duration(minutes: 5));

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_graceNudgeMessageVi), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeScreen(tester);
  });

  testWidgets(
      'genuine AdManager re-init (dispose old vip, swap in new) while the '
      'screen is attached does not crash on removeListener against the '
      'disposed old graceNudgeDueListenable', (tester) async {
    // 1. Screen attaches to a first vip instance, same as a normal cold
    //    start completing init.
    final oldVip =
        await freshVip(graceNudgeThreshold: const Duration(days: 999));
    AdManager().debugVipManager = oldVip;
    await pumpScreen(tester);
    AdManager().initRevision.value = AdManager().initRevision.value + 1;
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 2. Mirror AdManager's real re-init path (ad_manager.dart:620-629):
    //    the previous VipManager is disposed before a fresh one is swapped
    //    in and initRevision bumped again — this is the exact stale-
    //    listener scenario VipManager.dispose() is written to be safe under.
    // Note: `ChangeNotifier.removeListener` is documented safe-after-dispose
    // in the currently pinned Flutter SDK (3.35.1), so this doesn't reproduce
    // a live crash — it's a regression guard against relying on that
    // SDK-version-specific guarantee (verified by temporarily restoring the
    // pre-fix dispose() during development; this test passed either way).
    oldVip.dispose();
    mgr = await freshVip(graceNudgeThreshold: const Duration(days: 999));
    AdManager().debugVipManager = mgr;
    AdManager().initRevision.value = AdManager().initRevision.value + 1;
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 3. New vip still works end-to-end after the swap.
    await mgr!.addVip(key: 'SOON2', duration: const Duration(minutes: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_graceNudgeMessageVi), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeScreen(tester);
  });
}
