/// base_api_service.dart - Shared utilities for all domain API services.
/// Extracts the duplicated _handleResponse(), baseUrl, and getHeaders() patterns
/// found across 13+ service files into a single reusable class.
///
/// Like a Laravel base controller or a shared Axios instance config in Vue.
/// Services call these static methods instead of duplicating the same logic.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';

/// Shared static utilities for domain API services.
///
/// Provides:
/// - [baseUrl] - Central API base URL from ApiService
/// - [getHeaders] - Auth headers (Bearer token + X-School-ID)
/// - [handleResponse] - Standard JSON response parser with error extraction
/// - [handleResponseWithValidation] - Same as above + Laravel 422 validation error extraction
abstract class BaseApiService {
  /// Base URL from central config. Like `config('app.url')` in Laravel.
  static String get baseUrl => ApiService.baseUrl;

  /// Auth headers with Bearer token + X-School-ID.
  /// Like Laravel's auth middleware injecting the current user context.
  static Future<Map<String, String>> getHeaders() => ApiService.getHeaders();

  /// Standard response handler for non-2xx responses.
  /// Parses JSON body and throws with the error message from the response.
  ///
  /// Use this for services that don't need Laravel 422 validation error extraction.
  static dynamic handleResponse(http.Response response) {
    if (response.statusCode == 204) {
      return null;
    }

    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    }

    throw Exception(
      responseBody['error'] ??
          responseBody['message'] ??
          'Request failed with status: ${response.statusCode}',
    );
  }

  /// Response handler with Laravel 422 validation error extraction.
  /// Extracts the first validation error from Laravel's `errors` map.
  ///
  /// Like Laravel's `$validator->errors()->first()` sent back to the client.
  static dynamic handleResponseWithValidation(http.Response response) {
    if (response.statusCode == 204) {
      return null;
    }

    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    }

    // Extract first Laravel validation error (422 Unprocessable Entity)
    if (response.statusCode == 422 && responseBody['errors'] != null) {
      final errors = responseBody['errors'] as Map<String, dynamic>;
      final firstError = errors.values.first;
      final errorMessage =
          firstError is List ? firstError.first : firstError.toString();
      throw Exception(errorMessage);
    }

    throw Exception(
      responseBody['message'] ??
          responseBody['error'] ??
          'Request failed with status: ${response.statusCode}',
    );
  }
}
