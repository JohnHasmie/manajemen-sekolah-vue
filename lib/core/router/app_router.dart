/// app_router.dart - Declarative route configuration using go_router.
/// Like Laravel's `routes/web.php` or Vue Router's `createRouter()`.
///
/// Auth guard: The `redirect` function checks token validity and redirects
/// unauthenticated users to /login (like Laravel's `auth` middleware).
/// Authenticated users are redirected to their role-specific dashboard.
library;

import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/presentation/screens/login_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:manajemensekolah/main.dart';

/// Guards the "already logged in on app start / reopen" FCM registration so
/// it fires at most once per app process.
///
/// The router `redirect` runs on every navigation, but FCM tokens are stable
/// per app-install — re-registering on each route change would be wasteful.
/// A fresh LOGIN already re-registers via the auth flow
/// (`DataPersistenceHelper`); this flag only covers the case where a stored
/// session is restored on launch (no fresh login runs), which is exactly the
/// "reopen doesn't refresh FCM" gap. Reset to `false` on logout so a
/// subsequent restored session re-registers.
bool _fcmRegisteredThisSession = false;

/// Called from logout so the next restored session re-registers its token.
void resetFcmSessionRegistration() {
  _fcmRegisteredThisSession = false;
}

/// Fire-and-forget FCM token registration for a restored session. Runs at
/// most once per process; fully resilient (never throws) inside
/// [FCMService.registerTokenWithBackend].
void _registerFcmForRestoredSession() {
  if (_fcmRegisteredThisSession) return;
  _fcmRegisteredThisSession = true;
  // Don't await: the router redirect must stay synchronous-fast and must
  // never be blocked by network I/O.
  FCMService().registerTokenWithBackend().catchError((Object e) {
    AppLogger.warning('router', 'FCM register on app-start failed: $e');
    return false;
  });
}

/// The app's declarative router. Handles auth guard + role-based routing.
final GoRouter appRouter = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: false,
  redirect: (context, state) async {
    final tokenService = TokenService();
    final isLoggedIn = await tokenService.isLoggedIn();
    final location = state.matchedLocation;

    // Restored-session FCM registration: when a stored session is valid on
    // app start/reopen (no fresh login ran), re-register the device's current
    // FCM token so the backend self-heals any stale token. Guarded to fire
    // once per process and fully non-blocking. The bearer token is already
    // persisted at this point (isLoggedIn verified it), so the POST carries
    // the auth header.
    if (isLoggedIn) {
      _registerFcmForRestoredSession();
    }

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
      builder: (context, state) =>
          LoginScreen(initialError: state.extra as String?),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const Dashboard(role: 'admin'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const Dashboard(role: 'admin'),
    ),
    GoRoute(
      path: '/guru',
      builder: (context, state) => const Dashboard(role: 'guru'),
    ),
    GoRoute(
      path: '/teacher',
      builder: (context, state) => const Dashboard(role: 'guru'),
    ),
    GoRoute(
      path: '/staff',
      builder: (context, state) => const Dashboard(role: 'staff'),
    ),
    GoRoute(
      path: '/wali',
      builder: (context, state) => const Dashboard(role: 'wali'),
    ),
    GoRoute(
      path: '/parent',
      builder: (context, state) => const Dashboard(role: 'wali'),
    ),
  ],
);
