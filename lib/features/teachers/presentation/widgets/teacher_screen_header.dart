import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

class TeacherScreenHeader extends ConsumerWidget {
  final GlobalKey menuKey;
  final GlobalKey searchKey;
  final GlobalKey filterKey;
  final TextEditingController searchController;
  final bool hasActiveFilter;
  final Color primaryColor;
  final VoidCallback onMenuRefresh;
  final VoidCallback onMenuExport;
  final VoidCallback onMenuImport;
  final VoidCallback onMenuTemplate;
  final VoidCallback onFilterTap;
  final VoidCallback onSearchSubmit;
  final VoidCallback onClearAllFilters;
  final List<Widget> filterChips;

  const TeacherScreenHeader({
    super.key,
    required this.menuKey,
    required this.searchKey,
    required this.filterKey,
    required this.searchController,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.onMenuRefresh,
    required this.onMenuExport,
    required this.onMenuImport,
    required this.onMenuTemplate,
    required this.onFilterTap,
    required this.onSearchSubmit,
    required this.onClearAllFilters,
    required this.filterChips,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.watch(languageRiverpod);

    return GradientPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Teacher Management',
        'id': 'Manajemen Guru',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Manage and monitor teachers',
        'id': 'Kelola dan pantau guru',
      }),
      primaryColor: primaryColor,
      actionMenu: PopupMenuButton<String>(
        key: menuKey,
        onSelected: (value) {
          switch (value) {
            case 'refresh':
              onMenuRefresh();
              break;
            case 'export':
              onMenuExport();
              break;
            case 'import':
              onMenuImport();
              break;
            case 'template':
              onMenuTemplate();
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
          child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
        ),
        itemBuilder: (BuildContext context) => [
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
                const Icon(Icons.download, size: 20),
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
                const Icon(Icons.upload, size: 20),
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
                const Icon(Icons.file_download, size: 20),
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
      ),
      searchBar: _buildSearchBar(context, languageProvider),
      filterChips: hasActiveFilter ? _buildFilterChipsSection() : null,
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
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
                        'en': 'Search teachers...',
                        'id': 'Cari guru...',
                      }),
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      onSearchSubmit();
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.search, color: primaryColor),
                    onPressed: onSearchSubmit,
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
                    decoration: const BoxDecoration(
                      color: Colors.red,
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
    );
  }

  Widget _buildFilterChipsSection() {
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
            child: const Icon(Icons.filter_alt, size: 18, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: filterChips,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          InkWell(
            onTap: onClearAllFilters,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              child: const Icon(Icons.clear_all, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
