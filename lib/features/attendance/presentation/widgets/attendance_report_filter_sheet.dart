import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/mixins/attendance_filter_ui_mixin.dart';

/// Holds the selected filter values returned by the filter sheet.
class AttendanceFilterResult {
  final String? selectedDate;
  final List<String> selectedSubjectIds;
  final List<String> selectedClassIds;
  final List<String> selectedDayIds;
  final List<String> selectedLessonHourIds;

  const AttendanceFilterResult({
    this.selectedDate,
    this.selectedSubjectIds = const [],
    this.selectedClassIds = const [],
    this.selectedDayIds = const [],
    this.selectedLessonHourIds = const [],
  });
}

/// Shows the attendance report filter bottom sheet modal.
void showAttendanceReportFilterSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Color primaryColor,
  required String? initialDate,
  required List<String> initialSubjectIds,
  required List<String> initialClassIds,
  required List<String> initialDayIds,
  required List<String> initialLessonHourIds,
  required List<dynamic> subjectList,
  required List<dynamic> classList,
  required List<dynamic> lessonHours,
  required void Function(AttendanceFilterResult result) onApply,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AttendanceFilterSheet(
      primaryColor: primaryColor,
      initialDate: initialDate,
      initialSubjectIds: initialSubjectIds,
      initialClassIds: initialClassIds,
      initialDayIds: initialDayIds,
      initialLessonHourIds: initialLessonHourIds,
      subjectList: subjectList,
      classList: classList,
      lessonHours: lessonHours,
      onApply: onApply,
    ),
  );
}

class _AttendanceFilterSheet extends ConsumerStatefulWidget {
  final Color primaryColor;
  final String? initialDate;
  final List<String> initialSubjectIds;
  final List<String> initialClassIds;
  final List<String> initialDayIds;
  final List<String> initialLessonHourIds;
  final List<dynamic> subjectList;
  final List<dynamic> classList;
  final List<dynamic> lessonHours;
  final void Function(AttendanceFilterResult result) onApply;

  const _AttendanceFilterSheet({
    required this.primaryColor,
    this.initialDate,
    required this.initialSubjectIds,
    required this.initialClassIds,
    required this.initialDayIds,
    required this.initialLessonHourIds,
    required this.subjectList,
    required this.classList,
    required this.lessonHours,
    required this.onApply,
  });

  @override
  ConsumerState<_AttendanceFilterSheet> createState() =>
      _AttendanceFilterSheetState();
}

class _AttendanceFilterSheetState extends ConsumerState<_AttendanceFilterSheet>
    with AttendanceFilterUiMixin {
  late String? _tempDateFilter;
  late List<String> _tempSubjectIds;
  late List<String> _tempClassIds;
  late List<String> _tempDayIds;
  late List<String> _tempLessonHourIds;

  @override
  void initState() {
    super.initState();
    _tempDateFilter = widget.initialDate;
    _tempSubjectIds = List.from(widget.initialSubjectIds);
    _tempClassIds = List.from(widget.initialClassIds);
    _tempDayIds = List.from(widget.initialDayIds);
    _tempLessonHourIds = List.from(widget.initialLessonHourIds);
  }

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: filterLang.getTranslatedText({
        'en': 'Filter Attendance Report',
        'id': 'Filter Laporan Kehadiran',
      }),
      content: _buildFilterContent(),
      primaryColor: widget.primaryColor,
      onApply: () => _onApplyPressed(context),
      onReset: _onResetPressed,
    );
  }

  Widget _buildFilterContent() {
    return TeacherFilterContent(
      sections: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: filterLang.getTranslatedText({
                'en': 'Time Range',
                'id': 'Rentang Waktu',
              }),
              icon: Icons.date_range_rounded,
              primaryColor: widget.primaryColor,
            ),
            buildDateRangeChips(),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: filterLang.getTranslatedText({
                'en': 'Subject',
                'id': 'Mata Pelajaran',
              }),
              icon: Icons.book_outlined,
              primaryColor: widget.primaryColor,
            ),
            buildSubjectChips(),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: filterLang.getTranslatedText({'en': 'Day', 'id': 'Hari'}),
              icon: Icons.calendar_today_rounded,
              primaryColor: widget.primaryColor,
            ),
            buildDayChips(),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: filterLang.getTranslatedText({
                'en': 'Lesson Hour',
                'id': 'Jam Pelajaran',
              }),
              icon: Icons.schedule_rounded,
              primaryColor: widget.primaryColor,
            ),
            buildLessonHourChips(),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterSectionHeader(
              title: filterLang
                  .getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
              icon: Icons.class_outlined,
              primaryColor: widget.primaryColor,
            ),
            _buildClassChips(),
          ],
        ),
      ],
    );
  }

  Widget _buildClassChips() {
    return FilterChipGrid<String>(
      options: widget.classList.map((classItem) {
        final model =
            Classroom.fromJson(classItem as Map<String, dynamic>);
        return FilterOption(
          value: model.id,
          label: model.name,
        );
      }).toList(),
      selectedValues: Set.from(_tempClassIds),
      onMultiSelected: (selected) {
        setState(() {
          _tempClassIds = selected.toList();
        });
      },
      multiSelect: true,
      selectedColor: widget.primaryColor,
    );
  }

  @override
  LanguageProvider get filterLang => ref.read(languageRiverpod);

  @override
  Color get filterPrimaryColor => widget.primaryColor;

  @override
  String? get tempDateFilter => _tempDateFilter;

  @override
  set tempDateFilter(String? value) {
    setState(() {
      _tempDateFilter = value;
    });
  }

  @override
  List<String> get tempSubjectIds => _tempSubjectIds;

  @override
  List<String> get tempDayIds => _tempDayIds;

  @override
  List<String> get tempLessonHourIds => _tempLessonHourIds;

  @override
  List<dynamic> get filterSubjects => widget.subjectList;

  @override
  List<dynamic> get filterLessonHours => widget.lessonHours;

  @override
  Function get onFilterApply => _onApplyPressed;

  void _onApplyPressed(BuildContext ctx) {
    AppNavigator.pop(ctx);
    widget.onApply(
      AttendanceFilterResult(
        selectedDate: _tempDateFilter,
        selectedSubjectIds: List.from(_tempSubjectIds),
        selectedClassIds: List.from(_tempClassIds),
        selectedDayIds: List.from(_tempDayIds),
        selectedLessonHourIds: List.from(_tempLessonHourIds),
      ),
    );
  }

  void _onResetPressed() {
    setState(() {
      _tempDateFilter = null;
      _tempSubjectIds.clear();
      _tempClassIds.clear();
      _tempDayIds.clear();
      _tempLessonHourIds.clear();
    });
  }
}
