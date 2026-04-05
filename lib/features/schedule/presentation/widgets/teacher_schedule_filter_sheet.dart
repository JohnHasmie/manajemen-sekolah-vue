// Bottom sheet widget for filtering the teacher's own teaching schedule.
// Extracted from TeachingScheduleScreenState._showFilterSheet to keep the
// screen lean and give filter state its own widget lifecycle.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

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
  }) onApply;

  @override
  TeacherScheduleFilterSheetState createState() =>
      TeacherScheduleFilterSheetState();
}

/// Local state for [TeacherScheduleFilterSheet].
///
/// Holds *temporary* "pending" selections that only become official when the
/// user taps Apply — like unsaved Vue form fields that are committed on submit.
class TeacherScheduleFilterSheetState
    extends State<TeacherScheduleFilterSheet> {
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Translates a raw Indonesian day name to the current UI language.
  String _getLocalizedDay(String dayRaw) {
    final dayMap = <String, Map<String, String>>{
      'senin': {'en': 'Monday', 'id': 'Senin'},
      'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
      'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
      'kamis': {'en': 'Thursday', 'id': 'Kamis'},
      'jumat': {'en': 'Friday', 'id': 'Jumat'},
      "jum'at": {'en': 'Friday', 'id': 'Jumat'},
      'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
      'minggu': {'en': 'Sunday', 'id': 'Minggu'},
    };
    final key = dayRaw.toLowerCase();
    return dayMap[key] != null
        ? widget.languageProvider.getTranslatedText(dayMap[key]!)
        : dayRaw;
  }

  /// Resets temporary selections back to "no filter" defaults.
  void _resetSelections() {
    setState(() {
      _tempDayIds.clear();
      _tempClassId = null;
      _tempSemester = widget.currentSemester;
    });
  }

  // ─── Sub-builders ──────────────────────────────────────────────────────────

  /// Small icon + label row used as a section heading in the filter list.
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(icon, size: 16, color: widget.primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  /// Animated toggle chip — selected state is highlighted with the role color.
  Widget _buildChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? widget.primaryColor.withValues(alpha: 0.1)
              : ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: selected ? widget.primaryColor : ColorUtils.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? widget.primaryColor : ColorUtils.slate600,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildScrollableContent()),
          _buildFooter(),
        ],
      ),
    );
  }

  /// Gradient header bar with title and Reset button.
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.primaryColor,
            widget.primaryColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  widget.languageProvider.getTranslatedText({
                    'en': 'Filter Schedule',
                    'id': 'Filter Jadwal',
                  }),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: _resetSelections,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Scrollable filter-chip sections.
  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Day filter ────────────────────────────────────────────────
          _buildSectionHeader(
            widget.languageProvider.getTranslatedText({
              'en': 'Day',
              'id': 'Hari',
            }),
            Icons.calendar_today_rounded,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.dayOptions
                .where((d) => d != 'Semua Hari')
                .map((day) {
                  final dayId = widget.dayIdMap[day] ?? '';
                  final selected = _tempDayIds.contains(dayId);
                  return _buildChip(
                    _getLocalizedDay(day),
                    selected,
                    () => setState(() {
                      if (selected) {
                        _tempDayIds.remove(dayId);
                      } else {
                        _tempDayIds.add(dayId);
                      }
                    }),
                  );
                })
                .toList(),
          ),

          // ── Class filter ──────────────────────────────────────────────
          if (widget.availableClasses.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader(
              widget.languageProvider.getTranslatedText({
                'en': 'Class',
                'id': 'Kelas',
              }),
              Icons.class_rounded,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.availableClasses.map((cls) {
                final selected = _tempClassId == cls['id'];
                return _buildChip(
                  cls['name'] ?? '',
                  selected,
                  () => setState(
                    () => _tempClassId = selected ? null : cls['id'],
                  ),
                );
              }).toList(),
            ),
          ],

          // ── Semester filter ───────────────────────────────────────────
          if (widget.semesterList.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildSectionHeader(
              widget.languageProvider.getTranslatedText({
                'en': 'Semester',
                'id': 'Semester',
              }),
              Icons.school_rounded,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.semesterList.map((sem) {
                final semId = sem['id'].toString();
                final label = sem['name'] ?? sem['nama'] ?? 'Semester';
                final selected = _tempSemester == semId;
                return _buildChip(
                  label,
                  selected,
                  () => setState(
                    () => _tempSemester = selected ? null : semId,
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  /// Sticky footer with Cancel and Apply buttons.
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => AppNavigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: ColorUtils.slate300),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                child: Text(
                  widget.languageProvider.getTranslatedText({
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
                  // Determine whether the semester changed so the parent
                  // knows to re-fetch schedule data from the API.
                  final needsReload = _tempSemester != widget.currentSemester;
                  AppNavigator.pop(context);
                  widget.onApply(
                    dayIds: List<String>.from(_tempDayIds),
                    classId: _tempClassId,
                    semester: _tempSemester,
                    needsReload: needsReload,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.languageProvider.getTranslatedText({
                    'en': 'Apply',
                    'id': 'Terapkan',
                  }),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
