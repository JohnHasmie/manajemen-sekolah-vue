// excel_presence_service.dart - Export student attendance/presence (absensi) data to Excel.
// Like Laravel's Maatwebsite/Excel PresenceExport with backend validation.
// Handles attendance statuses: hadir, terlambat, izin, sakit, alpha.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Service for exporting student attendance (absensi/presence) data to Excel.
/// Similar to Laravel's `Excel::download(new AttendanceExport, 'Absensi.xlsx')`.
///
/// Supports filter-based export (by class, subject, date range) and validates
/// attendance status against an allowlist (hadir/terlambat/izin/sakit/alpha).
///
/// Also provides helper methods for status labels, date formatting, and
/// day name translation -- like Laravel model accessors or helper functions.
class ExcelPresenceService {
  static String get baseUrl => '/attendance';

  /// Export attendance data to Excel via backend POST to `/attendance/export`.
  /// [presenceData] - list of attendance records. [filters] - optional filters.
  /// Side effects: saves file to device, opens it, shows SnackBar.
  static Future<void> exportPresenceToExcel({
    required List<dynamic> presenceData,
    required BuildContext context,
    Map<String, dynamic> filters = const {},
  }) async {
    

    try {
      AppLogger.debug('attendance', 'Starting export with ${presenceData.length} records');

      // Validasi data
      if (presenceData.isEmpty) {
        throw Exception('No attendance data to export');
      }

      final response = await dioClient.post<List<int>>(
        '$baseUrl/export',
        data: {'presenceData': presenceData, 'filters': filters},
        options: Options(responseType: ResponseType.bytes),
      );

      AppLogger.debug('attendance', 'Response status: ${response.statusCode}');

      // Simpan file Excel
      final Directory directory = await getApplicationDocumentsDirectory();
      final String filePath =
          '${directory.path}/Data_Absensi_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      final File file = File(filePath);
      await file.writeAsBytes(response.data ?? []);

      AppLogger.info('attendance', 'File saved to: $filePath');

      // Buka file
      final result = await OpenFile.open(filePath);
      AppLogger.debug('attendance', 'Open file result: $result');

      if (context.mounted) {
                SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
                'en': 'Presence data exported successfully',
                'id': 'Data absensi berhasil diexport',
              }));
      }
    } catch (e) {
      AppLogger.error('attendance', e);
      if (context.mounted) {
                SnackBarUtils.showError(context, languageProvider.getTranslatedText({
                'en': 'Failed to export data: $e',
                'id': 'Gagal mengexport data: $e',
              }));
      }
    }
  }

  /// Server-side validation via POST to `/attendance/validate`.
  /// Like submitting to a Laravel FormRequest for authoritative validation.
  static Future<List<Map<String, dynamic>>> validatePresenceDataBackend(
    List<dynamic> presenceData,
  ) async {
    try {
      final response = await dioClient.post(
        '$baseUrl/validate',
        data: {'presenceData': presenceData},
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

  /// Local fallback validation for attendance data.
  /// Checks required fields and validates status against the allowlist:
  /// ['hadir', 'terlambat', 'izin', 'sakit', 'alpha'].
  /// Like a Laravel FormRequest with `Rule::in([...])` validation.
  static List<Map<String, dynamic>> validatePresenceData(
    List<dynamic> presenceData,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < presenceData.length; i++) {
      final presence = presenceData[i];
      final Map<String, dynamic> validatedPresence = {};

      // Validasi field required
      if (presence['nis'] == null || presence['nis'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: NIS tidak boleh kosong');
      } else {
        validatedPresence['nis'] = presence['nis'];
      }

      if (presence['student_name'] == null ||
          presence['student_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama siswa tidak boleh kosong');
      } else {
        validatedPresence['student_name'] = presence['student_name'];
      }

      if (presence['class_name'] == null ||
          presence['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedPresence['class_name'] = presence['class_name'];
      }

      if (presence['subject_name'] == null ||
          presence['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedPresence['subject_name'] = presence['subject_name'];
      }

      if (presence['date'] == null || presence['date'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Tanggal tidak boleh kosong');
      } else {
        validatedPresence['date'] = presence['date'];
      }

      if (presence['status'] == null || presence['status'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Status tidak boleh kosong');
      } else {
        final status = presence['status'].toString().toLowerCase();
        final allowedStatus = ['hadir', 'terlambat', 'izin', 'sakit', 'alpha'];
        if (!allowedStatus.contains(status)) {
          errors.add(
            'Baris ${i + 1}: Status harus salah satu dari: hadir, terlambat, izin, sakit, alpha',
          );
        } else {
          validatedPresence['status'] = status;
        }
      }

      // Field optional
      validatedPresence['notes'] = presence['notes'] ?? '';
      validatedPresence['teacher_name'] = presence['teacher_name'] ?? '';
      validatedPresence['lesson_hour'] = presence['lesson_hour'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedPresence);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  /// Get a localized label for attendance status codes.
  /// Like Laravel's `__('attendance.hadir')` translation helper.
  static String getStatusLabel(
    String status,
    LanguageProvider languageProvider,
  ) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'terlambat':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      case 'izin':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'sakit':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'alpha':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      default:
        return status;
    }
  }

  /// Format a DateTime to 'YYYY-MM-DD' string for export. Like Carbon's `format('Y-m-d')`.
  static String formatDateForExport(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get localized day name from a DateTime. Like Carbon's `translatedFormat('l')`.
  static String getDayName(DateTime date, LanguageProvider languageProvider) {
    final days = [
      languageProvider.getTranslatedText({'en': 'Sunday', 'id': 'Minggu'}),
      languageProvider.getTranslatedText({'en': 'Monday', 'id': 'Senin'}),
      languageProvider.getTranslatedText({'en': 'Tuesday', 'id': 'Selasa'}),
      languageProvider.getTranslatedText({'en': 'Wednesday', 'id': 'Rabu'}),
      languageProvider.getTranslatedText({'en': 'Thursday', 'id': 'Kamis'}),
      languageProvider.getTranslatedText({'en': 'Friday', 'id': 'Jumat'}),
      languageProvider.getTranslatedText({'en': 'Saturday', 'id': 'Sabtu'}),
    ];
    return days[date.weekday % 7];
  }
}
