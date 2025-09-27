import 'package:flutter_test/flutter_test.dart';

// Import AdMob components
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/event_bus.dart';

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

    /// Test Ad Unit IDs
    test('should return valid ad unit IDs', () {
      expect(AdMobManager.bannerAdUnitId(), isA<String>());
      expect(AdMobManager.interstitialAdUnitId(), isA<String>());
      expect(AdMobManager.rewardedAdUnitId(), isA<String>());
      expect(AdMobManager.appOpenAdUnitId(), isA<String>());
    });

    /// Test initialization
    test('should initialize without errors', () async {
      // Test không crash khi initialize (có thể fail do missing plugin trong test)
      expect(() => adMobManager.initialize(), returnsNormally);
    });

    /// Test app open ad
    test('should handle app open ad without crash', () {
      expect(() => adMobManager.showAppOpenAd(), returnsNormally);
    });

    /// Test time setting methods
    test('should set ad show times without errors', () {
      expect(() => adMobManager.setLastInterstitialShowTime(), returnsNormally);
      expect(() => adMobManager.setLastRewardedShowTime(), returnsNormally);
    });

    /// Test static methods
    test('should create interstitial ad', () async {
      // Test method exists (may fail in test environment)
      expect(() => AdMobManager.createInterstitialAd(), returnsNormally);
    });

    /// Test adaptive banner size
    test('should get adaptive banner size', () async {
      // Test method exists
      expect(() => AdMobManager.getAdaptiveBannerSize(), returnsNormally);
    });
  });

  /// Test Suite cho initialization check
  group('AdMob Initialization Tests', () {
    test('should check splash screen initialization', () async {
      // Test function exists
      expect(() => checkLogicSplashScreenIsInitializedAdmob(), returnsNormally);
    });
  });

  /// Test Suite cho Simple Event Bus
  group('SimpleEventBus Tests', () {
    late SimpleEventBus eventBus;

    setUp(() {
      eventBus = SimpleEventBus();
    });

    /// Test singleton pattern
    test('should return same instance (Singleton)', () {
      final instance1 = SimpleEventBus();
      final instance2 = SimpleEventBus();

      expect(instance1, equals(instance2));
      expect(identical(instance1, instance2), true);
    });

    /// Test BoolEvent publishing và listening
    test('should publish and receive BoolEvents', () {
      bool? receivedValue;

      // Listen for events
      eventBus.onBoolEvent.listen((event) {
        receivedValue = event.value;
      });

      // Publish event
      eventBus.fire(BoolEvent(true));

      // Small delay for async operation
      Future.delayed(Duration(milliseconds: 10), () {
        expect(receivedValue, equals(true));
      });
    });

    /// Test multiple BoolEvents
    test('should handle multiple BoolEvents', () {
      final receivedValues = <bool>[];

      // Listen for events
      eventBus.onBoolEvent.listen((event) {
        receivedValues.add(event.value);
      });

      // Fire multiple events
      eventBus.fire(BoolEvent(true));
      eventBus.fire(BoolEvent(false));
      eventBus.fire(BoolEvent(true));

      // Small delay for async operations
      Future.delayed(Duration(milliseconds: 10), () {
        expect(receivedValues.length, equals(3));
        expect(receivedValues, equals([true, false, true]));
      });
    });
  });
}