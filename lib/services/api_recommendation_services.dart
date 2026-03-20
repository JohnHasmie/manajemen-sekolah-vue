/// api_recommendation_services.dart - Interfaces with the AI recommendation engine.
/// Like a Laravel service that calls an external AI microservice / Vue's AI store module.
///
/// This service communicates with a separate AI API (KamillLabs Edu AI), not the main
/// Laravel backend. It handles AI-powered teaching recommendations: generating them
/// (async via job polling), listing, updating status, and getting class summaries.
///
/// Key patterns:
/// - Async job processing: generate returns 202 with a job_id, then poll until done
/// - Rate limiting: 429 responses throw [RateLimitException]
/// - Separate auth headers (no X-School-ID, only Bearer token)
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for AI-powered teaching recommendation API calls.
/// Talks to a separate microservice (KamillLabs Edu AI), not the main Laravel backend.
/// Like a Laravel service class that uses `Http::baseUrl()` to call an external API,
/// or a Vue composable that wraps a dedicated Axios instance for an AI service.
///
/// Key difference from other services: uses [_aiBaseUrl] instead of [ApiService.baseUrl],
/// and has its own [_getAiHeaders] without X-School-ID.
class ApiRecommendationService {
  /// Base URL for the AI microservice. Separate from the main Laravel API.
  /// Like having a second `API_BASE_URL` in your Laravel `.env` file.
  static const String _aiBaseUrl = 'https://edu-ai-api.kamillabs.com/api';

  /// Headers for KamillLabs AI API (Bearer token only, no X-School-ID)
  static Future<Map<String, String>> _getAiHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Parses JSON response with special handling for 429 (rate limit) and 500 errors.
  /// Unlike main API's handler, this throws [RateLimitException] for 429 responses.
  /// Like a custom Axios interceptor that maps specific HTTP codes to exception types.
  static dynamic _handleResponse(http.Response response) {
    final body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else if (response.statusCode == 429) {
      final message = body['message'] ?? 'Rate limit exceeded';
      throw RateLimitException(message, body);
    } else if (response.statusCode == 422) {
      final message = body['message'] ?? 'Validation error';
      throw Exception(message);
    } else if (response.statusCode == 500) {
      if (kDebugMode) {
        print('🔴 Server Error 500: ${response.body}');
      }
      throw Exception('Server sedang bermasalah. Coba lagi nanti.');
    } else {
      throw Exception(
        body['message'] ?? body['error'] ?? 'Request failed (${response.statusCode})',
      );
    }
  }

  // ==================== RECOMMENDATIONS ====================

  /// Generate recommendations for a class
  /// Returns 202 with job_id for async processing, or 200 with data
  static Future<Map<String, dynamic>> generateForClass({
    required String teacherId,
    required String classId,
    required String subjectId,
    String? triggerSource,
    bool forceRegenerate = false,
    bool? includeOnTrack,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_aiBaseUrl/recommendations/generate'),
          headers: await _getAiHeaders(),
          body: json.encode({
            'teacher_id': teacherId,
            'class_id': classId,
            'subject_id': subjectId,
            if (triggerSource != null) 'trigger_source': triggerSource,
            if (forceRegenerate) 'force_regenerate': true,
            if (includeOnTrack != null) 'include_on_track': includeOnTrack,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (kDebugMode) {
      print('🤖 Generate recommendations: ${response.statusCode}');
      print('🤖 Request body sent: ${json.encode({
        'teacher_id': teacherId,
        'class_id': classId,
        'subject_id': subjectId,
        if (triggerSource != null) 'trigger_source': triggerSource,
        if (forceRegenerate) 'force_regenerate': true,
        if (includeOnTrack != null) 'include_on_track': includeOnTrack,
      })}');
      print('🤖 Response body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
    }

    final body = json.decode(response.body);

    if (response.statusCode == 202) {
      // Async processing - return job info
      return {
        'async': true,
        'job_id': body['data']?['job_id'] ?? body['job_id'],
        'poll_url': body['data']?['poll_url'] ?? body['poll_url'],
        'message': body['message'] ?? 'Processing...',
      };
    } else if (response.statusCode == 429) {
      throw RateLimitException(
        body['message'] ?? 'Rate limit exceeded',
        body,
      );
    }

    return {
      'async': false,
      'data': body,
    };
  }

  /// Generate recommendations for a single student
  static Future<Map<String, dynamic>> generateForStudent({
    required String teacherId,
    required String classId,
    required String subjectId,
    required String studentId,
    bool forceRegenerate = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_aiBaseUrl/recommendations/generate-student'),
          headers: await _getAiHeaders(),
          body: json.encode({
            'teacher_id': teacherId,
            'class_id': classId,
            'subject_id': subjectId,
            'student_id': studentId,
            if (forceRegenerate) 'force_regenerate': true,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (kDebugMode) {
      print('🤖 Generate student recommendation: ${response.statusCode}');
    }

    final body = json.decode(response.body);

    if (response.statusCode == 202) {
      return {
        'async': true,
        'job_id': body['data']?['job_id'] ?? body['job_id'],
        'poll_url': body['data']?['poll_url'] ?? body['poll_url'],
        'message': body['message'] ?? 'Processing...',
      };
    } else if (response.statusCode == 429) {
      throw RateLimitException(
        body['message'] ?? 'Rate limit exceeded',
        body,
      );
    }

    return {
      'async': false,
      'data': body,
    };
  }

  /// List recommendations with filters (paginated)
  static Future<Map<String, dynamic>> getRecommendations({
    String? teacherId,
    String? classId,
    String? studentId,
    String? subjectId,
    String? status,
    String? priority,
    String? category,
    int page = 1,
    int perPage = 15,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (teacherId != null && teacherId.isNotEmpty) params['teacher_id'] = teacherId;
    if (classId != null) params['class_id'] = classId;
    if (studentId != null) params['student_id'] = studentId;
    if (subjectId != null) params['subject_id'] = subjectId;
    if (status != null) params['status'] = status;
    if (priority != null) params['priority'] = priority;
    if (category != null) params['category'] = category;

    final uri = Uri.parse('$_aiBaseUrl/recommendations')
        .replace(queryParameters: params);

    final response = await http
        .get(uri, headers: await _getAiHeaders())
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print('📋 List recommendations: ${response.statusCode} - URL: $uri');
      print('📋 Response body: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
    }

    final body = _handleResponse(response);
    return {
      'success': true,
      'data': body['data'] ?? [],
      'meta': body['meta'],
    };
  }

  /// Get recommendation detail
  static Future<Map<String, dynamic>> getRecommendationDetail(
    String recommendationId,
  ) async {
    final response = await http
        .get(
          Uri.parse('$_aiBaseUrl/recommendations/$recommendationId'),
          headers: await _getAiHeaders(),
        )
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print('📋 Recommendation detail: ${response.statusCode}');
    }

    return _handleResponse(response);
  }

  /// Update recommendation status
  static Future<Map<String, dynamic>> updateStatus({
    required String recommendationId,
    required String status, // pending, in_progress, completed, dismissed
    String? teacherNotes,
  }) async {
    final response = await http
        .patch(
          Uri.parse('$_aiBaseUrl/recommendations/$recommendationId/status'),
          headers: await _getAiHeaders(),
          body: json.encode({
            'status': status,
            if (teacherNotes != null) 'teacher_notes': teacherNotes,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print('📋 Update status: ${response.statusCode}');
    }

    return _handleResponse(response);
  }

  /// Get class summary (aggregated recommendations by category/priority/status)
  static Future<Map<String, dynamic>> getClassSummary(String classId) async {
    final response = await http
        .get(
          Uri.parse('$_aiBaseUrl/recommendations/class/$classId/summary'),
          headers: await _getAiHeaders(),
        )
        .timeout(const Duration(seconds: 30));

    if (kDebugMode) {
      print('📊 Class summary: ${response.statusCode} - ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
    }

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    // Return empty summary on error (class may have no recommendations yet)
    return {
      'success': true,
      'data': {
        'total_recommendations': 0,
        'by_status': {},
        'by_priority': {},
        'by_category': {},
      },
    };
  }

  // ==================== AI JOB POLLING ====================

  /// Poll an AI job until completion
  /// Returns the completed job data or throws on failure
  static Future<Map<String, dynamic>> pollJobUntilComplete(
    String jobId, {
    Duration interval = const Duration(seconds: 5),
    int maxAttempts = 60,
    void Function(String status, int attempt)? onProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final response = await http
          .get(
            Uri.parse('$_aiBaseUrl/ai-jobs/$jobId'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('🔄 Poll attempt $attempt: ${response.statusCode} - ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      }

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final data = body['data'] ?? body;
        final status = data['status']?.toString().toLowerCase() ?? '';

        if (kDebugMode) {
          print('📌 Job $jobId: status=$status, progress=${data['progress'] ?? 'N/A'}, error=${data['error'] ?? 'none'}');
        }

        onProgress?.call(status, attempt);

        if (status == 'completed' || status == 'done') {
          return data;
        } else if (status == 'failed' || status == 'error') {
          throw Exception(data['error'] ?? 'AI job failed');
        }
        // still processing - wait and retry
      } else {
        if (kDebugMode) {
          print('⚠️ Poll error: ${response.statusCode} - ${response.body}');
        }
      }

      if (attempt < maxAttempts) {
        await Future.delayed(interval);
      }
    }

    throw TimeoutException('AI job timed out after $maxAttempts attempts');
  }
}

/// Custom exception for HTTP 429 (Too Many Requests) responses.
/// Like Laravel's `ThrottleRequestsException` -- carries the response body
/// so the UI can display retry information or cooldown timers.
class RateLimitException implements Exception {
  final String message;
  final Map<String, dynamic>? body;

  RateLimitException(this.message, [this.body]);

  @override
  String toString() => message;
}
