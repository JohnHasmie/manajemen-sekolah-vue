// excel_schedule_service.dart - Export teaching schedule (jadwal mengajar) to Excel.
// Like Laravel's Maatwebsite/Excel ScheduleExport with day-name translation.
// Handles bilingual day names (Senin/Monday) based on the app's language setting.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Service for exporting teaching schedules (jadwal mengajar) to Excel.
/// Similar to `Excel::download(new ScheduleExport($data), 'Jadwal.xlsx')` in Laravel.
///
/// Unique feature: translates day names based on the current language before
/// sending to the backend, so the exported file matches the user's locale.
///
/// Supports flexible field name mapping for schedule data that can come from
/// different API response formats (e.g., 'day_name' vs 'hari_nama', nested
/// 'day.name' vs flat 'day_name'). Like Laravel's `$request->input('key', $fallback)`.
class ExcelScheduleService {
  static String get baseUrl => '/teaching-schedule';

  /// Export teaching schedule data to Excel via backend POST to `/teaching-schedule/export`.
  /// Translates day names to the user's current language before sending.
  /// [schedules] - list of schedule records. [context] - for SnackBar and i18n.
  static Future<void> exportSchedulesToExcel({
    required List<dynamic> schedules,
    required BuildContext context,
  }) async {
    

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateScheduleData(schedules);

      // Translate day names based on selected language
      final currentLang = languageProvider.currentLanguage;
      for (var item in validatedData) {
        item['day_name'] = _translateDay(item['day_name'], currentLang);
      }

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'schedules': validatedData},
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory untuk menyimpan file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Data_Jadwal_Mengajar_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Simpan file yang didownload
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Buka file
      await OpenFile.open(filePath);

            SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
              'en': 'Schedule data exported successfully',
              'id': 'Data jadwal mengajar berhasil diexport',
            }));
    } catch (e) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'Failed to export data: $e',
              'id': 'Gagal mengexport data: $e',
            }));
    }
  }

  /// Download a schedule import template from GET `/teaching-schedule/template`.
  /// Like Laravel returning `Excel::download(new ScheduleTemplateExport)`.
  static Future<void> downloadTemplate(BuildContext context) async {
    

    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/template',
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory untuk menyimpan file
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Template_Import_Jadwal_Mengajar.xlsx';

      // Simpan file yang didownload
      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      // Buka file
      await OpenFile.open(filePath);

            SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
              'en': 'Template downloaded successfully',
              'id': 'Template berhasil diunduh',
            }));
    } catch (e) {
            SnackBarUtils.showError(context, languageProvider.getTranslatedText({
              'en': 'Failed to download template: $e',
              'id': 'Gagal mengunduh template: $e',
            }));
    }
  }

  /// Server-side schedule validation via POST to `/teaching-schedule/validate`.
  static Future<List<Map<String, dynamic>>> validateScheduleDataBackend(
    List<dynamic> schedules,
  ) async {
    try {
      final response = await dioClient.post(
        '$baseUrl/validate',
        data: {'schedules': schedules},
      );

      final responseData = response.data;

      if (responseData is Map<String, dynamic> && responseData['success'] == true) {
        return List<Map<String, dynamic>>.from(responseData['validatedData']);
      } else {
        throw Exception(responseData['message'] ?? 'Validation failed');
      }
    } catch (e) {
      throw Exception('Validation error: $e');
    }
  }

  /// Local fallback validation for schedule data. Handles multiple field name
  /// conventions (e.g., 'teacher_name' vs 'guru_nama', nested 'day.name' vs
  /// flat 'day_name'). Like a Laravel FormRequest with complex input normalization.
  /// Validates: teacher, subject, class, day, lesson_hour, semester, academic_year.
  static List<Map<String, dynamic>> validateScheduleData(
    List<dynamic> schedules,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < schedules.length; i++) {
      final schedule = schedules[i];
      final Map<String, dynamic> validatedSchedule = {};

      // Validasi field required
      var teacherName = schedule['teacher_name'] ?? schedule['guru_nama'];
      if (teacherName == null || teacherName.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama guru tidak boleh kosong');
      } else {
        validatedSchedule['teacher_name'] = teacherName;
      }

      var subjectName =
          schedule['subject_name'] ?? schedule['mata_pelajaran_nama'];
      if (subjectName == null || subjectName.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama mata pelajaran tidak boleh kosong');
      } else {
        validatedSchedule['subject_name'] = subjectName;
      }

      var className = schedule['class_name'] ?? schedule['kelas_nama'];
      if (className == null || className.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama kelas tidak boleh kosong');
      } else {
        validatedSchedule['class_name'] = className;
      }

      final dayName =
          schedule['day_name'] ??
          schedule['hari_nama'] ??
          schedule['day']?['name'] ??
          schedule['day']?['nama'] ??
          schedule['hari']?['name'] ??
          schedule['hari']?['nama'] ??
          '';

      if (dayName.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Hari tidak boleh kosong');
      } else {
        validatedSchedule['day_name'] = dayName;
      }

      final lessonHour =
          schedule['lesson_hour'] ??
          schedule['hour_number'] ??
          schedule['jam_ke'];
      if (lessonHour == null) {
        errors.add('Baris ${i + 1}: Jam ke tidak boleh kosong');
      } else {
        validatedSchedule['lesson_hour'] = lessonHour;
      }

      var semesterName = schedule['semester_name'] ?? schedule['semester'];
      // Handle nested semester object if exists
      if (semesterName == null && schedule['semester'] is Map) {
        semesterName = schedule['semester']['name'];
      }
      if (semesterName == null || semesterName.toString().isEmpty) {
        errors.add('Baris ${i + 1}: Semester tidak boleh kosong');
      } else {
        validatedSchedule['semester_name'] = semesterName;
      }

      if (schedule['academic_year'] == null ||
          schedule['academic_year'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Tahun ajaran tidak boleh kosong');
      } else {
        validatedSchedule['academic_year'] = schedule['academic_year'];
      }

      // Field optional
      validatedSchedule['start_time'] =
          schedule['start_time'] ?? schedule['jam_mulai'];
      validatedSchedule['end_time'] =
          schedule['end_time'] ?? schedule['jam_selesai'];

      if (errors.isEmpty) {
        validatedData.add(validatedSchedule);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  /// Translate a day name between English and Indonesian.
  /// [targetLang] - 'id' for Indonesian, 'en' for English.
  /// Like Laravel's `__('days.Monday')` localization but done as a simple map lookup.
  static String _translateDay(String dayName, String targetLang) {
    const enToId = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };
    const idToEn = {
      'Senin': 'Monday',
      'Selasa': 'Tuesday',
      'Rabu': 'Wednesday',
      'Kamis': 'Thursday',
      'Jumat': 'Friday',
      'Sabtu': 'Saturday',
      'Minggu': 'Sunday',
    };

    if (targetLang == 'id') {
      return enToId[dayName] ?? dayName;
    } else {
      return idToEn[dayName] ?? dayName;
    }
  }
}
