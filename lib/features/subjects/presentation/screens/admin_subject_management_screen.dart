// Admin subject (mata pelajaran) management screen - full CRUD for subjects.
//
// Like `pages/admin/subjects.vue` - manages school subjects with create, edit,
// delete, search, multi-filter (status, grade level, class), infinite scroll
// pagination, and Excel import/export.
//
// In Laravel terms, this is the Blade View; business logic lives in
// AdminSubjectController (admin_subject_controller.dart).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/subjects/presentation/controllers/admin_subject_controller.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_card.dart';
import 'package:manajemensekolah/features/subjects/presentation/screens/subject_class_management_page.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_filter_sheet.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Admin subject management screen with full CRUD, search, filters, and Excel import/export.
///
/// This is a [StatefulWidget] - like a Vue page with extensive local state for
/// subject list, pagination, filters, and real-time sync via FCM.
class SubjectManagementScreen extends ConsumerStatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  SubjectManagementScreenState createState() => SubjectManagementScreenState();
}

/// Mutable state for [SubjectManagementScreen].
///
/// Key state (like Vue `data()`):
/// - [_subjectList] - paginated subject list from API
/// - [_availableMasterSubjects] - predefined subject templates for the create form
/// - Filter states: [_selectedStatusFilter], [_selectedGradeLevelFilter], [_selectedClassNameFilter]
/// - Pagination: [_currentPage], [_hasMoreData], [_isLoadingMore] for infinite scroll
///
/// Listens to FCM sync triggers for real-time updates.
/// setState() triggers re-render like Vue's reactivity system.
class SubjectManagementScreenState
    extends ConsumerState<SubjectManagementScreen> {
  List<dynamic> _subjectList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter States (Backend filtering)
  String? _selectedStatusFilter; // 'active', 'inactive', or null for all
  String? _selectedClassesStatusFilter; // 'ada', 'tidak_ada', or null for all
  String? _selectedGradeLevelFilter; // '1' through '12', or null for all
  String?
  _selectedClassNameFilter; // Specific class name (7A, 7B, etc.), or null for all
  bool _hasActiveFilter = false;

  // Dynamic list of available class names
  List<String> _availableClassNames = [];
  List<String> _availableGradeLevels = [];

  // Tour Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  List<dynamic> _availableMasterSubjects = [];

  // Search debounce
  Timer? _searchDebounce;

  /// Like Vue's `mounted()` - sets up scroll listener for infinite scroll,
  /// loads filter options, master subjects, and the subject list.
  /// Also subscribes to FCM sync triggers for real-time updates.
  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    _loadFilterOptions();
    _loadMasterSubjects();
    _loadSubjects();

    // Listen to background sync triggers (FCM)
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  void _onSyncTriggered() {
    if (FCMService().syncTrigger.value?['type'] == 'refresh_subjects') {
      AppLogger.debug('subject', 'Refreshing subjects due to FCM sync trigger');
      _loadSubjects(resetPage: true, useCache: false).then((_) {
        // Optional: show a small snackbar if item count changed
      });
    }
  }

  Future<void> _loadMasterSubjects() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final data = await ctrl.loadMasterSubjects();
    if (mounted) {
      setState(() {
        _availableMasterSubjects = data;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    _searchController.dispose();
    _searchDebounce?.cancel();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    super.dispose();
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreSubjects();
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.loadFilterOptions();
  }

  void _checkActiveFilter() {
    final ctrl = ref.read(adminSubjectControllerProvider);
    setState(() {
      _hasActiveFilter = ctrl.checkActiveFilter(
        selectedStatusFilter: _selectedStatusFilter,
        selectedClassesStatusFilter: _selectedClassesStatusFilter,
        selectedGradeLevelFilter: _selectedGradeLevelFilter,
        selectedClassNameFilter: _selectedClassNameFilter,
      );
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedClassesStatusFilter = null;
      _selectedGradeLevelFilter = null;
      _selectedClassNameFilter = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadSubjects(); // Reload data after clearing filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final ctrl = ref.read(adminSubjectControllerProvider);
    return ctrl.buildFilterChips(
      selectedStatusFilter: _selectedStatusFilter,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedGradeLevelFilter: _selectedGradeLevelFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
      languageProvider: languageProvider,
      onStatusRemoved: () {
        setState(() {
          _selectedStatusFilter = null;
        });
        _checkActiveFilter();
        _loadSubjects();
      },
      onClassesStatusRemoved: () {
        setState(() {
          _selectedClassesStatusFilter = null;
        });
        _checkActiveFilter();
        _loadSubjects();
      },
      onGradeLevelRemoved: () {
        setState(() {
          _selectedGradeLevelFilter = null;
        });
        _checkActiveFilter();
        _loadSubjects();
      },
      onClassNameRemoved: () {
        setState(() {
          _selectedClassNameFilter = null;
        });
        _checkActiveFilter();
        _loadSubjects();
      },
    );
  }

  void _showFilterSheet() {
    // Delegate to SubjectFilterSheet widget – like mounting a Vue modal component.
    // Data flows in via constructor params; results come back via onApply callback.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectFilterSheet(
        initialStatus: _selectedStatusFilter,
        initialClassStatus: _selectedClassesStatusFilter,
        initialGradeLevel: _selectedGradeLevelFilter,
        initialClassName: _selectedClassNameFilter,
        availableGradeLevels: _availableGradeLevels,
        availableClassNames: _availableClassNames,
        onApply: (status, classStatus, gradeLevel, className) {
          setState(() {
            _selectedStatusFilter = status;
            _selectedClassesStatusFilter = classStatus;
            _selectedGradeLevelFilter = gradeLevel;
            _selectedClassNameFilter = className;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      ),
    );
  }

  Future<void> _loadSubjects({
    bool resetPage = true,
    bool useCache = true,
  }) async {
    final ctrl = ref.read(adminSubjectControllerProvider);

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;

      // Show loading skeleton only if we have no data yet
      if (_subjectList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }
    }

    final result = await ctrl.loadSubjects(
      selectedStatusFilter: _selectedStatusFilter,
      selectedGradeLevelFilter: _selectedGradeLevelFilter,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
      searchText: _searchController.text,
      perPage: _perPage,
      useCache: useCache,
    );

    if (!mounted) return;

    if (result.errorMessage != null && result.subjects.isEmpty) {
      // Hard failure — show error screen
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage!;
      });
    } else {
      setState(() {
        _subjectList = result.subjects;
        _hasMoreData = result.hasMoreData;
        _isLoading = false;
        _errorMessage = '';
        _availableClassNames = result.availableClassNames;
        _availableGradeLevels = result.availableGradeLevels;
      });
    }

    // Trigger tour after load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndShowTour();
      }
    });
  }

  /// Force refresh: clear cache and reload from API
  Future<void> _forceRefresh() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.invalidateSubjectCache(
      selectedStatusFilter: _selectedStatusFilter,
      selectedGradeLevelFilter: _selectedGradeLevelFilter,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
      searchText: _searchController.text,
    );
    await _loadSubjects(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreSubjects() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    final ctrl = ref.read(adminSubjectControllerProvider);
    final nextPage = _currentPage + 1;

    final result = await ctrl.loadMoreSubjects(
      nextPage: nextPage,
      perPage: _perPage,
      selectedStatusFilter: _selectedStatusFilter,
      selectedGradeLevelFilter: _selectedGradeLevelFilter,
      searchText: _searchController.text,
      existingClassNames: _availableClassNames,
      existingGradeLevels: _availableGradeLevels,
    );

    if (!mounted) return;

    if (result.errorMessage != null) {
      AppLogger.error('subject', 'Error loading more data: ${result.errorMessage}');
      setState(() {
        _isLoadingMore = false;
        // currentPage not incremented — stays where it was
      });
    } else {
      setState(() {
        _currentPage = nextPage;
        _subjectList.addAll(result.additionalSubjects);
        _availableClassNames = result.availableClassNames;
        _availableGradeLevels = result.availableGradeLevels;
        _hasMoreData = result.hasMoreData;
        _isLoadingMore = false;
      });

      AppLogger.info(
        'subject',
        'Loaded more subjects: Page $_currentPage, Total: ${_subjectList.length}',
      );
    }
  }

  Future<void> _exportToExcel() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.exportToExcel(subjects: _subjectList, context: context);
  }

  Future<void> _importFromExcel() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final languageProvider = ref.read(languageRiverpod);

    final errorMsg = await ctrl.importFromExcel();

    if (!mounted) return;

    if (errorMsg == null) {
      // Success — refresh the list
      await _loadSubjects();
      if (mounted) {
        ctrl.showSuccessSnackBar(
          context,
          languageProvider.getTranslatedText({
            'en': 'Subjects imported successfully',
            'id': 'Mata pelajaran berhasil diimpor',
          }),
        );
      }
    } else {
      ctrl.showErrorSnackBar(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to import file: $errorMsg',
          'id': '${AppLocalizations.failedToImport.tr}: $errorMsg',
        }),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.downloadTemplate(context);
  }

  void _showAddEditDialog({Map<String, dynamic>? subject}) {
    // Delegate to SubjectAddEditSheet widget – all form state lives there.
    // onSaved triggers a data reload here, like receiving a Vue $emit('saved').
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubjectAddEditSheet(
        subject: subject,
        availableMasterSubjects: _availableMasterSubjects,
        onSaved: _loadSubjects,
      ),
    );
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final languageProvider = ref.read(languageRiverpod);
    final ctrl = ref.read(adminSubjectControllerProvider);

    final confirmed = await showDialog(
      context: context,
      builder: (context) {
        final lp = ref.watch(languageRiverpod);
        return ConfirmationDialog(
          title: lp.getTranslatedText({
            'en': 'Delete Subject',
            'id': 'Hapus Mata Pelajaran',
          }),
          content: lp.getTranslatedText({
            'en': 'Are you sure you want to delete subject "${subject['name']}"?',
            'id': 'Yakin ingin menghapus mata pelajaran "${subject['name']}"?',
          }),
          confirmText: lp.getTranslatedText({
            'en': 'Delete',
            'id': 'Hapus',
          }),
          confirmColor: Colors.red,
        );
      },
    );

    if (confirmed == true) {
      final errorMsg = await ctrl.deleteSubject(subject['id']);

      if (!mounted) return;

      if (errorMsg == null) {
        ctrl.showSuccessSnackBar(
          context,
          languageProvider.getTranslatedText({
            'en': 'Subject successfully deleted',
            'id': 'Mata pelajaran berhasil dihapus',
          }),
        );
        _loadSubjects();
      } else {
        ctrl.showErrorSnackBar(
          context,
          '${languageProvider.getTranslatedText({'en': 'Failed to delete: ', 'id': 'Gagal menghapus: '})}$errorMsg',
        );
      }
    }
  }

  // Navigate to class management page for the subject
  void _navigateToClassManagement(Map<String, dynamic> subject) {
    AppNavigator.push(context, SubjectClassManagementPage(subject: subject));
  }

  List<dynamic> _getFilteredSubjects() {
    final ctrl = ref.read(adminSubjectControllerProvider);
    return ctrl.getFilteredSubjects(
      subjectList: _subjectList,
      searchText: _searchController.text,
      selectedClassesStatusFilter: _selectedClassesStatusFilter,
      selectedClassNameFilter: _selectedClassNameFilter,
    );
  }

  Widget _buildHeader(BuildContext context, LanguageProvider languageProvider) {
    final ctrl = ref.read(adminSubjectControllerProvider);
    return GradientPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Subject Management',
        'id': 'Manajemen Mata Pelajaran',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Manage and monitor subjects',
        'id': 'Kelola dan pantau mata pelajaran',
      }),
      primaryColor: ctrl.getPrimaryColor(),
      onBackPressed: () => AppNavigator.pop(context),
      actionMenu: PopupMenuButton<String>(
        key: _menuKey,
        onSelected: (value) {
          switch (value) {
            case 'refresh':
              _forceRefresh();
              break;
            case 'export':
              _exportToExcel();
              break;
            case 'import':
              _importFromExcel();
              break;
            case 'template':
              _downloadTemplate();
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
          child: Icon(Icons.more_vert, color: Colors.white, size: 20),
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
      ),
      searchBar: Row(
          children: [
            Expanded(
              child: Container(
                key: _searchKey,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: languageProvider.getTranslatedText({
                            'en': 'Search subjects...',
                            'id': 'Cari mata pelajaran...',
                          }),
                          hintStyle: TextStyle(color: Colors.grey),
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            _currentPage = 1;
                          });
                          _loadSubjects();
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(Icons.search, color: ctrl.getPrimaryColor()),
                        onPressed: () {
                          setState(() {
                            _currentPage = 1;
                          });
                          _loadSubjects();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              key: _filterKey,
              decoration: BoxDecoration(
                color: _hasActiveFilter
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Stack(
                children: [
                  IconButton(
                    onPressed: _showFilterSheet,
                    icon: Icon(
                      Icons.tune,
                      color: _hasActiveFilter
                          ? ctrl.getPrimaryColor()
                          : Colors.white,
                    ),
                    tooltip: languageProvider.getTranslatedText({
                      'en': 'Filter',
                      'id': 'Filter',
                    }),
                  ),
                  if (_hasActiveFilter)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                            BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      filterChips: _hasActiveFilter
          ? SizedBox(
              height: 42,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Icon(
                      Icons.filter_alt,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._buildFilterChips(languageProvider).map((filter) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(
                                filter['label'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ctrl.getPrimaryColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              deleteIcon: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                              onDeleted: filter['onRemove'],
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              labelPadding: const EdgeInsets.only(left: 4),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InkWell(
                    onTap: _clearAllFilters,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: Icon(
                        Icons.clear_all,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final ctrl = ref.read(adminSubjectControllerProvider);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: ColorUtils.lightGray,
        body: Column(
          children: [
            _buildHeader(context, languageProvider),
            Expanded(child: SkeletonListLoading(itemCount: 6, infoTagCount: 2)),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return ErrorScreen(errorMessage: _errorMessage, onRetry: _loadSubjects);
    }

    final filteredSubjects = _getFilteredSubjects();

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          _buildHeader(context, languageProvider),

          Expanded(
            child: filteredSubjects.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No subjects',
                      'id': 'Tidak ada mata pelajaran',
                    }),
                    subtitle:
                        _searchController.text.isEmpty && !_hasActiveFilter
                        ? languageProvider.getTranslatedText({
                            'en': 'Tap + to add a subject',
                            'id': 'Tap + untuk menambah mata pelajaran',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'No search results found',
                            'id': 'Tidak ditemukan hasil pencarian',
                          }),
                    icon: Icons.school_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: _loadSubjects,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount:
                          filteredSubjects.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at bottom
                        if (index == filteredSubjects.length) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        return SubjectCard(
                          subject: filteredSubjects[index],
                          index: index,
                          primaryColor: ctrl.getPrimaryColor(),
                          onTap: () => _navigateToClassManagement(
                            filteredSubjects[index],
                          ),
                          onEdit: () => _showAddEditDialog(
                            subject: filteredSubjects[index],
                          ),
                          onDelete: () => _deleteSubject(
                            filteredSubjects[index],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _fabKey,
        onPressed: _showAddEditDialog,
        backgroundColor: ctrl.getPrimaryColor(),
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(16))),
        child: Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'subject_management',
        'admin',
      );

      // Only use cache (pre-fetched by dashboard), no API call
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('subject', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'subject_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'subject_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "SubjectMenu",
        keyTarget: _menuKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Subject Data Tools',
                      'id': 'Alat Data Mata Pelajaran',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Export, import, or download subject templates from this menu.',
                        'id':
                            'Ekspor, impor, atau unduh template mata pelajaran dari menu ini.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "SubjectSearch",
        keyTarget: _searchKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Search Subjects',
                      'id': 'Cari Mata Pelajaran',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Quickly find subjects by typing their name here.',
                        'id':
                            'Temukan mata pelajaran dengan cepat dengan mengetikkan namanya di sini.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "SubjectFilter",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Advanced Filtering',
                      'id': 'Filter Lanjutan',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Filter subjects by status, grade level, or specific class names.',
                        'id':
                            'Filter mata pelajaran berdasarkan status, tingkat kelas, atau nama kelas tertentu.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "AddSubject",
        keyTarget: _fabKey,
        alignSkip: Alignment.topLeft,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Add New Subject',
                      'id': 'Tambah Mata Pelajaran Baru',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'Click here to manually add a new subject to the curriculum.',
                        'id':
                            'Klik di sini untuk menambahkan mata pelajaran baru secara manual ke kurikulum.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}
