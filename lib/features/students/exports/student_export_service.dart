// excel_student_service.dart - Client-side Excel generation for student data.
// Unlike other Excel services that delegate to the backend, this one builds
// the .xlsx file locally using the Syncfusion XlsIO library.
// Similar to using Laravel Maatwebsite/Excel but running entirely on the client.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Service for generating student data Excel files entirely on the client side.
/// Unlike the other `Excel*Service` classes that POST to the backend, this service
/// uses `syncfusion_flutter_xlsio` to create .xlsx files locally -- like running
/// Maatwebsite/Excel directly in the app instead of on the Laravel server.
///
/// Provides:
/// 1. [exportStudentsToExcel] - Export current student data with styled headers
/// 2. [downloadTemplate] - Generate a pre-formatted import template (.xlsx)
/// 3. [downloadTemplateCSV] - Generate a CSV import template (simpler alternative)
///
/// The Syncfusion `Workbook` / `Worksheet` API is similar to PhpSpreadsheet
/// in PHP: create workbook -> get sheet -> set cell values -> save as bytes.
class ExcelService {
  /// Export student data to a locally-generated Excel file.
  /// Creates a Workbook (like PhpSpreadsheet's `new Spreadsheet()`), adds
  /// styled headers (blue background, white text), populates rows with student
  /// data, auto-fits columns, and saves/opens the file.
  ///
  /// [students] - list of student maps from state/API.
  /// [context] - for SnackBar and i18n access via LanguageProvider.
  /// Side effects: writes .xlsx to device documents directory and opens it.
  static Future<void> exportStudentsToExcel({
    required List<dynamic> students,
    required BuildContext context,
  }) async {
    try {
      // Create a new Excel document
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Siswa';

      // Add header row
      sheet.getRangeByIndex(1, 1).setText('NIS');
      sheet.getRangeByIndex(1, 2).setText('Name');
      sheet.getRangeByIndex(1, 3).setText('Class');
      sheet.getRangeByIndex(1, 4).setText('Gender');
      sheet.getRangeByIndex(1, 5).setText('Date of Birth');
      sheet.getRangeByIndex(1, 6).setText('Address');
      sheet.getRangeByIndex(1, 7).setText('Parent Name');
      sheet.getRangeByIndex(1, 8).setText('Parent Email');
      sheet.getRangeByIndex(1, 9).setText('Phone Number');
      sheet.getRangeByIndex(1, 10).setText('Status');

      // Style header row
      final Range headerRange = sheet.getRangeByName('A1:J1');
      headerRange.cellStyle.backColor = '#4361EE';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;

      // Add data rows
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        final rowIndex = i + 2;

        sheet
            .getRangeByIndex(rowIndex, 1)
            .setText(student['student_number'] ?? '');
        sheet.getRangeByIndex(rowIndex, 2).setText(student['name'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 3)
            .setText(student['class']?['name'] ?? student['class_name'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 4)
            .setText(_getGenderText(student['gender'], languageProvider));
        sheet
            .getRangeByIndex(rowIndex, 5)
            .setText(_formatDateForExport(student['date_of_birth']));
        sheet.getRangeByIndex(rowIndex, 6).setText(student['address'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 7)
            .setText(student['guardian_name'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 8)
            .setText(student['guardian_email'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 9)
            .setText(student['phone_number'] ?? '');
        sheet.getRangeByIndex(rowIndex, 10).setText('Active');

        // Alternate row colors for better readability
        if (i % 2 == 0) {
          final Range rowRange = sheet.getRangeByIndex(
            rowIndex,
            1,
            rowIndex,
            10,
          );
          rowRange.cellStyle.backColor = '#F8F9FA';
        }
      }

      // Auto fit columns
      for (int i = 1; i <= 10; i++) {
        sheet.autoFitColumn(i);
      }

      // Save and launch the file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path =
          '${directory.path}/Data_Siswa_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(path);

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Student data exported successfully',
          'id': 'Data siswa berhasil diexport',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to export data: $e',
          'id': 'Gagal mengexport data: $e',
        }),
      );
    }
  }

  /// Generate and download an Excel import template with headers, example data,
  /// and formatting notes. Like a Laravel Maatwebsite/Excel export that creates
  /// a template with `WithHeadings` and sample rows for user guidance.
  /// Fields marked with `*` are required.
  static Future<void> downloadTemplate(BuildContext context) async {
    try {
      // Create a new Excel document
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Template Siswa';

      // Add header row
      sheet.getRangeByIndex(1, 1).setText('NIS*');
      sheet.getRangeByIndex(1, 2).setText('Name*');
      sheet.getRangeByIndex(1, 3).setText('Class*');
      sheet.getRangeByIndex(1, 4).setText('Gender*');
      sheet.getRangeByIndex(1, 5).setText('Date of Birth*');
      sheet.getRangeByIndex(1, 6).setText('Address*');
      sheet.getRangeByIndex(1, 7).setText('Parent Name*');
      sheet.getRangeByIndex(1, 8).setText('Parent Email');
      sheet.getRangeByIndex(1, 9).setText('Phone Number*');

      // Style header row
      final Range headerRange = sheet.getRangeByName('A1:I1');
      headerRange.cellStyle.backColor = '#28a745';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;

      // Add example data
      sheet.getRangeByIndex(2, 1).setText('12345');
      sheet.getRangeByIndex(2, 2).setText('John Doe');
      sheet.getRangeByIndex(2, 3).setText('10 IPA 1');
      sheet.getRangeByIndex(2, 4).setText('Laki-laki');
      sheet.getRangeByIndex(2, 5).setText('2005-01-15');
      sheet.getRangeByIndex(2, 6).setText('Jl. Contoh No. 123');
      sheet.getRangeByIndex(2, 7).setText('Jane Doe');
      sheet.getRangeByIndex(2, 8).setText('jane@example.com');
      sheet.getRangeByIndex(2, 9).setText('08123456789');

      // Add notes
      sheet.getRangeByIndex(4, 1).setText('* Wajib diisi');
      sheet.getRangeByIndex(5, 1).setText(AppLocalizations.dateFormatHint.tr);
      sheet
          .getRangeByIndex(6, 1)
          .setText('Jenis Kelamin: Laki-laki / Perempuan');

      // Auto fit columns
      for (int i = 1; i <= 9; i++) {
        sheet.autoFitColumn(i);
      }

      // Save and launch the file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/Template_Import_Siswa.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(path);

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Template downloaded successfully',
          'id': 'Template berhasil diunduh',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to download template: $e',
          'id': 'Gagal mengunduh template: $e',
        }),
      );
    }
  }

  /// Generate and download a CSV import template as a simpler alternative to Excel.
  /// Like a plain-text version of the template for users without Excel software.
  static Future<void> downloadTemplateCSV(BuildContext context) async {
    try {
      final String csvContent =
          '''NIS*,Name*,Class*,Gender*,Date of Birth*,Address*,Parent Name*,Parent Email,Phone Number*
12345,John Doe,10 IPA 1,Laki-laki,2005-01-15,Jl. Contoh No. 123,Jane Doe,jane@example.com,08123456789
*Wajib diisi,Format tanggal: YYYY-MM-DD,Jenis Kelamin: Laki-laki / Perempuan''';

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/Template_Import_Siswa.csv';
      final File file = File(path);
      await file.writeAsString(csvContent);

      // Open the file
      await OpenFile.open(path);

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'CSV Template downloaded successfully',
          'id': 'Template CSV berhasil diunduh',
        }),
      );
    } catch (e) {
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to download CSV template: $e',
          'id': 'Gagal mengunduh template CSV: $e',
        }),
      );
    }
  }

  /// Convert gender code ('L'/'M' = male, 'P'/'F' = female) to localized text.
  /// Like a Laravel accessor: `getGenderTextAttribute()`.
  static String _getGenderText(
    String? gender,
    LanguageProvider languageProvider,
  ) {
    switch (gender) {
      case 'L':
      case 'M':
        return languageProvider.getTranslatedText({
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'P':
      case 'F':
        return languageProvider.getTranslatedText({
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return '-';
    }
  }

  /// Format a date string to 'YYYY-MM-DD' for export. Like Carbon's `format('Y-m-d')`.
  static String _formatDateForExport(String? date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return date;
    }
  }
}
