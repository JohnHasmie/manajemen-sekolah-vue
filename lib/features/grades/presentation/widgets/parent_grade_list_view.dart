// Scrollable list of grade cards for the parent grade screen.
// Each card auto-triggers a visibility callback so the screen can mark it read.
// Like a Vue `<GradeList>` that emits `item-visible` and `item-tap` events.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';

/// Scrollable list of grade cards shown in the parent grade screen.
///
/// Uses two callbacks instead of calling parent setState directly:
///   - [onItemVisible] → screen queues the grade for "mark as read"
///                       (debounced).
///   - [onGradeTap]    → screen opens the detail dialog.
///
/// This mirrors the Vue pattern of emitting events upward rather than mutating
/// parent state from a child component.
class ParentGradeListView extends StatelessWidget {
  /// Full grade list fetched from the API.
  final List<dynamic> gradeList;

  /// Currently selected student ID; null means "no student chosen yet".
  final String? selectedStudentId;

  /// Whether the grade data is still loading (shows skeleton when true).
  final Widget loadingWidget;

  /// Key used to anchor the onboarding tour spotlight on this list.
  final GlobalKey listKey;

  /// Map of grade type → accent colour (e.g. `'tugas' → blue`).
  final Map<String, Color> gradeTypeColorMap;

  /// Formats a raw API date value into a display string.
  /// Like a Laravel accessor or a Vue filter.
  final String Function(dynamic date) formatDate;

  /// Returns the human-readable label for a grade type key.
  final String Function(String type) getGradeTypeLabel;

  /// Called when a list item scrolls into the viewport.
  /// The screen uses this to queue the grade for "mark as read".
  final void Function(Map<String, dynamic> grade) onItemVisible;

  /// Called when the user taps a grade card; the screen shows the detail
  /// dialog.
  final void Function(Map<String, dynamic> grade) onGradeTap;

  /// Optional scroll controller — attach for infinite-scroll pagination.
  final ScrollController? controller;

  /// Whether the next page is currently loading (shows a footer spinner).
  final bool isLoadingMore;

  const ParentGradeListView({
    super.key,
    required this.gradeList,
    required this.selectedStudentId,
    required this.loadingWidget,
    required this.listKey,
    required this.gradeTypeColorMap,
    required this.formatDate,
    required this.getGradeTypeLabel,
    required this.onItemVisible,
    required this.onGradeTap,
    this.controller,
    this.isLoadingMore = false,
  });

  // ---------------------------------------------------------------------------
  // Private helper — small info-tag chip (under 25 lines, stays here).
  // Equivalent to a tiny Vue `<InfoTag>` scoped to this component.
  // ---------------------------------------------------------------------------
  Widget _buildInfoTag(IconData icon, String text, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guard: no student chosen yet.
    if (selectedStudentId == null) {
      return BrandEmptyState(
        icon: Icons.assignment_outlined,
        tone: BrandEmptyStateTone.info,
        kicker: 'Belum ada data',
        title: 'Belum ada nilai',
        message: AppLocalizations.selectChildToViewGrades.tr,
      );
    }

    // Guard: data still fetching — show skeleton passed from parent.
    if (gradeList.isEmpty) {
      // loadingWidget is shown when the list is empty (covers both "loading"
      // and "truly empty" cases; parent passes the right widget via build()).
      // The parent differentiates: if isLoading → SkeletonLoading, else
      // EmptyState.
      return loadingWidget;
    }

    return ListView.builder(
      key: listKey,
      controller: controller,
      // The parent screen now hosts a single outer ListView so the
      // gradient hero scrolls with the body. shrinkWrap +
      // NeverScrollable defers scrolling to the outer list.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: gradeList.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == gradeList.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final grade = gradeList[index];
        final type = grade['type']?.toString().toLowerCase() ?? 'tugas';
        final typeColor = gradeTypeColorMap[type] ?? ColorUtils.brandAzure;
        final score = double.tryParse(grade['score']?.toString() ?? '0') ?? 0;
        final assessmentTitle = grade['title']?.toString();
        final isRead =
            grade['is_read'] == true ||
            grade['is_read'] == 1 ||
            grade['is_read'] == '1';

        return Builder(
          builder: (context) {
            // Notify the parent screen that this item is now visible so it can
            // be queued for "mark as read" — like calling
            // $emit('item-visible').
            onItemVisible(grade);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onGradeTap(grade),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(Radius.circular(14)),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score badge — coloured by grade type.
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(14),
                            ),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                score.toStringAsFixed(0) == score.toString()
                                    ? score.toStringAsFixed(0)
                                    : score.toString(),
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        // Card body — subject, title, info tags.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      grade['subject_name'] ??
                                          grade['mata_pelajaran'] ??
                                          AppLocalizations.subject.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: ColorUtils.slate900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Unread indicator dot (like a Vue v-if
                                  // badge).
                                  if (!isRead) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: ColorUtils.error600,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (assessmentTitle != null &&
                                  assessmentTitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  assessmentTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColorUtils.slate600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              // Info tags row — type, date, teacher.
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildInfoTag(
                                    Icons.category_outlined,
                                    getGradeTypeLabel(type),
                                    tagColor: typeColor,
                                  ),
                                  _buildInfoTag(
                                    Icons.calendar_today_outlined,
                                    formatDate(grade['date']),
                                  ),
                                  if (grade['teacher_name'] != null)
                                    _buildInfoTag(
                                      Icons.person_outlined,
                                      grade['teacher_name'],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
