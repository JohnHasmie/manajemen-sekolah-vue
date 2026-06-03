/// Filter and display helper for admin attendance report.
///
/// Encapsulates filter logic, chip building, and search filtering.
library;

import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

class AttendanceFilterHelper {
  /// Returns true when any filter parameter is non-default.
  bool checkActiveFilter({
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
  }) {
    return selectedDateFilter != null ||
        selectedSubjectIds.isNotEmpty ||
        selectedClassIds.isNotEmpty ||
        selectedDayIds.isNotEmpty ||
        selectedLessonHourIds.isNotEmpty;
  }

  /// Builds list of active filter chip descriptors.
  ///
  /// Each chip has a label and onRemove callback. The onRemoveSideEffect
  /// closure is called by each chip's onRemove so the screen can do
  /// setState() + loadData() after dismissal.
  List<ActiveFilter> buildFilterChips({
    required LanguageProvider languageProvider,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
    required List<dynamic> subjectList,
    required List<dynamic> classList,
    required void Function(void Function()) onRemoveSideEffect,
  }) {
    final List<ActiveFilter> filterChips = [];

    if (selectedDateFilter != null) {
      // Fix-DD — keep this aligned with `buildDateRangeChips` in
      // `attendance_filter_ui_mixin.dart`.
      String label;
      switch (selectedDateFilter) {
        case 'today':
          label = languageProvider.getTranslatedText({
            'en': 'Today',
            'id': 'Hari Ini',
          });
          break;
        case 'week':
          label = languageProvider.getTranslatedText({
            'en': 'This Week',
            'id': 'Minggu Ini',
          });
          break;
        case 'semester':
          label = languageProvider.getTranslatedText({
            'en': 'Last 6 Months',
            'id': 'Semester (6 Bulan)',
          });
          break;
        case 'year':
          label = languageProvider.getTranslatedText({
            'en': 'This Year',
            'id': 'Tahunan',
          });
          break;
        default:
          label = languageProvider.getTranslatedText({
            'en': 'This Month',
            'id': 'Bulan Ini',
          });
      }
      final dateWord = languageProvider.getTranslatedText({
        'en': 'Date',
        'id': 'Tanggal',
      });
      filterChips.add(
        ActiveFilter(
          label: '$dateWord: $label',
          onRemove: () => onRemoveSideEffect(() => selectedDateFilter = null),
        ),
      );
    }

    for (final subjectId in selectedSubjectIds) {
      final raw = subjectList.firstWhere(
        (s) => s['id'].toString() == subjectId,
        orElse: () => {'name': 'Subject #$subjectId'},
      );
      final subjectName = Subject.fromJson(raw as Map<String, dynamic>).name;
      final subjectWord = languageProvider.getTranslatedText({
        'en': 'Subject',
        'id': 'Mapel',
      });
      filterChips.add(
        ActiveFilter(
          label: '$subjectWord: $subjectName',
          onRemove: () =>
              onRemoveSideEffect(() => selectedSubjectIds.remove(subjectId)),
        ),
      );
    }

    for (final classId in selectedClassIds) {
      final classItem = classList.firstWhere(
        (k) => k['id'].toString() == classId,
        orElse: () => {'name': 'Class #$classId'},
      );
      final className = Classroom.fromJson(
        classItem as Map<String, dynamic>,
      ).name;
      final classWord = languageProvider.getTranslatedText({
        'en': 'Class',
        'id': 'Kelas',
      });
      filterChips.add(
        ActiveFilter(
          label: '$classWord: $className',
          onRemove: () =>
              onRemoveSideEffect(() => selectedClassIds.remove(classId)),
        ),
      );
    }

    if (selectedDayIds.isNotEmpty) {
      final dayWord = languageProvider.getTranslatedText({
        'en': 'Day',
        'id': 'Hari',
      });
      filterChips.add(
        ActiveFilter(
          label: '$dayWord: ${selectedDayIds.length}',
          onRemove: () => onRemoveSideEffect(() => selectedDayIds.clear()),
        ),
      );
    }

    if (selectedLessonHourIds.isNotEmpty) {
      final hourWord = languageProvider.getTranslatedText({
        'en': 'Hour',
        'id': 'Jam',
      });
      filterChips.add(
        ActiveFilter(
          label: '$hourWord: ${selectedLessonHourIds.length}',
          onRemove: () =>
              onRemoveSideEffect(() => selectedLessonHourIds.clear()),
        ),
      );
    }

    return filterChips;
  }

  /// Filters in-memory summary list by search and active filters.
  /// Pure function with no side effects or API calls.
  List<AttendanceSummary> getFilteredSummaries({
    required List<AttendanceSummary> summaryList,
    required String searchText,
    required String? selectedDateFilter,
    required List<String> selectedSubjectIds,
    required List<String> selectedClassIds,
    required List<String> selectedDayIds,
    required List<String> selectedLessonHourIds,
  }) {
    final searchTerm = searchText.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    // Fix-DD — semester (rolling 6 months) and yearly (current year) bounds.
    final startOfSemester = DateTime(now.year, now.month - 6, now.day);
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31);

    return summaryList.where((summary) {
      final matchesSearch =
          searchTerm.isEmpty ||
          summary.subjectName.toLowerCase().contains(searchTerm) ||
          summary.className.toLowerCase().contains(searchTerm);

      bool matchesDateFilter = true;
      if (selectedDateFilter != null) {
        if (selectedDateFilter == 'today') {
          matchesDateFilter = _isSameDay(summary.date, now);
        } else if (selectedDateFilter == 'week') {
          matchesDateFilter =
              summary.date.isAfter(
                startOfWeek.subtract(const Duration(days: 1)),
              ) &&
              summary.date.isBefore(endOfWeek.add(const Duration(days: 1)));
        } else if (selectedDateFilter == 'month') {
          matchesDateFilter =
              summary.date.isAfter(
                startOfMonth.subtract(const Duration(days: 1)),
              ) &&
              summary.date.isBefore(endOfMonth.add(const Duration(days: 1)));
        } else if (selectedDateFilter == 'semester') {
          matchesDateFilter =
              summary.date.isAfter(
                startOfSemester.subtract(const Duration(days: 1)),
              ) &&
              summary.date.isBefore(now.add(const Duration(days: 1)));
        } else if (selectedDateFilter == 'year') {
          matchesDateFilter =
              summary.date.isAfter(
                startOfYear.subtract(const Duration(days: 1)),
              ) &&
              summary.date.isBefore(endOfYear.add(const Duration(days: 1)));
        }
      }

      final matchesSubject =
          selectedSubjectIds.isEmpty ||
          selectedSubjectIds.contains(summary.subjectId);

      final matchesClass =
          selectedClassIds.isEmpty ||
          selectedClassIds.contains(summary.classId);

      final matchesDay =
          selectedDayIds.isEmpty ||
          selectedDayIds.contains(summary.date.weekday.toString());

      final matchesLessonHour =
          selectedLessonHourIds.isEmpty ||
          selectedLessonHourIds.contains(summary.lessonHourId);

      return matchesSearch &&
          matchesDateFilter &&
          matchesSubject &&
          matchesClass &&
          matchesDay &&
          matchesLessonHour;
    }).toList();
  }

  /// Checks if two DateTime values fall on the same calendar day.
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
