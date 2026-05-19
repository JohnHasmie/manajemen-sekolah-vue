/// schedule_print_pdf_service.dart - Print teaching schedule to PDF.
///
/// Hits POST /teaching-schedule/print-pdf (added in Fix-1b) with the
/// currently-applied filter dimensions plus a `scope` (all | per_teacher |
/// per_class) so admin can choose grouping. The endpoint streams a PDF
/// back — this service saves it under the documents dir and opens it via
/// OpenFile. Replaces the never-wired Excel export with a print-friendly
/// artefact.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Available scopes for the schedule Print PDF. Mirrors the backend's
/// `scope` query param contract on `POST /teaching-schedule/print-pdf`.
enum SchedulePrintScope {
  /// Flat table sorted by day → hour (default).
  all,

  /// One section per guru.
  perTeacher,

  /// One section per kelas.
  perClass,
}

extension SchedulePrintScopeX on SchedulePrintScope {
  String get apiValue => switch (this) {
    SchedulePrintScope.all => 'all',
    SchedulePrintScope.perTeacher => 'per_teacher',
    SchedulePrintScope.perClass => 'per_class',
  };

  String get labelId => switch (this) {
    SchedulePrintScope.all => 'Semua Jadwal',
    SchedulePrintScope.perTeacher => 'Per Guru',
    SchedulePrintScope.perClass => 'Per Kelas',
  };
}

/// Service for printing schedule PDFs.
class SchedulePrintPdfService {
  static const String _endpoint = '/teaching-schedule/print-pdf';

  /// Calls the backend Print PDF endpoint with the supplied filters +
  /// scope, saves the response to the documents dir, opens it, and
  /// returns the saved file path.
  ///
  /// Throws if the request fails. Caller is responsible for showing
  /// success / error UI — typical pattern is to wrap in try/catch and
  /// call [SnackBarUtils.showSuccess] / [SnackBarUtils.showError].
  static Future<String> printSchedulePdf({
    required SchedulePrintScope scope,
    String? teacherId,
    String? subjectId,
    String? classId,
    String? dayId,
    String? hourNumber,
    String? semesterId,
    String? academicYearId,
  }) async {
    // Build the body payload. Null/empty values are stripped so the
    // backend sees only the dimensions admin actually narrowed.
    final body = <String, dynamic>{'scope': scope.apiValue};
    if (teacherId != null && teacherId.isNotEmpty) {
      body['teacher_id'] = teacherId;
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      body['subject_id'] = subjectId;
    }
    if (classId != null && classId.isNotEmpty) body['class_id'] = classId;
    if (dayId != null && dayId.isNotEmpty) body['day_id'] = dayId;
    if (hourNumber != null && hourNumber.isNotEmpty) {
      body['hour_number'] = hourNumber;
    }
    if (semesterId != null && semesterId.isNotEmpty) {
      body['semester_id'] = semesterId;
    }
    if (academicYearId != null && academicYearId.isNotEmpty) {
      body['academic_year_id'] = academicYearId;
    }

    final response = await dioClient.post<List<int>>(
      _endpoint,
      data: body,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data ?? <int>[];
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath =
        '${directory.path}/Jadwal_${scope.apiValue}_$timestamp.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await OpenFile.open(filePath);
    return filePath;
  }

  /// Convenience wrapper that surfaces success / error snackbars + a
  /// loading state, so callers only need to pass context + filters.
  static Future<void> printAndShow({
    required BuildContext context,
    required SchedulePrintScope scope,
    String? teacherId,
    String? subjectId,
    String? classId,
    String? dayId,
    String? hourNumber,
    String? semesterId,
    String? academicYearId,
  }) async {
    try {
      await printSchedulePdf(
        scope: scope,
        teacherId: teacherId,
        subjectId: subjectId,
        classId: classId,
        dayId: dayId,
        hourNumber: hourNumber,
        semesterId: semesterId,
        academicYearId: academicYearId,
      );
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(
        context,
        'PDF jadwal berhasil dibuat dan dibuka.',
      );
    } catch (e) {
      if (!context.mounted) return;
      SnackBarUtils.showError(context, 'Gagal membuat PDF jadwal: $e');
    }
  }
}
