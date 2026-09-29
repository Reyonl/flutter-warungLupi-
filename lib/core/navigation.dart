import 'package:flutter/material.dart';

/// Navigation service global — menghindari circular import antar layar
/// (Dashboard → BonCreate, BonList → BonDetail, dst).
class Nav {
  Nav._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get _navigator => navigatorKey.currentState;

  static Future<T?> push<T>(Widget page, {String? routeName}) {
    return _navigator!.push<T>(
      MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (_) => page,
      ),
    );
  }

  static Future<T?> pushReplacement<T, TO>(Widget page, {String? routeName}) {
    return _navigator!.pushReplacement<T, TO>(
      MaterialPageRoute(
        settings: RouteSettings(name: routeName),
        builder: (_) => page,
      ),
    );
  }

  static void pop<T>([T? result]) {
    if (_navigator!.canPop()) _navigator!.pop(result);
  }
}