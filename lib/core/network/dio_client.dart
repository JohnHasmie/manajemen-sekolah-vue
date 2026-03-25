/// dio_client.dart - Singleton Dio HTTP client with interceptors.
/// Like Laravel's Http facade with global middleware (auth, logging, error handling).
/// In Vue terms, this is the root Axios instance with interceptors configured.
///
/// Replaces the duplicated _getHeaders() and _handleResponse() patterns found
/// across 13+ service files. Interceptors handle:
/// - Auth header injection (Bearer token + X-School-ID)
/// - Error response parsing (401 auto-logout, 422 validation, 403 school access)
/// - Debug logging in development mode
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/main.dart';
import 'package:manajemensekolah/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global Dio instance. Initialized once via [createDioClient].
/// Like a singleton Axios instance in Vue or a Http facade in Laravel.
late final Dio dioClient;

/// Creates and configures the global Dio instance with all interceptors.
/// Called once during app initialization (from main.dart).
///
/// [baseUrl] - The API base URL (from .env via ApiService.baseUrl).
Dio createDioClient(String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add interceptors in order: auth first, then error handling, then logging
  dio.interceptors.addAll([
    AuthInterceptor(),
    ErrorInterceptor(),
    if (kDebugMode) LoggingInterceptor(),
  ]);

  dioClient = dio;
  return dio;
}

/// Injects Bearer token and X-School-ID headers into every request.
/// Like Laravel Sanctum auth middleware + multi-tenant school middleware combined.
/// Replaces the duplicated _getHeaders() method found in 13+ service files.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _secureStorage.getToken();
      final userData = await _secureStorage.getUserData();

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }

      // Inject school ID for multi-tenant requests
      if (userData != null && userData['school_id'] != null) {
        options.headers['X-School-ID'] = userData['school_id'].toString();
      }
    } catch (_) {
      // If secure storage fails, continue without auth headers
    }

    handler.next(options);
  }
}

/// Handles API error responses centrally.
/// Like Laravel's exception handler (Handler::render()) or an Axios response interceptor.
///
/// Converts Dio errors into typed ApiExceptions:
/// - 401 → AuthenticationException (triggers auto-logout)
/// - 403 → SchoolAccessDeniedException or ForbiddenException
/// - 422 → ValidationException (extracts first Laravel validation error)
/// - 429 → RateLimitException
/// - 5xx → ServerException
/// - Network errors → NetworkException
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;

    // Network-level errors (no response from server)
    if (response == null) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: NetworkException(
            _getNetworkErrorMessage(err),
            statusCode: null,
          ),
          type: err.type,
        ),
      );
      return;
    }

    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Parse response body
    dynamic responseBody;
    if (data is Map) {
      responseBody = data;
    } else if (data is String) {
      try {
        responseBody = json.decode(data);
      } catch (_) {
        responseBody = {'error': data};
      }
    } else {
      responseBody = {};
    }

    switch (statusCode) {
      case 401:
        // Auto-logout on authentication failure
        await _handleAuthenticationError('Session expired. Please login again.');
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: AuthenticationException(
              'Session expired. Please login again.',
              statusCode: 401,
              responseBody: responseBody,
            ),
          ),
        );
        return;

      case 403:
        final errorMsg = (responseBody['error'] ?? '').toString();
        if (errorMsg.contains('Anda tidak memiliki akses ke sekolah ini')) {
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: response,
              error: SchoolAccessDeniedException(
                'SCHOOL_ACCESS_DENIED: $errorMsg',
                statusCode: 403,
                responseBody: responseBody,
              ),
            ),
          );
        } else {
          await _handleAuthenticationError('Access forbidden. Please login again.');
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: response,
              error: ForbiddenException(
                'Access forbidden.',
                statusCode: 403,
                responseBody: responseBody,
              ),
            ),
          );
        }
        return;

      case 422:
        String errorMessage = responseBody['message'] ?? 'Validation failed';
        if (responseBody['errors'] != null) {
          final errors = responseBody['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first;
          errorMessage = firstError is List
              ? firstError.first.toString()
              : firstError.toString();
        }
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: ValidationException(
              errorMessage,
              errors: responseBody['errors'] is Map
                  ? responseBody['errors'] as Map<String, dynamic>
                  : null,
              statusCode: 422,
              responseBody: responseBody,
            ),
          ),
        );
        return;

      case 429:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: RateLimitException(
              responseBody['message'] ?? 'Rate limit exceeded',
              statusCode: 429,
              responseBody: responseBody,
            ),
          ),
        );
        return;

      default:
        if (statusCode >= 500) {
          handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              response: response,
              error: ServerException(
                responseBody['error'] ??
                    responseBody['message'] ??
                    'Server error ($statusCode)',
                statusCode: statusCode,
                responseBody: responseBody,
              ),
            ),
          );
          return;
        }
    }

    // For any other error, pass it through with a generic message
    final errorMessage = responseBody['error'] ??
        responseBody['message'] ??
        'Request failed with status: $statusCode';
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        error: Exception(errorMessage),
      ),
    );
  }

  String _getNetworkErrorMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out. Please check your internet.';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending data.';
      case DioExceptionType.receiveTimeout:
        return 'Response timed out. Server may be busy.';
      case DioExceptionType.connectionError:
        return 'Could not connect to server. Check your internet.';
      default:
        return 'Network error: ${err.message ?? 'Unknown error'}';
    }
  }

  /// Handles authentication failure by clearing stored data and navigating to login.
  /// Mirrors the exact behavior of ApiService._handleAuthenticationErrorWithMessage().
  Future<void> _handleAuthenticationError(String errorMessage) async {
    try {
      if (kDebugMode) {
        print('🔴 Dio ErrorInterceptor: $errorMessage');
      }

      // Clear secure storage (tokens, user data)
      await SecureStorageService().clearAll();
      // Also clear SharedPreferences (cache, prefs)
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      await Future.delayed(const Duration(milliseconds: 300));

      if (navigatorKey.currentState != null &&
          navigatorKey.currentState!.mounted) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(initialError: errorMessage),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during Dio auth cleanup: $e');
      }
      try {
        navigatorKey.currentState?.pushReplacementNamed('/auth/login');
      } catch (_) {}
    }
  }
}

/// Debug logging interceptor. Only active in debug mode.
/// Like Laravel's Http::dd() or an Axios request/response logger.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('📡 ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('✅ ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('❌ ${err.response?.statusCode ?? 'N/A'} ${err.requestOptions.uri}: ${err.message}');
    }
    handler.next(err);
  }
}
