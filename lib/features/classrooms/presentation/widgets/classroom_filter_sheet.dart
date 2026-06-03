// Bottom sheet widget for filtering the classroom list by grade and homeroom
// status.
//
// Like Vue's `<ClassroomFilterModal>` component — owns its own temporary
// selection state and calls back via [onApply] only when the user taps Apply.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// Bottom sheet for filtering classrooms by grade level and homeroom-teacher
/// status.
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

  /// Language provider injected from the parent screen (avoids re-reading
  /// Riverpod here).
  final dynamic languageProvider;

  /// Called when the user taps "Apply Filter" — passes (gradeFilter,
  /// homeroomFilter).
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
    final primary = ColorUtils.getRoleColor('admin');

    return AppFilterBottomSheet(
      title: lang.getTranslatedText({
        'en': 'Filter Classes',
        'id': 'Filter Kelas',
      }),
      icon: Icons.filter_list_rounded,
      primaryColor: primary,
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Grade Level',
                  'id': 'Tingkat Kelas',
                }),
                icon: Icons.layers_outlined,
                primaryColor: primary,
              ),
              FilterChipGrid<String?>(
                options: widget.availableGradeLevels
                    .map((g) => FilterOption<String?>(value: g, label: g))
                    .toList(),
                selectedValue: _tempGrade,
                onSelected: (val) =>
                    setState(() => _tempGrade = val == _tempGrade ? null : val),
                selectedColor: primary,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Homeroom Teacher',
                  'id': 'Status Wali Kelas',
                }),
                icon: Icons.person_outline,
                primaryColor: primary,
              ),
              FilterChipGrid<String?>(
                options: [
                  FilterOption<String?>(
                    value: null,
                    label: lang.getTranslatedText({'en': 'All', 'id': 'Semua'}),
                  ),
                  FilterOption<String?>(
                    value: 'true',
                    label: lang.getTranslatedText({
                      'en': 'Assigned',
                      'id': 'Sudah Ada',
                    }),
                  ),
                  FilterOption<String?>(
                    value: 'false',
                    label: lang.getTranslatedText({
                      'en': 'Unassigned',
                      'id': 'Belum Ada',
                    }),
                  ),
                ],
                selectedValue: _tempHomeroom,
                onSelected: (val) => setState(() => _tempHomeroom = val),
                selectedColor: primary,
              ),
            ],
          ),
        ],
      ),
      onApply: () {
        AppNavigator.pop(context);
        widget.onApply(_tempGrade, _tempHomeroom);
      },
      onReset: () => setState(() {
        _tempGrade = null;
        _tempHomeroom = null;
      }),
    );
  }
}
