/// Helper for sorting classes and subjects by today's schedule.
class SortingHelper {
  /// Sorts classes, prioritizing those with today's schedule.
  static void sortClassesByTodaySchedule(
    List<dynamic> classes,
    List<dynamic> todaySchedules,
  ) {
    if (todaySchedules.isEmpty) return;
    final todayClassIds = todaySchedules
        .map((s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();

    classes.sort((a, b) {
      final isTodayA = todayClassIds.contains(a['id'].toString());
      final isTodayB = todayClassIds.contains(b['id'].toString());
      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;
      return 0;
    });
  }

  /// Sorts subjects, prioritizing those with today's schedule.
  static void sortSubjectsByTodaySchedule(
    List<dynamic> subjects,
    String classId,
    List<dynamic> todaySchedules,
  ) {
    if (todaySchedules.isEmpty) return;
    final todaySubjectIds = todaySchedules
        .where(
          (s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString() == classId,
        )
        .map(
          (s) => (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString(),
        )
        .where((id) => id.isNotEmpty)
        .toSet();

    subjects.sort((a, b) {
      final isTodayA = todaySubjectIds.contains(a['id'].toString());
      final isTodayB = todaySubjectIds.contains(b['id'].toString());
      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;
      return 0;
    });
  }
}
