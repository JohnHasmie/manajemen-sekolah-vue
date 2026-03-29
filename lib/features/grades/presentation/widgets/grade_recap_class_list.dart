// Step 0 of the grade recap wizard: scrollable, searchable list of classes.
// Like a Vue `<ClassList>` component — purely presentational, emits item taps
// upward so all wizard-state mutations stay in the parent StatefulWidget.
//
// Extracted from `_buildClassList` in `teacher_grade_recap_screen.dart`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_class_card.dart';

/// Scrollable list of classroom cards for the grade recap wizard (step 0).
///
/// Handles its own empty-state and loading-more footer, but all actual state
/// (pagination, selection) lives in the parent via callbacks.
///
/// In Laravel terms: renders the paginated output of `ClassroomController@index`.
class GradeRecapClassList extends StatelessWidget {
  /// Raw class list from the API; filtered by [searchQuery] internally.
  final List<dynamic> classList;

  /// Current search text (lowercased comparison happens inside this widget).
  final String searchQuery;

  /// Whether the initial data load is in progress — shows skeleton loader.
  final bool isLoading;

  /// Whether a paginated page-load is in progress — shows spinner at list end.
  final bool isLoadingMore;

  /// Brand colour passed through to each [GradeRecapClassCard].
  final Color primaryColor;

  /// Schedule entries for today, used to decide if a class gets a TODAY badge.
  final List<dynamic> todaySchedules;

  /// Translated label for the TODAY badge (e.g. "TODAY" / "HARI INI").
  final String todayLabel;

  /// Translated "No classes found" message for the empty state.
  final String emptyLabel;

  /// Scroll controller owned by the parent for infinite-scroll detection.
  final ScrollController scrollController;

  /// Called when the user taps a class card; the parent stores the selection
  /// and advances the wizard to step 1.
  final ValueChanged<Map<String, dynamic>> onClassTap;

  const GradeRecapClassList({
    super.key,
    required this.classList,
    required this.searchQuery,
    required this.isLoading,
    required this.isLoadingMore,
    required this.primaryColor,
    required this.todaySchedules,
    required this.todayLabel,
    required this.emptyLabel,
    required this.scrollController,
    required this.onClassTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show skeleton while the first page is loading (like Vue's v-if="isLoading").
    if (isLoading) return SkeletonListLoading();

    // Client-side filter: matches against class name and grade level.
    final filteredList = classList.where((item) {
      final name =
          (item['nama'] ?? item['name'] ?? '').toString().toLowerCase();
      final level = (item['grade_level'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) || level.contains(searchQuery);
    }).toList();

    // Empty state — like Vue's v-else block.
    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: ColorUtils.slate300),
            SizedBox(height: AppSpacing.lg),
            Text(
              emptyLabel,
              style: TextStyle(color: ColorUtils.slate500, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
      // +1 for the loading-more spinner row when paginating.
      itemCount: filteredList.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Last item slot: spinner while loading the next page.
        if (index == filteredList.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final item = filteredList[index];
        final classId = item['id']?.toString();
        final isToday = todaySchedules.any(
          (s) => s['class_id']?.toString() == classId,
        );

        return GradeRecapClassCard(
          item: Map<String, dynamic>.from(item as Map),
          primaryColor: primaryColor,
          isToday: isToday,
          todayLabel: todayLabel,
          onTap: () => onClassTap(Map<String, dynamic>.from(item)),
        );
      },
    );
  }
}
