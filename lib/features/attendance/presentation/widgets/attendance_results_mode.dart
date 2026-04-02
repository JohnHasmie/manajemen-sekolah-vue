// Extracted from teacher_attendance_screen.dart (_buildResultsMode).
// Like a Vue `<AttendanceResultsMode>` component -- renders the "View Results"
// tab content: class-list fallback, skeleton loader, search/filter bar, active
// filter chips, and the summary-card list. All state mutations fire callbacks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_summary_card.dart';

/// The "View Results" tab body for the teacher attendance screen.
///
/// Parameters (like Vue props / emits):
/// - [selectedClassId]      -- currently selected class; null shows class list
/// - [isLoadingSummary]     -- when true, shows skeleton loader
/// - [filteredSummaries]    -- already-filtered list of summary items to display
/// - [searchController]     -- TextEditingController owned by parent for search
/// - [hasActiveFilter]      -- whether any filter chip is active
/// - [filterChips]          -- list of chip models [{label, onRemove}] from parent
/// - [primaryColor]         -- role-based accent colour
/// - [classListWidget]      -- pre-built class-list widget (AttendanceTeacherClassList)
/// - [searchFilterBarWidget]-- pre-built search/filter bar widget
/// - [onClearAllFilters]    -- callback to clear all active filters
/// - [onNavigateToDetail]   -- called when user taps a summary card
/// - [onDelete]             -- called when user taps delete on a summary card
class AttendanceResultsMode extends ConsumerWidget {
  final String? selectedClassId;
  final bool isLoadingSummary;
  final List<AttendanceSummaryItem> filteredSummaries;
  final TextEditingController searchController;
  final bool hasActiveFilter;
  final List<Map<String, dynamic>> filterChips;
  final Color primaryColor;
  final Widget classListWidget;
  final Widget searchFilterBarWidget;
  final VoidCallback onClearAllFilters;
  final void Function(AttendanceSummaryItem) onNavigateToDetail;
  final void Function(AttendanceSummaryItem) onDelete;
  final ScrollController? scrollController;

  const AttendanceResultsMode({
    super.key,
    required this.selectedClassId,
    required this.isLoadingSummary,
    required this.filteredSummaries,
    required this.searchController,
    required this.hasActiveFilter,
    required this.filterChips,
    required this.primaryColor,
    required this.classListWidget,
    required this.searchFilterBarWidget,
    required this.onClearAllFilters,
    required this.onNavigateToDetail,
    required this.onDelete,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    // No class selected -- show the class picker list instead
    if (selectedClassId == null) {
      return classListWidget;
    }

    if (isLoadingSummary) {
      return SkeletonListLoading(itemCount: 5, infoTagCount: 2);
    }

    return Column(
      children: [
        // Search dan Filter Bar
        searchFilterBarWidget,

        // Active filter chips row
        if (hasActiveFilter) ...[
          AppSpacing.v4,
          SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ...filterChips.map((filter) {
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: filter['onRemove'] as VoidCallback?,
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.all(Radius.circular(10)),
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
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  AppSpacing.h4,
                                  Icon(
                                    Icons.close,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: InkWell(
                    onTap: onClearAllFilters,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color: ColorUtils.error600.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Clear',
                          'id': 'Hapus',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.error600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.v4,
        ],

        AppSpacing.v8,

        Expanded(
          child: filteredSummaries.isEmpty
              ? EmptyState(
                  title: languageProvider.getTranslatedText({
                    'en': 'No attendance records',
                    'id': 'Belum ada data absensi',
                  }),
                  subtitle: searchController.text.isEmpty && !hasActiveFilter
                      ? languageProvider.getTranslatedText({
                          'en': 'No attendance data available',
                          'id': 'Tidak ada data absensi tersedia',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'No search results found',
                          'id': 'Tidak ditemukan hasil pencarian',
                        }),
                  icon: Icons.list_alt,
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredSummaries.length,
                  itemBuilder: (context, index) {
                    final summary = filteredSummaries[index];
                    return AttendanceSummaryCard(
                      summary: summary,
                      primaryColor: primaryColor,
                      languageProvider: languageProvider,
                      onTap: () => onNavigateToDetail(summary),
                      onDelete: () => onDelete(summary),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
