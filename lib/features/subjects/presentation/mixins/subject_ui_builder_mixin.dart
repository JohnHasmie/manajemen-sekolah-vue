import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/controllers/admin_subject_controller.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/screens/admin_subject_management_screen.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/widgets/subject_header_menu.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/widgets/subject_header_search.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/widgets/subject_filter_chips.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/widgets/subject_card.dart';

/// Mixin handling subject UI building for header and list.
mixin SubjectUIBuilderMixin on ConsumerState<AdminSubjectManagementScreen> {
  Widget buildHeader(BuildContext context, LanguageProvider languageProvider) {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final primaryColor = ctrl.getPrimaryColor();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderContainer(languageProvider, primaryColor),
          if (hasActiveFilter)
            _buildFilterChipsWidget(languageProvider, primaryColor),
        ],
      ),
    );
  }

  Widget _buildHeaderContainer(
    LanguageProvider languageProvider,
    Color primaryColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        MediaQuery.of(context).padding.top + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderTop(languageProvider),
          const SizedBox(height: AppSpacing.md),
          _buildHeaderSearch(primaryColor),
        ],
      ),
    );
  }

  Widget _buildHeaderTop(LanguageProvider languageProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildHeaderTitle(languageProvider),
        SubjectHeaderMenu(
          menuKey: menuKey,
          onRefresh: forceRefresh,
          onExport: exportToExcel,
          onImport: importFromExcel,
          onTemplate: downloadTemplate,
        ),
      ],
    );
  }

  Widget _buildHeaderTitle(LanguageProvider languageProvider) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getTranslatedText({
              'en': 'Subject Management',
              'id': 'Manajemen Mata Pelajaran',
            }),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            languageProvider.getTranslatedText({
              'en': 'Manage and monitor subjects',
              'id':
                  'Kelola dan pantau mata '
                  'pelajaran',
            }),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSearch(Color primaryColor) {
    return SubjectHeaderSearch(
      searchKey: searchKey,
      searchController: searchController,
      filterKey: filterKey,
      hasActiveFilter: hasActiveFilter,
      primaryColor: primaryColor,
      onSearch: () {
        setState(() {
          currentPage = 1;
        });
        loadSubjects();
      },
      onFilter: () =>
          showFilterSheet(availableGradeLevels, availableClassNames),
    );
  }

  Widget _buildFilterChipsWidget(
    LanguageProvider languageProvider,
    Color primaryColor,
  ) {
    return SubjectFilterChips(
      filters: buildFilterChips(languageProvider),
      onClear: () {
        clearAllFilters();
        searchController.clear();
        setState(() {
          currentPage = 1;
        });
        loadSubjects();
      },
      primaryColor: primaryColor,
    );
  }

  Widget buildListView(List<dynamic> filteredSubjects) {
    final ctrl = ref.read(adminSubjectControllerProvider);

    return PaginatedListView<dynamic>(
      items: filteredSubjects,
      controller: scrollController,
      onLoadMore: loadMoreSubjects,
      hasMore: hasMoreData,
      isLoadingMore: isLoadingMore,
      onRefresh: loadSubjects,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, subject, index) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: SubjectCard(
          subject: subject,
          index: index,
          primaryColor: ctrl.getPrimaryColor(),
          onTap: () => navigateToClassManagement(subject),
          onEdit: () => showAddEditDialog(subject: subject),
          onDelete: () => deleteSubject(subject),
        ),
      ),
    );
  }

  // Abstract properties/methods from mixins
  TextEditingController get searchController;
  ScrollController get scrollController;
  List<String> get availableGradeLevels;
  List<String> get availableClassNames;
  bool get hasActiveFilter;
  bool get isLoadingMore;
  bool get hasMoreData;
  int get currentPage;
  set currentPage(int v);

  GlobalKey get menuKey;
  GlobalKey get searchKey;
  GlobalKey get filterKey;
  GlobalKey get fabKey;

  Future<void> forceRefresh();
  Future<void> exportToExcel();
  Future<void> importFromExcel();
  Future<void> downloadTemplate();
  void showFilterSheet(
    List<String> availableGradeLevels,
    List<String> availableClassNames,
  );
  List<Map<String, dynamic>> buildFilterChips(
    LanguageProvider languageProvider,
  );
  void clearAllFilters();
  void navigateToClassManagement(Map<String, dynamic> subject);
  void showAddEditDialog({Map<String, dynamic>? subject});
  Future<void> deleteSubject(Map<String, dynamic> subject);
  Future<void> loadSubjects({bool resetPage = true, bool useCache = true});
  Future<void> loadMoreSubjects();
}
