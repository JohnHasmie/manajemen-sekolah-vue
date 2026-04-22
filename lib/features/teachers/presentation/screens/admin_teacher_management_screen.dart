import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_data_loading_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_crud_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_filter_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_tour_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_ui_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_screen_header.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_list_content.dart';

class TeacherAdminScreen extends ConsumerStatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  TeacherAdminScreenState createState() => TeacherAdminScreenState();
}

class TeacherAdminScreenState extends ConsumerState<TeacherAdminScreen>
    with
        TeacherDataLoadingMixin,
        TeacherCrudMixin,
        TeacherFilterMixin,
        TeacherTourMixin,
        TeacherUiMixin {
  final ApiTeacherService _teacherService = getIt<ApiTeacherService>();

  // Core data state
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Pagination state
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter state
  String? _selectedClassId;
  String? _selectedHomeroomFilter;
  String? _selectedGender;
  String? _selectedEmploymentStatus;
  String? _selectedTeachingClassId;
  bool _hasActiveFilter = false;
  bool _showAllTeachers = false;

  // Filter options state
  List<dynamic> _availableClass = [];
  List<dynamic> _availableGenders = [];
  List<dynamic> _availableEmploymentStatus = [];

  // Tour targets
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // ─── Mixin getters/setters bridge (Abstract getters for mixins) ───
  @override
  List<dynamic> get teachers => _teachers;
  @override
  set teachers(List<dynamic> v) => _teachers = v;

  @override
  List<dynamic> get subjects => _subjects;
  @override
  set subjects(List<dynamic> v) => _subjects = v;

  @override
  List<dynamic> get classes => _classes;
  @override
  set classes(List<dynamic> v) => _classes = v;

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
  String? get selectedClassId => _selectedClassId;
  @override
  set selectedClassId(String? v) => _selectedClassId = v;

  @override
  String? get selectedHomeroomFilter => _selectedHomeroomFilter;
  @override
  set selectedHomeroomFilter(String? v) => _selectedHomeroomFilter = v;

  @override
  String? get selectedGender => _selectedGender;
  @override
  set selectedGender(String? v) => _selectedGender = v;

  @override
  String? get selectedEmploymentStatus => _selectedEmploymentStatus;
  @override
  set selectedEmploymentStatus(String? v) => _selectedEmploymentStatus = v;

  @override
  String? get selectedTeachingClassId => _selectedTeachingClassId;
  @override
  set selectedTeachingClassId(String? v) => _selectedTeachingClassId = v;

  @override
  bool get hasActiveFilter => _hasActiveFilter;
  @override
  set hasActiveFilter(bool v) => _hasActiveFilter = v;

  @override
  bool get showAllTeachers => _showAllTeachers;
  @override
  set showAllTeachers(bool v) => _showAllTeachers = v;

  @override
  String get searchText => _searchController.text;

  @override
  List<dynamic> get availableClass => _availableClass;
  @override
  set availableClass(List<dynamic> v) => _availableClass = v;

  @override
  List<dynamic> get availableGenders => _availableGenders;
  @override
  set availableGenders(List<dynamic> v) => _availableGenders = v;

  @override
  List<dynamic> get availableEmploymentStatus => _availableEmploymentStatus;
  @override
  set availableEmploymentStatus(List<dynamic> v) =>
      _availableEmploymentStatus = v;

  @override
  GlobalKey get menuKey => _menuKey;
  @override
  GlobalKey get searchKey => _searchKey;
  @override
  GlobalKey get filterKey => _filterKey;
  @override
  GlobalKey get fabKey => _fabKey;

  @override
  void initState() {
    super.initState();
    _initializeListeners();
    _initializeData();
  }

  void _initializeListeners() {
    final academicYearProvider = ref.read(academicYearRiverpod);
    academicYearProvider.addListener(_onAcademicYearChanged);
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  void _initializeData() {
    loadFilterOptions();
    loadData();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_teachers' ||
            trigger['type'] == 'refresh_schedules')) {
      if (mounted) {
        AppLogger.debug('teacher', 'Sync triggered: ${trigger['type']}');
        loadData(useCache: false);
      }
    }
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onAcademicYearChanged() {
    if (mounted) {
      loadFilterOptions();
      loadData();
    }
  }

  void _handleSearchSubmit() {
    setState(() {
      _currentPage = 1;
    });
    loadData();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (_errorMessage != null) {
      return ErrorScreen(errorMessage: _errorMessage!, onRetry: loadData);
    }

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          TeacherScreenHeader(
            menuKey: _menuKey,
            searchKey: _searchKey,
            filterKey: _filterKey,
            searchController: _searchController,
            hasActiveFilter: hasActiveFilter,
            primaryColor: _getPrimaryColor(),
            onMenuRefresh: forceRefresh,
            onMenuExport: exportToExcel,
            onMenuImport: importFromExcel,
            onMenuTemplate: downloadTemplate,
            onFilterTap: showFilterSheet,
            onSearchSubmit: _handleSearchSubmit,
            onClearAllFilters: clearAllFilters,
            filterChips: buildFilterChipWidgets(),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TeacherListContent(
              isLoading: _isLoading,
              teachers: _teachers,
              isLoadingMore: _isLoadingMore,
              hasSearch: _searchController.text.isNotEmpty,
              hasFilter: hasActiveFilter,
              scrollController: _scrollController,
              languageProvider: languageProvider,
              onRefresh: refreshData,
              onLoadMore: loadMoreData,
              hasMoreData: _hasMoreData,
              onTapDetail: navigateToDetail,
              onEdit: (teacher) => openTeacherFormDialog(teacher: teacher),
              onDelete: deleteTeacher,
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (ref.read(academicYearRiverpod).isReadOnly) {
      return null;
    }
    return FloatingActionButton(
      key: _fabKey,
      onPressed: openTeacherFormDialog,
      backgroundColor: _getPrimaryColor(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 20),
    );
  }

  @override
  Future<void> checkAndShowTour() async {
    try {
      await super.checkAndShowTour();
    } catch (e) {
      AppLogger.error('teacher', 'Error in tour check: $e');
    }
  }
}
