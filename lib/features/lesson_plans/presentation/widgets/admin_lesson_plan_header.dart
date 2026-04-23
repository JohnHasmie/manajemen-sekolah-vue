import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Gradient header for the admin lesson plan screen.
///
/// Extracted from [_AdminLessonPlanScreenState.build] to keep the build method
/// readable. Like a Blade partial: `@include('lesson_plans._header')`.
class AdminLessonPlanHeader extends StatelessWidget {
  final Color primaryColor;
  final LinearGradient gradient;
  final String title;
  final String? subtitle;
  final bool showTeacherList;
  final bool hasActiveFilter;
  final String filterSummary;
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final TextEditingController searchController;
  final String searchHint;
  final String exportLabel;
  final String updateDataLabel;
  final String filterTooltip;
  final VoidCallback onBack;
  final VoidCallback onSearch;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final VoidCallback onShowFilter;
  final VoidCallback onClearFilter;

  const AdminLessonPlanHeader({
    required this.primaryColor,
    required this.gradient,
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back, title/subtitle, popup menu
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: menuKey,
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      onExport();
                      break;
                    case 'refresh':
                      onRefresh();
                      break;
                  }
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                itemBuilder: (BuildContext context) => [
                  if (!showTeacherList)
                    PopupMenuItem<String>(
                      value: 'export',
                      child: Row(
                        children: [
                          const Icon(Icons.download, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(exportLabel),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: ColorUtils.info600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(updateDataLabel),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Search bar + optional filter button
          Row(
            children: [
              Expanded(
                key: searchKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onSubmitted: (_) => onSearch(),
                          style: TextStyle(color: ColorUtils.slate800),
                          decoration: InputDecoration(
                            hintText: searchHint,
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            prefixIcon: Icon(
                              Icons.search,
                              color: ColorUtils.slate400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: primaryColor),
                          onPressed: onSearch,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!showTeacherList) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  key: filterKey,
                  decoration: BoxDecoration(
                    color: hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        onPressed: onShowFilter,
                        icon: Icon(
                          Icons.tune,
                          color: hasActiveFilter ? primaryColor : Colors.white,
                        ),
                        tooltip: filterTooltip,
                      ),
                      if (hasActiveFilter)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: ColorUtils.error600,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          // Filter chips (RPP only)
          if (!showTeacherList && hasActiveFilter) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(16),
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                filterSummary,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              GestureDetector(
                                onTap: onClearFilter,
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
