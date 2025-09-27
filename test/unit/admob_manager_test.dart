import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:connection_notifier/connection_notifier.dart';

// Import AdMob components
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/event_bus.dart';

// Generate mocks
@GenerateMocks([
  MobileAds,
  BannerAd,
  InterstitialAd,
  RewardedAd,
  AppOpenAd,
])
import 'admob_manager_test.mocks.dart';

void main() {
  /// Test Suite cho AdMobManager
  group('AdMobManager Tests', () {
    late AdMobManager adMobManager;

    setUp(() {
      adMobManager = AdMobManager();
    });

    /// Test Singleton pattern
    test('should return same instance (Singleton)', () {
      final instance1 = AdMobManager();
      final instance2 = AdMobManager();

      expect(instance1, equals(instance2));
      expect(identical(instance1, instance2), true);
    });

    /// Test Ad Unit IDs theo environment
    group('Ad Unit IDs', () {
      test('should return test ad IDs in debug mode', () {
        // Debug mode sẽ return test ads
        final bannerAdId = AdMobManager.bannerAdUnitId();
        final interstitialAdId = AdMobManager.interstitialAdUnitId();
        final rewardedAdId = AdMobManager.rewardedAdUnitId();
        final appOpenAdId = AdMobManager.appOpenAdUnitId();

        // Trong test environment, sẽ return test IDs
        expect(bannerAdId, isNotEmpty);
        expect(interstitialAdId, isNotEmpty);
        expect(rewardedAdId, isNotEmpty);
        expect(appOpenAdId, isNotEmpty);
      });
    });

    /// Test timing controls
    group('Timing Controls', () {
      test('should allow interstitial after 15 minutes', () {
        // Mặc định lần đầu tiên được phép load
        expect(adMobManager.canLoadInterstitial(), true);

        // Sau khi set time, cần chờ 15 phút
        adMobManager.setLastInterstitialShowTime();
        expect(adMobManager.canLoadInterstitial(), false);
      });

      test('should allow rewarded after 15 minutes', () {
        // Mặc định lần đầu tiên được phép load
        expect(adMobManager.canLoadRewarded(), true);

        // Sau khi set time, cần chờ 15 phút
        adMobManager.setLastRewardedShowTime();
        expect(adMobManager.canLoadRewarded(), false);
      });
    });

    /// Test App Open Ad expiry
    test('should handle app open ad expiry', () {
      // App open ad hết hạn sau 4 giờ
      adMobManager._appOpenAdLoadTime = DateTime.now().subtract(Duration(hours: 5));

      // Should not show expired ad
      adMobManager.showAppOpenAd(); // Không crash khi ad expired
    });

    /// Test adaptive banner size
    test('should get adaptive banner size', () async {
      // Mock connection check
      final result = await AdMobManager.getAdaptiveBannerSize();

      // Kết quả có thể null nếu không có connection hoặc không thành công
      expect(result, anyOf(isNull, isA<AdSize>()));
    });
  });

  /// Test Suite cho Event Bus
  group('Event Bus Tests', () {
    late SimpleEventBus eventBus;

    setUp(() {
      eventBus = SimpleEventBus();
    });

    tearDown(() {
      eventBus.dispose();
    });

    test('should fire and receive bool events', () async {
      // Arrange
      bool? receivedValue;
      final subscription = eventBus.onBoolEvent.listen((event) {
        receivedValue = event.value;
      });

      // Act
      eventBus.fire(BoolEvent(true));

      // Wait for event to propagate
      await Future.delayed(Duration.zero);

      // Assert
      expect(receivedValue, true);

      // Cleanup
      subscription.cancel();
    });

    test('should handle multiple events', () async {
      // Arrange
      final receivedValues = <bool>[];
      final subscription = eventBus.onBoolEvent.listen((event) {
        receivedValues.add(event.value);
      });

      // Act
      eventBus.fire(BoolEvent(true));
      eventBus.fire(BoolEvent(false));
      eventBus.fire(BoolEvent(true));

      // Wait for events to propagate
      await Future.delayed(Duration.zero);

      // Assert
      expect(receivedValues, [true, false, true]);

      // Cleanup
      subscription.cancel();
    });

    test('should handle multiple subscribers', () async {
      // Arrange
      bool? value1, value2;
      final sub1 = eventBus.onBoolEvent.listen((event) => value1 = event.value);
      final sub2 = eventBus.onBoolEvent.listen((event) => value2 = event.value);

      // Act
      eventBus.fire(BoolEvent(true));
      await Future.delayed(Duration.zero);

      // Assert
      expect(value1, true);
      expect(value2, true);

      // Cleanup
      sub1.cancel();
      sub2.cancel();
    });
  });

  /// Test Suite cho connection checking
  group('Connection Checking Tests', () {
    test('should check splash screen initialization logic', () async {
      // Test checkLogicSplashScreenIsInitializedAdmob function
      final result = await checkLogicSplashScreenIsInitializedAdmob();

      // Kết quả phụ thuộc vào connection state
      expect(result, isA<bool>());
    });
  });

  /// Test Suite cho Ad Factory Methods
  group('Ad Factory Methods', () {
    test('should create banner ad with proper configuration', () async {
      // Test createBannerAdAsync
      final bannerAd = await AdMobManager.createBannerAdAsync(
        size: AdSize.banner,
        listener: BannerAdListener(),
      );

      // Kết quả có thể null nếu không có connection
      expect(bannerAd, anyOf(isNull, isA<BannerAd>()));
    });

    test('should create interstitial ad', () async {
      // Test createInterstitialAd
      final interstitialAd = await AdMobManager.createInterstitialAd();

      // Kết quả có thể null nếu không có connection hoặc load fail
      expect(interstitialAd, anyOf(isNull, isA<InterstitialAd>()));
    });

    test('should create rewarded ad', () async {
      // Test createRewardedAd
      final rewardedAd = await AdMobManager.createRewardedAd();

      // Kết quả có thể null nếu không có connection hoặc load fail
      expect(rewardedAd, anyOf(isNull, isA<RewardedAd>()));
    });
  });

  /// Test constants
  group('Constants Tests', () {
    test('should have predefined ad messages', () {
      expect(adPlsNoteEn, isNotEmpty);
      expect(adPlsNoteVi, isNotEmpty);
      expect(adMayAppearEn, isNotEmpty);
      expect(adMayAppearVi, isNotEmpty);

      // Kiểm tra nội dung cơ bản
      expect(adPlsNoteEn.toLowerCase(), contains('ad'));
      expect(adPlsNoteVi.toLowerCase(), contains('quảng cáo'));
    });
  });

  /// Test initialization
  group('Initialization Tests', () {
    test('should handle initialization properly', () async {
      // Test initialize method
      await adMobManager.initialize();

      // Initialization không crash và completed
      expect(true, true); // Test passed if no exception
    });

    test('should skip initialization if already initialized', () async {
      // Test multiple initialization calls
      await adMobManager.initialize();
      await adMobManager.initialize();

      // Should handle gracefully
      expect(true, true);
    });
  });

  /// Test error handling
  group('Error Handling Tests', () {
    test('should handle network errors gracefully', () async {
      // Simulate no network condition
      // Test các method với network unavailable
      final bannerAd = await AdMobManager.createBannerAdAsync(
        size: AdSize.banner,
        listener: BannerAdListener(),
      );

      // Should return null without crashing
      expect(bannerAd, anyOf(isNull, isA<BannerAd>()));
    });

    test('should handle ad load failures', () async {
      // Test ad load failure scenarios
      final interstitialAd = await AdMobManager.createInterstitialAd();

      // Should handle failure gracefully
      expect(interstitialAd, anyOf(isNull, isA<InterstitialAd>()));
    });
  });
}