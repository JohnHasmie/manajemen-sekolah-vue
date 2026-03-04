import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';

class ApiTourService {
  static String get baseUrl => ApiService.baseUrl;

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
