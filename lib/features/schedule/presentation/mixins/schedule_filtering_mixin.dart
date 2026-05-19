import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Mixin providing filtering helper methods for the
/// admin schedule controller.
mixin ScheduleFilteringMixin {
  /// Filters [scheduleList] client-side by search text and
  /// active filter fields.
  List<dynamic> getFilteredSchedules({
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required String searchText,
    required String? selectedTeacherId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
    String? selectedSubjectId,
  }) {
    final searchTerm = searchText.toLowerCase();
    return scheduleList.where((schedule) {
      return _matchesFilter(
        schedule: schedule,
        dayList: dayList,
        searchTerm: searchTerm,
        selectedTeacherId: selectedTeacherId,
        selectedSubjectId: selectedSubjectId,
        selectedClassId: selectedClassId,
        selectedDayId: selectedDayId,
        selectedJamPelajaran: selectedJamPelajaran,
      );
    }).toList();
  }

  /// Checks if a schedule matches all
  /// active filters.
  bool _matchesFilter({
    required Map<String, dynamic> schedule,
    required List<dynamic> dayList,
    required String searchTerm,
    required String? selectedTeacherId,
    required String? selectedSubjectId,
    required String? selectedClassId,
    required String? selectedDayId,
    required String? selectedJamPelajaran,
  }) {
    final names = _extractScheduleNames(schedule);
    final matchesSearch = _matchesSearch(
      searchTerm: searchTerm,
      subjectName: names['subject'] as String,
      teacherName: names['teacher'] as String,
      className: names['class'] as String,
      schedule: schedule,
      dayList: dayList,
    );
    final matchesGuru = _matchesTeacher(
      schedule: schedule,
      selectedTeacherId: selectedTeacherId,
    );
    final matchesMapel = _matchesSubject(
      schedule: schedule,
      selectedSubjectId: selectedSubjectId,
    );
    final matchesKelas = _matchesClass(
      schedule: schedule,
      selectedClassId: selectedClassId,
    );
    final matchesHari = selectedDayId == null
        ? true
        : _matchesDayId(schedule: schedule, selectedDayId: selectedDayId);
    final matchesJamPelajaran = selectedJamPelajaran == null
        ? true
        : _matchesLessonHour(
            schedule: schedule,
            selectedJamPelajaran: selectedJamPelajaran,
          );

    return matchesSearch &&
        matchesGuru &&
        matchesMapel &&
        matchesKelas &&
        matchesHari &&
        matchesJamPelajaran;
  }

  /// Extracts and normalizes
  /// schedule names.
  Map<String, dynamic> _extractScheduleNames(Map<String, dynamic> schedule) {
    final model = Schedule.fromJson(schedule);
    return {
      'subject': (model.subjectName ?? '').toLowerCase(),
      'teacher': (model.teacherName ?? '').toLowerCase(),
      'class': (model.className ?? '').toLowerCase(),
    };
  }

  /// Checks if schedule matches
  /// search terms.
  bool _matchesSearch({
    required String searchTerm,
    required String subjectName,
    required String teacherName,
    required String className,
    required Map<String, dynamic> schedule,
    required List<dynamic> dayList,
  }) {
    if (searchTerm.isEmpty) return true;

    final daysIds = [];
    if (schedule['days_ids'] is List) {
      daysIds.addAll(schedule['days_ids']);
    } else if (schedule['day_id'] != null) {
      daysIds.add(schedule['day_id']);
    }
    final dayNamesString = daysIds
        .map((id) {
          final d = dayList.firstWhere(
            (element) => element['id'].toString() == id.toString(),
            orElse: () => <String, dynamic>{},
          );
          return ((d as Map).isNotEmpty ? (d['name'] ?? d['nama'] ?? '') : '')
              .toString()
              .toLowerCase();
        })
        .join(' ');

    return subjectName.contains(searchTerm) ||
        teacherName.contains(searchTerm) ||
        className.contains(searchTerm) ||
        dayNamesString.contains(searchTerm);
  }

  /// Checks if schedule matches
  /// selected teacher.
  bool _matchesTeacher({
    required Map<String, dynamic> schedule,
    required String? selectedTeacherId,
  }) {
    if (selectedTeacherId == null) {
      return true;
    }
    return Schedule.fromJson(schedule).teacherId == selectedTeacherId;
  }

  /// Checks if schedule matches
  /// selected subject.
  bool _matchesSubject({
    required Map<String, dynamic> schedule,
    required String? selectedSubjectId,
  }) {
    if (selectedSubjectId == null) {
      return true;
    }
    return Schedule.fromJson(schedule).subjectId == selectedSubjectId;
  }

  /// Checks if schedule matches
  /// selected class.
  bool _matchesClass({
    required Map<String, dynamic> schedule,
    required String? selectedClassId,
  }) {
    if (selectedClassId == null) {
      return true;
    }
    return Schedule.fromJson(schedule).classId == selectedClassId;
  }

  /// Checks if schedule matches
  /// selected day ID.
  bool _matchesDayId({
    required Map<String, dynamic> schedule,
    required String selectedDayId,
  }) {
    final ids = [];
    if (schedule['days_ids'] is List) {
      ids.addAll(schedule['days_ids']);
    } else if (schedule['day_id'] != null) {
      ids.add(schedule['day_id']);
    }
    return ids.any((id) => id.toString() == selectedDayId.toString());
  }

  /// Checks if schedule matches
  /// selected lesson hour.
  bool _matchesLessonHour({
    required Map<String, dynamic> schedule,
    required String selectedJamPelajaran,
  }) {
    final rawHour = schedule['lesson_hour'];
    String? hourNumber;
    if (rawHour is Map) {
      hourNumber =
          rawHour['hour_number']?.toString() ??
          rawHour['jam_ke']?.toString();
    } else if (rawHour != null) {
      hourNumber = rawHour.toString();
    }
    return hourNumber == selectedJamPelajaran;
  }

  /// Returns true if any non-default filter is active.
  bool checkActiveFilter({
    required String? selectedDayId,
    required String? selectedClassId,
    required String? selectedJamPelajaran,
    required String? selectedFilterSemester,
    required String selectedSemester,
    String? selectedTeacherId,
    String? selectedSubjectId,
  }) {
    return selectedDayId != null ||
        selectedClassId != null ||
        selectedJamPelajaran != null ||
        selectedTeacherId != null ||
        selectedSubjectId != null ||
        (selectedFilterSemester != null &&
            selectedFilterSemester != selectedSemester);
  }
}
