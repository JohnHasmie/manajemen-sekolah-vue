import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/presentation/controllers/admin_classroom_controller.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/classroom_action_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/classroom_data_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/classroom_fab_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/classroom_filter_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/classroom_tour_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/mixins/classroom_ui_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_card.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_management_fab.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_management_header.dart';

/// Admin class management screen with full CRUD, search, filters, and
/// Excel import/export.
class AdminClassManagementScreen extends ConsumerStatefulWidget {
  const AdminClassManagementScreen({super.key});

  @override
  AdminClassManagementScreenState createState() =>
      AdminClassManagementScreenState();
}

/// State for [AdminClassManagementScreen].
///
/// Manages class list, pagination, filters, FAB animation, and tour.
/// Uses mixins for logical grouping of methods.
class AdminClassManagementScreenState
    extends ConsumerState<AdminClassManagementScreen>
    with
        SingleTickerProviderStateMixin,
        ClassroomDataMixin,
        ClassroomFilterMixin,
        ClassroomActionMixin,
        ClassroomFabMixin,
        ClassroomTourMixin,
        ClassroomUiMixin {
  // State: classes and teachers
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // FAB animation
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;
  late Animation<double> _fabScaleAnimation;
  bool _isFabOpen = false;

  // Controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Pagination
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  // Filters
  String? _selectedGradeFilter;
  String? _selectedHomeroomFilter;
  bool _hasActiveFilter = false;
  final List<String> _availableGradeLevels = [];
  // Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  // Mixin property bridge
  @override
  List<dynamic> get classes => _classes;
  @override
  set classes(List<dynamic> v) => _classes = v;
  @override
  List<dynamic> get teachers => _teachers;
  @override
  set teachers(List<dynamic> v) => _teachers = v;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool v) => _isLoading = v;
  @override
  String? get errorMessage => _errorMessage;
  @override
  set errorMessage(String? v) => _errorMessage = v;
  @override
  int get currentPage => _currentPage;
  @override
  set currentPage(int v) => _currentPage = v;
  @override
  int get perPage => _perPage;
  @override
  bool get hasMoreData => _hasMoreData;
  @override
  set hasMoreData(bool v) => _hasMoreData = v;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  set isLoadingMore(bool v) => _isLoadingMore = v;
  @override
  ScrollController get scrollController => _scrollController;
  @override
  TextEditingController get searchController => _searchController;
  @override
  String? get selectedGradeFilter => _selectedGradeFilter;
  @override
  set selectedGradeFilter(String? v) => _selectedGradeFilter = v;
  @override
  String? get selectedHomeroomFilter => _selectedHomeroomFilter;
  @override
  set selectedHomeroomFilter(String? v) => _selectedHomeroomFilter = v;
  @override
  bool get hasActiveFilter => _hasActiveFilter;
  @override
  set hasActiveFilter(bool v) => _hasActiveFilter = v;
  @override
  List<String> get availableGradeLevels => _availableGradeLevels;
  @override
  bool get isFabOpen => _isFabOpen;
  @override
  set isFabOpen(bool v) => _isFabOpen = v;
  @override
  AnimationController get fabAnimationController => _fabAnimationController;
  @override
  Animation<double> get fabRotateAnimation => _fabRotateAnimation;
  @override
  Animation<double> get fabScaleAnimation => _fabScaleAnimation;
  @override
  GlobalKey get menuKey => _menuKey;
  @override
  GlobalKey get searchKey => _searchKey;
  @override
  GlobalKey get filterKey => _filterKey;
  @override
  GlobalKey get fabKey => _fabKey;

  // ========== Lifecycle ==========
  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fabRotateAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
    FCMService().syncTrigger.addListener(_handleSyncTrigger);
    _initialize();
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_handleSyncTrigger);
    _fabAnimationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initialize() async {
    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadSchoolSettings();
    if (mounted) {
      setState(() {
        _availableGradeLevels
          ..clear()
          ..addAll(result.gradeLevels);
      });
    }
    await fetchTeachers();
    await loadData();
  }

  void _handleSyncTrigger() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_classes' ||
            trigger['type'] == 'refresh_teachers')) {
      AppLogger.debug(
        'classroom',
        'Real-time sync triggered (${trigger['type']}): Reloading',
      );
      loadData(resetPage: true, useCache: false);
    }
  }

  // ========== Mixin Implementations ==========
  @override
  void onDataLoaded() {
    checkAndShowTour();
  }

  @override
  void onFiltersCleared() {
    loadData();
  }

  @override
  void onGradeFilterRemoved() {
    loadData();
  }

  @override
  void onHomeroomFilterRemoved() {
    loadData();
  }

  @override
  void onFilterApplied() {
    loadData();
  }

  @override
  void onClassSaved() {
    loadData();
  }

  @override
  void onClassDeleted() {
    loadData();
  }

  @override
  void onCreateNewClass() {
    showAddEditDialog();
  }

  @override
  void onPromoteClass() {
    showPromotionWizard();
  }

  @override
  void onMenuSelected(String value) {
    switch (value) {
      case 'refresh':
        forceRefresh();
      case 'export':
        exportToExcel();
      case 'import':
        importFromExcel();
      case 'template':
        downloadTemplate();
    }
  }

  @override
  void onSearchSubmitted() {
    setState(() => _currentPage = 1);
    loadData();
  }

  @override
  Color getPrimaryColor() {
    return ref.read(adminClassroomControllerProvider).getPrimaryColor();
  }

  // ========== Build ==========
  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    if (errorMessage != null) {
      return ErrorScreen(errorMessage: errorMessage!, onRetry: loadData);
    }
    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          ClassroomManagementHeader(
            languageProvider: languageProvider,
            menuKey: menuKey,
            searchKey: searchKey,
            filterKey: filterKey,
            hasActiveFilter: hasActiveFilter,
            availableGradeLevels: availableGradeLevels,
            searchController: searchController,
            selectedGradeFilter: selectedGradeFilter,
            selectedHomeroomFilter: selectedHomeroomFilter,
            buildMenuItems: buildMenuItems,
            buildFilterButton: buildFilterButton,
            buildFilterChipsBar: buildFilterChipsBar,
            onMenuSelected: onMenuSelected,
            onSearchSubmitted: onSearchSubmitted,
            onFilterPressed: showFilterSheet,
            onClearAllFilters: clearAllFilters,
            onBackPressed: () => AppNavigator.pop(context),
            primaryColor: getPrimaryColor(),
            onFilterChipsBuilt: buildFilterChips,
          ),
          Expanded(child: _buildListContent(languageProvider)),
        ],
      ),
      floatingActionButton: ClassroomManagementFab(
        isFabOpen: isFabOpen,
        fabAnimationController: fabAnimationController,
        fabRotateAnimation: fabRotateAnimation,
        fabScaleAnimation: fabScaleAnimation,
        fabKey: fabKey,
        primaryColor: getPrimaryColor(),
        languageProvider: languageProvider,
        isReadOnly: ref.watch(academicYearRiverpod).isReadOnly,
        onToggleFab: toggleFabMenu,
        onAddClass: onAddClassPressed,
        onPromoteClass: onPromoteClassPressed,
      ),
    );
  }

  Widget _buildListContent(LanguageProvider languageProvider) {
    return PaginatedListView<dynamic>(
      items: _classes,
      controller: _scrollController,
      isInitialLoading: isLoading && _classes.isEmpty,
      loadingState: const SkeletonListLoading(itemCount: 6, infoTagCount: 1),
      emptyState: EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No classes',
          'id': 'Tidak ada kelas',
        }),
        subtitle: _searchController.text.isEmpty && !hasActiveFilter
            ? languageProvider.getTranslatedText({
                'en': 'Tap + to add a class',
                'id': 'Tap + untuk menambah kelas',
              })
            : languageProvider.getTranslatedText({
                'en': 'No search results found',
                'id': 'Tidak ditemukan hasil pencarian',
              }),
        icon: Icons.school_outlined,
      ),
      onLoadMore: loadMoreData,
      hasMore: hasMoreData,
      isLoadingMore: isLoadingMore,
      onRefresh: onRefresh,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemBuilder: (context, classItem, index) => ClassroomCard(
        classData: classItem,
        index: index,
        gradeText: getGradeLevelText(classItem['grade_level'], languageProvider),
        onTap: () => showClassDetail(classItem),
        onEdit: () => showAddEditDialog(classData: classItem),
        onDelete: () => deleteClass(classItem),
      ),
    );
  }
}
