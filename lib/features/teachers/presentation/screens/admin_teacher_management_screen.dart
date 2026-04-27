// Admin teacher management screen — full CRUD for teachers.
//
// Refactored from the 5-mixin (DataLoading + Crud + Filter + Tour + Ui)
// implementation into a single flat [ConsumerState] that delegates all
// data/Excel/CRUD work to [AdminTeacherController]. The per-feature
// gradient header (`TeacherScreenHeader`) and list wrapper
// (`TeacherListContent`) are retired in favor of the shared
// [AdminCrudScaffold] + [AdminDataMenu] + [PaginatedListView] stack.
//
// What lives here: UI flags (loading / error / filters / pagination
// cursor) + dispatch glue that hands state down to the controller.
// Everything else has moved out.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/teachers/presentation/controllers/admin_teacher_controller.dart';
import 'package:manajemensekolah/features/teachers/presentation/controllers/helpers/teacher_filter_helper.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_filter_sheet.dart';

/// Admin-facing teacher management screen.
class TeacherAdminScreen extends ConsumerStatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  TeacherAdminScreenState createState() => TeacherAdminScreenState();
}

/// Mutable state for [TeacherAdminScreen].
///
/// Holds the pagination cursor, filter selections, and loaded-data cache
/// that feed [AdminCrudScaffold]. All network + cache + Excel work is
/// delegated to [AdminTeacherController].
class TeacherAdminScreenState extends ConsumerState<TeacherAdminScreen> {
  // Search text — shared with [AdminCrudScaffold] via [searchController].
  final TextEditingController _searchController = TextEditingController();

  // Loaded data.
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Filter selections.
  String? _selectedClassId;
  String? _selectedHomeroomFilter;
  String? _selectedGender;
  String? _selectedEmploymentStatus;
  String? _selectedTeachingClassId;
  bool _showAllTeachers = false;
  bool _hasActiveFilter = false;

  // Filter-option lists (populated once from /filter-options).
  List<dynamic> _availableClass = [];
  List<dynamic> _availableGenders = [];
  List<dynamic> _availableEmploymentStatus = [];

  // FAB GlobalKey reserved for potential reintroduction of tour plumbing.
  final GlobalKey _fabKey = GlobalKey();

  late final _academicYearProvider = ref.read(academicYearRiverpod);

  @override
  void initState() {
    super.initState();
    _academicYearProvider.addListener(_onAcademicYearChanged);
    FCMService().syncTrigger.addListener(_onSyncTriggered);
    _loadFilterOptions();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _academicYearProvider.removeListener(_onAcademicYearChanged);
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> _loadFilterOptions() async {
    final options = await ref
        .read(adminTeacherControllerProvider)
        .loadFilterOptions();
    if (!mounted || options == null) return;
    setState(() {
      _availableClass = options.availableClass;
      _availableGenders = options.availableGenders;
      _availableEmploymentStatus = options.availableEmploymentStatus;
    });
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_teachers.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final result = await ref
        .read(adminTeacherControllerProvider)
        .loadData(
          useCache: useCache,
          currentPage: _currentPage,
          perPage: _perPage,
          selectedClassId: _selectedClassId,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          selectedGender: _selectedGender,
          selectedEmploymentStatus: _selectedEmploymentStatus,
          selectedTeachingClassId: _selectedTeachingClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );

    if (!mounted) return;

    if (result.errorMessage != null && _teachers.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }

    setState(() {
      _teachers = result.teachers;
      _subjects = result.subjects;
      _classes = result.classes;
      _hasMoreData = result.hasMoreData;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result = await ref
        .read(adminTeacherControllerProvider)
        .loadMoreData(
          nextPage: _currentPage + 1,
          perPage: _perPage,
          selectedClassId: _selectedClassId,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          selectedGender: _selectedGender,
          selectedEmploymentStatus: _selectedEmploymentStatus,
          selectedTeachingClassId: _selectedTeachingClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    _currentPage++;
    setState(() {
      _teachers = [..._teachers, ...result.additionalTeachers];
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
    });
    AppLogger.info(
      'teacher',
      'Loaded more data: Page $_currentPage, Total items: ${_teachers.length}',
    );
  }

  Future<void> _onRefresh() => _loadData(resetPage: true, useCache: false);

  Future<void> _forceRefresh() async {
    await ref
        .read(adminTeacherControllerProvider)
        .forceRefreshCaches(
          currentPage: _currentPage,
          selectedClassId: _selectedClassId,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          selectedGender: _selectedGender,
          selectedEmploymentStatus: _selectedEmploymentStatus,
          selectedTeachingClassId: _selectedTeachingClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );
    await _loadFilterOptions();
    await _loadData(resetPage: true, useCache: false);
  }

  void _onAcademicYearChanged() {
    if (!mounted) return;
    _loadFilterOptions();
    _loadData();
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger == null || !mounted) return;
    if (trigger['type'] == 'refresh_teachers' ||
        trigger['type'] == 'refresh_schedules') {
      AppLogger.debug('teacher', 'Sync triggered: ${trigger['type']}');
      _loadData(useCache: false);
    }
  }

  // ── Filter state ────────────────────────────────────────────────────

  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = TeacherFilterHelper.checkActiveFilter(
        selectedHomeroomFilter: _selectedHomeroomFilter,
        selectedGender: _selectedGender,
        selectedEmploymentStatus: _selectedEmploymentStatus,
        selectedTeachingClassId: _selectedTeachingClassId,
        searchText: _searchController.text,
      );
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherFilterSheet(
        initialHomeroom: _selectedHomeroomFilter,
        initialGender: _selectedGender,
        initialEmploymentStatus: _selectedEmploymentStatus,
        initialTeachingClass: _selectedTeachingClassId,
        initialShowAll: _showAllTeachers,
        availableGenders: _availableGenders,
        availableEmploymentStatus: _availableEmploymentStatus,
        availableClass: _availableClass,
        languageProvider: ref.read(languageRiverpod),
        onApply: (homeroom, gender, employment, teachingClass, showAll) {
          setState(() {
            _selectedHomeroomFilter = homeroom;
            _selectedGender = gender;
            _selectedEmploymentStatus = employment;
            _selectedTeachingClassId = teachingClass;
            _showAllTeachers = showAll;
          });
          _refreshHasActiveFilter();
          _loadData();
        },
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedClassId = null;
      _selectedHomeroomFilter = null;
      _selectedGender = null;
      _selectedEmploymentStatus = null;
      _selectedTeachingClassId = null;
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData();
  }

  // Per-chip removal callbacks — each chip carries its own targeted
  // callback so the × on one chip only removes that filter.
  void _removeHomeroomFilter() {
    setState(() => _selectedHomeroomFilter = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeGenderFilter() {
    setState(() => _selectedGender = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeEmploymentFilter() {
    setState(() => _selectedEmploymentStatus = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeTeachingClassFilter() {
    setState(() => _selectedTeachingClassId = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _openTeacherDetail(Map<String, dynamic> teacher) {
    ref.read(adminTeacherControllerProvider).navigateToDetail(context, teacher);
  }

  void _openAddEditSheet({Map<String, dynamic>? teacher}) {
    ref
        .read(adminTeacherControllerProvider)
        .openTeacherFormDialog(
          context: context,
          subjects: _subjects,
          classes: _classes,
          teacher: teacher,
          onSaved: _loadData,
        );
  }

  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final deleted = await ref
        .read(adminTeacherControllerProvider)
        .deleteTeacher(teacher, context);
    if (!deleted || !mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Teacher successfully deleted',
        'id': 'Guru berhasil dihapus',
      }),
    );
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() {
    return ref
        .read(adminTeacherControllerProvider)
        .exportToExcel(
          context: context,
          selectedClassId: _selectedClassId,
          showAllTeachers: _showAllTeachers,
          searchText: _searchController.text,
        );
  }

  Future<void> _importFromExcel() async {
    final imported = await ref
        .read(adminTeacherControllerProvider)
        .importFromExcel(context);
    if (!imported || !mounted) return;
    await _loadData();
  }

  Future<void> _downloadTemplate() {
    return ref.read(adminTeacherControllerProvider).downloadTemplate(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    final activeFilters = TeacherFilterHelper.buildFilterChips(
      selectedHomeroomFilter: _selectedHomeroomFilter,
      selectedGender: _selectedGender,
      selectedEmploymentStatus: _selectedEmploymentStatus,
      selectedTeachingClassId: _selectedTeachingClassId,
      availableClass: _availableClass,
      availableEmploymentStatus: _availableEmploymentStatus,
      languageProvider: lang,
      onClearHomeroom: _removeHomeroomFilter,
      onClearGender: _removeGenderFilter,
      onClearEmploymentStatus: _removeEmploymentFilter,
      onClearTeachingClass: _removeTeachingClassFilter,
    );

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {
        'en': 'Teacher Management',
        'id': 'Manajemen Guru',
      }),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage and monitor teachers',
        'id': 'Kelola dan pantau guru',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search teachers...',
        'id': 'Cari guru...',
      }),
      onSearchChanged: (_) => _refreshHasActiveFilter(),
      onSearchSubmitted: (_) => _loadData(),
      onFilterTap: _openFilterSheet,
      hasActiveFilter: _hasActiveFilter,
      activeFilters: activeFilters,
      onClearAllFilters: _clearAllFilters,
      actionMenu: AdminDataMenu(
        languageProvider: lang,
        onRefresh: _forceRefresh,
        onExport: _exportToExcel,
        onImport: _importFromExcel,
        onDownloadTemplate: _downloadTemplate,
      ),
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      isEmpty: _teachers.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No teachers',
        'id': 'Tidak ada guru',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a teacher',
              'id': 'Tap + untuk menambah guru',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.person_outline,
      childBuilder: () => PaginatedListView<Map<String, dynamic>>(
        items: _teachers.cast<Map<String, dynamic>>(),
        itemBuilder: (context, teacher, index) {
          return TeacherCard(
            teacher: teacher,
            index: index,
            onTap: () => _openTeacherDetail(teacher),
            onEdit: () => _openAddEditSheet(teacher: teacher),
            onDelete: () => _deleteTeacher(teacher),
          );
        },
        onLoadMore: _loadMoreData,
        hasMore: _hasMoreData,
        isLoadingMore: _isLoadingMore,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
      ),
      onFabTap: academicYear.isReadOnly ? null : _openAddEditSheet,
      fabKey: _fabKey,
      hideFab: academicYear.isReadOnly,
    );
  }
}
