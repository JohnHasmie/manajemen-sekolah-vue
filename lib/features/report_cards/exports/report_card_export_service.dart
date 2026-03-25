// excel_raport_service.dart - Export student report cards (raport) to Excel and PDF.
// Like Laravel's Maatwebsite/Excel + DomPDF combined for generating raport documents.
// Supports class-wide Excel export, individual student PDF, and certificate PDF.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

/// Service for exporting student report cards (raport) in multiple formats.
/// Like a Laravel controller with three export actions:
/// - `exportRaportToExcel` -> `Excel::download(new RaportExport)` for a whole class
/// - `exportSingleRaportPdf` -> `PDF::loadView('raport.single')->download()` for one student
/// - `exportCertificateRaportPdf` -> `PDF::loadView('raport.certificate')->download()`
///
/// All exports are server-side: Flutter sends parameters, Laravel generates the file,
/// Flutter saves and opens the binary response. Uses query parameters (GET) rather
/// than POST body since the data is just IDs/filters.
class ExcelRaportService {
  static String get baseUrl => '/raports';

  /// Export an entire class's raport data to Excel via GET `/raports/export`.
  /// [classId], [academicYearId], [semesterId] filter the data server-side.
  /// [className] is used to build a sanitized filename.
  /// Side effects: saves .xlsx to device, opens it, shows SnackBar feedback.
  static Future<void> exportRaportToExcel({
    required String classId,
    required String academicYearId,
    required String semesterId,
    required String className,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/export',
        queryParameters: {
          'class_id': classId,
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();

      String formattedClass = className.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String filePath =
          '${directory.path}/Raport_${formattedClass}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      // Save file
      final File file = File(filePath);
      await file.writeAsBytes(response.data!);

      // Open the file
      await OpenFile.open(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Raport exported successfully',
              'id': 'Raport berhasil diexport',
            }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to export data: $e',
              'id': 'Gagal mengexport data: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Export a single student's raport as PDF via GET `/raports/export-pdf`.
  /// Like Laravel's `PDF::loadView('raport.single', $data)->download()`.
  /// [studentClassId] identifies the student-class pivot record.
  static Future<void> exportSingleRaportPdf({
    required String studentClassId,
    required String academicYearId,
    required String semesterId,
    required String studentName,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/export-pdf',
        queryParameters: {
          'student_class_id': studentClassId,
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();

      String formattedName = studentName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String filePath =
          '${directory.path}/Raport_${formattedName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Save file
      final File file = File(filePath);
      await file.writeAsBytes(response.data!);

      // Open the file
      await OpenFile.open(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'PDF downloaded successfully',
              'id': 'PDF berhasil diunduh',
            }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to download PDF: $e',
              'id': 'Gagal mengunduh PDF: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Export a student's raport certificate as PDF via GET `/raports/export-certificate-pdf`.
  /// Like Laravel's `PDF::loadView('raport.certificate', $data)->download()`.
  static Future<void> exportCertificateRaportPdf({
    required String studentClassId,
    required String academicYearId,
    required String semesterId,
    required String studentName,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final response = await dioClient.get<List<int>>(
        '$baseUrl/export-certificate-pdf',
        queryParameters: {
          'student_class_id': studentClassId,
          'academic_year_id': academicYearId,
          'semester_id': semesterId,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();

      String formattedName = studentName.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final String filePath =
          '${directory.path}/Sertifikat_Raport_${formattedName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Save file
      final File file = File(filePath);
      await file.writeAsBytes(response.data!);

      // Open the file
      await OpenFile.open(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Certificate PDF downloaded successfully',
              'id': 'Sertifikat PDF berhasil diunduh',
            }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to download Certificate PDF: $e',
              'id': 'Gagal mengunduh Sertifikat PDF: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
