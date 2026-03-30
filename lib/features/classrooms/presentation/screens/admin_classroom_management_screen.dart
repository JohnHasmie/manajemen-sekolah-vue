// Admin class management screen - full CRUD for school classes.
//
// Like `pages/admin/classes.vue` - manages school classes (create, edit, delete)
// with homeroom teacher assignment, student listing, and class promotion.
// Supports infinite scroll pagination, search, filtering, Excel import/export.
//
// In Laravel terms, this consumes ClassController (GET/POST/PUT/DELETE /api/classes).
// Business logic lives in [AdminClassroomController] — this file is the View layer.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/classrooms/presentation/controllers/admin_classroom_controller.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_detail_dialog.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_add_edit_sheet.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_card.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_filter_sheet.dart';

/// Admin class management screen with full CRUD, search, filters, and Excel import/export.
///
/// This is a [StatefulWidget] - like a Vue page component with local state for
/// class list, pagination, filters, and FAB (Floating Action Button) animations.
class AdminClassManagementScreen extends ConsumerStatefulWidget {
  const AdminClassManagementScreen({super.key});

  @override
  AdminClassManagementScreenState createState() =>
      AdminClassManagementScreenState();
}

/// Mutable state for [AdminClassManagementScreen].
///
/// Key state (like Vue `data()`):
/// - [_classes] / [_teachers] - data lists from API
/// - [_currentPage] / [_hasMoreData] / [_isLoadingMore] - infinite scroll pagination
/// - [_selectedGradeFilter] / [_selectedHomeroomFilter] - filter state
/// - [_isFabOpen] - animated FAB menu state (add class, import Excel, promote)
///
/// Uses [SingleTickerProviderStateMixin] for FAB animation (like Vue `<transition>`).
/// Listens to FCM sync triggers for real-time updates from other users.
class AdminClassManagementScreenState
    extends ConsumerState<AdminClassManagementScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // FAB Animation
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;
  late Animation<double> _fabScaleAnimation;
  bool _isFabOpen = false;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter States (Backend filtering)
  String? _selectedGradeFilter; // '1' to '12', or null for all
  String? _selectedHomeroomFilter; // 'true', 'false', or null
  bool _hasActiveFilter = false;

  // Tour Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // Filter Options (from backend)
  final List<String> _availableGradeLevels = [];

  // Search debounce removed

  /// Like Vue's `mounted()` lifecycle hook.
  /// Sets up FAB animations, scroll listener for infinite scroll,
  /// FCM sync listener, and loads initial data (school settings, teachers, classes).
  @override
  void initState() {
    super.initState();

    // FAB Init
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    _fabRotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to search changes with debounce - Removed to match StudentManagement
    // _searchController.addListener(_onSearchChanged);

    // Listen to sync triggers from FCM
    FCMService().syncTrigger.addListener(_onSyncTriggered);

    _loadSchoolSettings(); // Load dynamic grade levels
    _fetchTeachers();
    _loadData();
  }

  /// Like Vue's `beforeUnmount()` - cleans up listeners, controllers, and timers.
  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _fabAnimationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    // _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_classes' ||
            trigger['type'] == 'refresh_teachers')) {
      AppLogger.debug(
        'classroom',
        'Real-time sync triggered (${trigger['type']}): Reloading classes',
      );
      _loadData(resetPage: true, useCache: false);
    }
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // 200px before bottom
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Data helpers — all delegate to [AdminClassroomController].
  // Like calling `this.classService.method()` in a Vue component.
  // ---------------------------------------------------------------------------

  /// Loads school settings and populates [_availableGradeLevels] via setState.
  /// Jenjang is owned by the controller; the screen only needs the grade list.
  Future<void> _loadSchoolSettings() async {
    final result =
        await ref.read(adminClassroomControllerProvider).loadSchoolSettings();
    if (!mounted) return;
    setState(() {
      _availableGradeLevels
        ..clear()
        ..addAll(result.gradeLevels);
    });
  }

  /// Loads all teachers and updates [_teachers] via setState.
  Future<void> _fetchTeachers() async {
    final teachers =
        await ref.read(adminClassroomControllerProvider).fetchTeachers();
    if (!mounted) return;
    setState(() => _teachers = teachers);
  }

  /// Recomputes [_hasActiveFilter] after any filter change.
  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminClassroomControllerProvider)
          .checkActiveFilter(
            selectedGradeFilter: _selectedGradeFilter,
            selectedHomeroomFilter: _selectedHomeroomFilter,
          );
    });
  }

  /// Resets all filters + search, then reloads data.
  void _clearAllFilters() {
    final reset = ref
        .read(adminClassroomControllerProvider)
        .clearAllFilters();
    setState(() {
      _selectedGradeFilter = reset.gradeFilter;
      _selectedHomeroomFilter = reset.homeroomFilter;
      _hasActiveFilter = reset.hasActiveFilter;
      _searchController.clear();
      _currentPage = 1;
    });
    _loadData();
  }

  /// Builds chip data for active filter badges in the header.
  ///
  /// The [onRemove] callbacks live here (not in the controller) because they
  /// call [setState] — pure UI side-effect wiring, like a Vue event handler.
  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    return ref.read(adminClassroomControllerProvider).buildFilterChips(
      selectedGradeFilter: _selectedGradeFilter,
      selectedHomeroomFilter: _selectedHomeroomFilter,
      languageProvider: languageProvider,
      onRemoveGrade: () {
        setState(() => _selectedGradeFilter = null);
        _checkActiveFilter();
        _loadData();
      },
      onRemoveHomeroom: () {
        setState(() => _selectedHomeroomFilter = null);
        _checkActiveFilter();
        _loadData();
      },
    );
  }

  /// Opens the filter bottom-sheet; applies selections and reloads on confirm.
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassroomFilterSheet(
        initialGradeFilter: _selectedGradeFilter,
        initialHomeroomFilter: _selectedHomeroomFilter,
        availableGradeLevels: _availableGradeLevels,
        languageProvider: ref.read(languageRiverpod),
        onApply: (grade, homeroom) {
          setState(() {
            _selectedGradeFilter = grade;
            _selectedHomeroomFilter = homeroom;
          });
          _checkActiveFilter();
          _loadData();
        },
      ),
    );
  }

  /// Loads (or reloads) the paginated class list via the controller and
  /// updates local state with the returned [ClassLoadResult].
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    // Show skeleton only when starting fresh with no existing data.
    if (resetPage && _classes.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMoreData = true;
      });
    } else if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
    }

    final result = await ref.read(adminClassroomControllerProvider).loadData(
      currentPage: _currentPage,
      perPage: _perPage,
      existingClasses: _classes,
      selectedGradeFilter: _selectedGradeFilter,
      selectedHomeroomFilter: _selectedHomeroomFilter,
      searchText: _searchController.text,
      resetPage: resetPage,
      useCache: useCache,
    );

    if (!mounted) return;

    setState(() {
      _classes = result.classes;
      _hasMoreData = result.hasMoreData;
      _isLoading = false;
      if (result.errorMessage != null) {
        _errorMessage = result.errorMessage;
      }
    });

    if (result.errorMessage != null && _classes.isNotEmpty) {
      // Non-empty list: show snackbar instead of full error screen.
      SnackBarUtils.showError(
        context,
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Gagal memuat data kelas', 'id': 'Gagal memuat data kelas'})}: ${result.errorMessage}',
      );
    }

    // Trigger tour after data loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndShowTour();
    });
  }

  /// Clears cache and forces a full reload from the API.
  Future<void> _forceRefresh() async {
    final result =
        await ref.read(adminClassroomControllerProvider).forceRefresh(
          perPage: _perPage,
          selectedGradeFilter: _selectedGradeFilter,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          searchText: _searchController.text,
        );
    if (!mounted) return;
    setState(() {
      _classes = result.classes;
      _hasMoreData = result.hasMoreData;
      _isLoading = false;
      _currentPage = 1;
      _errorMessage = result.errorMessage;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndShowTour();
    });
  }

  /// Pull-to-refresh handler — bypasses cache.
  Future<void> _onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  /// Appends the next page of classes to the existing list.
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result =
        await ref.read(adminClassroomControllerProvider).loadMoreData(
          nextPage: _currentPage + 1,
          perPage: _perPage,
          existingClasses: _classes,
          selectedGradeFilter: _selectedGradeFilter,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          searchText: _searchController.text,
        );

    if (!mounted) return;
    setState(() {
      _classes = result.classes;
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
      if (result.errorMessage == null) _currentPage++;
    });

    if (result.errorMessage != null) {
      AppLogger.error('classroom', 'Load more error: ${result.errorMessage}');
    }
  }

  /// Exports the current class list to Excel via the controller.
  Future<void> _exportToExcel() async {
    await ref
        .read(adminClassroomControllerProvider)
        .exportToExcel(classes: _classes, context: context);
  }

  /// Opens a file picker, imports an Excel file, then reloads on success.
  Future<void> _importFromExcel() async {
    final success = await ref
        .read(adminClassroomControllerProvider)
        .importFromExcel(context);
    if (success) await _loadData();
  }

  /// Downloads the Excel import template via the controller.
  Future<void> _downloadTemplate() async {
    await ref
        .read(adminClassroomControllerProvider)
        .downloadTemplate(context);
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? classData}) async {
    // Refresh teacher list and fetch fresh class data before opening the sheet,
    // ensuring the dropdown always reflects current DB state.
    await _fetchTeachers();

    if (classData != null) {
      try {
        final freshData = await getIt<ApiClassService>().getClassById(
          classData['id'].toString(),
        );
        if (freshData != null && freshData is Map<String, dynamic>) {
          classData = freshData;

          // Ensure the assigned homeroom teacher appears in the list even if
          // they are soft-deleted or outside the paginated teacher fetch.
          String? homeroomId = classData['homeroom_teacher_id']?.toString();
          String? homeroomName = classData['homeroom_teacher_name']?.toString();

          if (homeroomId == null &&
              classData['homeroom_teacher'] is List &&
              (classData['homeroom_teacher'] as List).isNotEmpty) {
            homeroomId = classData['homeroom_teacher'][0]['id']?.toString();
            homeroomName = classData['homeroom_teacher'][0]['name']?.toString();
          } else if (homeroomId == null &&
              classData['homeroom_teacher'] is Map) {
            homeroomId = classData['homeroom_teacher']['id']?.toString();
            homeroomName = classData['homeroom_teacher']['name']?.toString();
          }

          if (homeroomId != null && homeroomName != null) {
            final exists = _teachers.any(
              (t) => t['id'].toString() == homeroomId,
            );
            if (!exists) {
              setState(() {
                _teachers.add({'id': homeroomId, 'name': homeroomName});
                _teachers.sort(
                  (a, b) =>
                      (a['name'] ?? '').toString().compareTo(b['name'] ?? ''),
                );
              });
            }
          }
        }
      } catch (e) {
        AppLogger.error('classroom', 'Error fetching fresh class data: $e');
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassroomAddEditSheet(
        classData: classData,
        teachers: _teachers,
        availableGradeLevels: _availableGradeLevels,
        onSaved: _loadData,
      ),
    );
  }

  /// Deletes a class by delegating to [AdminClassroomController.deleteClass]
  /// (confirmation dialog + API call + snackbar), then reloads on success.
  Future<void> _deleteClass(Map<String, dynamic> classData) async {
    final deleted = await ref
        .read(adminClassroomControllerProvider)
        .deleteClass(classData, context);
    if (deleted) _loadData();
  }

  void _showClassDetail(Map<String, dynamic> classData) {
    ClassDetailDialog.show(
      context: context,
      classData: classData,
      gradeText: _getGradeLevelText(
        classData['grade_level'],
        ref.read(languageRiverpod),
      ),
      primaryColor: _getPrimaryColor(),
      isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
      onEdit: () => _showAddEditDialog(classData: classData),
      languageProvider: ref.read(languageRiverpod),
    );
  }

  /// Delegates to [AdminClassroomController.getGradeLevelText].
  String _getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    return ref
        .read(adminClassroomControllerProvider)
        .getGradeLevelText(gradeLevel, languageProvider);
  }

  /// Delegates to [AdminClassroomController.getPrimaryColor].
  Color _getPrimaryColor() {
    return ref.read(adminClassroomControllerProvider).getPrimaryColor();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    if (_errorMessage != null) {
      return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
    }

    // Backend handles all filtering, so we use _classes directly
    final filteredClasses = _classes;

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          // Header
          GradientPageHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Class Management',
              'id': 'Manajemen Kelas',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'Manage and monitor classes',
              'id': 'Kelola dan pantau kelas',
            }),
            primaryColor: _getPrimaryColor(),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.more_vert, color: Colors.white, size: 20),
              ),
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                      SizedBox(width: AppSpacing.sm),
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
                      SizedBox(width: AppSpacing.sm),
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
                      SizedBox(width: AppSpacing.sm),
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
                      SizedBox(width: AppSpacing.sm),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Search classes...',
                                'id': 'Cari kelas...',
                              }),
                              hintStyle: TextStyle(color: Colors.grey),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Colors.grey,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) {
                              setState(() {
                                _currentPage = 1;
                              });
                              _loadData();
                            },
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(right: 4),
                          child: IconButton(
                            key: _filterKey,
                            icon: Icon(Icons.search, color: _getPrimaryColor()),
                            onPressed: () {
                              setState(() {
                                _currentPage = 1;
                              });
                              _loadData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Filter Button
                Container(
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        onPressed: _showFilterSheet,
                        icon: Icon(
                          Icons.tune,
                          color: _hasActiveFilter
                              ? _getPrimaryColor()
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
                            padding: EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(
                              minWidth: 8,
                              minHeight: 8,
                            ),
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
                          padding: EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.filter_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ..._buildFilterChips(languageProvider).map((
                                filter,
                              ) {
                                return Container(
                                  margin: EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      filter['label'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getPrimaryColor(),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: _getPrimaryColor(),
                                    ),
                                    onDeleted: filter['onRemove'],
                                    backgroundColor: _getPrimaryColor()
                                        .withValues(alpha: 0.1),
                                    side: BorderSide(
                                      color: _getPrimaryColor().withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    labelPadding: EdgeInsets.only(left: 4),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
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
          ),

          Expanded(
            child: _isLoading && _classes.isEmpty
                ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                : filteredClasses.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No classes',
                      'id': 'Tidak ada kelas',
                    }),
                    subtitle:
                        _searchController.text.isEmpty && !_hasActiveFilter
                        ? languageProvider.getTranslatedText({
                            'en': 'Tap + to add a class',
                            'id': 'Tap + untuk menambah kelas',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'No search results found',
                            'id': 'Tidak ditemukan hasil pencarian',
                          }),
                    icon: Icons.school_outlined,
                  )
                : RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(top: 8, bottom: 16),
                      itemCount:
                          filteredClasses.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at bottom
                        if (index == filteredClasses.length) {
                          return Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final classItem = filteredClasses[index];
                        return ClassroomCard(
                          classData: classItem,
                          index: index,
                          gradeText: _getGradeLevelText(
                            classItem['grade_level'],
                            languageProvider,
                          ),
                          onTap: () => _showClassDetail(classItem),
                          onEdit: () =>
                              _showAddEditDialog(classData: classItem),
                          onDelete: () => _deleteClass(classItem),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final academicYearProvider = ref.watch(academicYearRiverpod);
          final languageProvider = ref.read(languageRiverpod);

          if (academicYearProvider.isReadOnly) return SizedBox.shrink();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isFabOpen) ...[
                ScaleTransition(
                  scale: _fabScaleAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Promote Class',
                            'id': 'Naik Kelas / Promosi',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      FloatingActionButton(
                        heroTag: 'fab_promote_class',
                        mini: true,
                        backgroundColor: Colors.orange,
                        onPressed: () {
                          setState(() {
                            _isFabOpen = false;
                            _fabAnimationController.reverse();
                          });
                          _showPromotionWizard();
                        },
                        child: Icon(Icons.upgrade, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                ScaleTransition(
                  scale: _fabScaleAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Create New Class',
                            'id': 'Buat Kelas Baru',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      FloatingActionButton(
                        heroTag: 'fab_add_class',
                        mini: true,
                        backgroundColor: _getPrimaryColor(),
                        onPressed: () {
                          setState(() {
                            _isFabOpen = false;
                            _fabAnimationController.reverse();
                          });
                          _showAddEditDialog();
                        },
                        child: Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
              ],
              FloatingActionButton(
                key: _fabKey,
                heroTag: 'fab_main_class',
                onPressed: () {
                  setState(() {
                    _isFabOpen = !_isFabOpen;
                    if (_isFabOpen) {
                      _fabAnimationController.forward();
                    } else {
                      _fabAnimationController.reverse();
                    }
                  });
                },
                backgroundColor: _getPrimaryColor(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: RotationTransition(
                  turns: _fabRotateAnimation,
                  child: Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPromotionWizard() {
    AppNavigator.push(context, ClassPromotionWizard());
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_management',
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
      AppLogger.error('classroom', 'Error checking tour status: $e');
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
          name: 'admin_class_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('class_management', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'admin_class_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('class_management', 'admin'),
          {'should_show': false},
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
        identify: "ClassMenu",
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
                      'en': 'Class Tools',
                      'id': 'Alat Manajemen Kelas',
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
                            'Export, import, or download class templates from here.',
                        'id':
                            'Ekspor, impor, atau unduh template data kelas dari sini.',
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
        identify: "ClassSearch",
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
                      'en': 'Find Classes',
                      'id': 'Cari Kelas',
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
                            'Quickly find classes by name using this search bar.',
                        'id':
                            'Temukan kelas dengan cepat berdasarkan nama menggunakan bilah pencarian ini.',
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
        identify: "ClassFilter",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
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
                      'en': 'Filter Options',
                      'id': 'Opsi Filter',
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
                            'Filter classes by grade level or homeroom teacher status.',
                        'id':
                            'Filter kelas berdasarkan tingkat kelas atau status wali kelas.',
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
        identify: "AddClass",
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
                      'en': 'Add New Class',
                      'id': 'Tambah Kelas Baru',
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
                            'Create a new class and assign a homeroom teacher.',
                        'id': 'Buat kelas baru dan tugaskan wali kelas.',
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
