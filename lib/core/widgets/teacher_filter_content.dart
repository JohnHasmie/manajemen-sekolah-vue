// Shared filter content body used inside AppFilterBottomSheet.
//
// Why this exists
// ---------------
// Grades, Attendance, Materials, Class Activity, and Schedule all build the
// same filter layout inside their bottom sheet: a Column of FilterChipGrid
// sections for class / subject / optional date — with identical spacing
// between sections. This widget composes them so each feature's filter
// mixin only declares which sections it wants, without repeating layout
// glue or re-implementing the gap-between-sections rule.
//
// Usage:
// ```dart
// showFilterSheet(
//   context: context,
//   title: 'Filter Nilai',
//   primaryColor: primaryColor,
//   onApply: _apply,
//   onReset: _reset,
//   content: TeacherFilterContent(
//     sections: [
//       FilterChipGrid<String>(
//         title: 'Kelas',
//         options: classOptions,
//         selectedValue: _filterClassId,
//         onSelected: (v) => setState(() => _filterClassId = v),
//         selectedColor: primaryColor,
//       ),
//       FilterChipGrid<String>(
//         title: 'Mata Pelajaran',
//         options: subjectOptions,
//         selectedValue: _filterSubjectId,
//         onSelected: (v) => setState(() => _filterSubjectId = v),
//         selectedColor: primaryColor,
//       ),
//     ],
//   ),
// );
// ```
//
// Sections are plain Widgets — typically [FilterChipGrid]s — so callers keep
// full type safety on their value type (T stays `String` for class IDs, etc.)
// without this helper needing any generics.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Renders a vertical stack of filter sections with consistent spacing.
///
/// Designed to be passed to [AppFilterBottomSheet.content] or
/// [showFilterSheet]. Stateless on its own — callers own the selection
/// state via setState or Riverpod.
class TeacherFilterContent extends StatelessWidget {
  /// The filter sections — each is typically a [FilterChipGrid] or a
  /// `Column` of `[FilterSectionHeader, FilterChipGrid]`.
  final List<Widget> sections;

  /// Gap between sections. Defaults to [AppSpacing.lg] (16) — the sheet
  /// scaffold trims top whitespace below the gradient header, and
  /// [FilterSectionHeader] no longer contributes its own top padding, so
  /// 16 px between sections is enough to feel airy without looking
  /// sparse. Override to [AppSpacing.xl] or higher if a sheet needs
  /// more separation.
  final double sectionSpacing;

  const TeacherFilterContent({
    super.key,
    required this.sections,
    this.sectionSpacing = AppSpacing.lg,
  });

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) SizedBox(height: sectionSpacing),
          sections[i],
        ],
      ],
    );
  }
}
