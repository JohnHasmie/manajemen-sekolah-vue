import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Helper for grade lookups and filtering operations.
class GradeLookupHelper {
  /// Finds the grade record for a specific student + assessment + type.
  /// Returns null when no grade exists yet.
  static Map<String, dynamic>? getGradeForStudentAndHeader(
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

        return gradeType == type.toLowerCase() &&
            gradeDate == header['date'] &&
            nTitle == hTitle;
      }, orElse: () => <String, dynamic>{});

      return result.isEmpty ? null : result;
    } catch (e) {
      return null;
    }
  }

  /// Filters student list by name or student number (case-insensitive).
  static List<Student> filterStudents(List<Student> studentList, String query) {
    if (query.isEmpty) return List.from(studentList);
    final lq = query.toLowerCase();
    return studentList
        .where(
          (s) =>
              s.name.toLowerCase().contains(lq) ||
              s.studentNumber.toLowerCase().contains(lq),
        )
        .toList();
  }

  /// Returns the list of active grade type keys from filter map.
  static List<String> computeFilteredGradeTypes(
    List<String> allGradeTypeList,
    Map<String, bool> gradeTypeFilter,
  ) {
    return allGradeTypeList
        .where((type) => gradeTypeFilter[type] == true)
        .toList();
  }
}
