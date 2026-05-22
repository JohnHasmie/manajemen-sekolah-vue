/// api_settings_services.dart - Manages user profile and school settings.
/// Like Laravel's ProfileController + SchoolSettingsController / Vue's settings store.
///
/// Handles password changes, profile CRUD, lesson hour session management,
/// and school-level configuration.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for user profile and school settings API calls.
/// Like a combined Laravel controller handling /profile and /school/settings routes.
/// In Vue terms, this is a settings store module managing user prefs and school config.
class ApiSettingsService {
  /// Updates the current user's password.
  /// Like Laravel's `Hash::check()` + `$user->update(['password' => ...])`.
  /// Throws on validation failure (e.g., wrong old password).
  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await dioClient.put(
        '/profile/password',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the current user's profile. Like `auth()->user()` in Laravel.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dioClient.get('/profile');
      return response.data;
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Updates the current user's profile fields.
  /// Like `auth()->user()->update($data)` in Laravel.
  Future<void> updateProfile({
    required String name,
    required String? phoneNumber,
    required String? address,
  }) async {
    try {
      await dioClient.put(
        '/profile',
        data: {'name': name, 'phone_number': phoneNumber, 'address': address},
      );
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Fetches lesson hour settings (daily time slots for each period).
  /// Like `LessonHourSetting::all()` in Laravel grouped by day.
  Future<List<dynamic>> getLessonHourSettings() async {
    try {
      final response = await dioClient.get('/lesson-hour-settings');

      final result = response.data;
      if (result is List) {
        return result;
      }
      return [];
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Creates a new lesson session time slot for a specific day.
  /// Like `LessonHourSetting::create($data)` in Laravel.
  Future<void> createLessonSession({
    required String dayId,
    required int hourNumber,
    required String startTime,
    required String endTime,
  }) async {
    try {
      await dioClient.post(
        '/lesson-hour-settings',
        data: {
          'day_id': dayId,
          'hour_number': hourNumber,
          'start_time': startTime,
          'end_time': endTime,
        },
      );
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Updates an existing lesson session's time and hour number.
  /// Like `LessonHourSetting::find($id)->update($data)` in Laravel.
  Future<void> updateLessonSession({
    required String id,
    required String startTime,
    required String endTime,
    required int hourNumber,
  }) async {
    try {
      await dioClient.put(
        '/lesson-hour-settings/$id',
        data: {
          'start_time': startTime,
          'end_time': endTime,
          'hour_number': hourNumber,
        },
      );
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Deletes a lesson session slot by ID.
  /// Like `LessonHourSetting::find($id)->delete()` in Laravel.
  Future<void> deleteLessonSession(String id) async {
    try {
      await dioClient.delete('/lesson-hour-settings/$id');
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Bulk deletes a list of lesson sessions by ID in a single
  /// round-trip. Used by the long-press multi-select flow in
  /// Sistem → Waktu Pembelajaran.
  ///
  /// Returns the parsed response so the caller can show a precise
  /// toast — typically `{ deleted_count, blocked: [{id, reason}] }`.
  Future<Map<String, dynamic>> bulkDeleteLessonHours(List<String> ids) async {
    try {
      final response = await dioClient.post(
        '/lesson-hour-settings/bulk-delete',
        data: {'ids': ids},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Copies all lesson sessions from one day to another. When
  /// [replaceExisting] is true, any sessions already on the target day
  /// are cleared first (rows tied to active teaching schedules are
  /// skipped and reported in the response's `blocked` list).
  Future<Map<String, dynamic>> copyLessonHoursToDay({
    required String fromDayId,
    required String toDayId,
    bool replaceExisting = false,
  }) async {
    try {
      final response = await dioClient.post(
        '/lesson-hour-settings/copy',
        data: {
          'from_day_id': fromDayId,
          'to_day_id': toDayId,
          'replace_existing': replaceExisting,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Fetches the school's general settings (name, address, jenjang/level).
  /// Like `School::find($schoolId)->settings` in Laravel.
  Future<Map<String, dynamic>> getSchoolSettings() async {
    try {
      final response = await dioClient.get('/school/settings');
      return response.data;
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Updates school-level settings (jenjang, name, address).
  /// Like `School::find($id)->update($data)` in Laravel.
  /// Only provided fields are updated (partial update).
  Future<void> updateSchoolSettings({
    String? jenjang,
    String? schoolName,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (jenjang != null) body['jenjang'] = jenjang;
      if (schoolName != null) body['school_name'] = schoolName;
      if (address != null) body['address'] = address;

      await dioClient.post('/school/settings', data: body);
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }
}
