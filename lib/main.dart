/// main.dart - Application entry point and root widget configuration.
/// Like Laravel's `public/index.php` + `bootstrap/app.php` + `app/Http/Kernel.php` combined.
/// In Vue terms, this is `main.ts` where you create the Vue app, install plugins (Vuex, Router),
/// and mount it to the DOM.
///
/// Initialization flow (in `main()`):
/// 1. Load `.env` file (like Laravel's `Dotenv::load()` in `bootstrap/app.php`).
/// 2. Initialize ApiService (HTTP client setup - like configuring Axios baseURL).
/// 3. Initialize Firebase (analytics, crash reporting, FCM push notifications).
/// 4. Initialize date formatting for Indonesian locale.
/// 5. Load saved language preference from SharedPreferences.
/// 6. Set up global error handling (like Laravel's exception Handler).
/// 7. Run the root widget [SchoolManagementApp].
///
/// Provider setup (in `build()`):
/// - [LanguageProvider]: Reactive i18n state (like Vue-i18n plugin).
/// - [AcademicYearProvider]: Tracks selected academic year (like a Vuex module).
/// - [TeacherProvider]: Caches logged-in teacher's data (like a Vuex module).
///
/// Auth flow:
/// - Checks token validity via [TokenService.isLoggedIn] (like Laravel auth middleware).
/// - If authenticated: reads user role from SharedPreferences and routes to the
///   role-specific Dashboard (like Laravel's `RedirectIfAuthenticated` middleware).
/// - If not authenticated: shows LoginScreen (like Laravel's `auth` middleware redirect).
///
/// Named routes map roles to Dashboard instances (like Laravel's `Route::get('/admin', ...)`).
library;

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:manajemensekolah/core/widgets/error_handler.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/services/analytics_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/log_service.dart';
import 'package:manajemensekolah/core/services/performance_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Global navigator key that enables navigation from anywhere without a BuildContext.
/// Like a global `$router` reference in Vue, or using `app()->make('redirect')` in Laravel.
/// Used by the global error handler to redirect to LoginScreen on auth failures.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// App entry point. Wrapped in [runZonedGuarded] to catch unhandled async errors
/// (like Laravel's global exception handler in `bootstrap/app.php`).
///
/// Initialization order matters:
/// 1. WidgetsFlutterBinding (required before any plugin calls).
/// 2. .env loading (API URLs, keys - like Laravel's `.env`).
/// 3. ApiService init (HTTP client - like configuring Axios or Guzzle).
/// 4. Firebase init (analytics, crash reporting).
/// 5. Date locale init (for Indonesian date formatting).
/// 6. Language provider (load saved locale preference).
/// 7. Error handling setup.
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load environment variables
    try {
      await dotenv.load(fileName: ".env");
      AppLogger.info('init', '.env loaded');
    } catch (e, stack) {
      AppLogger.warning('init', 'Failed to load .env: $e');
      LogService.sendError(e, stack);
    }

    // Initialize PreferencesService (SharedPreferences wrapper)
    await PreferencesService().init();
    AppLogger.info('init', 'PreferencesService initialized');

    // Initialize ApiService FIRST (before anything else)
    await ApiService.init();
    AppLogger.info('init', 'ApiService initialized');

    // Initialize Dio HTTP client with interceptors
    createDioClient(ApiService.baseUrl);
    AppLogger.info('init', 'Dio client initialized');

    // Setup dependency injection
    await setupServiceLocator();
    AppLogger.info('init', 'Service locator initialized');

    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AppLogger.info('init', 'Firebase initialized');
    } catch (e, stack) {
      AppLogger.error('init', 'Firebase initialization error: $e');
      AppLogger.warning(
        'init',
        'Please configure Firebase using FlutterFire CLI or update firebase_options.dart',
      );
      LogService.sendError(e, stack);
    }

    // Initialize Firebase Analytics & Performance
    try {
      await AnalyticsService.initialize();
      await PerformanceService.initialize();
      // Set user if already logged in previously
      await AnalyticsService.setUserFromPrefs();
    } catch (e) {
      AppLogger.warning(
        'init',
        'Analytics/Performance init failed (non-critical): $e',
      );
    }

    await initializeDateFormatting('id_ID', null);

    // Initialize language provider and load saved language
    await languageProvider.loadSavedLanguage();

    // Setup error handling (non-blocking)
    _setupErrorHandling();

    runApp(ProviderScope(child: SchoolManagementApp()));
  }, LogService.sendError);
}

/// Top-level error handling setup (called from `main`).
/// Like registering Laravel's exception handler in `bootstrap/app.php`.
void _setupErrorHandling() {
  try {
    AppErrorHandler.setupErrorHandling();
  } catch (e) {
    AppLogger.error('init', 'Error setting up error handling: $e');
  }
}

/// The root widget of the application. Like Vue's `App.vue` or Laravel's root layout.
///
/// This is a [StatefulWidget] because it needs to:
/// 1. Run async initialization (FCM, error stream subscription).
/// 2. Track initialization state to show a loading screen until ready.
/// 3. Listen to a global error stream for auth failures.
///
/// The `build()` method sets up:
/// - [MultiProvider]: Injects global state providers (like Vue's `app.use(store)`).
/// - [MaterialApp]: Configures theming, localization, routing, and the auth gate.
class SchoolManagementApp extends ConsumerStatefulWidget {
  /// Set to true during integration tests to skip FCM initialization
  /// (which triggers the notification permission dialog on iOS simulator).
  static bool skipFCM = false;

  const SchoolManagementApp({super.key});

  @override
  ConsumerState<SchoolManagementApp> createState() =>
      _SchoolManagementAppState();
}

class _SchoolManagementAppState extends ConsumerState<SchoolManagementApp> {
  /// Handles token storage, validation, and logout. Like Laravel's `Auth` guard.
  final TokenService _tokenService = TokenService();

  /// Subscription to the global error stream for catching auth errors app-wide.
  /// Like a Laravel middleware that intercepts 401 responses and redirects to login.
  StreamSubscription<Exception>? _errorSubscription;

  /// Tracks whether async init (FCM, error handling) has completed.
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Performs async initialization that can't happen in `initState` synchronously.
  /// Clears stale force-logout flags, sets up FCM push notifications, and
  /// subscribes to the global error stream.
  void _initializeApp() async {
    try {
      // Clear any existing force logout flag on app start
      final prefs = PreferencesService();
      await prefs.setBool('force_logout', false);

      // Setup error handling
      _setupErrorHandling();

      // Initialize FCM Service (skip if disabled, e.g. during integration tests)
      if (!SchoolManagementApp.skipFCM) {
        try {
          await FCMService().initialize();
          AppLogger.info('init', 'FCM Service initialized in app');
        } catch (e) {
          AppLogger.warning(
            'init',
            'FCM Service initialization failed (non-critical): $e',
          );
        }
      } else {
        AppLogger.info('init', 'FCM skipped (skipFCM=true)');
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e, stack) {
      AppLogger.error('init', 'App initialization error: $e');
      LogService.sendError(e, stack);
      setState(() {
        _isInitialized = true;
      });
    }
  }

  /// Subscribes to the global error stream to catch auth errors from any screen.
  /// Like a global Axios response interceptor in Vue that handles 401s.
  void _setupErrorHandling() {
    _errorSubscription = AppErrorHandler.errorStream.listen((error) async {
      await _handleGlobalError(error);
    });
  }

  /// Handles authentication-related errors globally.
  /// If the error is an auth error (expired token, 401, etc.), logs the user out
  /// and navigates to LoginScreen. Like Laravel's `unauthenticated()` method
  /// in `Handler.php` that redirects to the login route.
  Future<void> _handleGlobalError(Exception error) async {
    AppLogger.error('app', error);

    // Only handle authentication-related errors
    if (_isAuthError(error)) {
      AppLogger.warning('auth', 'Auth error detected, logging out...');

      await _tokenService.logout();

      // Navigate to login screen via go_router
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appRouter.go('/login');
      });
    }
  }

  /// Checks if an exception is authentication-related by keyword matching.
  /// Only matches genuine auth failures (expired token, 401) - not general errors.
  ///
  /// [error] - The exception to check.
  /// Returns true if this is an auth error that should trigger a logout.
  bool _isAuthError(Exception error) {
    final errorString = error.toString().toLowerCase();

    // Only handle errors that are truly auth-related
    return errorString.contains('token expired') ||
        errorString.contains('jwt expired') ||
        errorString.contains('authentication failed') ||
        errorString.contains('401') ||
        errorString.contains('invalid token');
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    AppErrorHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: AppSpacing.lg),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    final langProvider = ref.watch(languageRiverpod);
    return MaterialApp.router(
      routerConfig: appRouter,
      title: langProvider.getTranslatedText({
        'en': 'School Management',
        'id': 'Manajemen Sekolah',
      }),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      debugShowCheckedModeBanner: false,
    );
  }
}
