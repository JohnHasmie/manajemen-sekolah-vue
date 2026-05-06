// Gradient header for the admin attendance report screen — now backed
// by the shared `BrandPageHeader` so admin pages follow one canonical
// hero pattern app-wide.
//
// What it surfaces:
//   • Centered title + kicker (subtitle)
//   • Back button (drill-down: when a class is selected, back returns
//     to the class list before popping the screen)
//   • Action icons: View toggle (when class selected), Filter (with
//     badge), More (refresh + export)
//   • Compact white search field in `bottomSlot`
//
// The legacy `ActiveFilterChips` row that lived BELOW the search bar
// has been retired — the badge dot on the filter icon already shows
// active state, matching the parent role pattern.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';

class AdminReportHeader extends StatelessWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final bool hasClassSelected;
  final bool showTableView;
  final bool hasActiveFilter;
  final GlobalKey infoKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final GlobalKey moreKey;
  final TextEditingController searchController;
  // Kept for API compatibility — admin attendance report tracks its
  // own active filter list internally; we no longer paint the chip
  // row here, but downstream callers may still rely on the prop.
  final List<ActiveFilter> filterChips;
  final VoidCallback onBack;
  final VoidCallback onBackToClassList;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onShowFilter;
  final VoidCallback onClearAllFilters; // unused now — clear via sheet
  final VoidCallback onSearch;

  const AdminReportHeader({
    super.key,
    required this.primaryColor,
    // ignore: unused_element_parameter
    LinearGradient? gradient,
    required this.languageProvider,
    required this.hasClassSelected,
    required this.showTableView,
    required this.hasActiveFilter,
    required this.infoKey,
    required this.searchKey,
    required this.filterKey,
    required this.moreKey,
    required this.searchController,
    required this.filterChips,
    required this.onBack,
    required this.onBackToClassList,
    required this.onToggleView,
    required this.onRefresh,
    required this.onExport,
    required this.onShowFilter,
    required this.onClearAllFilters,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return BrandPageHeader(
      key: infoKey,
      role: 'admin',
      subtitle: 'Akademik · Kehadiran',
      title: languageProvider.getTranslatedText({
        'en': 'Attendance Report',
        'id': 'Laporan Absensi',
      }),
      onBackPressed: hasClassSelected ? onBackToClassList : onBack,
      showBackButton: true,
      actionIcons: [
        if (hasClassSelected)
          BrandHeaderIconButton(
            icon: showTableView
                ? Icons.view_list_rounded
                : Icons.table_chart_rounded,
            onTap: onToggleView,
          ),
        BrandHeaderIconButton(
          key: filterKey,
          icon: Icons.tune_rounded,
          onTap: onShowFilter,
          badgeCount: hasActiveFilter ? 1 : null,
          badgeBorderColor: primaryColor,
        ),
        BrandHeaderIconButton(
          key: moreKey,
          icon: Icons.more_vert_rounded,
          onTap: () => _showMoreMenu(context),
        ),
      ],
      bottomSlot: Container(
        key: searchKey,
        height: 36,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: ColorUtils.slate400),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: searchController,
                style: TextStyle(
                  color: ColorUtils.slate800,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Search attendance...',
                    'id': 'Cari absensi...',
                  }),
                  hintStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 12.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Offset position = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + (box?.size.width ?? 0) - 200,
        position.dy + 56,
        position.dx + (box?.size.width ?? 0) - 12,
        position.dy + 600,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded,
                  size: 18, color: ColorUtils.slate700),
              const SizedBox(width: 12),
              Text(AppLocalizations.updateData.tr),
            ],
          ),
        ),
        if (hasClassSelected)
          PopupMenuItem<String>(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.file_download_outlined,
                    size: 18, color: ColorUtils.slate700),
                const SizedBox(width: 12),
                Text(languageProvider.getTranslatedText({
                  'en': 'Export Excel',
                  'id': 'Export Excel',
                })),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == 'refresh') onRefresh();
      if (value == 'export') onExport();
    });
  }
}
