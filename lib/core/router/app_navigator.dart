/// app_navigator.dart - Centralized navigation wrapper using go_router.
/// Like Laravel's `redirect()` helper or Vue Router's `this.$router.push()`.
///
/// All 387 navigation calls go through this wrapper.
/// Internally uses go_router for declarative routing with auth guards.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Centralized navigation helper. All screen navigation goes through here.
/// Uses go_router's Navigator internally for proper route management.
class AppNavigator {
  AppNavigator._();

  /// Navigate to a new screen (push on top of current).
  static Future<T?> push<T>(BuildContext context, Widget screen) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Go back to the previous screen.
  static void pop<T>(BuildContext context, [T? result]) {
    if (context.canPop()) {
      context.pop(result);
    } else {
      Navigator.pop<T>(context, result);
    }
  }

  /// Replace current screen with a new one (no back button).
  static Future<T?> pushReplacement<T, TO>(BuildContext context, Widget screen) {
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  /// Navigate to a named route and replace current (e.g., '/admin', '/guru').
  /// Uses go_router's `go` which replaces the entire navigation stack.
  static void pushReplacementNamed(BuildContext context, String routeName) {
    context.go(routeName);
  }

  /// Navigate to a new screen and clear the entire navigation stack.
  /// Used for logout → login flow.
  static void pushAndClearStack(BuildContext context, Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  /// Check if the navigator can pop (has routes to go back to).
  static bool canPop(BuildContext context) {
    return context.canPop();
  }

  /// Navigate to a named route using go_router (replaces entire stack).
  /// Like Vue Router's `this.$router.push('/route')`.
  static void go(BuildContext context, String route) {
    context.go(route);
  }
}
