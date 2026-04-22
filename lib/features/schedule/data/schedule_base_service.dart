/// schedule_base_service.dart - Basic CRUD operations for
/// schedule-related entities (days, semesters, academic years,
/// lesson hours). Like Laravel's basic resource endpoints: Day,
/// Semester, AcademicYear, LessonHour.
library;

import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Service for basic schedule-related CRUD operations.
class ScheduleBaseService {
  /// Fetches the list of school days (hari).
  /// Like `Day::all()` in Laravel.
  Future<List<dynamic>> getDays() async {
    final response = await dioClient.get('/day');
    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches the list of semesters.
  /// Like `Semester::all()` in Laravel.
  Future<List<dynamic>> getSemester() async {
    final response = await dioClient.get('/semester');
    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches academic years.
  /// Like `AcademicYear::all()` in Laravel.
  Future<List<dynamic>> getAcademicYear() async {
    final response = await dioClient.get('/academic-year');
    final result = response.data;
    return result is List ? result : [];
  }

  /// Fetches lesson hour slots (jam pelajaran).
  /// Like `LessonHour::all()` in Laravel.
  Future<List<dynamic>> getJamPelajaran() async {
    final response = await dioClient.get('/lesson-hour');
    final result = response.data;
    return result is List ? result : [];
  }

  /// Creates a new lesson hour slot.
  /// Like `LessonHour::create($data)` in Laravel.
  Future<dynamic> addJamPelajaran(Map<String, dynamic> data) async {
    final response = await dioClient.post('/lesson-hour', data: data);
    return response.data;
  }

  /// Fetches lesson hours filtered by day, semester, class, and
  /// academic year. Like `LessonHour::where(...)->get()` in Laravel.
  Future<List<dynamic>> getJamPelajaranByFilter({
    String? dayId,
    String? semesterId,
    String? classId,
    String? academicYear,
  }) async {
    String url = '/lesson-hour-filter?';
    if (dayId != null) url += 'day_id=$dayId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (classId != null) url += 'class_id=$classId&';
    if (academicYear != null) url += 'academic_year_id=$academicYear&';

    final response = await dioClient.get(url);
    final result = response.data;
    return result is List ? result : [];
  }

  /// Gets the current semester based on the server date (Ganjil/Genap).
  /// Like a Laravel helper that determines the active semester from
  /// today's date.
  Future<Map<String, dynamic>> getDateBasedSemester() async {
    try {
      final response = await dioClient.get('/semester/current-date-based');
      final result = response.data;
      return result is Map<String, dynamic> ? result : {};
    } catch (e) {
      AppLogger.error('schedule', 'Error getting date based semester: $e');
      return {};
    }
  }
}
