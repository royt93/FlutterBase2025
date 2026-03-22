import 'package:flutter/material.dart';

import 'utils/safe_logger.dart';

/// Global RouteObserver — dùng bởi BannerAdWidget (RouteAware) để biết
/// khi nào route bị che khuất (didPushNext) hoặc hiện lại (didPopNext).
///
/// Inject vào GetMaterialApp.navigatorObservers trong main.dart.
final RouteObserver<ModalRoute<void>> adRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// NavigatorObserver để log TOÀN BỘ route push/pop cho mục đích debug navigation.
/// Giúp biết user đang ở màn hình nào.
class AdScreenRouteLogger extends NavigatorObserver {
  static const String _tag = 'roy93~Router';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    SafeLogger.d(
      _tag,
      '➡️ PUSH: ${_routeName(route)} '
      '(from: ${_routeName(previousRoute)})',
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    SafeLogger.d(
      _tag,
      '⬅️ POP: ${_routeName(route)} '
      '(back to: ${_routeName(previousRoute)})',
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    SafeLogger.d(
      _tag,
      '🔄 REPLACE: ${_routeName(oldRoute)} → ${_routeName(newRoute)}',
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    SafeLogger.d(
      _tag,
      '🗑️ REMOVE: ${_routeName(route)} '
      '(previous: ${_routeName(previousRoute)})',
    );
    super.didRemove(route, previousRoute);
  }

  String _routeName(Route<dynamic>? route) {
    if (route == null) return 'null';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    // Fallback: extract class name from runtimeType
    return route.runtimeType.toString();
  }
}
