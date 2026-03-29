// Activity list body for Step 2 of the class-activity wizard.
// Shows search/filter bar, active-filter chips, and the scrollable activity cards.
// Replaces _buildActivityList() from teacher_class_activity_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_search_filter_bar.dart';

/// The scrollable activity list displayed in Step 2 of the teacher wizard.
///
/// Handles three visual states: loading skeleton, empty state, and a
/// [ListView.builder] with infinite-scroll support. Active filter chips sit
/// between the search bar and the list. This is like a Vue component that
/// receives all its data and callbacks as props — no local state, no setState.
///
/// Uses [ConsumerWidget] because it calls `ref.watch(languageRiverpod)` to
/// react to locale changes without the parent needing to pass the provider down.
class ActivityListView extends ConsumerWidget {
  // ── Loading / data state ──────────────────────────────────────────────────
  final bool isLoading;
  final bool isLoadingMore;
  final List<dynamic> activityList;

  // ── Filter state ──────────────────────────────────────────────────────────
  final bool hasActiveFilter;

  /// Non-null when a date filter is active; value is 'today' | 'week' | 'month'.
  final String? selectedDateFilter;

  // ── Controllers passed from parent State ─────────────────────────────────
  final TextEditingController searchController;
  final ScrollController scrollController;

  // ── Keys for the onboarding tour (owned by parent State) ─────────────────
  final GlobalKey searchFilterKey;

  // ── Visual config ─────────────────────────────────────────────────────────
  final Color primaryColor;

  // ── Selection context displayed inside cards ──────────────────────────────
  final bool canEdit;
  final String? selectedSubjectName;
  final String? selectedClassName;

  // ── Callbacks (replaces direct setState / method calls on parent) ─────────
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilterPressed;

  /// Called when the user removes the active date filter chip.
  final VoidCallback onRemoveDateFilter;

  final void Function(dynamic activity) onActivityTap;
  final void Function(dynamic activity) onActivityEdit;
  final void Function(dynamic activity) onActivityDelete;

  const ActivityListView({
    super.key,
    required this.isLoading,
    required this.isLoadingMore,
    required this.activityList,
    required this.hasActiveFilter,
    this.selectedDateFilter,
    required this.searchController,
    required this.scrollController,
    required this.searchFilterKey,
    required this.primaryColor,
    required this.canEdit,
    this.selectedSubjectName,
    this.selectedClassName,
    required this.onSearchSubmitted,
    required this.onFilterPressed,
    required this.onRemoveDateFilter,
    required this.onActivityTap,
    required this.onActivityEdit,
    required this.onActivityDelete,
  });

  // ── Filter chip data builder ──────────────────────────────────────────────

  /// Returns a list of active filter descriptors so the chip row can be
  /// rendered generically. Like a Vue computed property — derives UI data
  /// from props without mutating state.
  List<Map<String, dynamic>> _filterChips(
    String dateLabel,
    String datePrefix,
  ) {
    if (selectedDateFilter == null) return [];
    return [
      {
        'label': '$datePrefix: $dateLabel',
        'onRemove': onRemoveDateFilter,
      },
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    if (isLoading && activityList.isEmpty) {
      return SkeletonListLoading(itemCount: 5, infoTagCount: 2);
    }

    // ── Translate filter chip label ───────────────────────────────────────
    final dateLabel = selectedDateFilter == 'today'
        ? languageProvider.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'})
        : selectedDateFilter == 'week'
        ? languageProvider.getTranslatedText({
            'en': 'This Week',
            'id': 'Minggu Ini',
          })
        : languageProvider.getTranslatedText({
            'en': 'This Month',
            'id': 'Bulan Ini',
          });

    final datePrefix = languageProvider.getTranslatedText({
      'en': 'Date',
      'id': 'Tanggal',
    });

    final chips = _filterChips(dateLabel, datePrefix);

    return Column(
      children: [
        // ── Search & Filter bar ───────────────────────────────────────────
        ActivitySearchFilterBar(
          searchController: searchController,
          searchFilterKey: searchFilterKey,
          primaryColor: primaryColor,
          hasActiveFilter: hasActiveFilter,
          languageProvider: languageProvider,
          onSearchSubmitted: onSearchSubmitted,
          onFilterPressed: onFilterPressed,
        ),

        // ── Active filter chips ───────────────────────────────────────────
        if (hasActiveFilter) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: chips.map((filter) {
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(
                      filter['label'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onDeleted: filter['onRemove'] as VoidCallback,
                    backgroundColor: primaryColor.withValues(alpha: 0.7),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    labelPadding: const EdgeInsets.only(left: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Activity list / empty state ───────────────────────────────────
        Expanded(
          child: activityList.isEmpty
              ? EmptyState(
                  title: languageProvider.getTranslatedText({
                    'en': 'No Activities',
                    'id': 'Belum ada kegiatan',
                  }),
                  subtitle: searchController.text.isEmpty && !hasActiveFilter
                      ? languageProvider.getTranslatedText({
                          'en': 'No activities found for this subject.',
                          'id':
                              'Tidak ada kegiatan untuk mata pelajaran ini.',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'No search results found',
                          'id': 'Tidak ditemukan hasil pencarian',
                        }),
                  icon: Icons.event_note,
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  itemCount:
                      activityList.length + (isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Loading indicator at the bottom during pagination
                    if (index == activityList.length) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: CircularProgressIndicator(
                            color: primaryColor,
                          ),
                        ),
                      );
                    }
                    final activity = activityList[index];
                    return ActivityCard(
                      activity: activity,
                      primaryColor: primaryColor,
                      languageProvider: languageProvider,
                      canEdit: canEdit,
                      onTap: () => onActivityTap(activity),
                      onEdit: () => onActivityEdit(activity),
                      onDelete: () => onActivityDelete(activity),
                      selectedSubjectName: selectedSubjectName,
                      selectedClassName: selectedClassName,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
