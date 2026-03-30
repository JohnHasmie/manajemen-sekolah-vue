// Controller for GradeBookPage.
// Like a Vue Composition API `setup()` extracted into its own composable file,
// or a Laravel controller class extracted from a fat route closure.
//
// Holds all data-fetching, data-manipulation and pure helper logic so that
// grade_book_screen.dart only concerns itself with widget rendering and
// `setState` calls.
//
// Usage in screen:
//   final ctrl = ref.read(gradeBookControllerProvider);

import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Riverpod provider for [GradeBookController].
/// Use `ref.read(gradeBookControllerProvider)` from the screen.
///
/// This is a plain [Provider] (not AsyncNotifier) because the controller
/// does not own state — it just provides methods. State stays in the screen's
/// `setState` calls, matching the pattern used throughout this codebase for
/// ConsumerStatefulWidgets.
final gradeBookControllerProvider = Provider<GradeBookController>((ref) {
  return GradeBookController(ref);
});

// ---------------------------------------------------------------------------
// Result types — plain records returned by controller methods so the screen
// can apply them via setState without the controller ever calling setState.
// Think of these like DTOs from a Laravel Service returning structured data.
// ---------------------------------------------------------------------------

/// Result of [GradeBookController.loadData].
/// The screen destructures this and applies every field via setState.
///
/// [error] is non-null when the load failed — the screen should show a
/// snackbar with the message. This avoids passing BuildContext across async
/// gaps inside the controller.
class LoadDataResult {
  final List<Student> studentList;
  final List<Student> filteredStudentList;
  final List<Map<String, dynamic>> gradeList;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;
  final bool isLoading;

  /// Non-null means something went wrong. Show this to the user.
  final String? error;

  const LoadDataResult({
    required this.studentList,
    required this.filteredStudentList,
    required this.gradeList,
    required this.assessmentHeaders,
    required this.isLoading,
    this.error,
  });

  /// Convenience constructor for error-only results.
  LoadDataResult.failure(String message)
      : studentList = const [],
        filteredStudentList = const [],
        gradeList = const [],
        assessmentHeaders = const {},
        isLoading = false,
        error = message;
}

/// Result of [GradeBookController.enterEditMode].
/// The screen applies this via setState and wires up the returned controllers.
class EnterEditModeResult {
  final bool isEditMode;
  final String editGradeType;
  final Map<String, dynamic> editHeader;
  final Map<String, TextEditingController> editControllers;
  final Map<String, FocusNode> editFocusNodes;

  const EnterEditModeResult({
    required this.isEditMode,
    required this.editGradeType,
    required this.editHeader,
    required this.editControllers,
    required this.editFocusNodes,
  });
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Plain Dart class that holds all data/logic for [GradeBookPage].
///
/// Analogy for a Laravel developer: this is the Controller class that was
/// previously inlined inside the View (grade_book_screen.dart). It receives
/// `ref` (like Laravel's DI container) and the widget props (like route
/// parameters) on each method call so it stays stateless itself.
class GradeBookController {
  /// Riverpod ref — used to read providers (academicYearRiverpod,
  /// languageRiverpod) the same way Laravel reads service container bindings.
  final Ref _ref;

  GradeBookController(this._ref);

  // ─── Cache key ────────────────────────────────────────────────────────────

  /// Builds the local-cache key for this class+subject+year combination.
  /// Like a Laravel cache tag: `Cache::remember("grade_book_{id}", ...)`.
  String buildGradeCacheKey({
    required Map<String, dynamic> subject,
    required Map<String, dynamic> classData,
  }) {
    final academicYearId =
        _ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString() ??
            'default';
    final subjectId = subject['id']?.toString() ?? 'unknown';
    final classId = classData['id']?.toString() ?? 'unknown';
    return 'grade_book_${subjectId}_${classId}_$academicYearId';
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  /// Processes raw API student + grade arrays into the structured state used
  /// by the grade table. Like a Laravel Resource/Transformer converting an
  /// Eloquent collection to a JSON-friendly shape.
  ///
  /// Returns a [LoadDataResult]; the screen applies it with setState.
  LoadDataResult processAndApplyGradeData(
    List<dynamic> studentData,
    List<dynamic> rawGradeItems,
    List<String> allGradeTypeList,
  ) {
    final studentList = studentData.map((s) => Student.fromJson(s)).toList();
    final filteredStudentList = List<Student>.from(studentList);

    final currentStudentIds = studentList.map((s) => s.id.toString()).toSet();
    final currentStudentClassIds = studentList
        .map((s) => s.studentClassId?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    // Filter and normalise grade items into the legacy internal format
    final gradeList = rawGradeItems
        .where((item) {
          final studentId =
              (item['student_id'] ?? item['siswa_id'] ?? item['siswa']?['id'])
                  ?.toString();
          final studentClassId =
              (item['student_class_id'] ?? item['siswa_kelas_id'])?.toString();

          return currentStudentIds.contains(studentId) ||
              (studentClassId != null &&
                  currentStudentClassIds.contains(studentClassId));
        })
        .map<Map<String, dynamic>>((item) {
          return {
            'id': item['id'],
            'siswa_id':
                (item['student_id'] ?? item['siswa_id'] ?? item['siswa']?['id'])
                    ?.toString(),
            'student_class_id':
                (item['student_class_id'] ?? item['siswa_kelas_id'])?.toString(),
            'nilai': item['score'] ?? item['nilai'],
            'deskripsi': item['notes'] ?? item['deskripsi'],
            'tanggal':
                item['assessment']?['date'] ?? item['date'] ?? item['tanggal'],
            'jenis':
                (item['assessment']?['type'] ?? item['type'] ?? item['jenis'])
                    ?.toString()
                    .toLowerCase(),
            'title': item['assessment']?['title'] ?? item['title'] ?? '',
            'assessment_id': item['assessment_id'],
          };
        })
        .toList();

    // Build unique assessment headers (columns) grouped by grade type
    final Map<String, List<Map<String, dynamic>>> assessmentHeaders = {};

    for (var gradeItem in gradeList) {
      final type = gradeItem['jenis']?.toString().toLowerCase();
      if (type == null || !allGradeTypeList.contains(type)) continue;

      final String? rawDate = gradeItem['tanggal'];
      if (rawDate != null) {
        final datePart = rawDate.split('T')[0];
        final assessmentId = gradeItem['assessment_id'];
        final title = (gradeItem['title'] ?? '').toString().trim();

        if (!assessmentHeaders.containsKey(type)) {
          assessmentHeaders[type] = [];
        }

        final existingIndex = assessmentHeaders[type]!.indexWhere((h) {
          final headerId = h['id']?.toString();
          final currentAssessmentId = assessmentId?.toString();

          if (currentAssessmentId != null && headerId != null) {
            return headerId == currentAssessmentId;
          }
          if (currentAssessmentId != null || headerId != null) {
            return false;
          }
          final hTitle = (h['title'] ?? '').toString().trim();
          return h['date'] == datePart && hTitle == title;
        });

        if (existingIndex == -1) {
          assessmentHeaders[type]!.add({
            'id': assessmentId,
            'date': datePart,
            'title': title,
            'is_temp': false,
          });
        }
      }
    }

    // Sort headers by date then title — like `ORDER BY date, title` in SQL
    for (var key in assessmentHeaders.keys) {
      assessmentHeaders[key]!.sort((a, b) {
        final dateCompare = (a['date'] as String).compareTo(b['date'] as String);
        if (dateCompare != 0) return dateCompare;
        return (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString());
      });
    }

    return LoadDataResult(
      studentList: studentList,
      filteredStudentList: filteredStudentList,
      gradeList: gradeList,
      assessmentHeaders: assessmentHeaders,
      isLoading: false,
    );
  }

  /// Loads grade data for the given teacher / subject / class.
  /// Cache-first strategy: tries local cache then falls back to API.
  ///
  /// Like Laravel's `Cache::remember()` wrapping an Eloquent query.
  /// Always returns a [LoadDataResult]; check [LoadDataResult.error] to detect
  /// failure — the screen shows the error snackbar itself so no BuildContext
  /// is needed here (avoids the "don't use BuildContext across async gaps" lint).
  Future<LoadDataResult> loadData({
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> subject,
    required Map<String, dynamic> classData,
    required List<String> allGradeTypeList,
    bool showLoading = true,
    bool useCache = true,
  }) async {
    try {
      // ── Step 1: Cache hit → return immediately ──────────────────────────
      if (showLoading && useCache) {
        try {
          final cacheKey = buildGradeCacheKey(subject: subject, classData: classData);
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null) {
            final cachedData = Map<String, dynamic>.from(cached);
            final studentData =
                List<dynamic>.from(cachedData['studentData'] ?? []);
            final gradeItems =
                List<dynamic>.from(cachedData['gradeItems'] ?? []);
            if (studentData.isNotEmpty) {
              AppLogger.info('grades', 'Grade book loaded from cache — skipping API');
              return processAndApplyGradeData(
                  studentData, gradeItems, allGradeTypeList);
            }
          }
        } catch (e) {
          AppLogger.error('grades', e);
        }
      }

      // ── Step 2: API fetch ────────────────────────────────────────────────
      final studentData =
          await getIt<ApiStudentService>().getStudentByClass(classData['id']);

      final academicYearId =
          _ref.read(academicYearRiverpod).selectedAcademicYear?['id'];
      final subjectId = subject['id'];
      final url =
          '/grades/teacher?subject_id=$subjectId&limit=500${academicYearId != null ? "&academic_year_id=$academicYearId" : ""}';

      AppLogger.debug('grades', 'DEBUG: Loading grades from $url');

      final response = await ApiService().get(url);

      List<dynamic> rawGradeItems = [];
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        rawGradeItems = response['data'] as List<dynamic>;
      } else if (response is List) {
        rawGradeItems = response;
      }

      AppLogger.debug(
          'grades', 'DEBUG: Received ${rawGradeItems.length} grade items');

      // ── Step 3: Persist to cache ─────────────────────────────────────────
      final cacheKey = buildGradeCacheKey(subject: subject, classData: classData);
      LocalCacheService.save(cacheKey, {
        'studentData': studentData,
        'gradeItems': rawGradeItems,
      });

      return processAndApplyGradeData(
          studentData, rawGradeItems, allGradeTypeList);
    } catch (e) {
      AppLogger.error('grades', e);
      return LoadDataResult.failure(ErrorUtils.getFriendlyMessage(e));
    }
  }

  // ─── Filter helpers ───────────────────────────────────────────────────────

  /// Returns a filtered copy of [studentList] matching [query].
  /// Pure function — no side effects. Like a Vue computed filter or a
  /// Laravel Collection `filter()` call.
  List<Student> filterStudents(List<Student> studentList, String query) {
    if (query.isEmpty) return List.from(studentList);
    final lq = query.toLowerCase();
    return studentList
        .where((s) =>
            s.name.toLowerCase().contains(lq) ||
            s.studentNumber.toLowerCase().contains(lq))
        .toList();
  }

  /// Returns the list of active grade type keys from [gradeTypeFilter].
  /// Like a Vue computed that maps a `{ uh: true, tugas: false, … }` object
  /// into an array of enabled keys.
  List<String> computeFilteredGradeTypes(
    List<String> allGradeTypeList,
    Map<String, bool> gradeTypeFilter,
  ) {
    return allGradeTypeList
        .where((type) => gradeTypeFilter[type] == true)
        .toList();
  }

  // ─── Grade lookup ─────────────────────────────────────────────────────────

  /// Finds the grade record for a specific [student] + assessment [header] +
  /// grade [type]. Returns `null` when no grade exists yet.
  ///
  /// Like `$grades->where('student_id', $id)->where('assessment_id', $aid)->first()`
  /// in a Laravel Blade view.
  Map<String, dynamic>? getGradeForStudentAndHeader(
    Student student,
    String type,
    Map<String, dynamic> header,
    List<Map<String, dynamic>> gradeList,
  ) {
    try {
      final studentId = student.id.toString();
      final studentClassId = student.studentClassId?.toString();

      final result = gradeList.firstWhere((gradeItem) {
        final gradeStudentId = gradeItem['siswa_id']?.toString();
        final gradeStudentClassId = gradeItem['student_class_id']?.toString();

        bool studentMatch = (gradeStudentId == studentId);
        if (!studentMatch &&
            (studentClassId != null || gradeStudentClassId != null)) {
          studentMatch =
              (gradeStudentClassId == studentClassId) ||
              (gradeStudentId == studentClassId);
        }
        if (!studentMatch) return false;

        final headerId = header['id']?.toString();
        final currentAssessmentId = gradeItem['assessment_id']?.toString();

        if (headerId != null && currentAssessmentId != null) {
          if (headerId != currentAssessmentId) return false;
        } else if (headerId != null || currentAssessmentId != null) {
          return false;
        }

        final gradeDate = gradeItem['tanggal']?.toString().split('T')[0];
        final gradeType = gradeItem['jenis']?.toString().toLowerCase();
        final nTitle = (gradeItem['title'] ?? '').toString().trim();
        final hTitle = (header['title'] ?? '').toString().trim();

        return (gradeType == type.toLowerCase() &&
            gradeDate == header['date'] &&
            nTitle == hTitle);
      }, orElse: () => <String, dynamic>{});

      return result.isEmpty ? null : result;
    } catch (e) {
      return null;
    }
  }

  // ─── Inline edit mode ─────────────────────────────────────────────────────

  /// Builds and returns the edit-mode state for a given grade column.
  /// The caller (screen) must `setState` with the returned result and also
  /// attach the focus-node listeners that call [saveInlineGrade].
  ///
  /// Like Vue's `enterEditMode()` method that prepares reactive form fields
  /// for each row in a table.
  EnterEditModeResult enterEditMode(
    String type,
    Map<String, dynamic> header,
    List<Student> filteredStudentList,
    List<Map<String, dynamic>> gradeList, {
    /// Called when a focus node loses focus so the screen can trigger a save.
    /// Signature: (student, type, header, field, value)
    required void Function(
            Student, String, Map<String, dynamic>, String, String)
        onFocusLost,
  }) {
    final editControllers = <String, TextEditingController>{};
    final editFocusNodes = <String, FocusNode>{};

    for (var student in filteredStudentList) {
      final gradeData =
          getGradeForStudentAndHeader(student, type, header, gradeList);

      // Score controller + focus node
      final scoreKey = '${student.id}_score';
      editControllers[scoreKey] = TextEditingController(
        text: formatGradeValue(gradeData?['nilai']),
      );
      editFocusNodes[scoreKey] = FocusNode();
      editFocusNodes[scoreKey]!.addListener(() {
        if (!editFocusNodes[scoreKey]!.hasFocus) {
          onFocusLost(
              student, type, header, 'nilai', editControllers[scoreKey]!.text);
        }
      });

      // Description controller + focus node
      final deskripsiKey = '${student.id}_deskripsi';
      editControllers[deskripsiKey] = TextEditingController(
        text: gradeData?['deskripsi']?.toString() ?? '',
      );
      editFocusNodes[deskripsiKey] = FocusNode();
      editFocusNodes[deskripsiKey]!.addListener(() {
        if (!editFocusNodes[deskripsiKey]!.hasFocus) {
          onFocusLost(student, type, header, 'deskripsi',
              editControllers[deskripsiKey]!.text);
        }
      });
    }

    return EnterEditModeResult(
      isEditMode: true,
      editGradeType: type,
      editHeader: header,
      editControllers: editControllers,
      editFocusNodes: editFocusNodes,
    );
  }

  // ─── API mutation methods ─────────────────────────────────────────────────

  /// Saves a single inline grade value (create or update).
  /// Like `axios.post/put('/api/grades')` in a Vue method.
  ///
  /// Returns `null` on success, or an error message string on failure.
  /// The caller shows the snackbar itself — no BuildContext needed here.
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
    final currentData =
        getGradeForStudentAndHeader(student, type, header, gradeList);
    final currentValue = currentData?[field]?.toString() ?? '';

    if (value.isEmpty && currentValue.isEmpty) return null;
    if (value == currentValue) return null;

    try {
      final data = {
        'student_id': student.id,
        'student_class_id': student.studentClassId,
        'teacher_id': teacher['id'],
        'subject_id': subject['id'],
        'type': type,
        'date': header['date'],
        'title': header['title'],
        'assessment_id': header['id'],
        'score': field == 'score'
            ? (value.isEmpty ? 0 : double.tryParse(value) ?? 0)
            : (currentData?['nilai'] ?? 0),
        'notes': field == 'deskripsi'
            ? value
            : (currentData?['deskripsi'] ?? ''),
      };

      if (currentData != null && currentData['id'] != null) {
        await ApiService().put('/grades/${currentData['id']}', data);
      } else {
        if (value.isNotEmpty) {
          await ApiService().post('/grades', data);
        }
      }
      return null;
    } catch (e) {
      AppLogger.error('grades', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  /// Deletes all grades for a given assessment column (batch delete).
  /// Returns `null` on success, or an error message string on failure.
  /// The caller shows success/error snackbars itself.
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

      final queryString = Uri(queryParameters: queryParams).query;
      await ApiService().delete('/grades/batch?$queryString');
      return null;
    } catch (e) {
      AppLogger.error('grades', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  /// Adds a temporary assessment header for [pickedDate].
  /// The screen calls `showDatePicker` first, then passes the result here —
  /// this keeps UI concerns (context, date picker dialog) in the screen layer.
  ///
  /// Returns the updated [assessmentHeaders] map (cloned) so the screen can
  /// apply it via setState. Returns `null` if [pickedDate] is null.
  ///
  /// Like a Vue method that pushes a new item into a reactive array.
  Map<String, List<Map<String, dynamic>>>? addNewAssessment(
    String type,
    Map<String, List<Map<String, dynamic>>> assessmentHeaders,
    DateTime? pickedDate,
  ) {
    if (pickedDate == null) return null;

    final dateStr =
        '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';

    // Clone the map so the caller can compare old vs new
    final updated = Map<String, List<Map<String, dynamic>>>.from(
      assessmentHeaders.map((k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v))),
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
        final dateCompare =
            (a['date'] as String).compareTo(b['date'] as String);
        if (dateCompare != 0) return dateCompare;
        return (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString());
      });
    }

    return updated;
  }

  /// Exports grades to an Excel file and opens/saves it.
  /// Returns `null` on success, or an error message string on failure.
  /// The caller shows success/error snackbars itself — no BuildContext needed.
  Future<String?> exportGrades(
    Map<String, dynamic> teacher,
    Map<String, dynamic> subject,
    Map<String, dynamic> classData,
  ) async {
    try {
      final academicYearId =
          _ref.read(academicYearRiverpod).selectedAcademicYear?['id'];
      final endpoint =
          '/grades/export?class_id=${classData['id']}&subject_id=${subject['id']}&teacher_id=${teacher['id']}&academic_year_id=$academicYearId';

      final bytes = await ApiService.downloadFile(endpoint);

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'grades_export_${DateTime.now().millisecond}',
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File(
          '${directory.path}/grades_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
        await file.writeAsBytes(bytes);
        await OpenFile.open(file.path);
      }

      return null;
    } catch (e) {
      AppLogger.error('grades', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  // ─── Pure helpers / utilities ─────────────────────────────────────────────

  /// Formats a raw grade value for display (strips trailing `.0`).
  /// Like a Vue filter: `{{ value | gradeFormat }}`.
  String formatGradeValue(dynamic value) {
    if (value == null) return '';
    final double? numVal = double.tryParse(value.toString());
    if (numVal == null) return '';
    if (numVal % 1 == 0) return numVal.toInt().toString();
    return numVal.toString();
  }

  /// Formats a `yyyy-MM-dd` date string into `dd/MM/yyyy` for display.
  String formatDateDisplay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  /// Returns the human-readable label for a grade type key.
  /// Like a Vue `$t('grades.uh')` i18n call.
  String getGradeTypeLabel(String type, LanguageProvider languageProvider) {
    switch (type) {
      case 'uh':
        return languageProvider
            .getTranslatedText({'en': 'Daily/Quiz', 'id': 'UH/Ulangan'});
      case 'tugas':
        return languageProvider
            .getTranslatedText({'en': 'Assignment', 'id': 'Tugas'});
      case 'uts':
        return languageProvider
            .getTranslatedText({'en': 'Midterm', 'id': 'UTS'});
      case 'uas':
        return languageProvider
            .getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return languageProvider
            .getTranslatedText({'en': 'Midterm Exam', 'id': 'PTS'});
      case 'pas':
        return languageProvider
            .getTranslatedText({'en': 'Final Exam', 'id': 'PAS'});
      default:
        return type.toUpperCase();
    }
  }

  /// Returns the primary theme color for the given teacher role.
  Color getPrimaryColor(Map<String, dynamic> teacher) {
    return ColorUtils.getRoleColor(teacher['role'] ?? 'guru');
  }

  // ─── Snackbar helpers ─────────────────────────────────────────────────────

  /// Shows an error snackbar. Requires [BuildContext] because snackbars are
  /// widget-layer concerns — but the logic of *what* to show lives here.
  void showErrorSnackBar(BuildContext context, String message) {
    SnackBarUtils.showError(context, message);
  }

  /// Shows a success snackbar, translating the message if needed.
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
