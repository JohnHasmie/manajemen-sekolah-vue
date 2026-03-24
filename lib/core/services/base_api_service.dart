/// base_api_service.dart - Shared utilities for all domain API services.
/// Extracts the duplicated _handleResponse(), baseUrl, and getHeaders() patterns
/// found across 13+ service files into a single reusable class.
///
/// Like a Laravel base controller or a shared Axios instance config in Vue.
/// Services call these static methods instead of duplicating the same logic.
library;

import 'package:manajemensekolah/core/services/api_service.dart';

/// Shared static utilities for domain API services.
///
/// Provides:
/// - [baseUrl] - Central API base URL from ApiService
/// - [getHeaders] - Auth headers (Bearer token + X-School-ID)
///
/// Response handling is now done by Dio interceptors (ErrorInterceptor in
/// dio_client.dart), so the old handleResponse/handleResponseWithValidation
/// methods have been removed.
abstract class BaseApiService {
  /// Base URL from central config. Like `config('app.url')` in Laravel.
  static String get baseUrl => ApiService.baseUrl;

  /// Auth headers with Bearer token + X-School-ID.
  /// Like Laravel's auth middleware injecting the current user context.
  static Future<Map<String, String>> getHeaders() => ApiService.getHeaders();
}
