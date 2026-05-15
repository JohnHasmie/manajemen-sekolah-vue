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
    required this.semesterList,
    required this.lessonHourList,
    required this.currentSemester,
    this.selectedDayId,
    this.selectedClassId,
    this.selectedFilterSemester,
    this.selectedJamPelajaran,
    this.activeAcademicYearLabel,
    required this.onApply,
  });

  /// Reference data passed in from the parent screen (already loaded).
  final List<dynamic> availableDays;
  final List<dynamic> availableClasses;
  final List<dynamic> semesterList;
  final List<dynamic> lessonHourList;

  /// The screen-level default semester id used for the Reset action.
  final String currentSemester;

  /// Pre-selected filter values - null means "no filter active for this field".
  final String? selectedDayId;
  final String? selectedClassId;
  final String? selectedFilterSemester;
  final String? selectedJamPelajaran;

  /// Optional display label for the academic year currently active in the
  /// app-level [AcademicYearProvider] — e.g. "2024/2025". Surfaced in
  /// the filter sheet header subtitle so the admin can see the period
  /// context (the year picker itself lives in the global app shell, not
  /// here — this sheet only edits semester / day / class / hour).
  final String? activeAcademicYearLabel;

  /// Called when the user confirms their filter selections.
  /// Parameters mirror the four filterable dimensions exposed by the sheet.
  final void Function({
    required String? dayId,
    required String? classId,
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
  List<dynamic> get semesterList => widget.semesterList;
  @override
  List<dynamic> get lessonHourList => widget.lessonHourList;

  @override
  void initState() {
    super.initState();
    // Seed the temporary selections from the current values passed by parent.
    _tempSelectedHariId = widget.selectedDayId;
    _tempSelectedClassId = widget.selectedClassId;
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
    if (_tempSelectedLessonHour != null) n++;
    // Semester is treated as "active" only when it differs from the
    // screen-level default; matching the default reads as "no override".
    if (_tempSelectedSemester != null &&
        _tempSelectedSemester != widget.currentSemester) {
      n++;
    }
    return n;
  }

  /// Builds the header subtitle that surfaces the active academic period
  /// + filter count. Reads like "Periode 2024/2025 · 2 filter aktif"
  /// when filters are set, or just the period when none are pending.
  String? _composeSubtitle(dynamic languageProvider) {
    final year = widget.activeAcademicYearLabel;
    final count = _activeFilterCount;
    final pieces = <String>[];
    if (year != null && year.isNotEmpty) {
      pieces.add(languageProvider.getTranslatedText({
        'en': 'Period $year',
        'id': 'Periode $year',
      }));
    }
    if (count > 0) {
      pieces.add(languageProvider.getTranslatedText({
        'en': count == 1 ? '1 active filter' : '$count active filters',
        'id': '$count filter aktif',
      }));
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
      semester: _tempSelectedSemester,
      lessonHour: _tempSelectedLessonHour,
    );
  }
}
