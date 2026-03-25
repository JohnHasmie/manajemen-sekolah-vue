/// api_exceptions.dart - Typed exception classes for API error handling.
/// Like Laravel's custom exception classes (e.g., AuthenticationException, ValidationException).
/// Replaces the generic `throw Exception(message)` pattern used across all services.
library;

/// Base class for all API-related exceptions.
/// Like Laravel's `HttpException` base class.
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic responseBody;

  const ApiException(this.message, {this.statusCode, this.responseBody});

  @override
  String toString() => message;
}

/// Thrown when the user's session has expired or token is invalid (401).
/// Like Laravel's `AuthenticationException`.
class AuthenticationException extends ApiException {
  const AuthenticationException(super.message, {super.statusCode, super.responseBody});
}

/// Thrown when the user doesn't have access to the requested school (403 with school context).
/// Like a custom Laravel `SchoolAccessDeniedException`.
class SchoolAccessDeniedException extends ApiException {
  const SchoolAccessDeniedException(super.message, {super.statusCode, super.responseBody});
}

/// Thrown when the server returns 403 Forbidden (non-school context).
/// Like Laravel's `AccessDeniedHttpException`.
class ForbiddenException extends ApiException {
  const ForbiddenException(super.message, {super.statusCode, super.responseBody});
}

/// Thrown when Laravel returns 422 Unprocessable Entity with validation errors.
/// Like Laravel's `ValidationException`.
class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  const ValidationException(super.message, {this.errors, super.statusCode, super.responseBody});
}

/// Thrown for 5xx server errors.
/// Like Laravel's `HttpServerException`.
class ServerException extends ApiException {
  const ServerException(super.message, {super.statusCode, super.responseBody});
}

/// Thrown for network-related errors (timeout, no internet, DNS failure).
/// Like a connection refused error in Laravel's HTTP client.
class NetworkException extends ApiException {
  const NetworkException(super.message, {super.statusCode, super.responseBody});
}

/// Thrown when the AI service returns 429 Too Many Requests.
/// Like Laravel's `ThrottleRequestsException`.
class RateLimitException extends ApiException {
  const RateLimitException(super.message, {super.statusCode, super.responseBody});
}
