// Controller for GradeBookPage. Delegates to helpers; state in screen's
// setState. Usage: ref.read(gradeBookControllerProvider).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_models.dart'
    as models;
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_data_processor.dart'
    as proc;
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_edit_helper.dart'
    as edit;
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_export_helper.dart'
    as exp;
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_format_helper.dart'
    as fmt;
import 'package:manajemensekolah/features/grades/presentation/controllers/helpers/grade_lookup_helper.dart'
    as lookup;
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

final gradeBookControllerProvider = Provider<GradeBookController>((ref) {
  return GradeBookController(ref);
});

class GradeBookController {
  final Ref _ref;
  GradeBookController(this._ref);

  String buildGradeCacheKey({
    required Map<String, dynamic> subject,
    required Map<String, dynamic> classData,
  }) {
    final academicYearId =
        _ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    final subjectId = subject['id']?.toString() ?? 'unknown';
    final classId = classData['id']?.toString() ?? 'unknown';
    return 'grade_book_${subjectId}_${classId}_$academicYearId';
  }

  Future<models.LoadDataResult> loadData({
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> subject,
    required Map<String, dynamic> classData,
    required List<String> allGradeTypeList,
    bool showLoading = true,
    bool useCache = true,
  }) async {
    try {
      final cacheKey = buildGradeCacheKey(
        subject: subject,
        classData: classData,
      );

      final academicYearId = _ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id'];

      final (
        :studentData,
        :rawGradeItems,
      ) = await proc.GradeDataProcessor.fetchDataWithCache(
        cacheKey: cacheKey,
        classId: classData['id'],
        subjectId: subject['id'],
        academicYearId: academicYearId?.toString(),
        useCache: useCache && showLoading,
      );

      final (
        :studentList,
        :filteredStudentList,
        :gradeList,
        :assessmentHeaders,
      ) = proc.GradeDataProcessor.processRawData(
        studentData,
        rawGradeItems,
        allGradeTypeList,
      );

      return models.LoadDataResult(
        studentList: studentList,
        filteredStudentList: filteredStudentList,
        gradeList: gradeList,
        assessmentHeaders: assessmentHeaders,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('grades', e);
      return models.LoadDataResult.failure(ErrorUtils.getFriendlyMessage(e));
    }
  }

  List<Student> filterStudents(List<Student> studentList, String query) {
    return lookup.GradeLookupHelper.filterStudents(studentList, query);
  }

  /// Returns the list of active grade type keys from [gradeTypeFilter].
  /// Like a Vue computed that maps a `{ uh: true, tugas: false, … }` object
  /// into an array of enabled keys.
  List<String> computeFilteredGradeTypes(
    List<String> allGradeTypeList,
    Map<String, bool> gradeTypeFilter,
  ) {
    return lookup.GradeLookupHelper.computeFilteredGradeTypes(
      allGradeTypeList,
      gradeTypeFilter,
    );
  }

  Map<String, dynamic>? getGradeForStudentAndHeader(
    Student student,
    String type,
    Map<String, dynamic> header,
    List<Map<String, dynamic>> gradeList,
  ) {
    return lookup.GradeLookupHelper.getGradeForStudentAndHeader(
      student,
      type,
      header,
      gradeList,
    );
  }

  models.EnterEditModeResult enterEditMode(
    String type,
    Map<String, dynamic> header,
    List<Student> filteredStudentList,
    List<Map<String, dynamic>> gradeList, {
    required void Function(
      Student,
      String,
      Map<String, dynamic>,
      String,
      String,
    )
    onFocusLost,
  }) {
    return edit.GradeEditHelper.enterEditMode(
      type,
      header,
      filteredStudentList,
      gradeList,
      onFocusLost: onFocusLost,
    );
  }

  Future<String?> saveInlineGrade(
    Student student,
    String type,
    Map<String, dynamic> header,
    String field,
    String value,
    List<Map<String, dynamic>> gradeList,
    Map<String, dynamic> teacher,
    Map<String, dynamic> subject,
  ) async {
    final currentData = getGradeForStudentAndHeader(
      student,
      type,
      header,
      gradeList,
    );
    final currentValue = currentData?[field]?.toString() ?? '';

    if (value.isEmpty && currentValue.isEmpty) return null;
    if (value == currentValue) return null;

    try {
      final data = {
        'student_id': student.id,
        'student_class_id': student.studentClassId,
        'teacher_id': Teacher.fromJson(teacher).id,
        'subject_id': Subject.fromJson(subject).id,
        'type': type,
        'date': header['date'],
        'title': header['title'],
        'assessment_id': header['id'],
        'score': field == 'score'
            ? (value.isEmpty ? 0 : double.tryParse(value) ?? 0)
            : (currentData?['score'] ?? 0),
        'notes': field == 'deskripsi'
            ? value
            : (currentData?['deskripsi'] ?? ''),
      };

      if (currentData != null && currentData['id'] != null) {
        await GradeService.updateGrade(currentData['id'], data);
      } else {
        if (value.isNotEmpty) {
          await GradeService.createGrade(data);
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('grades', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  Future<String?> deleteAssessment(
    String type,
    Map<String, dynamic> header,
    Map<String, dynamic> subject,
  ) async {
    try {
      final queryParams = {
        'mata_pelajaran_id': subject['id'].toString(),
        'jenis': type,
        'tanggal': header['date'].toString(),
      };

      if (header['title'] != null) {
        queryParams['title'] = header['title'].toString();
      }

      await GradeService.deleteAssessmentBatch(queryParams);
      return null;
    } catch (e) {
      AppLogger.error('grades', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  Map<String, List<Map<String, dynamic>>>? addNewAssessment(
    String type,
    Map<String, List<Map<String, dynamic>>> assessmentHeaders,
    DateTime? pickedDate,
  ) {
    if (pickedDate == null) return null;

    final dateStr =
        '${pickedDate.year}-'
        '${pickedDate.month.toString().padLeft(2, '0')}-'
        '${pickedDate.day.toString().padLeft(2, '0')}';

    // Clone the map so the caller can compare old vs new
    final updated = Map<String, List<Map<String, dynamic>>>.from(
      assessmentHeaders.map(
        (k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)),
      ),
    );

    if (!updated.containsKey(type)) {
      updated[type] = [];
    }

    final bool exists = updated[type]!.any(
      (h) => h['date'] == dateStr && h['title'] == null,
    );

    if (!exists) {
      updated[type]!.add({
        'id': null,
        'date': dateStr,
        'title': null,
        'is_temp': true,
      });

      updated[type]!.sort((a, b) {
        final dateCompare = (a['date'] as String).compareTo(
          b['date'] as String,
        );
        if (dateCompare != 0) return dateCompare;
        return (a['title'] ?? '').toString().compareTo(
          (b['title'] ?? '').toString(),
        );
      });
    }

    return updated;
  }

  Future<String?> exportGrades(
    Map<String, dynamic> teacher,
    Map<String, dynamic> subject,
    Map<String, dynamic> classData,
  ) async {
    final academicYearId = _ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id'];

    // Build the query map and only append `academic_year_id` when the
    // value is non-null. The previous string interpolation produced
    // `academic_year_id=null` (literal "null") whenever the academic
    // year hadn't been chosen yet, which caused a Postgres "invalid
    // input syntax for type bigint" → 500 on the export endpoint and
    // surfaced as the generic "Terjadi kesalahan pada sistem server"
    // toast in the UI.
    final params = <String, String>{
      'class_id': classData['id']?.toString() ?? '',
      'subject_id': Subject.fromJson(subject).id,
      'teacher_id': Teacher.fromJson(teacher).id,
      if (academicYearId != null)
        'academic_year_id': academicYearId.toString(),
    };
    final endpoint = Uri(
      path: '/grades/export',
      queryParameters: params,
    ).toString();

    return exp.GradeExportHelper.exportGrades(endpoint);
  }

  String formatGradeValue(dynamic value) {
    return fmt.GradeFormatHelper.formatGradeValue(value);
  }

  String formatDateDisplay(String dateStr) {
    return fmt.GradeFormatHelper.formatDateDisplay(dateStr);
  }

  String getGradeTypeLabel(String type, LanguageProvider languageProvider) {
    return fmt.GradeFormatHelper.getGradeTypeLabel(type, languageProvider);
  }

  /// Returns the primary theme color for the given teacher role.
  Color getPrimaryColor(Map<String, dynamic> teacher) {
    return ColorUtils.getRoleColor(Teacher.fromJson(teacher).role);
  }

  void showErrorSnackBar(BuildContext context, String message) {
    SnackBarUtils.showError(context, message);
  }

  void showSuccessSnackBar(BuildContext context, String message) {
    SnackBarUtils.showSuccess(
      context,
      _ref.read(languageRiverpod).getTranslatedText({
        'en': message,
        'id': message.replaceAll('successfully', 'berhasil'),
      }),
    );
  }
}
