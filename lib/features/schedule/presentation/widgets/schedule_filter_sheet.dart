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
class ScheduleFilterSheetState extends ConsumerState<ScheduleFilterSheet>
    with FilterChipBuilderMixin, FilterSheetUiMixin {
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    return AppFilterBottomSheet(
      title: languageProvider.getTranslatedText({
        'en': 'Filter Schedules',
        'id': 'Filter Jadwal',
      }),
      content: buildFilterContent(languageProvider, primaryColor),
      primaryColor: primaryColor,
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
