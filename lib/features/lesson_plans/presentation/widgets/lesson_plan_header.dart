// Header widget for the lesson plan screen.
// Uses TeacherPageHeader for consistent styling with other teacher pages
// (schedule, activity class, etc).
// Refresh is handled by pull-to-refresh on the list body, not a menu action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Header widget for the lesson plan screen with search, filter, and view toggle.
class LessonPlanHeader extends ConsumerWidget {
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onFilter;
  final bool hasActiveFilter;
  final Color primaryColor;
  final GlobalKey filterKey;
  final String filterSummary;
  final VoidCallback onClearFilters;
  final Widget? trailing;

  const LessonPlanHeader({
    super.key,
    required this.searchController,
    required this.onSearch,
    required this.onFilter,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.filterKey,
    required this.filterSummary,
    required this.onClearFilters,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.read(languageRiverpod);

    return TeacherPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Lesson Plans',
        'id': 'Daftar RPP',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'View and manage your lesson plans',
        'id': 'Lihat dan kelola dokumen RPP Anda',
      }),
      primaryColor: primaryColor,
      showSearchFilter: true,
      searchController: searchController,
      onSearchSubmitted: (_) => onSearch(),
      onFilterTap: onFilter,
      hasActiveFilter: hasActiveFilter,
      searchHintText: languageProvider.getTranslatedText({
        'en': 'Search lesson plans...',
        'id': 'Cari RPP...',
      }),
      activeFilters: hasActiveFilter
          ? [ActiveFilter(label: filterSummary, onRemove: onClearFilters)]
          : null,
      onClearAllFilters: onClearFilters,
      trailing: trailing,
    );
  }
}
