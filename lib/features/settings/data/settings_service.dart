/// api_settings_services.dart - Manages user profile and school settings.
/// Like Laravel's ProfileController + SchoolSettingsController / Vue's settings store.
///
/// Handles password changes, profile CRUD, lesson hour session management,
/// and school-level configuration.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Service for user profile and school settings API calls.
/// Like a combined Laravel controller handling /profile and /school/settings routes.
/// In Vue terms, this is a settings store module managing user prefs and school
/// config.
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
  ///
  /// Side-effect: hydrates the global [LanguageProvider] from the
  /// `preferred_language` field in the response. This means a user
  /// who picked English on their phone gets English on a freshly-
  /// installed tablet as soon as they open the app and the profile
  /// loads — no manual re-pick needed. `hydrateFromServer` is a
  /// no-op when the value is null, unsupported, or already matches,
  /// and crucially does NOT push the same value back to the server,
  /// so there's no infinite-PATCH loop.
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await dioClient.get('/profile');
      final data = response.data;

      // Pipe the server's saved preference into the global provider.
      // Wrapped in a try/catch so a malformed payload (older API
      // version, network proxy stripping fields, etc.) never breaks
      // the profile screen itself.
      try {
        if (data is Map<String, dynamic>) {
          final code = data['preferred_language'];
          await languageProvider.hydrateFromServer(
            code is String ? code : null,
          );
        }
      } catch (e) {
        AppLogger.warning('settings', 'Language hydrate failed: $e');
      }

      return data;
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }

  /// Persists the user's UI-language preference server-side so it
  /// follows them across devices and survives logout.
  ///
  /// Why this exists alongside the local SharedPreferences write
  /// in `LanguageProvider.setLanguage`:
  /// - SharedPreferences is per-device. If the user installs the app
  ///   on a tablet at school, they shouldn't have to re-pick.
  /// - The backend reads this column on every API request (see
  ///   `SetLocaleFromHeader` middleware) to localise inbox labels,
  ///   validation messages, and mail templates.
  ///
  /// Pass [code] = 'id' or 'en' to pin, or `null` to clear the saved
  /// choice and let the server fall back to the `Accept-Language`
  /// header. Returns silently on failure — the local prefs write
  /// already happened, so UX continues; we just log so it surfaces
  /// in monitoring if backend sync breaks.
  Future<void> updatePreferredLanguage(String? code) async {
    try {
      await dioClient.patch(
        '/profile/language',
        data: {'preferred_language': code},
      );
    } catch (e) {
      // Non-fatal: local prefs already updated, app UX unaffected.
      // Server will catch up on next explicit pick or manual sync.
      AppLogger.error('settings', e);
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

  /// Updates school-level settings (education_level, name, address).
  /// Like `School::find($id)->update($data)` in Laravel.
  /// Only provided fields are updated (partial update).
  ///
  /// Backend rename: `schools.jenjang` → `schools.education_level`,
  /// `schools.school_name` → `schools.name`.
  Future<void> updateSchoolSettings({
    String? jenjang,
    String? schoolName,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (jenjang != null) body['education_level'] = jenjang;
      if (schoolName != null) body['name'] = schoolName;
      if (address != null) body['address'] = address;

      await dioClient.post('/school/settings', data: body);
    } catch (e) {
      AppLogger.error('settings', e);
      rethrow;
    }
  }
}
