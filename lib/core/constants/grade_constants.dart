/// Grade type constants — single source of truth for the six assessment
/// categories used across the grade book, filters, and recap screens.
///
/// In Laravel terms this is like an enum or a config/grades.php constant.
/// Import this wherever a hardcoded ['uh', 'tugas', ...] list appeared before.
class GradeConstants {
  GradeConstants._();

  /// Canonical ordered list of all grade types.
  static const List<String> allTypes = [
    'uh',
    'tugas',
    'uts',
    'uas',
    'pts',
    'pas',
  ];

  /// Default filter state — all types visible.
  static Map<String, bool> get defaultFilter => {
    for (final t in allTypes) t: true,
  };

  /// English labels for each grade type.
  static const Map<String, String> labelsEn = {
    'uh': 'Daily/Quiz',
    'tugas': 'Assignment',
    'uts': 'Midterm',
    'uas': 'Final',
    'pts': 'Midterm Exam',
    'pas': 'Final Exam',
  };

  /// Indonesian labels for each grade type.
  static const Map<String, String> labelsId = {
    'uh': 'UH/Ulangan',
    'tugas': 'Tugas',
    'uts': 'UTS',
    'uas': 'UAS',
    'pts': 'PTS',
    'pas': 'PAS',
  };
}
