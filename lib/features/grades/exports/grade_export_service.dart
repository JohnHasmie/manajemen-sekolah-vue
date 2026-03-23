// excel_nilai_service.dart - Export student grade/score (nilai) data to Excel.
// Like Laravel's Maatwebsite/Excel NilaiExport class with FormRequest validation.
// "Nilai" means grades/scores in Indonesian school context.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Service for exporting student grade data (nilai) to Excel via the backend.
/// Similar to Laravel's `Excel::download(new NilaiExport($data), 'Data_Nilai.xlsx')`.
///
/// Supports optional [filters] for narrowing the export (class, subject, etc.),
/// like query parameters on a Laravel export route: `/grade/export?class_id=1`.
///
/// Grade types supported: UH (daily quiz), Tugas (assignment), UTS/PTS (midterm),
/// UAS/PAS (final exam).
class ExcelNilaiService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  /// Export grade data to Excel via backend POST to `/grade/export`.
  /// [nilaiData] - list of grade records. [filters] - optional filter map
  /// (e.g., class_id, subject_id). [context] - for SnackBar and i18n.
  /// Side effects: validates, downloads .xlsx, saves to device, opens file.
  static Future<void> exportNilaiToExcel({
    required List<dynamic> nilaiData,
    required BuildContext context,
    Map<String, dynamic> filters = const {},
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateNilaiData(nilaiData);

      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/grade/export'),
        headers: await ApiService.getHeaders(),
        body: jsonEncode({'nilaiData': validatedData, 'filters': filters}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Nilai_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Grade data exported successfully',
                'id': 'Data nilai berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to export grade data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to export grade data: $e',
              'id': 'Gagal mengexport data nilai: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Local validation for grade data before export.
  /// Like a Laravel FormRequest: checks required fields (nis, student_name,
  /// class_name, subject_name, type, grade) and ensures grade is 0-100.
  /// Throws with accumulated error messages if any row fails validation.
  static List<Map<String, dynamic>> validateNilaiData(List<dynamic> nilaiData) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < nilaiData.length; i++) {
      final nilai = nilaiData[i];
      final Map<String, dynamic> validatedNilai = {};

      // Validasi field required
      if (nilai['nis'] == null || nilai['nis'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: NIS tidak boleh kosong');
      } else {
        validatedNilai['nis'] = nilai['nis'];
      }

      if (nilai['student_name'] == null ||
          nilai['student_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama siswa tidak boleh kosong');
      } else {
        validatedNilai['student_name'] = nilai['student_name'];
      }

      if (nilai['class_name'] == null ||
          nilai['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedNilai['class_name'] = nilai['class_name'];
      }

      if (nilai['subject_name'] == null ||
          nilai['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedNilai['subject_name'] = nilai['subject_name'];
      }

      if (nilai['type'] == null || nilai['type'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Jenis nilai tidak boleh kosong');
      } else {
        validatedNilai['type'] = nilai['type'];
      }

      if (nilai['grade'] == null) {
        errors.add('Baris ${i + 1}: Nilai tidak boleh kosong');
      } else {
        final nilaiValue = double.tryParse(nilai['grade'].toString());
        if (nilaiValue == null || nilaiValue < 0 || nilaiValue > 100) {
          errors.add('Baris ${i + 1}: Nilai harus antara 0-100');
        } else {
          validatedNilai['grade'] = nilaiValue;
        }
      }

      // Field optional
      validatedNilai['description'] = nilai['description'] ?? '';
      validatedNilai['date'] = nilai['date'] ?? '';
      validatedNilai['teacher_name'] = nilai['teacher_name'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedNilai);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  /// Get a localized label for grade type codes (uh, tugas, uts, uas, pts, pas).
  /// Like a Laravel accessor that maps enum values to display strings.
  /// Uses [LanguageProvider] for i18n (en/id), similar to Laravel's `__()` helper.
  static String getJenisNilaiLabel(
    String jenis,
    LanguageProvider languageProvider,
  ) {
    switch (jenis) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return jenis.toUpperCase();
    }
  }
}
