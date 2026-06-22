import 'package:flutter/widgets.dart';

/// Tracks the live route stack so we can jump across several levels at once
/// (e.g. a breadcrumb tap straight to Home) by removing the in-between routes
/// instantly — instead of `popUntil`, which pops them one by one and overlaps
/// their (container-transform) reverse animations into a broken-looking blur.
class RouteStackObserver extends NavigatorObserver {
  final List<Route<dynamic>> _stack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) _stack[i] = newRoute;
  }

  /// Navigates down to the first route (top-down) that satisfies [keep],
  /// removing the routes above it.
  ///
  /// Navigates down to the first route (top-down) that satisfies [keep],
  /// removing the routes above it.
  ///
  /// A single-level jump (only one route to remove) is popped with its normal
  /// transition when [animate] is true. Multi-level jumps are always instant —
  /// animating them would morph the surviving page from a source tile that no
  /// longer exists, which looks broken.
  void jumpTo(
    NavigatorState nav,
    bool Function(Route<dynamic>) keep, {
    bool animate = false,
  }) {
    final toRemove = <Route<dynamic>>[];
    for (final route in _stack.reversed) {
      if (keep(route)) break;
      toRemove.add(route);
    }
    if (toRemove.isEmpty) return;

    if (animate && toRemove.length == 1) {
      nav.pop();
    } else {
      for (final route in toRemove) {
        nav.removeRoute(route);
      }
    }
  }
}

/// App-wide instance, wired into `MaterialApp.navigatorObservers`.
final routeStackObserver = RouteStackObserver();
