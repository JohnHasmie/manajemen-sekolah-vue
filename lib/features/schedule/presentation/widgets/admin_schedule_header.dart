import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';

/// Header for admin schedule management screen.
///
/// Extracted to keep the main screen clean. Builds search bar, filter button,
/// view toggle, and action menu.
class AdminScheduleHeader extends ConsumerWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;
  final TextEditingController searchController;
  final bool showTableView;
  final bool hasActiveFilter;
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final GlobalKey viewToggleKey;
  final List<ActiveFilter> filterChips;
  final String? clearAllLabel;

  final VoidCallback onBack;
  final VoidCallback onViewToggle;
  final VoidCallback onShowFilter;
  final VoidCallback onClearAllFilters;
  final VoidCallback onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onDownloadTemplate;
  final bool canImport;

  const AdminScheduleHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.searchController,
    required this.showTableView,
    required this.hasActiveFilter,
    required this.menuKey,
    required this.searchKey,
    required this.filterKey,
    required this.viewToggleKey,
    required this.filterChips,
    required this.clearAllLabel,
    required this.onBack,
    required this.onViewToggle,
    required this.onShowFilter,
    required this.onClearAllFilters,
    required this.onSearch,
    required this.onRefresh,
    required this.onExport,
    required this.onImport,
    required this.onDownloadTemplate,
    required this.canImport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = ref.watch(languageRiverpod);
    return GradientPageHeader(
      title: title,
      subtitle: subtitle,
      primaryColor: primaryColor,
      onBackPressed: onBack,
      actionMenu: _buildActionMenu(lp),
      searchBar: _buildSearchBar(lp),
      filterChips: hasActiveFilter ? _buildFilterChipsRow(lp) : null,
    );
  }

  Widget _buildActionMenu(LanguageProvider lp) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildViewToggleButton(),
        const SizedBox(width: AppSpacing.sm),
        _buildOverflowMenu(lp),
      ],
    );
  }

  Widget _buildViewToggleButton() {
    return GestureDetector(
      onTap: onViewToggle,
      child: Container(
        key: viewToggleKey,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(
          showTableView ? Icons.view_list : Icons.table_chart,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(LanguageProvider lp) {
    return PopupMenuButton<String>(
      key: menuKey,
      onSelected: (value) {
        switch (value) {
          case 'refresh':
            onRefresh();
          case 'export':
            onExport();
          case 'import':
            onImport();
          case 'template':
            onDownloadTemplate();
        }
      },
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
              const SizedBox(width: AppSpacing.sm),
              Text(
                lp.getTranslatedText({
                  'en': 'Refresh Data',
                  'id': 'Perbarui Data',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              const Icon(Icons.download, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                lp.getTranslatedText({
                  'en': 'Export to Excel',
                  'id': 'Export ke Excel',
                }),
              ),
            ],
          ),
        ),
        if (canImport)
          PopupMenuItem(
            value: 'import',
            child: Row(
              children: [
                const Icon(Icons.upload, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  lp.getTranslatedText({
                    'en': 'Import from Excel',
                    'id': 'Import dari Excel',
                  }),
                ),
              ],
            ),
          ),
        PopupMenuItem(
          value: 'template',
          child: Row(
            children: [
              const Icon(Icons.file_download, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                lp.getTranslatedText({
                  'en': 'Download Template',
                  'id': 'Download Template',
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(LanguageProvider lp) {
    return Row(
      children: [
        Expanded(child: _buildSearchField(lp)),
        const SizedBox(width: AppSpacing.sm),
        _buildFilterButton(lp),
      ],
    );
  }

  Widget _buildSearchField(LanguageProvider lp) {
    return Container(
      key: searchKey,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: lp.getTranslatedText({
                  'en': 'Search schedules...',
                  'id': 'Cari jadwal...',
                }),
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => onSearch(),
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
    );
  }

  Widget _buildFilterButton(LanguageProvider lp) {
    return Container(
      key: filterKey,
      decoration: BoxDecoration(
        color: hasActiveFilter
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          IconButton(
            onPressed: onShowFilter,
            icon: Icon(
              Icons.tune,
              color: hasActiveFilter ? primaryColor : Colors.white,
            ),
            tooltip: lp.getTranslatedText({'en': 'Filter', 'id': 'Filter'}),
          ),
          if (hasActiveFilter)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChipsRow(LanguageProvider lp) {
    return ActiveFilterChips(
      filters: filterChips,
      primaryColor: primaryColor,
      onClearAll: onClearAllFilters,
      clearAllLabel: lp.getTranslatedText({
        'en': 'Clear All',
        'id': 'Hapus Semua',
      }),
      transparentStyle: true,
      padding: EdgeInsets.zero,
    );
  }
}
