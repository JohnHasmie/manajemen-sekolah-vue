/// app_router.dart - Declarative route configuration using go_router.
/// Like Laravel's `routes/web.php` or Vue Router's `createRouter()`.
///
/// Auth guard: The `redirect` function checks token validity and redirects
/// unauthenticated users to /login (like Laravel's `auth` middleware).
/// Authenticated users are redirected to their role-specific dashboard.
library;

import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/screens/login_screen.dart';
import 'package:manajemensekolah/features/dashboard/screens/dashboard_screen.dart';
import 'package:manajemensekolah/main.dart';

/// The app's declarative router. Handles auth guard + role-based routing.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: false,
  redirect: (context, state) async {
    final tokenService = TokenService();
    final isLoggedIn = await tokenService.isLoggedIn();
    final location = state.matchedLocation;

    // Unauthenticated → force to login
    if (!isLoggedIn && location != '/login') {
      AppLogger.debug('router', 'Not logged in, redirecting to /login');
      return '/login';
    }

    // Authenticated + on login page → redirect to role dashboard
    if (isLoggedIn && location == '/login') {
      final userData = await tokenService.getUserData();
      final role = userData?['role']?.toString() ?? 'guru';
      AppLogger.debug('router', 'Logged in on /login, redirecting to /$role');
      return '/$role';
    }

    // Authenticated + on root → redirect to role dashboard
    if (isLoggedIn && location == '/') {
      final userData = await tokenService.getUserData();
      final role = userData?['role']?.toString() ?? 'guru';
      AppLogger.debug('router', 'On root, redirecting to /$role');
      return '/$role';
    }

    return null; // No redirect needed
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
