/// app_navigator.dart - Centralized navigation wrapper.
/// Like Laravel's `redirect()` helper or Vue Router's `this.$router.push()`.
///
/// Wraps all navigation calls in a single place so the internal implementation
/// can be swapped from Navigator to go_router without changing 400+ call sites.
///
/// Current: Uses Navigator.push/pop (same as before)
/// Future: Can switch internals to go_router's context.push/go
library;

import 'package:flutter/material.dart';

/// Centralized navigation helper. All screen navigation goes through here.
///
/// Usage:
/// ```dart
/// AppNavigator.push(context, SomeScreen(param: value));
/// AppNavigator.pop(context);
/// AppNavigator.pushReplacement(context, DashboardScreen());
/// AppNavigator.pushAndClearStack(context, LoginScreen());
/// ```
class AppNavigator {
  AppNavigator._();

  /// Navigate to a new screen (push on top of current).
  /// Like `Navigator.push` or Vue Router's `this.$router.push`.
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Go back to the previous screen.
  /// Like `Navigator.pop` or Vue Router's `this.$router.back()`.
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.pop<T>(context, result);
  }

  /// Replace current screen with a new one (no back button).
  /// Like `Navigator.pushReplacement` or Vue Router's `this.$router.replace`.
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget screen) {
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Navigate to a named route (e.g., '/admin', '/guru').
  /// Like `Navigator.pushReplacementNamed`.
  static Future<T?> pushReplacementNamed<T, TO>(BuildContext context, String routeName) {
    return Navigator.pushReplacementNamed<T, TO>(context, routeName);
  }

  /// Navigate to a new screen and clear the entire navigation stack.
  /// Used for logout → login flow.
  /// Like `Navigator.pushAndRemoveUntil` with `(route) => false`.
  static Future<T?> pushAndClearStack<T>(BuildContext context, Widget screen) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  /// Check if the navigator can pop (has routes to go back to).
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }
}
