import 'package:flutter/foundation.dart';

/// Production optimization flags — port từ ProductionConfig.kt
class ProductionConfig {
  static const bool enableDemoFeatures = kDebugMode;
  static const bool enableVerboseLogging = kDebugMode;
  static const bool enableMemoryOptimization = !kDebugMode;
}

/// Safe logging wrapper — port từ SafeLogger.kt
/// Bọc try-catch để không crash khi unit test
class SafeLogger {
  static void d(String tag, String message) {
    if (ProductionConfig.enableVerboseLogging) {
      try {
        debugPrint('[$tag] $message');
      } catch (_) {
        // Ignore in unit tests
      }
    }
  }

  static void w(String tag, String message) {
    if (ProductionConfig.enableVerboseLogging) {
      try {
        debugPrint('⚠️ [$tag] $message');
      } catch (_) {
        // Ignore in unit tests
      }
    }
  }
}
