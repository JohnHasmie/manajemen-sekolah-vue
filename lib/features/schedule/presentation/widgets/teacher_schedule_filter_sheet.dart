// Bottom sheet widget for filtering the teacher's own teaching schedule.
// Extracted from TeachingScheduleScreenState._showFilterSheet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/'
    'mixins/teacher_schedule_ui_mixin.dart';

/// Filter bottom sheet for the teacher teaching-schedule screen.
///
/// This is the teacher-side filter (day multi-select, class, semester).
/// It is different from [ScheduleFilterSheet] which serves the admin screen.
///
/// Data flows:
///   IN  → constructor: primary color, reference lists, pre-selected values
///   OUT → [onApply] callback: new day-id list, classId, semester
///         [needsReload] in the callback signals whether the semester changed
///         so the parent can decide whether to re-fetch from the API.
class TeacherScheduleFilterSheet extends StatefulWidget {
  const TeacherScheduleFilterSheet({
    super.key,
    required this.primaryColor,
    required this.dayOptions,
    required this.dayIdMap,
    required this.availableClasses,
    required this.semesterList,
    required this.currentSemester,
    required this.selectedDayIds,
    this.selectedClassId,
    this.selectedFilterSemester,
    required this.languageProvider,
    required this.onApply,
  });

  /// The role-specific accent color used for selected-chip highlights and
  /// the Apply button.  Like a CSS variable passed down from a Vue parent.
  final Color primaryColor;

  /// Full list of day-name strings, e.g. ['Semua Hari', 'Senin', …].
  /// 'Semua Hari' is always skipped when rendering chips.
  final List<String> dayOptions;

  /// Maps day-name → day-id, e.g. {'Senin': '1', 'Selasa': '2', …}.
  final Map<String, String> dayIdMap;

  /// Available class options: each map has 'id' and 'name' keys.
  final List<Map<String, String>> availableClasses;

  /// Full list of semester objects from the API (id, name/nama).
  final List<dynamic> semesterList;

  /// The screen-level default semester id — used when the user taps Reset.
  final String currentSemester;

  /// Currently active day-id filters (may be empty).
  final List<String> selectedDayIds;

  /// Currently active class filter (null = no class filter).
  final String? selectedClassId;

  /// Currently active semester filter (null = uses currentSemester).
  final String? selectedFilterSemester;

  /// Language provider for bilingual labels.
  final dynamic languageProvider;

  /// Called when the user confirms their selection.
  /// [dayIds]     — new list of selected day IDs (empty = all days)
  /// [classId]    — selected class ID, or null
  /// [semester]   — selected semester ID, or null
  /// [needsReload] — true when the semester selection changed so the parent
  ///                 knows to re-fetch schedule data from the API.
  final void Function({
    required List<String> dayIds,
    required String? classId,
    required String? semester,
    required bool needsReload,
  })
  onApply;

  @override
  TeacherScheduleFilterSheetState createState() =>
      TeacherScheduleFilterSheetState();
}

/// Local state for [TeacherScheduleFilterSheet].
///
/// Holds *temporary* "pending" selections that only become official when the
/// user taps Apply — like unsaved Vue form fields that are committed on submit.
class TeacherScheduleFilterSheetState extends State<TeacherScheduleFilterSheet>
    with TeacherScheduleUiMixin {
  // Temporary selections — copied from the parent's current values on init.
  late List<String> _tempDayIds;
  late String? _tempClassId;
  late String? _tempSemester;

  @override
  void initState() {
    super.initState();
    // Seed temporaries from parent's current filter state.
    _tempDayIds = List<String>.from(widget.selectedDayIds);
    _tempClassId = widget.selectedClassId;
    _tempSemester = widget.selectedFilterSemester ?? widget.currentSemester;
  }

  // ─── Mixin abstractions ────────────────────────────────────────────────

  @override
  Color get primaryColor => widget.primaryColor;

  @override
  List<String> get tempDayIds => _tempDayIds;

  @override
  set tempDayIds(List<String> value) => _tempDayIds = value;

  @override
  String? get tempClassId => _tempClassId;

  @override
  set tempClassId(String? value) => _tempClassId = value;

  @override
  String? get tempSemester => _tempSemester;

  @override
  set tempSemester(String? value) => _tempSemester = value;

  @override
  List<String> get dayOptions => widget.dayOptions;

  @override
  Map<String, String> get dayIdMap => widget.dayIdMap;

  @override
  List<Map<String, String>> get availableClasses => widget.availableClasses;

  @override
  List<dynamic> get semesterList => widget.semesterList;

  @override
  String get currentSemester => widget.currentSemester;

  @override
  dynamic get languageProvider => widget.languageProvider;

  @override
  void Function(
    List<String> dayIds,
    String? classId,
    String? semester,
    bool needsReload,
  )
  get onApplyCallback =>
      (dayIds, classId, semester, needsReload) => widget.onApply(
        dayIds: dayIds,
        classId: classId,
        semester: semester,
        needsReload: needsReload,
      );

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: languageProvider.getTranslatedText({
        'en': 'Filter Schedule',
        'id': 'Filter Jadwal',
      }),
      content: buildScrollableContent(),
      primaryColor: primaryColor,
      maxHeightFactor: 0.75,
      onApply: _onApplyPressed,
      onReset: _onResetPressed,
    );
  }

  void _onApplyPressed() {
    final semesterChanged =
        _tempSemester != widget.selectedFilterSemester && _tempSemester != null;
    Navigator.pop(context);
    onApplyCallback(_tempDayIds, _tempClassId, _tempSemester, semesterChanged);
  }

  void _onResetPressed() {
    setState(() {
      _tempDayIds.clear();
      _tempClassId = null;
      _tempSemester = currentSemester;
    });
  }
}
