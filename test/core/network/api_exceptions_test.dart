/// Tests for API exception classes — verifies type hierarchy, message storage,
/// statusCode, responseBody, and toString() output.
///
/// Like testing custom Laravel exception classes to ensure they carry
/// the right data for error handlers.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';

void main() {
  group('AuthenticationException', () {
    test('implements Exception', () {
      const e = AuthenticationException('Unauthenticated');
      expect(e, isA<Exception>());
      expect(e, isA<ApiException>());
    });

    test('stores message', () {
      const e = AuthenticationException('Token expired');
      expect(e.message, 'Token expired');
    });

    test('stores statusCode and responseBody', () {
      const e = AuthenticationException(
        'Unauthenticated',
        statusCode: 401,
        responseBody: {'error': 'token_expired'},
      );
      expect(e.statusCode, 401);
      expect(e.responseBody, {'error': 'token_expired'});
    });

    test('toString returns message', () {
      const e = AuthenticationException('Unauthenticated');
      expect(e.toString(), 'Unauthenticated');
    });
  });

  group('SchoolAccessDeniedException', () {
    test('implements ApiException', () {
      const e = SchoolAccessDeniedException('No access to school');
      expect(e, isA<ApiException>());
      expect(e, isA<Exception>());
    });

    test('stores statusCode', () {
      const e = SchoolAccessDeniedException('Denied', statusCode: 403);
      expect(e.statusCode, 403);
    });

    test('toString returns message', () {
      const e = SchoolAccessDeniedException('No access');
      expect(e.toString(), 'No access');
    });
  });

  group('ForbiddenException', () {
    test('implements ApiException', () {
      const e = ForbiddenException('Forbidden');
      expect(e, isA<ApiException>());
    });

    test('stores all fields', () {
      const e = ForbiddenException(
        'Forbidden',
        statusCode: 403,
        responseBody: 'not allowed',
      );
      expect(e.message, 'Forbidden');
      expect(e.statusCode, 403);
      expect(e.responseBody, 'not allowed');
    });

    test('toString returns message', () {
      const e = ForbiddenException('Access denied');
      expect(e.toString(), 'Access denied');
    });
  });

  group('ValidationException', () {
    test('implements ApiException', () {
      const e = ValidationException('Validation failed');
      expect(e, isA<ApiException>());
    });

    test('stores errors map', () {
      const e = ValidationException(
        'The given data was invalid.',
        statusCode: 422,
        errors: {'email': {'0': 'Email is required'}},
      );
      expect(e.errors, isNotNull);
      expect(e.errors!['email'], isNotNull);
      expect(e.statusCode, 422);
    });

    test('errors defaults to null', () {
      const e = ValidationException('Validation failed');
      expect(e.errors, isNull);
    });

    test('toString returns message', () {
      const e = ValidationException('Invalid data');
      expect(e.toString(), 'Invalid data');
    });
  });

  group('ServerException', () {
    test('implements ApiException', () {
      const e = ServerException('Internal server error');
      expect(e, isA<ApiException>());
    });

    test('stores statusCode', () {
      const e = ServerException('Server error', statusCode: 500);
      expect(e.statusCode, 500);
    });

    test('toString returns message', () {
      const e = ServerException('Oops');
      expect(e.toString(), 'Oops');
    });
  });

  group('NetworkException', () {
    test('implements ApiException', () {
      const e = NetworkException('No internet');
      expect(e, isA<ApiException>());
    });

    test('stores responseBody', () {
      const e = NetworkException('Timeout', responseBody: null);
      expect(e.responseBody, isNull);
    });

    test('toString returns message', () {
      const e = NetworkException('Connection refused');
      expect(e.toString(), 'Connection refused');
    });
  });

  group('RateLimitException', () {
    test('implements ApiException', () {
      const e = RateLimitException('Too many requests');
      expect(e, isA<ApiException>());
    });

    test('stores statusCode 429', () {
      const e = RateLimitException('Slow down', statusCode: 429);
      expect(e.statusCode, 429);
    });

    test('toString returns message', () {
      const e = RateLimitException('Rate limited');
      expect(e.toString(), 'Rate limited');
    });
  });

  group('ApiException defaults', () {
    test('statusCode defaults to null', () {
      const e = AuthenticationException('test');
      expect(e.statusCode, isNull);
    });

    test('responseBody defaults to null', () {
      const e = ServerException('test');
      expect(e.responseBody, isNull);
    });
  });
}
