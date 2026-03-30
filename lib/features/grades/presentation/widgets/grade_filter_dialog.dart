// Bottom-sheet widget for filtering which grade types are visible in the grade book.
// Like a Vue modal component with checkbox filters for 'uh', 'tugas', 'uts', etc.
// Pass current filter state in; receive updated state back via [onFilterChanged].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A bottom-sheet widget that lets the teacher toggle which grade types
/// (uh, tugas, uts, uas, pts, pas) are shown in the grade-book table.
///
/// Equivalent to a Vue `<FilterModal>` component that emits an updated
/// filter map back to the parent via [onFilterChanged].
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   builder: (_) => GradeFilterSheet(...)
/// );
/// ```
class GradeFilterSheet extends StatefulWidget {
  /// All available grade types, e.g. ['uh', 'tugas', 'uts', 'uas', 'pts', 'pas'].
  final List<String> allGradeTypes;

  /// Current checked/unchecked state, e.g. {'uh': true, 'tugas': false, ...}.
  final Map<String, bool> gradeTypeFilter;

  /// The primary brand colour used for the header gradient and active checkboxes.
  final Color primaryColor;

  /// Called every time a checkbox changes — like Vue `$emit('update:filter', newMap)`.
  final void Function(Map<String, bool> updated) onFilterChanged;

  /// Helper that turns a type key into a display label (delegates to screen helper).
  final String Function(String type) getLabel;

  const GradeFilterSheet({
    super.key,
    required this.allGradeTypes,
    required this.gradeTypeFilter,
    required this.primaryColor,
    required this.onFilterChanged,
    required this.getLabel,
  });

  @override
  State<GradeFilterSheet> createState() => _GradeFilterSheetState();
}

class _GradeFilterSheetState extends State<GradeFilterSheet> {
  // Local copy so we can preview changes before the parent commits them.
  // Like Vue's local `data()` copy of a prop — avoids mutating the parent directly.
  late Map<String, bool> _localFilter;

  @override
  void initState() {
    super.initState();
    // Deep-copy so we don't mutate the parent's map immediately.
    _localFilter = Map<String, bool>.from(widget.gradeTypeFilter);
  }

  void _resetAll() {
    setState(() {
      for (final key in _localFilter.keys) {
        _localFilter[key] = true;
      }
    });
    widget.onFilterChanged(Map<String, bool>.from(_localFilter));
  }

  void _toggleType(String type, bool? value) {
    setState(() {
      _localFilter[type] = value ?? false;
    });
    widget.onFilterChanged(Map<String, bool>.from(_localFilter));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.primaryColor,
                  widget.primaryColor.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.filter_list_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Hard-coded bilingual label — no LanguageProvider needed
                    // because the screen already passes a resolved label helper.
                    // We show this text as-is; the screen controls the language.
                    const Text(
                      'Filter Jenis Nilai / Filter Grade Types',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _resetAll,
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable checkbox list ────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: widget.allGradeTypes.map((type) {
                  return CheckboxListTile(
                    title: Text(
                      widget.getLabel(type),
                      style: TextStyle(
                        color: ColorUtils.slate800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: _localFilter[type] ?? true,
                    activeColor: widget.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onChanged: (bool? value) => _toggleType(type, value),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Footer apply button ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => AppNavigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Terapkan / Apply',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience function to open the [GradeFilterSheet] as a modal bottom sheet.
///
/// Like a Vue helper method that calls `this.$modal.open(FilterModal, props)`.
/// The screen calls this instead of building the sheet inline.
void showGradeFilterSheet({
  required BuildContext context,
  required List<String> allGradeTypes,
  required Map<String, bool> gradeTypeFilter,
  required Color primaryColor,
  required void Function(Map<String, bool> updated) onFilterChanged,
  required String Function(String type) getLabel,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GradeFilterSheet(
      allGradeTypes: allGradeTypes,
      gradeTypeFilter: gradeTypeFilter,
      primaryColor: primaryColor,
      onFilterChanged: onFilterChanged,
      getLabel: getLabel,
    ),
  );
}
