// Admin student management screen - full CRUD for students.
//
// Wraps [AdminCrudScaffold] with a Siswa-specific data layer:
//   • header       → AdminCrudScaffold (SchoolPill + AdminDataMenu trailing)
//   • body         → paginated student list
//   • add/edit     → AppEditBottomSheet via showStudentAddEditDialog()
//   • filter       → AppFilterBottomSheet via showStudentFilterSheet()
//   • bulk actions → none yet (Phase 2 scope if ever needed for Siswa)
//
// Refactored from 354 lines + 5 mixins (data_loading / filter_helper /
// excel_operations / student_actions / tour_helper) into a single
// flattened ConsumerState that delegates all data work to
// [AdminStudentController]. The per-feature gradient header and tour
// plumbing are retired — every admin CRUD screen now shares the same
// shell.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_crud_scaffold.dart';
import 'package:manajemensekolah/core/widgets/admin_data_menu.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/student_detail_screen.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_add_edit_dialog.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_card.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet.dart';

/// Admin student management screen with full CRUD, search, filters, and
/// Excel import/export.
///
/// Optionally accepts [initialClassId] to pre-filter by class (e.g., when
/// navigating from a class detail screen).
class StudentManagementScreen extends ConsumerStatefulWidget {
  final String? initialClassId;

  const StudentManagementScreen({super.key, this.initialClassId});

  @override
  StudentManagementScreenState createState() => StudentManagementScreenState();
}

/// Mutable state for [StudentManagementScreen].
///
/// Everything lives here now — no more mixin-based state smuggling. The
/// controller ([AdminStudentController]) owns data fetching, cache
/// invalidation, Excel flows, and deletion; this State owns only the UI
/// flags (loading / error / filters / pagination cursor) and the
/// dispatch glue.
class StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen> {
  // Search field controller — reused across rebuilds and disposed in
  // [dispose]. The AdminCrudScaffold wires it into its header.
  final TextEditingController _searchController = TextEditingController();

  // Data loaded from the API.
  List<dynamic> _students = [];
  List<dynamic> _classList = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Infinite-scroll pagination cursor.
  int _currentPage = 1;
  static const int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  // Active filters. `_hasActiveFilter` is the denormalized OR of these +
  // the search text — kept as a field so the filter-icon badge rebuilds
  // without re-traversing the state each frame.
  String? _selectedStatusFilter;
  List<String> _selectedClassIds = [];
  String? _selectedGenderFilter;
  String? _selectedGuardian;
  bool _hasActiveFilter = false;

  // FAB key kept for potential reintroduction of onboarding tour later;
  // the per-header menu/search/filter keys are intentionally retired.
  final GlobalKey _fabKey = GlobalKey();

  // Cache the provider reference so dispose() doesn't call ref after unmount.
  late final _academicYearProvider = ref.read(academicYearRiverpod);

  @override
  void initState() {
    super.initState();

    // Reload data whenever the active academic year changes in the header.
    _academicYearProvider.addListener(_onAcademicYearChanged);

    // If we arrived from a class detail screen, pre-apply that class id as
    // the only filter.
    if (widget.initialClassId != null) {
      _selectedClassIds = [widget.initialClassId!];
      _hasActiveFilter = true;
    }

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _academicYearProvider.removeListener(_onAcademicYearChanged);
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────

  /// Loads the first page of students and the class list for filters.
  /// Any user-driven reload (search submit, filter apply, pull-to-refresh)
  /// calls this with `resetPage: true`.
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    final controller = ref.read(adminStudentControllerProvider);

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      if (_students.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }

    final result = await controller.loadData(
      resetPage: resetPage,
      useCache: useCache,
      currentPage: _currentPage,
      perPage: _perPage,
      selectedClassIds: _selectedClassIds,
      selectedGradeLevel: null,
      selectedGenderFilter: _selectedGenderFilter,
      selectedGuardian: _selectedGuardian,
      selectedStatusFilter: _selectedStatusFilter,
      searchText: _searchController.text,
    );

    if (!mounted) return;

    if (result.errorMessage != null && _students.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = result.errorMessage;
      });
      return;
    }

    setState(() {
      _students = result.students;
      _classList = result.classList;
      _hasMoreData = result.hasMoreData;
      _isLoading = false;
      _errorMessage = null;
    });
  }

  /// Appends the next page of students. Called by [PaginatedListView]'s
  /// scroll-near-bottom callback.
  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result = await ref
        .read(adminStudentControllerProvider)
        .loadMoreData(
          nextPage: _currentPage + 1,
          perPage: _perPage,
          selectedClassIds: _selectedClassIds,
          selectedGradeLevel: null,
          selectedGenderFilter: _selectedGenderFilter,
          selectedGuardian: _selectedGuardian,
          selectedStatusFilter: _selectedStatusFilter,
          searchText: _searchController.text,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() => _isLoadingMore = false);
      return;
    }

    _currentPage++;
    setState(() {
      _students = [..._students, ...result.additionalStudents];
      _hasMoreData = result.hasMoreData;
      _isLoadingMore = false;
    });
  }

  /// Pull-to-refresh handler. Skips the cache so users see fresh data.
  Future<void> _onRefresh() => _loadData(resetPage: true, useCache: false);

  /// Force-refresh handler for the "Refresh Data" overflow menu item —
  /// also evicts the server-side cache.
  Future<void> _forceRefresh() async {
    await ref
        .read(adminStudentControllerProvider)
        .forceRefreshCaches(
          currentPage: _currentPage,
          selectedClassIds: _selectedClassIds,
          selectedGradeLevel: null,
          selectedGenderFilter: _selectedGenderFilter,
          selectedGuardian: _selectedGuardian,
          selectedStatusFilter: _selectedStatusFilter,
          searchText: _searchController.text,
        );
    await _loadData(resetPage: true, useCache: false);
  }

  void _onAcademicYearChanged() {
    if (mounted) _loadData();
  }

  // ── Filter state ────────────────────────────────────────────────────

  /// Recomputes the `_hasActiveFilter` flag after any filter mutation.
  void _refreshHasActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminStudentControllerProvider)
          .checkActiveFilter(
            selectedStatusFilter: _selectedStatusFilter,
            selectedClassIds: _selectedClassIds,
            selectedGenderFilter: _selectedGenderFilter,
            selectedGradeLevel: null,
            selectedGuardian: _selectedGuardian,
            searchText: _searchController.text,
          );
    });
  }

  void _openFilterSheet() {
    showStudentFilterSheet(
      context: context,
      classList: _classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      initialStatus: _selectedStatusFilter,
      initialClassIds: _selectedClassIds,
      initialGender: _selectedGenderFilter,
      initialGuardian: _selectedGuardian,
      translate: ref.read(languageRiverpod).getTranslatedText,
      onApply:
          ({
            required String? status,
            required List<String> classIds,
            required String? gender,
            required String? guardian,
          }) {
            setState(() {
              _selectedStatusFilter = status;
              _selectedClassIds = classIds;
              _selectedGenderFilter = gender;
              _selectedGuardian = guardian;
            });
            _refreshHasActiveFilter();
            _loadData();
          },
    );
  }

  /// Clears every filter and search and reloads from scratch.
  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _selectedStatusFilter = null;
      _selectedClassIds = [];
      _selectedGenderFilter = null;
      _selectedGuardian = null;
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData();
  }

  // Per-chip removal callbacks — each chip in the header carries its own
  // targeted callback so the × on a specific class chip removes only that
  // class id, not every active filter. (Fixed the pre-existing bug where
  // every chip's × fired the same generic callback.)

  void _removeStatusFilter() {
    setState(() => _selectedStatusFilter = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeClassFilter(String classId) {
    setState(
      () => _selectedClassIds = _selectedClassIds
          .where((id) => id != classId)
          .toList(),
    );
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeGenderFilter() {
    setState(() => _selectedGenderFilter = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  void _removeGuardianFilter() {
    setState(() => _selectedGuardian = null);
    _refreshHasActiveFilter();
    _loadData();
  }

  // ── Row-level actions ───────────────────────────────────────────────

  void _openStudentDetail(Map<String, dynamic> student) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    AppNavigator.push(
      context,
      StudentDetailScreen(
        student: student,
        onEdit: isReadOnly ? null : () => _openAddEditSheet(student: student),
      ),
    );
  }

  void _openAddEditSheet({Map<String, dynamic>? student}) {
    showStudentAddEditDialog(
      context: context,
      ref: ref,
      classList: _classList,
      primaryColor: ColorUtils.getRoleColor('admin'),
      student: student,
      onSave: _loadData,
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final deleted = await ref
        .read(adminStudentControllerProvider)
        .deleteStudent(student, context);
    if (!deleted || !mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Student successfully deleted',
        'id': 'Siswa berhasil dihapus',
      }),
    );
  }

  // ── Excel flows ─────────────────────────────────────────────────────

  Future<void> _exportToExcel() {
    return ref
        .read(adminStudentControllerProvider)
        .exportToExcel(
          context: context,
          selectedClassIds: _selectedClassIds,
          selectedGradeLevel: null,
          selectedGenderFilter: _selectedGenderFilter,
          searchText: _searchController.text,
        );
  }

  Future<void> _importFromExcel() async {
    final imported = await ref
        .read(adminStudentControllerProvider)
        .importFromExcel(context);
    if (!imported || !mounted) return;
    await _loadData();
    if (!mounted) return;
    SnackBarUtils.showSuccess(
      context,
      ref.read(languageRiverpod).getTranslatedText(const {
        'en': 'Students imported successfully',
        'id': 'Data siswa berhasil diimpor',
      }),
    );
  }

  Future<void> _downloadTemplate() {
    return ref.read(adminStudentControllerProvider).downloadTemplate(context);
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final academicYear = ref.watch(academicYearRiverpod);
    final primaryColor = ColorUtils.getRoleColor('admin');

    final controller = ref.read(adminStudentControllerProvider);
    final activeFilters = controller.buildFilterChips(
      selectedStatusFilter: _selectedStatusFilter,
      selectedClassIds: _selectedClassIds,
      selectedGenderFilter: _selectedGenderFilter,
      selectedGuardian: _selectedGuardian,
      classList: _classList,
      languageProvider: lang,
      onClearStatus: _removeStatusFilter,
      onClearClass: _removeClassFilter,
      onClearGender: _removeGenderFilter,
      onClearGuardian: _removeGuardianFilter,
    );

    return AdminCrudScaffold(
      title: lang.getTranslatedText(const {
        'en': 'Student Management',
        'id': 'Manajemen Siswa',
      }),
      subtitle: lang.getTranslatedText(const {
        'en': 'Manage and monitor students',
        'id': 'Kelola dan pantau siswa',
      }),
      primaryColor: primaryColor,
      searchController: _searchController,
      searchHint: lang.getTranslatedText(const {
        'en': 'Search students...',
        'id': 'Cari siswa...',
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
      isEmpty: _students.isEmpty,
      onRefresh: _onRefresh,
      emptyTitle: lang.getTranslatedText(const {
        'en': 'No students',
        'id': 'Tidak ada siswa',
      }),
      emptySubtitle: _searchController.text.isEmpty && !_hasActiveFilter
          ? lang.getTranslatedText(const {
              'en': 'Tap + to add a student',
              'id': 'Tap + untuk menambah siswa',
            })
          : lang.getTranslatedText(const {
              'en': 'No search results found',
              'id': 'Tidak ditemukan hasil pencarian',
            }),
      emptyIcon: Icons.people_outline,
      childBuilder: () => PaginatedListView<Map<String, dynamic>>(
        items: _students.cast<Map<String, dynamic>>(),
        itemBuilder: (context, student, index) {
          return StudentCard(
            student: student,
            index: index,
            isReadOnly: academicYear.isReadOnly,
            primaryColor: primaryColor,
            genderText: ref
                .read(adminStudentControllerProvider)
                .getGenderText(Student.fromJson(student).gender, lang),
            onTap: () => _openStudentDetail(student),
            onEdit: () => _openAddEditSheet(student: student),
            onDelete: () => _deleteStudent(student),
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
