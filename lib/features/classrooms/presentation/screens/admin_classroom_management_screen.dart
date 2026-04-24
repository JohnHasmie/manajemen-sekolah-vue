// Admin class management screen — full CRUD for classes.
//
// Refactored from the 6-mixin (Data + Action + Filter + Fab + Tour + Ui)
// implementation into a single flat [ConsumerState] that delegates all
// data/Excel/CRUD work to [AdminClassroomController]. The per-feature
// gradient header (`ClassroomManagementHeader`) is retired in favor of
// the shared [AdminCrudScaffold] + [AdminDataMenu] + [PaginatedListView]
// stack. The speed-dial FAB (+ add / promote-class) keeps its own domain
// widget — [ClassroomManagementFab] — and plugs into the scaffold via
// the shared `customFab` hook.
//
// What lives here: UI flags (loading / error / filters / pagination
// cursor), the teacher + grade-level lookup lists, and dispatch glue
// that hands state down to the controller + sheets. Everything else
// has moved out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/classrooms/presentation/controllers/admin_classroom_controller.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/class_promotion_wizard.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_detail_dialog.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_add_edit_sheet.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_card.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_filter_sheet.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_management_fab.dart';

/// Admin-facing class management screen.
class AdminClassManagementScreen extends ConsumerStatefulWidget {
  const AdminClassManagementScreen({super.key});

  @override
  AdminClassManagementScreenState createState() =>
      AdminClassManagementScreenState();
}

/// Mutable state for [AdminClassManagementScreen].
///
/// Holds the pagination cursor, filter selections, and loaded-data cache
/// that feed [AdminCrudScaffold]. All network + cache + Excel work is
/// delegated to [AdminClassroomController].
class AdminClassManagementScreenState
    extends ConsumerState<AdminClassManagementScreen> {
  // Search text — shared with [AdminCrudScaffold] via [searchController].
  final TextEditingController _searchController = TextEditingController();

  // Loaded data.
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Filter selections.
  String? _selectedGradeFilter;
  String? _selectedHomeroomFilter;
  bool _hasActiveFilter = false;

  // Grade-level options populated once from /school-settings.
  final List<String> _availableGradeLevels = [];

  // FAB GlobalKey reserved for potential reintroduction of tour plumbing.
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    FCMService().syncTrigger.addListener(_onSyncTriggered);
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    super.dispose();
  }

  // ── Initialization ──────────────────────────────────────────────────

  Future<void> _initialize() async {
    await _loadSchoolSettings();
    await _fetchTeachers();
    await _loadData();
  }

  Future<void> _loadSchoolSettings() async {
    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadSchoolSettings();
    if (!mounted) return;
    setState(() {
      _availableGradeLevels
        ..clear()
        ..addAll(result.gradeLevels);
    });
  }

  Future<void> _fetchTeachers() async {
    final teacherList = await ref
        .read(adminClassroomControllerProvider)
        .fetchTeachers();
    if (!mounted) return;
    setState(() => _teachers = teacherList);
  }

  // ── Data loading ────────────────────────────────────────────────────

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_classes.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadData(
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
      _errorMessage = result.errorMessage;
    });

    if (result.errorMessage != null && _classes.isNotEmpty) {
      final errorPrefix = ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Failed to load classes',
        'id': 'Gagal memuat data kelas',
      });
      SnackBarUtils.showError(context, '$errorPrefix: ${result.errorMessage}');
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result = await ref
        .read(adminClassroomControllerProvider)
        .loadMoreData(
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

  Future<void> _onRefresh() => _loadData(resetPage: true, useCache: false);

  Future<void> _forceRefresh() async {
    final result = await ref
        .read(adminClassroomControllerProvider)
        .forceRefresh(
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
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger == null || !mounted) return;
    if (trigger['type'] == 'refresh_classes' ||
        trigger['type'] == 'refresh_teachers') {
      AppLogger.debug(
        'classroom',
        'Real-time sync triggered (${trigger['type']}): Reloading',
      );
      _loadData(resetPage: true, useCache: false);
    }
  }

  // ── Filter state ────────────────────────────────────────────────────

  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminClassroomControllerProvider)
          .checkActiveFilter(
            selectedGradeFilter: _selectedGradeFilter,
            selectedHomeroomFilter: _selectedHomeroomFilter,
          );
    });
  }

  void _openFilterSheet() {
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
          _refreshHasActiveFilter();
          _loadData();
        },
      ),
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    final reset = ref.read(adminClassroomControllerProvider).clearAllFilters();
    setState(() {
      _selectedGradeFilter = reset.gradeFilter;
      _selectedHomeroomFilter = reset.homeroomFilter;
      _hasActiveFilter = reset.hasActiveFilter;
      _currentPage = 1;
    });
    _loadData();
  }

  // Per-chip removal callbacks — each chip carries its own targeted
  // callback so the × on one chip only removes that filter.
  void _removeGradeFilter() {
    setState(() => _selectedGradeFilter = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeHomeroomFilter() {
    setState(() => _selectedHomeroomFilter = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  // ── Row-level actions ───────────────────────────────────────────────

  Future<void> _openAddEditSheet({Map<String, dynamic>? classData}) async {
    // Refresh the teacher list on every open so a newly-created teacher
    // shows up in the homeroom dropdown without needing a pull-to-refresh.
    await _fetchTeachers();

    Map<String, dynamic>? resolvedClassData = classData;
    if (resolvedClassData != null) {
      resolvedClassData = await _getFreshClassData(resolvedClassData);
      if (resolvedClassData != null) {
        await _ensureHomeroomTeacherInList(resolvedClassData);
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClassroomAddEditSheet(
        classData: resolvedClassData,
        teachers: _teachers,
        availableGradeLevels: _availableGradeLevels,
        onSaved: _loadData,
      ),
    );
  }

  Future<Map<String, dynamic>?> _getFreshClassData(
    Map<String, dynamic> classData,
  ) async {
    try {
      final freshData = await getIt<ApiClassService>().getClassById(
        classData['id'].toString(),
      );
      if (freshData != null && freshData is Map<String, dynamic>) {
        return freshData;
      }
    } catch (e) {
      AppLogger.error('classroom', 'Error fetching fresh class data: $e');
    }
    return classData;
  }

  Future<void> _ensureHomeroomTeacherInList(
    Map<String, dynamic> classData,
  ) async {
    // Classroom model's _standardizeJson already unpacks homeroom_teacher
    // whether it arrives as List (pivot), Map (legacy), or flat fields.
    final model = Classroom.fromJson(classData);
    final homeroomId = model.homeroomTeacherId;
    final homeroomName = model.homeroomTeacherName;

    if (homeroomId != null &&
        homeroomId.isNotEmpty &&
        homeroomName != null &&
        homeroomName.isNotEmpty) {
      final exists = _teachers.any((t) => t['id'].toString() == homeroomId);
      if (!exists && mounted) {
        setState(() {
          _teachers.add({'id': homeroomId, 'name': homeroomName});
          _teachers.sort(
            (a, b) => (a['name'] ?? '').toString().compareTo(b['name'] ?? ''),
          );
        });
      }
    }
  }

  Future<void> _deleteClass(Map<String, dynamic> classData) async {
    final deleted = await ref
        .read(adminClassroomControllerProvider)
        .deleteClass(classData, context);
    if (!deleted || !mounted) return;
    await _loadData();
  }

  void _openClassDetail(Map<String, dynamic> classData) {
    final languageProvider = ref.read(languageRiverpod);
    final gradeText = ref
        .read(adminClassroomControllerProvider)
        .getGradeLevelText(classData['grade_level'], languageProvider);

    ClassDetailDialog.show(
      context: context,
      classData: classData,
      gradeText: gradeText,
      primaryColor: ColorUtils.getRoleColor('admin'),
      isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
      onEdit: () => _openAddEditSheet(classData: classData),
      languageProvider: languageProvider,
    );
  }

  void _openPromotionWizard() {
    AppNavigator.push(context, const ClassPromotionWizard());
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() {
    return ref
        .read(adminClassroomControllerProvider)
        .exportToExcel(classes: _classes, context: context);
  }

  Future<void> _importFromExcel() async {
    final imported = await ref
        .read(adminClassroomControllerProvider)
        .importFromExcel(context);
    if (!imported || !mounted) return;
    await _loadData();
  }

  Future<void> _downloadTemplate() {
    return ref.read(adminClassroomControllerProvider).downloadTemplate(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    final activeFilters = ref
        .read(adminClassroomControllerProvider)
        .buildActiveFilterChips(
          selectedGradeFilter: _selectedGradeFilter,
          selectedHomeroomFilter: _selectedHomeroomFilter,
          languageProvider: lang,
          onClearGrade: _removeGradeFilter,
          onClearHomeroom: _removeHomeroomFilter,
        );

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {
        'en': 'Class Management',
        'id': 'Manajemen Kelas',
      }),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage and monitor classes',
        'id': 'Kelola dan pantau kelas',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search classes...',
        'id': 'Cari kelas...',
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
      isEmpty: _classes.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No classes',
        'id': 'Tidak ada kelas',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a class',
              'id': 'Tap + untuk menambah kelas',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.school_outlined,
      childBuilder: () => PaginatedListView<dynamic>(
        items: _classes,
        itemBuilder: (context, classItem, index) => ClassroomCard(
          classData: classItem,
          index: index,
          gradeText: ref
              .read(adminClassroomControllerProvider)
              .getGradeLevelText(classItem['grade_level'], lang),
          onTap: () => _openClassDetail(classItem),
          onEdit: () => _openAddEditSheet(classData: classItem),
          onDelete: () => _deleteClass(classItem),
        ),
        onLoadMore: _loadMoreData,
        hasMore: _hasMoreData,
        isLoadingMore: _isLoadingMore,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
      ),
      customFab: ClassroomManagementFab(
        primaryColor: primaryColor,
        languageProvider: lang,
        isReadOnly: academicYear.isReadOnly,
        onAddClass: _openAddEditSheet,
        onPromoteClass: _openPromotionWizard,
        triggerKey: _fabKey,
      ),
      hideFab: academicYear.isReadOnly,
    );
  }
}
