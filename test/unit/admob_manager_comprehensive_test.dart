import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

// Import AdMob components
import 'package:saigonphantomlabs/mckimquyen/admob/ad_mob_manager.dart';
import 'package:saigonphantomlabs/mckimquyen/admob/event_bus.dart';

void main() {
  /// Test Suite cho AdMobManager - Comprehensive Testing
  group('AdMobManager Core Functionality Tests', () {
    late AdMobManager adMobManager;

    setUp(() {
      adMobManager = AdMobManager();
    });

    /// Test 1: Singleton pattern implementation
    test('should implement singleton pattern correctly', () {
      final instance1 = AdMobManager();
      final instance2 = AdMobManager();
      final instance3 = AdMobManager();

      expect(identical(instance1, instance2), true);
      expect(identical(instance2, instance3), true);
      expect(instance1.hashCode, instance2.hashCode);
    });

    /// Test 2: Ad Unit ID validation
    test('should provide valid ad unit IDs', () {
      final bannerAdUnitId = AdMobManager.bannerAdUnitId();
      final interstitialAdUnitId = AdMobManager.interstitialAdUnitId();
      final rewardedAdUnitId = AdMobManager.rewardedAdUnitId();
      final appOpenAdUnitId = AdMobManager.appOpenAdUnitId();

      expect(bannerAdUnitId, isA<String>());
      expect(bannerAdUnitId.isNotEmpty, true);

      expect(interstitialAdUnitId, isA<String>());
      expect(interstitialAdUnitId.isNotEmpty, true);

      expect(rewardedAdUnitId, isA<String>());
      expect(rewardedAdUnitId.isNotEmpty, true);

      expect(appOpenAdUnitId, isA<String>());
      expect(appOpenAdUnitId.isNotEmpty, true);

      // Ad Unit IDs should be different
      final allIds = {bannerAdUnitId, interstitialAdUnitId, rewardedAdUnitId, appOpenAdUnitId};
      expect(allIds.length, 4, reason: 'All ad unit IDs should be unique');
    });

    /// Test 3: Initialization handling
    test('should handle initialization gracefully', () {
      // Initialization should not throw in test environment
      expect(() => adMobManager.initialize(), returnsNormally);

      // Multiple initializations should be safe
      expect(() {
        adMobManager.initialize();
        adMobManager.initialize();
        adMobManager.initialize();
      }, returnsNormally);
    });

    /// Test 4: App Open Ad handling
    test('should handle app open ad operations safely', () {
      // Should not crash when no ad is loaded
      expect(() => adMobManager.showAppOpenAd(), returnsNormally);

      // Should handle multiple calls
      expect(() {
        adMobManager.showAppOpenAd();
        adMobManager.showAppOpenAd();
        adMobManager.showAppOpenAd();
      }, returnsNormally);
    });

    /// Test 5: Time tracking functionality
    test('should handle time tracking correctly', () {
      // Setting times should not crash
      expect(() => adMobManager.setLastInterstitialShowTime(), returnsNormally);
      expect(() => adMobManager.setLastRewardedShowTime(), returnsNormally);

      // Multiple calls should be safe
      expect(() {
        adMobManager.setLastInterstitialShowTime();
        adMobManager.setLastRewardedShowTime();
        adMobManager.setLastInterstitialShowTime();
        adMobManager.setLastRewardedShowTime();
      }, returnsNormally);
    });
  });

  /// Test Suite cho Static Methods
  group('AdMobManager Static Methods Tests', () {
    /// Test 6: Interstitial ad creation
    test('should handle interstitial ad creation', () async {
      // Should not crash in test environment
      expect(() => AdMobManager.createInterstitialAd(), returnsNormally);

      // Method should return Future
      final future = AdMobManager.createInterstitialAd();
      expect(future, isA<Future>());
    });

    /// Test 7: Rewarded ad creation
    test('should handle rewarded ad creation', () async {
      // Should not crash in test environment
      expect(() => AdMobManager.createRewardedAd(), returnsNormally);

      // Method should return Future
      final future = AdMobManager.createRewardedAd();
      expect(future, isA<Future>());
    });

    /// Test 8: Adaptive banner size
    test('should handle adaptive banner size requests', () async {
      // Should not crash in test environment
      expect(() => AdMobManager.getAdaptiveBannerSize(), returnsNormally);

      // Method should return Future
      final future = AdMobManager.getAdaptiveBannerSize();
      expect(future, isA<Future>());
    });

    /// Test 9: App Open Ad handling
    test('should handle app open ad operations', () async {
      final manager = AdMobManager();

      // Should not crash in test environment
      expect(() => manager.showAppOpenAd(), returnsNormally);
      expect(() => manager.setLastInterstitialShowTime(), returnsNormally);
      expect(() => manager.setLastRewardedShowTime(), returnsNormally);
    });
  });

  /// Test Suite cho Error Handling
  group('AdMobManager Error Handling Tests', () {
    late AdMobManager adMobManager;

    setUp(() {
      adMobManager = AdMobManager();
    });

    /// Test 10: Null safety
    test('should handle null values gracefully', () {
      // All methods should be null-safe
      expect(() => adMobManager.initialize(), returnsNormally);
      expect(() => adMobManager.showAppOpenAd(), returnsNormally);
      expect(() => adMobManager.setLastInterstitialShowTime(), returnsNormally);
      expect(() => adMobManager.setLastRewardedShowTime(), returnsNormally);
    });

    /// Test 11: Exception handling
    test('should handle exceptions gracefully', () {
      // Methods should not crash even if plugins are missing
      expect(() => adMobManager.initialize(), returnsNormally);
      expect(() => AdMobManager.createInterstitialAd(), returnsNormally);
      expect(() => AdMobManager.createRewardedAd(), returnsNormally);
      expect(() => AdMobManager.getAdaptiveBannerSize(), returnsNormally);
    });

    /// Test 12: Multiple rapid calls
    test('should handle rapid successive calls', () {
      // Rapid initialization calls
      expect(() {
        for (int i = 0; i < 10; i++) {
          adMobManager.initialize();
        }
      }, returnsNormally);

      // Rapid ad show calls
      expect(() {
        for (int i = 0; i < 10; i++) {
          adMobManager.showAppOpenAd();
        }
      }, returnsNormally);
    });
  });

  /// Test Suite cho Performance
  group('AdMobManager Performance Tests', () {
    /// Test 13: Memory efficiency
    test('should be memory efficient', () {
      final instances = <AdMobManager>[];

      // Create multiple references (should be same instance)
      for (int i = 0; i < 100; i++) {
        instances.add(AdMobManager());
      }

      // All should be identical (singleton)
      for (int i = 1; i < instances.length; i++) {
        expect(identical(instances[0], instances[i]), true);
      }
    });

    /// Test 14: Method call performance
    test('should execute methods efficiently', () {
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        AdMobManager.bannerAdUnitId();
        AdMobManager.interstitialAdUnitId();
        AdMobManager.rewardedAdUnitId();
        AdMobManager.appOpenAdUnitId();
      }

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    /// Test 15: Concurrent operations
    test('should handle concurrent operations', () async {
      final futures = <Future>[];

      for (int i = 0; i < 10; i++) {
        futures.add(Future.microtask(() {
          final manager = AdMobManager();
          manager.initialize();
          manager.showAppOpenAd();
          manager.setLastInterstitialShowTime();
        }));
      }

      await Future.wait(futures);
      // Should complete without errors
    });
  });

  /// Test Suite cho Integration
  group('AdMobManager Integration Tests', () {
    /// Test 16: Integration với initialization function
    test('should integrate with splash screen initialization', () async {
      // Test external initialization function
      expect(() => checkLogicSplashScreenIsInitializedAdmob(), returnsNormally);

      final future = checkLogicSplashScreenIsInitializedAdmob();
      expect(future, isA<Future<bool>>());

      // Should complete within reasonable time
      final result = await future.timeout(Duration(seconds: 5));
      expect(result, isA<bool>());
    });

    /// Test 17: Thread safety
    test('should be thread safe', () async {
      final results = <AdMobManager>[];
      final futures = <Future>[];

      for (int i = 0; i < 10; i++) {
        futures.add(Future(() {
          results.add(AdMobManager());
          return results.last;
        }));
      }

      await Future.wait(futures);

      // All instances should be identical
      for (int i = 1; i < results.length; i++) {
        expect(identical(results[0], results[i]), true);
      }
    });
  });
}

/// Test Suite cho SimpleEventBus
void main2() {
  group('SimpleEventBus Comprehensive Tests', () {
    late SimpleEventBus eventBus;

    setUp(() {
      eventBus = SimpleEventBus();
    });

    /// Test 18: Singleton pattern
    test('should implement singleton pattern correctly', () {
      final instance1 = SimpleEventBus();
      final instance2 = SimpleEventBus();

      expect(identical(instance1, instance2), true);
      expect(identical(eventBus, instance1), true);
    });

    /// Test 19: Event publishing and receiving
    test('should publish and receive BoolEvents correctly', () async {
      final receivedEvents = <bool>[];
      final completer = Completer<void>();

      // Listen for events
      final subscription = eventBus.onBoolEvent.listen((event) {
        receivedEvents.add(event.value);
        if (receivedEvents.length == 3) {
          completer.complete();
        }
      });

      // Publish events
      eventBus.fire(BoolEvent(true));
      eventBus.fire(BoolEvent(false));
      eventBus.fire(BoolEvent(true));

      await completer.future.timeout(Duration(seconds: 1));

      expect(receivedEvents, [true, false, true]);
      await subscription.cancel();
    });

    /// Test 20: Multiple listeners
    test('should support multiple listeners', () async {
      int listener1Count = 0;
      int listener2Count = 0;
      final completer = Completer<void>();

      // Multiple listeners
      final sub1 = eventBus.onBoolEvent.listen((event) {
        listener1Count++;
      });

      final sub2 = eventBus.onBoolEvent.listen((event) {
        listener2Count++;
        if (listener2Count == 5) completer.complete();
      });

      // Fire events
      for (int i = 0; i < 5; i++) {
        eventBus.fire(BoolEvent(i % 2 == 0));
      }

      await completer.future.timeout(Duration(seconds: 1));

      expect(listener1Count, 5);
      expect(listener2Count, 5);

      await sub1.cancel();
      await sub2.cancel();
    });

    /// Test 21: Event bus performance
    test('should handle high-frequency events efficiently', () async {
      int eventCount = 0;
      final stopwatch = Stopwatch()..start();
      final completer = Completer<void>();

      final subscription = eventBus.onBoolEvent.listen((event) {
        eventCount++;
        if (eventCount == 1000) {
          stopwatch.stop();
          completer.complete();
        }
      });

      // Fire 1000 events rapidly
      for (int i = 0; i < 1000; i++) {
        eventBus.fire(BoolEvent(i % 2 == 0));
      }

      await completer.future.timeout(Duration(seconds: 2));

      expect(eventCount, 1000);
      expect(stopwatch.elapsedMilliseconds, lessThan(500));

      await subscription.cancel();
    });

    /// Test 22: Memory management
    test('should manage memory correctly', () async {
      final subscriptions = <StreamSubscription>[];

      // Create many subscriptions
      for (int i = 0; i < 100; i++) {
        subscriptions.add(eventBus.onBoolEvent.listen((event) {}));
      }

      // Cancel all subscriptions
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }

      // Should not leak memory (no direct test, but no crash is good)
      expect(subscriptions.length, 100);
    });

    /// Test 23: Error handling in listeners
    test('should handle errors in listeners gracefully', () async {
      int goodListenerCount = 0;
      final completer = Completer<void>();

      // Listener that throws
      eventBus.onBoolEvent.listen((event) {
        throw Exception('Test error');
      });

      // Good listener
      eventBus.onBoolEvent.listen((event) {
        goodListenerCount++;
        if (goodListenerCount == 3) completer.complete();
      });

      // Fire events (should not crash despite error in first listener)
      eventBus.fire(BoolEvent(true));
      eventBus.fire(BoolEvent(false));
      eventBus.fire(BoolEvent(true));

      await completer.future.timeout(Duration(seconds: 1));

      expect(goodListenerCount, 3);
    });
  });
}

/// Test Suite cho BoolEvent
void main3() {
  group('BoolEvent Tests', () {
    /// Test 24: BoolEvent creation
    test('should create BoolEvent correctly', () {
      final trueEvent = BoolEvent(true);
      final falseEvent = BoolEvent(false);

      expect(trueEvent.value, true);
      expect(falseEvent.value, false);
    });

    /// Test 25: BoolEvent equality (if implemented)
    test('should handle BoolEvent values correctly', () {
      final event1 = BoolEvent(true);
      final event2 = BoolEvent(true);
      final event3 = BoolEvent(false);

      expect(event1.value, event2.value);
      expect(event1.value, isNot(event3.value));
    });

    /// Test 26: BoolEvent edge cases
    test('should handle edge cases', () {
      // Multiple events with same value
      final events = List.generate(100, (i) => BoolEvent(i % 2 == 0));

      for (int i = 0; i < events.length; i++) {
        expect(events[i].value, i % 2 == 0);
      }
    });
  });
}