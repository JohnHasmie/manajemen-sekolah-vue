import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiSettingsService {
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      throw Exception(
        responseBody['error'] ??
            'Request failed with status: ${response.statusCode}',
      );
    }
  }

  // Update Password
  static Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile/password'),
        headers: await _getHeaders(),
        body: json.encode({
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );
      _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  // Get Lesson Hour Settings (Now returns daily slots)
  static Future<List<dynamic>> getLessonHourSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lesson-hour-settings'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      if (result is List) {
        return result;
      }
      return [];
    } catch (e) {
      print('Error getting lesson hour settings: $e');
      rethrow;
    }
  }

  // Create Lesson Session (Slot)
  static Future<void> createLessonSession({
    required String dayId,
    required int hourNumber,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lesson-hour-settings'),
        headers: await _getHeaders(),
        body: json.encode({
          'day_id': dayId,
          'hour_number': hourNumber,
          'start_time': startTime,
          'end_time': endTime,
        }),
      );
      _handleResponse(response);
    } catch (e) {
      print('Error creating lesson session: $e');
      rethrow;
    }
  }

  // Update Lesson Session
  static Future<void> updateLessonSession({
    required String id,
    required String startTime,
    required String endTime,
    required int hourNumber,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/lesson-hour-settings/$id'),
        headers: await _getHeaders(),
        body: json.encode({
          'start_time': startTime,
          'end_time': endTime,
          'hour_number': hourNumber,
        }),
      );
      _handleResponse(response);
    } catch (e) {
      print('Error updating lesson session: $e');
      rethrow;
    }
  }

  // Delete Lesson Session
  static Future<void> deleteLessonSession(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/lesson-hour-settings/$id'),
        headers: await _getHeaders(),
      );
      _handleResponse(response);
    } catch (e) {
      print('Error deleting lesson session: $e');
      rethrow;
    }
  }

  // Get School Settings
  static Future<Map<String, dynamic>> getSchoolSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/school/settings'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result;
    } catch (e) {
      print('Error getting school settings: $e');
      rethrow;
    }
  }

  // Update School Settings (General)
  static Future<void> updateSchoolSettings({
    String? jenjang,
    String? schoolName,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (jenjang != null) body['jenjang'] = jenjang;
      if (schoolName != null) body['school_name'] = schoolName;
      if (address != null) body['address'] = address;

      final response = await http.put(
        Uri.parse('$baseUrl/school/settings'),
        headers: await _getHeaders(),
        body: json.encode(body),
      );
      _handleResponse(response);
    } catch (e) {
      print('Error updating school settings: $e');
      rethrow;
    }
  }
}
