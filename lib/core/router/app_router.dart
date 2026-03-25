/// app_router.dart - Declarative route configuration using go_router.
/// Like Laravel's `routes/web.php` or Vue Router's `createRouter()`.
///
/// This file defines the complete route tree for the app. Currently installed
/// as a foundation — the app still uses MaterialApp with named routes.
/// Screens will be gradually migrated to use go_router's `context.push/go`.
///
/// Auth guard: The `redirect` function checks token validity and redirects
/// unauthenticated users to /login (like Laravel's `auth` middleware).
library;

import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/features/auth/screens/login_screen.dart';
import 'package:manajemensekolah/features/dashboard/screens/dashboard_screen.dart';
import 'package:manajemensekolah/main.dart';

/// The app's declarative router configuration.
/// Not yet the primary router — installed as foundation for gradual migration.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: true,
  redirect: (context, state) async {
    final isLoggedIn = await TokenService().isLoggedIn();
    final isOnLogin = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLogin) return '/login';
    if (isLoggedIn && isOnLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(
        initialError: state.extra as String?,
      ),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => Dashboard(role: 'admin'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => Dashboard(role: 'admin'),
    ),
    GoRoute(
      path: '/guru',
      builder: (context, state) => Dashboard(role: 'guru'),
    ),
    GoRoute(
      path: '/teacher',
      builder: (context, state) => Dashboard(role: 'guru'),
    ),
    GoRoute(
      path: '/staff',
      builder: (context, state) => Dashboard(role: 'staff'),
    ),
    GoRoute(
      path: '/wali',
      builder: (context, state) => Dashboard(role: 'wali'),
    ),
    GoRoute(
      path: '/parent',
      builder: (context, state) => Dashboard(role: 'wali'),
    ),
  ],
);
