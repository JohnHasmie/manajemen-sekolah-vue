import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Helper for loading and processing grade data from API/cache.
class GradeDataProcessor {
  /// Processes raw API student + grade arrays into structured state.
  /// Returns a LoadDataResult tuple: (students, gradeList, assessmentHeaders).
  static ({
    List<Student> studentList,
    List<Student> filteredStudentList,
    List<Map<String, dynamic>> gradeList,
    Map<String, List<Map<String, dynamic>>> assessmentHeaders,
  })
  processRawData(
    List<dynamic> studentData,
    List<dynamic> rawGradeItems,
    List<String> allGradeTypeList,
  ) {
    final studentList = studentData.map((s) => Student.fromJson(s)).toList();
    final filteredStudentList = List<Student>.from(studentList);

    final gradeList = _normalizeGradeItems(rawGradeItems, studentList);

    final assessmentHeaders = _buildAssessmentHeaders(
      gradeList,
      allGradeTypeList,
    );

    return (
      studentList: studentList,
      filteredStudentList: filteredStudentList,
      gradeList: gradeList,
      assessmentHeaders: assessmentHeaders,
    );
  }

  /// Fetches student & grade data via API with cache fallback.
  static Future<({dynamic studentData, List<dynamic> rawGradeItems})>
  fetchDataWithCache({
    required String cacheKey,
    required String classId,
    required String subjectId,
    required String? academicYearId,
    required bool useCache,
  }) async {
    // Try cache first
    if (useCache) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null) {
          final cachedData = Map<String, dynamic>.from(cached);
          final studentData = List<dynamic>.from(
            cachedData['studentData'] ?? [],
          );
          final gradeItems = List<dynamic>.from(cachedData['gradeItems'] ?? []);
          if (studentData.isNotEmpty) {
            AppLogger.info(
              'grades',
              'Grade book loaded from cache — skipping API',
            );
            return (studentData: studentData, rawGradeItems: gradeItems);
          }
        }
      } catch (e) {
        AppLogger.error('grades', e);
      }
    }

    // Fetch from API.
    //
    // Forward the teacher's currently-selected academic year to the student
    // query so the Buku Nilai modal shows the same cohort the overview card
    // counted. Without this, `/student/class/{classId}` falls back to the
    // DB's `status=active` row, which can differ from the AY the app is
    // showing — the symptom was a card that said "16 siswa" opening a
    // modal with "0 siswa / Tidak ada siswa di kelas ini" because the
    // pivot rows for the selected year didn't match the active row.
    final studentData = await getIt<ApiStudentService>().getStudentByClass(
      classId,
      academicYearId: academicYearId,
    );

    final url =
        '/grades/teacher?subject_id=$subjectId&limit=500'
        '${academicYearId != null ? "&academic_year_id=$academicYearId" : ""}';

    AppLogger.debug('grades', 'DEBUG: Loading grades from $url');

    final response = await ApiService().get(url);

    List<dynamic> rawGradeItems = [];
    if (response is Map<String, dynamic> && response.containsKey('data')) {
      rawGradeItems = response['data'] as List<dynamic>;
    } else if (response is List) {
      rawGradeItems = response;
    }

    AppLogger.debug(
      'grades',
      'DEBUG: Received ${rawGradeItems.length} grade items',
    );

    // Save to cache
    await LocalCacheService.save(cacheKey, {
      'studentData': studentData,
      'gradeItems': rawGradeItems,
    });

    return (studentData: studentData, rawGradeItems: rawGradeItems);
  }

  /// Normalizes grade items into internal format.
  static List<Map<String, dynamic>> _normalizeGradeItems(
    List<dynamic> rawGradeItems,
    List<Student> studentList,
  ) {
    final currentStudentIds = studentList.map((s) => s.id.toString()).toSet();
    final currentStudentClassIds = studentList
        .map((s) => s.studentClassId?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    return rawGradeItems
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
                (item['student_class_id'] ?? item['siswa_kelas_id'])
                    ?.toString(),
            'score': item['score'] ?? item['nilai'],
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
  }

  /// Builds unique assessment headers grouped by grade type.
  static Map<String, List<Map<String, dynamic>>> _buildAssessmentHeaders(
    List<Map<String, dynamic>> gradeList,
    List<String> allGradeTypeList,
  ) {
    final Map<String, List<Map<String, dynamic>>> headers = {};

    for (final gradeItem in gradeList) {
      final type = gradeItem['jenis']?.toString().toLowerCase();
      if (type == null || !allGradeTypeList.contains(type)) continue;

      final String? rawDate = gradeItem['tanggal'];
      if (rawDate != null) {
        final datePart = rawDate.split('T')[0];
        final assessmentId = gradeItem['assessment_id'];
        final title = (gradeItem['title'] ?? '').toString().trim();

        if (!headers.containsKey(type)) {
          headers[type] = [];
        }

        final existingIndex = headers[type]!.indexWhere((h) {
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
          headers[type]!.add({
            'id': assessmentId,
            'date': datePart,
            'title': title,
            'is_temp': false,
          });
        }
      }
    }

    // Sort headers by date then title
    for (final key in headers.keys) {
      headers[key]!.sort((a, b) {
        final dateCompare = (a['date'] as String).compareTo(
          b['date'] as String,
        );
        if (dateCompare != 0) return dateCompare;
        return (a['title'] ?? '').toString().compareTo(
          (b['title'] ?? '').toString(),
        );
      });
    }

    return headers;
  }
}
