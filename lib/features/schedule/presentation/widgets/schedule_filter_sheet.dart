// Bottom sheet widget for filtering the admin schedule list.
// Extracted from TeachingScheduleManagementScreen._showFilterSheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/filter_chip_builder_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/filter_sheet_ui_mixin.dart';

/// Filter bottom sheet for the admin teaching schedule screen.
///
/// Receives the current filter values via constructor (so the sheet pre-selects
/// the active chips when opened) and calls [onApply] with the new values when
/// the user taps "Apply Filter".  Think of it like a Vue modal component that
/// emits an `apply` event back to its parent page.
///
/// Data flows:
///   IN  → constructor params: pre-selected ids, reference lists
///   OUT → [onApply] callback: (dayId, classId, semester, jamPelajaran)
class ScheduleFilterSheet extends ConsumerStatefulWidget {
  const ScheduleFilterSheet({
    super.key,
    required this.availableDays,
    required this.availableClasses,
    required this.availableTeachers,
    required this.availableSubjects,
    required this.semesterList,
    required this.lessonHourList,
    required this.currentSemester,
    this.scheduleList = const [],
    this.selectedDayId,
    this.selectedClassId,
    this.selectedTeacherId,
    this.selectedSubjectId,
    this.selectedFilterSemester,
    this.selectedJamPelajaran,
    this.activeAcademicYearLabel,
    required this.onApply,
  });

  /// Reference data passed in from the parent screen (already loaded).
  final List<dynamic> availableDays;
  final List<dynamic> availableClasses;
  final List<dynamic> availableTeachers;
  final List<dynamic> availableSubjects;
  final List<dynamic> semesterList;
  final List<dynamic> lessonHourList;

  /// The full schedule list — used to derive teacher↔subject relationships
  /// for cross-filtering (selecting a teacher narrows subjects, and vice
  /// versa).
  final List<dynamic> scheduleList;

  /// The screen-level default semester id used for the Reset action.
  final String currentSemester;

  /// Pre-selected filter values - null means "no filter active for this field".
  final String? selectedDayId;
  final String? selectedClassId;
  final String? selectedTeacherId;
  final String? selectedSubjectId;
  final String? selectedFilterSemester;
  final String? selectedJamPelajaran;

  /// Optional display label for the academic year currently active in the
  /// app-level [AcademicYearProvider] — e.g. "2024/2025". Surfaced in
  /// the filter sheet header subtitle so the admin can see the period
  /// context (the year picker itself lives in the global app shell, not
  /// here — this sheet only edits semester / day / class / hour).
  final String? activeAcademicYearLabel;

  /// Called when the user confirms their filter selections.
  /// Parameters mirror the six filterable dimensions exposed by the sheet:
  /// teacher, subject, day, class, semester, lesson-hour. Teacher + subject
  /// were added in Fix-1a so admin can scope per-guru / per-mapel listings.
  final void Function({
    required String? dayId,
    required String? classId,
    required String? teacherId,
    required String? subjectId,
    required String? semester,
    required String? lessonHour,
  })
  onApply;

  @override
  ScheduleFilterSheetState createState() => ScheduleFilterSheetState();
}

/// Local state for [ScheduleFilterSheet].
///
/// Holds temporary "pending" selections that only become official when the user
/// taps Apply – like a local draft that is committed or discarded.
// Mixin order matters: Dart applies left → right, so the LATER mixin's
// methods win. FilterSheetUiMixin still carries stub `buildDayChips /
// buildClassChips / buildTermChips / buildLessonHourChips` that return
// `SizedBox.shrink()` — keeping it last would shadow the real chip
// builders in FilterChipBuilderMixin and ship an empty filter sheet
// (the original prod bug). Put FilterChipBuilderMixin last so its real
// implementations override the UI mixin's stubs.
class ScheduleFilterSheetState extends ConsumerState<ScheduleFilterSheet>
    with FilterSheetUiMixin, FilterChipBuilderMixin {
  // Temporary selections - only applied when user taps "Apply Filter".
  // Like unsaved form fields in Vue before submit().
  late String? _tempSelectedHariId;
  late String? _tempSelectedClassId;
  late String? _tempSelectedTeacherId;
  late String? _tempSelectedSubjectId;
  late String? _tempSelectedSemester;
  late String? _tempSelectedLessonHour;

  // Mixin abstract getters/setters for _temp* fields.
  @override
  String? get tempSelectedHariId => _tempSelectedHariId;
  @override
  set tempSelectedHariId(String? value) => _tempSelectedHariId = value;

  @override
  String? get tempSelectedClassId => _tempSelectedClassId;
  @override
  set tempSelectedClassId(String? value) => _tempSelectedClassId = value;

  @override
  String? get tempSelectedTeacherId => _tempSelectedTeacherId;
  @override
  set tempSelectedTeacherId(String? value) => _tempSelectedTeacherId = value;

  @override
  String? get tempSelectedSubjectId => _tempSelectedSubjectId;
  @override
  set tempSelectedSubjectId(String? value) => _tempSelectedSubjectId = value;

  @override
  String? get tempSelectedSemester => _tempSelectedSemester;
  @override
  set tempSelectedSemester(String? value) => _tempSelectedSemester = value;

  @override
  String? get tempSelectedLessonHour => _tempSelectedLessonHour;
  @override
  set tempSelectedLessonHour(String? value) => _tempSelectedLessonHour = value;

  // Mixin stub overrides for widget data.
  @override
  List<dynamic> get availableDays => widget.availableDays;
  @override
  List<dynamic> get availableClasses => widget.availableClasses;
  @override
  List<dynamic> get availableTeachers => widget.availableTeachers;
  @override
  List<dynamic> get availableSubjects => widget.availableSubjects;
  @override
  List<dynamic> get semesterList => widget.semesterList;
  @override
  List<dynamic> get lessonHourList => widget.lessonHourList;
  @override
  List<dynamic> get scheduleList => widget.scheduleList;

  @override
  void initState() {
    super.initState();
    // Seed the temporary selections from the current values passed by parent.
    _tempSelectedHariId = widget.selectedDayId;
    _tempSelectedClassId = widget.selectedClassId;
    _tempSelectedTeacherId = widget.selectedTeacherId;
    _tempSelectedSubjectId = widget.selectedSubjectId;
    // Default to the screen-level semester when no filter semester is active.
    _tempSelectedSemester =
        widget.selectedFilterSemester ?? widget.currentSemester;
    _tempSelectedLessonHour = widget.selectedJamPelajaran;
  }

  /// Resets all temporary selections back to defaults (no filter except
  /// default semester).
  @override
  void onResetSelections() {
    setState(() {
      _tempSelectedHariId = null;
      _tempSelectedClassId = null;
      _tempSelectedTeacherId = null;
      _tempSelectedSubjectId = null;
      _tempSelectedLessonHour = null;
      _tempSelectedSemester = widget.currentSemester;
    });
  }

  /// Number of filters with a non-null pending selection — used to badge
  /// the Apply button and to drive the header subtitle wording.
  int get _activeFilterCount {
    var n = 0;
    if (_tempSelectedHariId != null) n++;
    if (_tempSelectedClassId != null) n++;
    if (_tempSelectedTeacherId != null) n++;
    if (_tempSelectedSubjectId != null) n++;
    if (_tempSelectedLessonHour != null) n++;
    // Semester is treated as "active" only when it differs from the
    // screen-level default; matching the default reads as "no override".
    if (_tempSelectedSemester != null &&
        _tempSelectedSemester != widget.currentSemester) {
      n++;
    }
    return n;
  }

  /// Live preview count — how many rows in [widget.scheduleList] match
  /// the *pending* temp selections (the chip taps not yet applied).
  ///
  /// Updates every rebuild so the header subtitle shows "12 jadwal
  /// cocok" alongside the period, giving admin a confidence cue
  /// before they hit Apply. Matches Frame G's brand intent — make
  /// the sheet feel responsive instead of "guess + check".
  int get _previewCount {
    if (widget.scheduleList.isEmpty) return 0;
    var n = 0;
    for (final raw in widget.scheduleList) {
      if (raw is! Map) continue;
      final s = raw as Map<String, dynamic>;
      if (_tempSelectedTeacherId != null &&
          s['teacher_id']?.toString() != _tempSelectedTeacherId) {
        continue;
      }
      if (_tempSelectedSubjectId != null &&
          s['subject_id']?.toString() != _tempSelectedSubjectId) {
        continue;
      }
      if (_tempSelectedClassId != null &&
          s['class_id']?.toString() != _tempSelectedClassId) {
        continue;
      }
      if (_tempSelectedHariId != null &&
          s['day_id']?.toString() != _tempSelectedHariId) {
        continue;
      }
      if (_tempSelectedLessonHour != null) {
        final rawHour = s['lesson_hour'];
        String? hourNumber;
        if (rawHour is Map) {
          hourNumber = (rawHour['hour_number'] ?? rawHour['jam_ke'])
              ?.toString();
        } else if (rawHour != null) {
          hourNumber = rawHour.toString();
        }
        if (hourNumber != _tempSelectedLessonHour) continue;
      }
      n++;
    }
    return n;
  }

  /// Builds the header subtitle that surfaces the active academic
  /// period + live preview count. Reads like
  /// "Periode 2024/2025 · 12 jadwal cocok" — the second segment
  /// updates in real-time as the admin selects / deselects chips so
  /// they can see if their filter will narrow to nothing before
  /// applying. Falls back to just the period (or null) when no list
  /// is available.
  String? _composeSubtitle(dynamic languageProvider) {
    final year = widget.activeAcademicYearLabel;
    final pieces = <String>[];
    if (year != null && year.isNotEmpty) {
      pieces.add(
        languageProvider.getTranslatedText({
          'en': 'Period $year',
          'id': 'Periode $year',
        }),
      );
    }
    if (widget.scheduleList.isNotEmpty) {
      final preview = _previewCount;
      pieces.add(
        languageProvider.getTranslatedText({
          'en': '$preview matches',
          'id': '$preview jadwal cocok',
        }),
      );
    }
    return pieces.isEmpty ? null : pieces.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');
    final count = _activeFilterCount;

    return AppFilterBottomSheet(
      title: languageProvider.getTranslatedText({
        'en': 'Filter Schedules',
        'id': 'Filter Jadwal',
      }),
      // Brand alignment (TR.G) — calendar icon makes the schedule
      // filter's intent obvious in the header rail vs the generic
      // `Icons.tune_rounded` default.
      icon: Icons.calendar_view_week_rounded,
      headerSubtitle: _composeSubtitle(languageProvider),
      content: buildFilterContent(languageProvider, primaryColor),
      primaryColor: primaryColor,
      applyLabel: count > 0
          ? languageProvider.getTranslatedText({
              'en': 'Apply ($count)',
              'id': 'Terapkan ($count)',
            })
          : languageProvider.getTranslatedText({
              'en': 'Apply Filter',
              'id': 'Terapkan Filter',
            }),
      onApply: _onApplyPressed,
      onReset: onResetSelections,
    );
  }

  void _onApplyPressed() {
    AppNavigator.pop(context);
    widget.onApply(
      dayId: _tempSelectedHariId,
      classId: _tempSelectedClassId,
      teacherId: _tempSelectedTeacherId,
      subjectId: _tempSelectedSubjectId,
      semester: _tempSelectedSemester,
      lessonHour: _tempSelectedLessonHour,
    );
  }
}
