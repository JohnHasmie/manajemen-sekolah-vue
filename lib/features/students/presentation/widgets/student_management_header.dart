// StudentManagementHeader widget -- the gradient header for the admin student
// management screen.
//
// Like a Vue `<StudentManagementHeader>` component. Extracted from
// AdminStudentManagementScreen._buildGradientHeader so the header tree
// (search bar, filter chips, action menu) lives in its own file.
//
// Props (like Vue props):
// - [primaryColor]      -- role-based accent color
// - [languageProvider]  -- for translated strings
// - [searchController]  -- the shared TextEditingController for the search field
// - [hasActiveFilter]   -- drives filter-icon highlight and chip row visibility
// - [filterChips]       -- pre-built list of {label, onRemove} maps (computed
//                          by the screen so setState stays in the screen)
// - [menuKey] / [searchKey] / [filterKey] -- GlobalKeys used by the onboarding tour
// - [onSearch]          -- called when the user submits the search field
// - [onMenuSelected]    -- called with the popup menu value ('refresh'|'export'|...)
// - [onFilterTap]       -- opens the filter bottom sheet
// - [onClearFilters]    -- removes all active filters

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';

/// Gradient header for the admin student management screen.
///
/// Stateless -- all mutable data and actions are injected as constructor
/// params, keeping `setState` logic in the parent screen (same pattern as a
/// Vue component that emits events instead of mutating parent state directly).
class StudentManagementHeader extends StatelessWidget {
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final TextEditingController searchController;
  final bool hasActiveFilter;

  /// Pre-built filter chips: each map has 'label' (String) and 'onRemove'
  /// (VoidCallback). Built by the screen so the `setState` calls stay there.
  final List<Map<String, dynamic>> filterChips;

  // GlobalKeys forwarded from the screen (used by the tutorial coach mark tour)
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;

  /// Triggered when the user submits the search field or taps the search icon.
  final VoidCallback onSearch;

  /// Triggered when the user selects a popup menu item.
  /// [value] is one of: 'refresh' | 'export' | 'import' | 'template'
  final void Function(String value) onMenuSelected;

  /// Opens the filter bottom sheet.
  final VoidCallback onFilterTap;

  /// Clears all active filters.
  final VoidCallback onClearFilters;

  const StudentManagementHeader({
    super.key,
    required this.primaryColor,
    required this.languageProvider,
    required this.searchController,
    required this.hasActiveFilter,
    required this.filterChips,
    required this.menuKey,
    required this.searchKey,
    required this.filterKey,
    required this.onSearch,
    required this.onMenuSelected,
    required this.onFilterTap,
    required this.onClearFilters,
  });

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Popup menu with refresh / export / import / template actions.
  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      key: menuKey,
      onSelected: onMenuSelected,
      icon: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      itemBuilder: (BuildContext ctx) => [
        PopupMenuItem<String>(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Refresh Data',
                  'id': 'Perbarui Data',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Export to Excel',
                  'id': 'Export ke Excel',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'import',
          child: Row(
            children: [
              Icon(Icons.upload, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Import from Excel',
                  'id': 'Import dari Excel',
                }),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'template',
          child: Row(
            children: [
              Icon(Icons.file_download, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                languageProvider.getTranslatedText({
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

  /// Search field + filter icon button row.
  Widget _buildSearchBar(BuildContext context) {
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
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search students...',
                        'id': 'Cari siswa...',
                      }),
                      hintStyle: TextStyle(color: ColorUtils.slate400),
                      prefixIcon: Icon(
                        Icons.search,
                        color: ColorUtils.slate400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
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
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
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
                onPressed: onFilterTap,
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
                    constraints: BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Horizontal scrollable row of active filter chips + a clear-all button.
  Widget _buildFilterChipsRow() {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(Icons.filter_alt, size: 18, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: filterChips.map((filter) {
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  child: Chip(
                    label: Text(
                      filter['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: ColorUtils.error600,
                    ),
                    onDeleted: filter['onRemove'] as VoidCallback,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    labelPadding: const EdgeInsets.only(left: 4),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: onClearFilters,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: ColorUtils.error600,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Icon(Icons.clear_all, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GradientPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Student Management',
        'id': 'Manajemen Siswa',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Manage and monitor students',
        'id': 'Kelola dan pantau siswa',
      }),
      primaryColor: primaryColor,
      actionMenu: _buildActionMenu(context),
      searchBar: _buildSearchBar(context),
      filterChips: hasActiveFilter ? _buildFilterChipsRow() : null,
    );
  }
}
