/// Tests for DioClient interceptors — unit tests for AuthInterceptor and
/// ErrorInterceptor behavior without needing a real HTTP server.
///
/// Like testing Laravel HTTP middleware in isolation: pass a crafted
/// request/response through the middleware and assert the output.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';

void main() {
  group('ErrorInterceptor', () {
    late ErrorInterceptor interceptor;

    // Mock storage and prefs platform channels so _handleAuthenticationError
    // doesn't crash when trying to clear storage.
    late Map<String, String> mockSecureStore;
    late Map<String, Object> mockPrefsStore;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      interceptor = ErrorInterceptor();
      mockSecureStore = {};
      mockPrefsStore = {};

      // Mock FlutterSecureStorage platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'write':
              mockSecureStore[methodCall.arguments['key'] as String] =
                  methodCall.arguments['value'] as String;
              return null;
            case 'read':
              return mockSecureStore[methodCall.arguments['key'] as String];
            case 'deleteAll':
              mockSecureStore.clear();
              return null;
            default:
              return null;
          }
        },
      );

      // Mock SharedPreferences platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAll':
              return mockPrefsStore;
            case 'clear':
              mockPrefsStore.clear();
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        null,
      );
    });

    test('401 response produces AuthenticationException', () async {
      // Use a real Dio interceptor chain to test error handling end-to-end.
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(interceptor);

      // Use a real Dio interceptor chain test
      dio.httpClientAdapter = _MockAdapter(statusCode: 401, data: {'message': 'Unauthenticated'});

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<AuthenticationException>());
        final authError = e.error as AuthenticationException;
        expect(authError.statusCode, 401);
        expect(authError.message, 'Session expired. Please login again.');
      }
    });

    test('422 response produces ValidationException with first error',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 422,
        data: {
          'message': 'The given data was invalid.',
          'errors': {
            'email': ['Email is required', 'Email must be valid'],
            'name': ['Name is required'],
          },
        },
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationException>());
        final valError = e.error as ValidationException;
        expect(valError.statusCode, 422);
        // Should extract the first error from the first field
        expect(valError.message, 'Email is required');
        expect(valError.errors, isNotNull);
      }
    });

    test('422 response without errors map uses message field', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 422,
        data: {'message': 'Validation failed'},
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationException>());
        final valError = e.error as ValidationException;
        expect(valError.message, 'Validation failed');
      }
    });

    test('429 response produces RateLimitException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 429,
        data: {'message': 'Too Many Requests'},
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<RateLimitException>());
        final rateError = e.error as RateLimitException;
        expect(rateError.statusCode, 429);
      }
    });

    test('500 response produces ServerException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 500,
        data: {'error': 'Internal Server Error'},
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerException>());
        final serverError = e.error as ServerException;
        expect(serverError.statusCode, 500);
        expect(serverError.message, 'Internal Server Error');
      }
    });

    test('503 response produces ServerException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 503,
        data: {'message': 'Service Unavailable'},
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ServerException>());
        final serverError = e.error as ServerException;
        expect(serverError.statusCode, 503);
      }
    });

    test('403 with school access denied message produces SchoolAccessDeniedException',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 403,
        data: {'error': 'Anda tidak memiliki akses ke sekolah ini'},
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<SchoolAccessDeniedException>());
        final schoolError = e.error as SchoolAccessDeniedException;
        expect(schoolError.statusCode, 403);
      }
    });

    test('403 without school context produces ForbiddenException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 403,
        data: {'error': 'You are not allowed'},
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ForbiddenException>());
        final forbiddenError = e.error as ForbiddenException;
        expect(forbiddenError.statusCode, 403);
      }
    });

    test('network error (no response) produces NetworkException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(throwConnectionError: true);

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<NetworkException>());
      }
    });

    test('422 with string response body is parsed correctly', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      dio.interceptors.add(ErrorInterceptor());

      dio.httpClientAdapter = _MockAdapter(
        statusCode: 422,
        data: json.encode({
          'message': 'Validation failed from string',
        }),
        isStringResponse: true,
      );

      try {
        await dio.get('/test');
        fail('Should have thrown');
      } on DioException catch (e) {
        expect(e.error, isA<ValidationException>());
        final valError = e.error as ValidationException;
        expect(valError.message, 'Validation failed from string');
      }
    });
  });

  group('createDioClient', () {
    // `dioClient` is a `late final` global — it can only be initialized once
    // per test process. So we call createDioClient once and run all assertions
    // on that single instance.
    late Dio dio;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock FlutterSecureStorage
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async => null,
      );

      dio = createDioClient('https://api.example.com');
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    test('creates Dio instance with correct baseUrl', () {
      expect(dio.options.baseUrl, 'https://api.example.com');
    });

    test('sets correct default headers', () {
      expect(dio.options.headers['Content-Type'], 'application/json');
      expect(dio.options.headers['Accept'], 'application/json');
    });

    test('sets timeout durations', () {
      expect(dio.options.connectTimeout, const Duration(seconds: 30));
      expect(dio.options.receiveTimeout, const Duration(seconds: 30));
      expect(dio.options.sendTimeout, const Duration(seconds: 30));
    });

    test('adds AuthInterceptor and ErrorInterceptor', () {
      final hasAuth = dio.interceptors.any((i) => i is AuthInterceptor);
      final hasError = dio.interceptors.any((i) => i is ErrorInterceptor);

      expect(hasAuth, isTrue);
      expect(hasError, isTrue);
    });
  });
}

/// A mock HttpClientAdapter that returns predetermined responses.
/// Like a Laravel Http::fake() handler that returns scripted responses.
class _MockAdapter implements HttpClientAdapter {
  final int statusCode;
  final dynamic data;
  final bool throwConnectionError;
  final bool isStringResponse;

  _MockAdapter({
    this.statusCode = 200,
    this.data,
    this.throwConnectionError = false,
    this.isStringResponse = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (throwConnectionError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Connection refused',
      );
    }

    final String responseData;
    if (isStringResponse && data is String) {
      responseData = data;
    } else if (data is Map || data is List) {
      responseData = json.encode(data);
    } else {
      responseData = data?.toString() ?? '';
    }

    return ResponseBody.fromString(
      responseData,
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
