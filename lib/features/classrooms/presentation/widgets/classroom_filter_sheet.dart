// Bottom sheet widget for filtering the classroom list by grade and homeroom status.
//
// Like Vue's `<ClassroomFilterModal>` component — owns its own temporary
// selection state and calls back via [onApply] only when the user taps Apply.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Bottom sheet for filtering classrooms by grade level and homeroom-teacher status.
///
/// Receives the currently active filter values as initial state, then calls
/// [onApply] with the new selections when the user taps "Apply Filter" —
/// analogous to a Vue `$emit('apply', filters)` event.
class ClassroomFilterSheet extends StatefulWidget {
  const ClassroomFilterSheet({
    super.key,
    this.initialGradeFilter,
    this.initialHomeroomFilter,
    required this.availableGradeLevels,
    required this.languageProvider,
    required this.onApply,
  });

  /// Currently active grade-level filter value (e.g. '7'), or null for "all".
  final String? initialGradeFilter;

  /// Currently active homeroom-teacher filter ('true'/'false'), or null for "all".
  final String? initialHomeroomFilter;

  /// Grade levels available for the current school type (e.g. ['7','8','9']).
  final List<String> availableGradeLevels;

  /// Language provider injected from the parent screen (avoids re-reading Riverpod here).
  final dynamic languageProvider;

  /// Called when the user taps "Apply Filter" — passes (gradeFilter, homeroomFilter).
  final void Function(String? gradeFilter, String? homeroomFilter) onApply;

  @override
  ClassroomFilterSheetState createState() => ClassroomFilterSheetState();
}

/// Mutable state for [ClassroomFilterSheet].
///
/// Like Vue `data()` inside the filter modal:
/// - [_tempGrade] — grade chip selection while the sheet is open
/// - [_tempHomeroom] — homeroom chip selection while the sheet is open
///
/// These are "temp" values: they only propagate to the parent on Apply,
/// matching the UX pattern where Cancel discards unsaved filter changes.
class ClassroomFilterSheetState extends State<ClassroomFilterSheet> {
  String? _tempGrade;
  String? _tempHomeroom;

  @override
  void initState() {
    super.initState();
    // Seed temp state from whatever the parent currently has applied.
    _tempGrade = widget.initialGradeFilter;
    _tempHomeroom = widget.initialHomeroomFilter;
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // ── Gradient header with Reset button ───────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
                    Text(
                      lang.getTranslatedText({
                        'en': 'Filter Classes',
                        'id': 'Filter Kelas',
                      }),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                // Reset clears temp state without closing or applying.
                TextButton(
                  onPressed: () => setState(() {
                    _tempGrade = null;
                    _tempHomeroom = null;
                  }),
                  child: Text(
                    lang.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable filter chips ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Grade level chips
                  Row(
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 16,
                        color: ColorUtils.slate600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        lang.getTranslatedText({
                          'en': 'Grade Level',
                          'id': 'Tingkat Kelas',
                        }),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.availableGradeLevels.map((gradeLevel) {
                      final isSelected = _tempGrade == gradeLevel;
                      return _buildFilterChip(
                        label: gradeLevel,
                        isSelected: isSelected,
                        onSelected: (selected) => setState(
                          () => _tempGrade = selected ? gradeLevel : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Homeroom teacher status chips
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: ColorUtils.slate600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        lang.getTranslatedText({
                          'en': 'Homeroom Teacher',
                          'id': 'Status Wali Kelas',
                        }),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {
                        'value': null,
                        'label': lang.getTranslatedText(
                            {'en': 'All', 'id': 'Semua'}),
                      },
                      {
                        'value': 'true',
                        'label': lang.getTranslatedText(
                            {'en': 'Assigned', 'id': 'Sudah Ada'}),
                      },
                      {
                        'value': 'false',
                        'label': lang.getTranslatedText(
                            {'en': 'Unassigned', 'id': 'Belum Ada'}),
                      },
                    ].map((item) {
                      final isSelected = _tempHomeroom == item['value'];
                      return _buildFilterChip(
                        label: item['label']! as String,
                        isSelected: isSelected,
                        onSelected: (_) => setState(
                          () => _tempHomeroom = item['value'] as String?,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer: Cancel / Apply ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    child: Text(
                      lang.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
                      style: TextStyle(
                        color: ColorUtils.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Propagate selections to parent then close.
                      widget.onApply(_tempGrade, _tempHomeroom);
                      AppNavigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.corporateBlue600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    child: Text(
                      lang.getTranslatedText({
                        'en': 'Apply Filter',
                        'id': 'Terapkan Filter',
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
        ],
      ),
    );
  }

  /// Builds a consistently styled [FilterChip] used throughout this sheet.
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required void Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: Colors.white,
      selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
      checkmarkColor: ColorUtils.corporateBlue600,
      labelStyle: TextStyle(
        color: isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color:
            isSelected ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(10))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
