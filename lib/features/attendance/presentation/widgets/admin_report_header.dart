import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Gradient header for the admin attendance report screen.
///
/// Contains back button, title/subtitle, view toggle, overflow
/// menu, search bar, filter button, and active filter chips.
class AdminReportHeader extends StatelessWidget {
  final Color primaryColor;
  final LinearGradient gradient;
  final LanguageProvider languageProvider;
  final bool hasClassSelected;
  final bool showTableView;
  final bool hasActiveFilter;
  final GlobalKey infoKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final GlobalKey moreKey;
  final TextEditingController searchController;
  final List<ActiveFilter> filterChips;
  final VoidCallback onBack;
  final VoidCallback onBackToClassList;
  final VoidCallback onToggleView;
  final VoidCallback onRefresh;
  final VoidCallback onExport;
  final VoidCallback onShowFilter;
  final VoidCallback onClearAllFilters;
  final VoidCallback onSearch;

  const AdminReportHeader({
    super.key,
    required this.primaryColor,
    required this.gradient,
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
          _topRow(context),
          const SizedBox(height: AppSpacing.lg),
          _searchRow(),
          if (hasActiveFilter) ...[
            const SizedBox(height: AppSpacing.md),
            _filterChipsRow(),
          ],
        ],
      ),
    );
  }

  Widget _topRow(BuildContext context) {
    return Row(
      children: [
        _backButton(context),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _titleColumn()),
        if (hasClassSelected) ...[
          _viewToggleButton(),
          const SizedBox(width: AppSpacing.sm),
        ],
        _overflowMenu(context),
      ],
    );
  }

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (hasClassSelected) {
          onBackToClassList();
        } else {
          onBack();
        }
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _titleColumn() {
    return Column(
      key: infoKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Attendance Report',
            'id': 'Laporan Absensi',
          }),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          languageProvider.getTranslatedText({
            'en': 'View attendance reports',
            'id': 'Lihat laporan absensi',
          }),
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _viewToggleButton() {
    return GestureDetector(
      onTap: onToggleView,
      child: Container(
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

  Widget _overflowMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'refresh':
            onRefresh();
            break;
          case 'export':
            if (hasClassSelected) {
              onExport();
            } else {
              // Show info snackbar handled by parent
              onExport();
            }
            break;
        }
      },
      icon: Container(
        width: 40,
        height: 40,
        key: moreKey,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
              const SizedBox(width: AppSpacing.sm),
              Text(AppLocalizations.updateData.tr),
            ],
          ),
        ),
        if (hasClassSelected)
          PopupMenuItem<String>(
            value: 'export',
            child: Row(
              children: [
                const Icon(Icons.file_download, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Export Excel',
                    'id': 'Export Excel',
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _searchRow() {
    return Row(
      children: [
        Expanded(
          child: Container(
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
                    onSubmitted: (_) => onSearch(),
                    style: TextStyle(color: ColorUtils.slate800),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search attendance...',
                        'id': 'Cari absensi...',
                      }),
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
        const SizedBox(width: AppSpacing.sm),
        _filterButton(),
      ],
    );
  }

  Widget _filterButton() {
    return Container(
      decoration: BoxDecoration(
        color: hasActiveFilter
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      key: filterKey,
      child: Stack(
        children: [
          IconButton(
            onPressed: onShowFilter,
            icon: Icon(
              Icons.tune,
              color: hasActiveFilter ? primaryColor : Colors.white,
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
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: ColorUtils.error600,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChipsRow() {
    return ActiveFilterChips(
      filters: filterChips,
      primaryColor: primaryColor,
      onClearAll: onClearAllFilters,
      clearAllLabel: languageProvider.getTranslatedText({
        'en': 'Clear All',
        'id': 'Hapus Semua',
      }),
      transparentStyle: true,
      padding: EdgeInsets.zero,
    );
  }
}
