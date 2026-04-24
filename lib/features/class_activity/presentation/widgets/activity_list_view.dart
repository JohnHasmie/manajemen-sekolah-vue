// Activity list body for Step 2 of the class-activity wizard.
// Shows search/filter bar, active-filter chips, and the scrollable activity cards.
// Replaces _buildActivityList() from teacher_class_activity_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_card.dart';

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

  /// Wali-kelas mode — makes each card surface the activity's author name.
  final bool isHomeroomView;

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
    this.isHomeroomView = false,
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
  List<Map<String, dynamic>> _filterChips(String dateLabel, String datePrefix) {
    if (selectedDateFilter == null) return [];
    return [
      {'label': '$datePrefix: $dateLabel', 'onRemove': onRemoveDateFilter},
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    if (isLoading && activityList.isEmpty) {
      return const SkeletonListLoading(itemCount: 5, infoTagCount: 2);
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
      'en': 'Time Range',
      'id': 'Rentang Waktu',
    });

    final chips = _filterChips(dateLabel, datePrefix);

    return Column(
      children: [
        // ── Search & Filter bar ───────────────────────────────────────────
        // Inlined from the legacy `ActivitySearchFilterBar` widget: a 48-px
        // white search field plus a 48×48 filter button with an active-state
        // badge dot. Matches the "Jadwal Mengajar" bar style.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            key: searchFilterKey,
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            color: ColorUtils.slate800,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Search activities...',
                              'id': 'Cari kegiatan...',
                            }),
                            hintStyle: TextStyle(
                              color: ColorUtils.slate400,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          onSubmitted: (_) {
                            onSearchSubmitted();
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(
                            Icons.search,
                            color: primaryColor,
                            size: 20,
                          ),
                          onPressed: () {
                            onSearchSubmitted();
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: hasActiveFilter
                      ? primaryColor.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasActiveFilter ? primaryColor : ColorUtils.slate200,
                    width: hasActiveFilter ? 1.5 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      onPressed: onFilterPressed,
                      icon: Icon(
                        Icons.tune,
                        color: hasActiveFilter
                            ? primaryColor
                            : ColorUtils.slate600,
                        size: 20,
                      ),
                      tooltip: languageProvider.getTranslatedText({
                        'en': 'Filter',
                        'id': 'Filter',
                      }),
                    ),
                    if (hasActiveFilter)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ColorUtils.error600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
                return GestureDetector(
                  onTap: filter['onRemove'] as VoidCallback,
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.close, size: 14, color: primaryColor),
                      ],
                    ),
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
                          'id': 'Tidak ada kegiatan untuk mata pelajaran ini.',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'No search results found',
                          'id': 'Tidak ditemukan hasil pencarian',
                        }),
                  icon: Icons.event_note,
                )
              : _buildDateGroupedList(languageProvider),
        ),
      ],
    );
  }

  /// Groups activities by date and renders with date headers.
  Widget _buildDateGroupedList(LanguageProvider languageProvider) {
    // Build flat list of items: date headers + activity cards
    final items = <_ListItem>[];
    String? lastDate;

    for (final activity in activityList) {
      final rawDate = (activity['date'] ?? '').toString();
      final dateKey = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

      if (dateKey != lastDate && dateKey.isNotEmpty) {
        items.add(_ListItem(isHeader: true, dateKey: dateKey));
        lastDate = dateKey;
      }
      items.add(_ListItem(isHeader: false, activity: activity));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        final item = items[index];
        if (item.isHeader) {
          return _DateGroupHeader(
            dateKey: item.dateKey!,
            primaryColor: primaryColor,
          );
        }

        final activity = item.activity!;
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
          isHomeroomView: isHomeroomView,
        );
      },
    );
  }
}

/// Item type for the flat date-grouped list.
class _ListItem {
  final bool isHeader;
  final String? dateKey;
  final dynamic activity;

  _ListItem({required this.isHeader, this.dateKey, this.activity});
}

/// Date group header shown between activity cards.
class _DateGroupHeader extends StatelessWidget {
  final String dateKey;
  final Color primaryColor;

  const _DateGroupHeader({required this.dateKey, required this.primaryColor});

  String _formatDateHeader(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    const dayNames = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    if (dateOnly == today) return 'Hari Ini';
    if (dateOnly == yesterday) return 'Kemarin';

    final dayName = dayNames[dt.weekday - 1];
    final monthName = monthNames[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDateHeader(dateKey),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate700,
            ),
          ),
        ],
      ),
    );
  }
}
