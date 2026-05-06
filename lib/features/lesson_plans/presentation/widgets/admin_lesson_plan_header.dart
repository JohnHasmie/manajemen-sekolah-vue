// Gradient header for the admin lesson plan screen — now powered by
// the shared `BrandPageHeader` so admin pages share one canonical
// gradient/title/chip pattern across the app.
//
// What it surfaces:
//   • Centered title + kicker (subtitle)
//   • Back button (auto, plus optional `onBack` override)
//   • Two action icons — Filter (with badge when active) + Refresh menu
//   • Compact search bar in `bottomSlot`
//
// The active-filter "summary pill" the legacy header carried below
// the search bar has been retired — the badge dot on the filter icon
// already telegraphs that state, matching the parent role pattern.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';

class AdminLessonPlanHeader extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String? subtitle;
  final bool showTeacherList;
  final bool hasActiveFilter;
  final String filterSummary; // unused now — kept for API stability
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final TextEditingController searchController;
  final String searchHint;
  final String exportLabel;
  final String updateDataLabel;
  final String filterTooltip; // unused now — kept for API stability
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final VoidCallback onShowFilter;
  final VoidCallback onClearFilter; // unused now — clearing happens in sheet

  const AdminLessonPlanHeader({
    required this.primaryColor,
    // ignore: unused_element_parameter
    LinearGradient? gradient,
    required this.title,
    required this.subtitle,
    required this.showTeacherList,
    required this.hasActiveFilter,
    required this.filterSummary,
    required this.menuKey,
    required this.searchKey,
    required this.filterKey,
    required this.searchController,
    required this.searchHint,
    required this.exportLabel,
    required this.updateDataLabel,
    required this.filterTooltip,
    required this.onBack,
    required this.onSearch,
    required this.onExport,
    required this.onRefresh,
    required this.onShowFilter,
    required this.onClearFilter,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BrandPageHeader(
      role: 'admin',
      title: title,
      subtitle: subtitle,
      onBackPressed: onBack,
      showBackButton: true,
      actionIcons: [
        // Filter — only meaningful in the teacher-list state (the
        // legacy header hid this button for nested drill-downs).
        if (showTeacherList)
          BrandHeaderIconButton(
            key: filterKey,
            icon: Icons.tune_rounded,
            onTap: onShowFilter,
            badgeCount: hasActiveFilter ? 1 : null,
            badgeBorderColor: primaryColor,
          ),
        BrandHeaderIconButton(
          key: menuKey,
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
                  hintText: searchHint,
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
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.file_download_outlined,
                  size: 18, color: ColorUtils.slate700),
              const SizedBox(width: 12),
              Text(exportLabel),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh_rounded,
                  size: 18, color: ColorUtils.slate700),
              const SizedBox(width: 12),
              Text(updateDataLabel),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'export') onExport();
      if (value == 'refresh') onRefresh();
    });
  }
}
