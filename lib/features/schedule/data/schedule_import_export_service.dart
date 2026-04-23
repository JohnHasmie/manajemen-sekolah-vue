/// schedule_import_export_service.dart - Excel import/export and template
/// download for teaching schedules.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Service for Excel import/export operations on schedules.
class ScheduleImportExportService {
  /// Downloads the Excel import template for teaching schedules.
  /// Like Laravel's file download response. Returns the local file path.
  Future<String> downloadScheduleTemplate() async {
    try {
      final response = await dioClient.get<List<int>>(
        '/teaching-schedule/template',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/template_import_jadwal_mengajar.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  /// Imports schedules from an Excel file via multipart upload.
  /// Like Laravel's `Excel::import()` with Maatwebsite package.
  /// [invalidateCache] - Callback to invalidate schedule cache after import.
  Future<Map<String, dynamic>> importSchedulesFromExcel(
    File file, {
    required Future<void> Function() invalidateCache,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        '/teaching-schedule/import',
        data: formData,
      );

      AppLogger.debug(
        'schedule',
        'Import Schedule Response Status: ${response.statusCode}',
      );
      AppLogger.debug(
        'schedule',
        'Import Schedule Response Body: ${response.data}',
      );

      await invalidateCache();
      return response.data;
    } catch (e) {
      AppLogger.error('schedule', 'Import schedule error details: $e');
      throw Exception('Import error: $e');
    }
  }

  /// Debug endpoint to preview Excel file parsing without importing.
  /// Like a Laravel debug/test route. Useful during development.
  Future<Map<String, dynamic>> debugExcelSchedule(File file) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await dioClient.post(
        '/debug/excel-teaching-schedule',
        data: formData,
      );

      return response.data;
    } catch (e) {
      throw Exception('Debug error: $e');
    }
  }

  /// Exports schedules to an Excel file with optional filters.
  /// Like Laravel's `Excel::download()` -- saves the file locally and
  /// returns the path.
  Future<String> exportSchedules({
    String? teacherId,
    String? classId,
    String? dayId,
    String? semesterId,
    String? academicYearId,
  }) async {
    try {
      String url = '/teaching-schedule/export?';
      if (teacherId != null) url += 'teacher_id=$teacherId&';
      if (classId != null) url += 'class_id=$classId&';
      if (dayId != null) url += 'day_id=$dayId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (academicYearId != null) {
        url += 'academic_year_id=$academicYearId&';
      }

      final response = await dioClient.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? [];
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath =
          '${directory.path}/jadwal_mengajar_export_$timestamp.xlsx';
      final file = File(filePath);

      await file.writeAsBytes(bytes);
      return filePath;
    } catch (e) {
      throw Exception('Failed to export schedules: $e');
    }
  }
}
