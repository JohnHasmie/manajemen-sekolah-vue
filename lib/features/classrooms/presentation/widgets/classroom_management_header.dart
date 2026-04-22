import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';

/// Header widget for classroom management screen.
///
/// Displays title, search bar, filter options, and action menu.
class ClassroomManagementHeader extends StatelessWidget {
  final LanguageProvider languageProvider;
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final bool hasActiveFilter;
  final List<String> availableGradeLevels;
  final TextEditingController searchController;
  final String? selectedGradeFilter;
  final String? selectedHomeroomFilter;
  final List<PopupMenuEntry<String>> Function(LanguageProvider) buildMenuItems;
  final Widget Function(LanguageProvider, VoidCallback) buildFilterButton;
  final Widget Function(
    LanguageProvider,
    List<Map<String, dynamic>>,
    VoidCallback,
  )
  buildFilterChipsBar;
  final Function(String) onMenuSelected;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onFilterPressed;
  final VoidCallback onClearAllFilters;
  final VoidCallback onBackPressed;
  final Color primaryColor;
  final List<Map<String, dynamic>> Function(LanguageProvider)
  onFilterChipsBuilt;

  const ClassroomManagementHeader({
    required this.languageProvider,
    required this.menuKey,
    required this.searchKey,
    required this.filterKey,
    required this.hasActiveFilter,
    required this.availableGradeLevels,
    required this.searchController,
    required this.selectedGradeFilter,
    required this.selectedHomeroomFilter,
    required this.buildMenuItems,
    required this.buildFilterButton,
    required this.buildFilterChipsBar,
    required this.onMenuSelected,
    required this.onSearchSubmitted,
    required this.onFilterPressed,
    required this.onClearAllFilters,
    required this.onBackPressed,
    required this.primaryColor,
    required this.onFilterChipsBuilt,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GradientPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Class Management',
        'id': 'Manajemen Kelas',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Manage and monitor classes',
        'id': 'Kelola dan pantau kelas',
      }),
      primaryColor: primaryColor,
      onBackPressed: onBackPressed,
      actionMenu: PopupMenuButton<String>(
        key: menuKey,
        onSelected: onMenuSelected,
        icon: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        ),
        itemBuilder: (BuildContext context) => buildMenuItems(languageProvider),
      ),
      searchBar: _buildSearchBar(),
      filterChips: hasActiveFilter
          ? buildFilterChipsBar(
              languageProvider,
              onFilterChipsBuilt(languageProvider),
              onClearAllFilters,
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
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
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search classes...',
                        'id': 'Cari kelas...',
                      }),
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => onSearchSubmitted(),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    key: filterKey,
                    icon: Icon(Icons.search, color: primaryColor),
                    onPressed: onSearchSubmitted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        buildFilterButton(languageProvider, onFilterPressed),
      ],
    );
  }
}
