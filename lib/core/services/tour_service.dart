/// api_tour_services.dart - Manages onboarding tour/walkthrough state.
/// Like Laravel's TourController / Vue's tour store module.
///
/// Tracks whether a user has seen the onboarding tour for their role,
/// saves progress (last step reached), and marks tours as completed.
/// Tours are platform-specific (mobile vs web) and role-specific.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';

/// Service for onboarding tour API calls.
/// Like a small Laravel controller with status/complete/save-progress actions.
/// In Vue terms, this is a simple store module for managing first-time user guidance.
class ApiTourService {
  /// Base URL from central config.
  static String get baseUrl => ApiService.baseUrl;

  /// Parses JSON response. Handles empty body (returns empty map).
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return json.decode(response.body);
    } else {
      String errorMessage =
          'Request failed with status: ${response.statusCode}';
      try {
        final body = json.decode(response.body);
        errorMessage = body['error'] ?? errorMessage;
      } catch (e) {
        // use default error message
      }
      throw Exception(errorMessage);
    }
  }

  /// Check if the authenticated user should see the tour.
  static Future<Map<String, dynamic>> getTourStatus({
    required String platform,
    required String role,
    required String name,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/tours/status?platform=$platform&role=$role&name=$name',
      ),
      headers: await ApiService.getHeaders(),
    );

    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Mark tour as completed.
  static Future<Map<String, dynamic>> completeTour({
    required String tourId,
    required String platform,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tours/complete'),
      headers: await ApiService.getHeaders(),
      body: json.encode({'tour_id': tourId, 'platform': platform}),
    );

    return _handleResponse(response) as Map<String, dynamic>;
  }

  /// Save tour progress (last step reached).
  static Future<Map<String, dynamic>> saveTourProgress({
    required String tourId,
    required String platform,
    required int lastStep,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tours/save-progress'),
      headers: await ApiService.getHeaders(),
      body: json.encode({
        'tour_id': tourId,
        'platform': platform,
        'last_step': lastStep,
      }),
    );

    return _handleResponse(response) as Map<String, dynamic>;
  }
}
