/// service_locator.dart - Dependency injection setup using get_it.
/// Like Laravel's Service Container (`app()->bind()`, `app()->singleton()`).
/// In Vue terms, this is like providing global services via `app.provide()`.
///
/// Registers all singleton services at app startup. Screens and other services
/// can then access them via `getIt<ServiceType>()` instead of creating new instances.
library;

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';

/// Global service locator instance. Like Laravel's `app()` helper.
/// Access any registered service via `getIt<ServiceType>()`.
final GetIt getIt = GetIt.instance;

/// Registers all application services as singletons.
/// Called once during app initialization (before runApp).
/// Like Laravel's `AppServiceProvider::register()`.
Future<void> setupServiceLocator() async {
  // Core services
  getIt.registerLazySingleton<PreferencesService>(() => PreferencesService());
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());
  getIt.registerLazySingleton<TokenService>(() => TokenService());
  getIt.registerLazySingleton<Dio>(() => dioClient);
}
