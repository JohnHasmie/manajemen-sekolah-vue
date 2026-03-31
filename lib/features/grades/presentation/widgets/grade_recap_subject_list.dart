// Step 1 of the grade recap wizard: searchable list of subjects for a class.
// Like a Vue `<SubjectList>` component — purely presentational, emits taps
// upward so all wizard-state mutations stay in the parent StatefulWidget.
//
// Extracted from `_buildSubjectList` in `teacher_grade_recap_screen.dart`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_subject_card.dart';

/// Searchable list of subject cards for the grade recap wizard (step 1).
///
/// Handles its own empty-state, but pagination is not needed for subjects
/// (typically a short list per teacher assignment).
///
/// In Laravel terms: renders the output of `SubjectController@index` filtered
/// by the selected classroom.
class GradeRecapSubjectList extends StatelessWidget {
  /// Raw subject list from the API; filtered by [searchQuery] internally.
  final List<dynamic> subjectList;

  /// Current search text (lowercased comparison happens inside this widget).
  final String searchQuery;

  /// Whether the initial data load is in progress — shows skeleton loader.
  final bool isLoading;

  /// Translated "No subjects found" message for the empty state.
  final String emptyLabel;

  /// Called when the user taps a subject card; the parent stores the selection
  /// and advances the wizard to step 2 (the recap table).
  final ValueChanged<Map<String, dynamic>> onSubjectTap;

  const GradeRecapSubjectList({
    super.key,
    required this.subjectList,
    required this.searchQuery,
    required this.isLoading,
    required this.emptyLabel,
    required this.onSubjectTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show skeleton while the subject list is loading.
    if (isLoading) return SkeletonListLoading();

    // Client-side filter: matches against subject name only.
    final filteredList = subjectList.where((item) {
      final name =
          (item['nama'] ?? item['name'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    // Empty state — like Vue's v-else block.
    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: ColorUtils.slate300),
            const SizedBox(height: AppSpacing.lg),
            Text(
              emptyLabel,
              style: TextStyle(color: ColorUtils.slate500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final item = filteredList[index];
        return GradeRecapSubjectCard(
          key: ValueKey(item['id']),
          item: Map<String, dynamic>.from(item),
          onTap: () => onSubjectTap(Map<String, dynamic>.from(item)),
        );
      },
    );
  }
}
