// Bottom sheet widget for filtering the admin schedule list.
// Extracted from TeachingScheduleManagementScreen._showFilterSheet to keep
// the screen file lean and give filter state its own widget lifecycle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_widgets.dart';

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
  }) onApply;

  @override
  ScheduleFilterSheetState createState() => ScheduleFilterSheetState();
}

/// Local state for [ScheduleFilterSheet].
///
/// Holds temporary "pending" selections that only become official when the user
/// taps Apply – like a local draft that is committed or discarded.
class ScheduleFilterSheetState extends ConsumerState<ScheduleFilterSheet> {
  // Temporary selections - only applied when user taps "Apply Filter".
  // Like unsaved form fields in Vue before submit().
  late String? _tempSelectedHariId;
  late String? _tempSelectedClassId;
  late String? _tempSelectedSemester;
  late String? _tempSelectedLessonHour;

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

  /// Resets all temporary selections back to defaults (no filter except default
  /// semester).  Only affects local state - nothing is applied to the screen
  /// until the user taps Apply.
  void _resetSelections() {
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(languageProvider),
            Expanded(child: _buildFilterContent(languageProvider)),
            _buildFooter(languageProvider),
          ],
        ),
      ),
    );
  }

  /// Gradient header with title and Reset button.
  Widget _buildHeader(dynamic languageProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(
              Icons.filter_list,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Filter Schedules',
                'id': 'Filter Jadwal',
              }),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: _resetSelections,
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Reset',
                'id': 'Reset',
              }),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Scrollable body containing day, class, semester, and lesson hour chips.
  Widget _buildFilterContent(dynamic languageProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day filter ──────────────────────────────────────────────────
          ScheduleFilterSectionHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Day',
              'id': 'Hari',
            }),
            icon: Icons.calendar_today_outlined,
          ),
          _buildDayChips(languageProvider),

          // ── Class filter ─────────────────────────────────────────────────
          ScheduleFilterSectionHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Class',
              'id': 'Kelas',
            }),
            icon: Icons.class_outlined,
          ),
          _buildClassChips(),

          // ── Semester filter ──────────────────────────────────────────────
          ScheduleFilterSectionHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Semester',
              'id': 'Semester',
            }),
            icon: Icons.school_outlined,
          ),
          _buildTermChips(),

          // ── Lesson Hour filter ───────────────────────────────────────────
          ScheduleFilterSectionHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Lesson Hour',
              'id': 'Jam Pelajaran',
            }),
            icon: Icons.access_time_outlined,
          ),
          _buildLessonHourChips(),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  /// FilterChip row for days.  Handles both Indonesian and English day names
  /// by normalising the raw value from the API to a bilingual map.
  Widget _buildDayChips(dynamic languageProvider) {
    // Bilingual day-name lookup - like a translation table in the Laravel lang files.
    const dayMap = <String, Map<String, String>>{
      'senin': {'en': 'Monday', 'id': 'Senin'},
      'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
      'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
      'kamis': {'en': 'Thursday', 'id': 'Kamis'},
      'jumat': {'en': 'Friday', 'id': 'Jumat'},
      "jum'at": {'en': 'Friday', 'id': 'Jumat'},
      'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
      'minggu': {'en': 'Sunday', 'id': 'Minggu'},
      'monday': {'en': 'Monday', 'id': 'Senin'},
      'tuesday': {'en': 'Tuesday', 'id': 'Selasa'},
      'wednesday': {'en': 'Wednesday', 'id': 'Rabu'},
      'thursday': {'en': 'Thursday', 'id': 'Kamis'},
      'friday': {'en': 'Friday', 'id': 'Jumat'},
      'saturday': {'en': 'Saturday', 'id': 'Sabtu'},
      'sunday': {'en': 'Sunday', 'id': 'Minggu'},
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.availableDays.map<Widget>((day) {
        final dayId = day['id'].toString();
        final dayNameRaw = day['name'] ?? day['nama'] ?? '';
        final normalizedKey = dayNameRaw.toString().toLowerCase();
        final dayName = dayMap[normalizedKey] != null
            ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
            : dayNameRaw;
        final isSelected = _tempSelectedHariId == dayId;

        return FilterChip(
          label: Text(dayName),
          selected: isSelected,
          onSelected: (selected) => setState(
            () => _tempSelectedHariId = selected ? dayId : null,
          ),
          backgroundColor: Colors.white,
          selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
          checkmarkColor: ColorUtils.corporateBlue600,
          side: BorderSide(
            color:
                isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
            width: 1,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          labelStyle: TextStyle(
            color: isSelected
                ? ColorUtils.corporateBlue600
                : ColorUtils.slate700,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  /// FilterChip row for class groups.
  Widget _buildClassChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.availableClasses.map<Widget>((cls) {
        final classId = cls['id'].toString();
        final className = cls['name'] ?? cls['nama'] ?? '';
        final isSelected = _tempSelectedClassId == classId;

        return FilterChip(
          label: Text(className),
          selected: isSelected,
          onSelected: (selected) => setState(
            () => _tempSelectedClassId = selected ? classId : null,
          ),
          backgroundColor: Colors.white,
          selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
          checkmarkColor: ColorUtils.corporateBlue600,
          side: BorderSide(
            color:
                isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
            width: 1,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          labelStyle: TextStyle(
            color: isSelected
                ? ColorUtils.corporateBlue600
                : ColorUtils.slate700,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  /// FilterChip row for semesters.  Appends the academic year in parentheses
  /// when the semester data includes a nested academic_year object.
  Widget _buildTermChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.semesterList.map<Widget>((semester) {
        final semesterId = semester['id'].toString();
        String semesterName =
            semester['name'] ?? semester['nama'] ?? 'Semester $semesterId';
        if (semester['academic_year'] != null &&
            semester['academic_year']['year'] != null) {
          semesterName += ' (${semester['academic_year']['year']})';
        }
        final isSelected = _tempSelectedSemester == semesterId;

        return FilterChip(
          label: Text(semesterName),
          selected: isSelected,
          onSelected: (selected) => setState(
            () => _tempSelectedSemester = selected ? semesterId : null,
          ),
          backgroundColor: Colors.white,
          selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
          checkmarkColor: ColorUtils.corporateBlue600,
          side: BorderSide(
            color:
                isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
            width: 1,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          labelStyle: TextStyle(
            color: isSelected
                ? ColorUtils.corporateBlue600
                : ColorUtils.slate700,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  /// FilterChip row for lesson hours.  Deduplicates by hour_number and sorts
  /// numerically before rendering.
  Widget _buildLessonHourChips() {
    final Set<String> uniqueHours = {};
    for (final jp in widget.lessonHourList) {
      final h = (jp['hour_number'] ?? jp['jam_ke'])?.toString();
      if (h != null) uniqueHours.add(h);
    }
    final sortedHours = uniqueHours.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedHours.map<Widget>((hourNum) {
        final isSelected = _tempSelectedLessonHour == hourNum;

        return FilterChip(
          label: Text('Jam $hourNum'),
          selected: isSelected,
          onSelected: (selected) => setState(
            () => _tempSelectedLessonHour = selected ? hourNum : null,
          ),
          backgroundColor: Colors.white,
          selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
          checkmarkColor: ColorUtils.corporateBlue600,
          side: BorderSide(
            color:
                isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
            width: 1,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          labelStyle: TextStyle(
            color: isSelected
                ? ColorUtils.corporateBlue600
                : ColorUtils.slate700,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        );
      }).toList(),
    );
  }

  /// Sticky footer with Cancel and Apply Filter buttons.
  Widget _buildFooter(dynamic languageProvider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => AppNavigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                side: BorderSide(color: ColorUtils.slate300),
              ),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Cancel',
                  'id': 'Batal',
                }),
                style: TextStyle(
                  color: ColorUtils.slate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Close the sheet first, then fire the callback so the parent
                // screen can update its own state and reload data.
                AppNavigator.pop(context);
                widget.onApply(
                  dayId: _tempSelectedHariId,
                  classId: _tempSelectedClassId,
                  semester: _tempSelectedSemester,
                  lessonHour: _tempSelectedLessonHour,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.corporateBlue600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
              ),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Apply Filter',
                  'id': 'Terapkan Filter',
                }),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
