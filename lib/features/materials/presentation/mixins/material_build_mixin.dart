// Mixin for build methods in TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart to keep main file under 400
// lines. Contains all UI building logic for header, content, filter chips,
// FAB, and various view states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_generate_sheet.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_overview_view.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';

/// Mixin providing build methods for [TeacherMaterialScreenState].
mixin MaterialBuildMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Getters the main state must expose ──
  String? get selectedSubject;
  String? get selectedClassId;
  String? get selectedClassName;
  List<dynamic> get chapterMaterialList;
  List<dynamic> get subChapterMaterialList;
  List<dynamic> get overviewSummary;
  set overviewSummary(List<dynamic> v);
  bool get isLoading;
  bool get isLoadingBab;
  bool get isLoadingProgress;
  bool get isLoadingOverview;
  set isLoadingOverview(bool v);
  bool get isListView;
  set isListView(bool v);
  bool get isHomeroomView;
  set isHomeroomView(bool v);
  Map<String, bool> get expandedChapter;
  Map<String, bool> get checkedChapter;
  Map<String, bool> get checkedSubChapter;
  TextEditingController get searchController;
  GlobalKey get filterKey;
  GlobalKey get searchKey;
  Color get primaryColor;
  Map<String, bool> get generatedChapter;
  Map<String, bool> get generatedSubChapter;

  /// Get filtered chapters from search.
  List<dynamic> getFilteredChapters();

  /// Get checkbox color for chapter.
  Color getCheckboxColor(String id, {bool isSubChapter = false});

  /// Handle chapter check change.
  void handleChapterCheck(String chId, bool? checked);

  /// Handle sub-chapter check change.
  void handleSubChapterCheck(String subChId, String babId, bool? checked);

  /// Open generate activity sheet.
  void openGenerateActivitySheet();

  /// Show filter dialog.
  Future<void> showFilterDialog(LanguageProvider lp);

  /// Clear all filters.
  void clearAllFilters();

  /// Get checked but not generated chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedChapters();

  /// Get checked but not generated sub-chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedSubChapters();

  /// Get selected subject name.
  String getSelectedSubjectName();

  /// Clear class filter.
  void clearClassFilter();

  /// Clear subject filter.
  void clearSubjectFilter();

  /// Navigate to sub-chapter detail.
  void navigateToSubChapterDetail(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> bab,
  );

  /// Open chapter sheet.
  void openChapterSheet(String classId, String cn, String subjectId, String sn);

  /// Auto-expand relevant chapter.
  void autoExpandToRelevant();

  /// Force refresh content.
  Future<void> forceRefresh();

  /// Load chapter content (with optional search).
  Future<void> loadChapterContent(
    String subjectId, {
    bool useCache,
    String? search,
  });

  /// Load overview and schedules (with optional search).
  Future<void> loadOverviewAndSchedules(
    String teacherId,
    List<dynamic> classes, {
    String? search,
  });

  /// Get teacher ID from widget.
  String get _teacherId => widget.teacher['id']?.toString() ?? '';

  /// Perform search — calls backend API with search term.
  void performSearch() {
    final term = searchController.text.trim();
    if (selectedSubject != null) {
      // Search within chapter content
      setState(() {
        isLoadingBab = true;
        chapterMaterialList = [];
        subChapterMaterialList = [];
      });
      loadChapterContent(
        selectedSubject!,
        useCache: false,
        search: term.isEmpty ? null : term,
      );
    } else {
      // Search within overview
      setState(() => isLoadingOverview = true);
      loadOverviewAndSchedules(
        _teacherId,
        [],
        search: term.isEmpty ? null : term,
      );
    }
  }

  // ignore: annotate_overrides
  set isLoadingBab(bool v);

  // ignore: annotate_overrides
  set chapterMaterialList(List<dynamic> v);

  // ignore: annotate_overrides
  set subChapterMaterialList(List<dynamic> v);

  // ── Build methods ──

  /// Build main screen with header.
  Widget buildMain(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            buildHeaderBar(lp),
            Expanded(child: buildContent(lp)),
          ],
        ),
        floatingActionButton: buildFab(lp),
      ),
    );
  }

  /// Build embedded screen (in bottom sheet).
  Widget buildEmbedded(LanguageProvider lp) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${lp.getTranslatedText({'en': 'Material', 'id': 'Materi'})} — '
          '${widget.initialSubjectName ?? ''} '
          '${widget.initialClassName ?? ''}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            AppSpacing.v8,
            Expanded(child: buildContent(lp)),
          ],
        ),
      ),
    );
  }

  /// Build header with search and filter buttons.
  Widget buildHeaderBar(LanguageProvider lp) {
    final isHomeroomTeacher = ref.watch(teacherRiverpod).isHomeroomTeacher;
    return TeacherPageHeader(
      title: lp.getTranslatedText({
        'en': 'Teaching Materials',
        'id': 'Materi Pembelajaran',
      }),
      subtitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'Material progress for your homeroom class',
              'id': 'Progress materi kelas perwalian',
            })
          : lp.getTranslatedText({
              'en': 'Browse chapters and sub-chapters',
              'id': 'Jelajahi bab dan sub-bab materi',
            }),
      primaryColor: primaryColor,
      showRoleToggle: isHomeroomTeacher,
      isHomeroomView: isHomeroomView,
      onRoleChanged: _handleRoleChange,
      showSearchFilter: true,
      searchController: searchController,
      onSearchTap: performSearch,
      onSearchSubmitted: (_) => performSearch(),
      onFilterTap: () => showFilterDialog(lp),
      hasActiveFilter: hasActiveFilter(),
      searchHintText: lp.getTranslatedText(
        selectedSubject != null
            ? {'en': 'Search chapters...', 'id': 'Cari bab...'}
            : {
                'en': 'Search class or subject...',
                'id': 'Cari kelas atau mapel...',
              },
      ),
      activeFilters: _buildActiveFilterChips(lp),
      onClearAllFilters: clearAllFilters,
      trailing: GestureDetector(
        onTap: toggleViewMode,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isListView ? Icons.grid_view_rounded : Icons.view_list_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }

  /// Handle role toggle (Mengajar ↔ Wali Kelas).
  void _handleRoleChange(bool val) {
    setState(() {
      isHomeroomView = val;
      // Reset to overview when switching views
      overviewSummary = [];
      isLoadingOverview = true;
    });
    clearAllFilters();
    forceRefresh();
  }

  /// Build active filter chips for display.
  List<ActiveFilter> _buildActiveFilterChips(LanguageProvider lp) {
    final filters = <ActiveFilter>[];

    if (selectedClassId != null) {
      filters.add(
        ActiveFilter(
          label: selectedClassName ?? '-',
          onRemove: clearClassFilter,
        ),
      );
    }

    if (selectedSubject != null) {
      filters.add(
        ActiveFilter(
          label: getSelectedSubjectName(),
          onRemove: clearSubjectFilter,
        ),
      );
    }

    return filters;
  }

  /// Toggle between list and grid view.
  void toggleViewMode() {
    setState(() {
      isListView = !isListView;
      LocalCacheService.save('materi_view_preference', {
        'is_list_view': isListView,
      });
    });
  }

  /// Build FAB for generating activity.
  Widget? buildFab(LanguageProvider lp) {
    if (selectedSubject == null) return null;
    return FloatingActionButton.extended(
      onPressed: () => MaterialGenerateSheet.show(
        context: context,
        checkedChapters: getCheckedNotGeneratedChapters(),
        checkedSubChapters: getCheckedNotGeneratedSubChapters(),
        subjectName: getSelectedSubjectName(),
        primaryColor: primaryColor,
        languageProvider: lp,
        onGenerate: openGenerateActivitySheet,
      ),
      backgroundColor: primaryColor,
      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
      label: Text(
        lp.getTranslatedText({'en': 'Generate', 'id': 'Generate'}),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? get materialErrorMessage;

  /// Build main content area.
  Widget buildContent(LanguageProvider lp) {
    // When subject is selected, show chapter content with async wrapper
    if (selectedSubject != null) {
      return TeacherAsyncView(
        isLoading: isLoadingBab || isLoadingProgress,
        errorMessage: null,
        isEmpty: chapterMaterialList.isEmpty,
        onRefresh: forceRefresh,
        role: 'guru',
        emptyTitle: lp.getTranslatedText({
          'en': 'No Materials',
          'id': 'Tidak Ada Materi',
        }),
        emptySubtitle: lp.getTranslatedText({
          'en': 'No materials available for this subject',
          'id': 'Tidak ada materi untuk mapel ini',
        }),
        emptyIcon: Icons.menu_book,
        childBuilder: () => buildChapterContent(lp),
        loadingBuilder: () => const SkeletonListLoading(
          padding: EdgeInsets.only(top: 8, bottom: 80),
          showActions: false,
        ),
      );
    }
    // Otherwise show overview with its own async wrapper
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: materialErrorMessage,
      isEmpty: false, // Overview handles empty state internally
      onRefresh: forceRefresh,
      role: 'guru',
      emptyTitle: '',
      emptySubtitle: '',
      emptyIcon: Icons.inbox,
      childBuilder: () => MaterialOverviewView(
        overviewSummary: overviewSummary,
        isLoading: isLoadingOverview,
        isListView: isListView,
        isHomeroomView: isHomeroomView,
        primaryColor: primaryColor,
        languageProvider: lp,
        onRefresh: forceRefresh,
        onOpenChapter: openChapterSheet,
        searchText: searchController.text,
      ),
    );
  }

  /// Build chapter content with chapters and sub-chapters (delegated to MaterialBuildListMixin).
  Widget buildChapterContent(LanguageProvider lp);

  /// Build content list with expandable chapters (delegated to MaterialBuildListMixin).
  Widget buildContentList();

  /// Check if any filter is active.
  bool hasActiveFilter() => selectedClassId != null || selectedSubject != null;
}
