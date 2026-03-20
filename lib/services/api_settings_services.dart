/// api_settings_services.dart - Manages user profile and school settings.
/// Like Laravel's ProfileController + SchoolSettingsController / Vue's settings store.
///
/// Handles password changes, profile CRUD, lesson hour session management,
/// and school-level configuration. All methods are static.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';

/// Service for user profile and school settings API calls.
/// Like a combined Laravel controller handling /profile and /school/settings routes.
/// In Vue terms, this is a settings store module managing user prefs and school config.
class ApiSettingsService {
  /// Base URL from central config.
  static String get baseUrl => ApiService.baseUrl;

  /// Auth headers with Bearer token.
  static Future<Map<String, String>> _getHeaders() => ApiService.getHeaders();

  /// Parses JSON response and throws on non-2xx status.
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

  /// Updates the current user's password.
  /// Like Laravel's `Hash::check()` + `$user->update(['password' => ...])`.
  /// Throws on validation failure (e.g., wrong old password).
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

  /// Fetches the current user's profile. Like `auth()->user()` in Laravel.
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
      );
      final result = _handleResponse(response);
      return result;
    } catch (e) {
      print('Error getting profile: $e');
      rethrow;
    }
  }

  /// Updates the current user's profile fields.
  /// Like `auth()->user()->update($data)` in Laravel.
  static Future<void> updateProfile({
    required String name,
    required String? phoneNumber,
    required String? address,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: await _getHeaders(),
        body: json.encode({
          'name': name,
          'phone_number': phoneNumber,
          'address': address,
        }),
      );
      _handleResponse(response);
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  /// Fetches lesson hour settings (daily time slots for each period).
  /// Like `LessonHourSetting::all()` in Laravel grouped by day.
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

  /// Creates a new lesson session time slot for a specific day.
  /// Like `LessonHourSetting::create($data)` in Laravel.
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

  /// Updates an existing lesson session's time and hour number.
  /// Like `LessonHourSetting::find($id)->update($data)` in Laravel.
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

  /// Deletes a lesson session slot by ID.
  /// Like `LessonHourSetting::find($id)->delete()` in Laravel.
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

  /// Fetches the school's general settings (name, address, jenjang/level).
  /// Like `School::find($schoolId)->settings` in Laravel.
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

  /// Updates school-level settings (jenjang, name, address).
  /// Like `School::find($id)->update($data)` in Laravel.
  /// Only provided fields are updated (partial update).
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

      final response = await http.post(
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
