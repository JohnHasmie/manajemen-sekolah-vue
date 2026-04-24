// Admin student management screen - full CRUD for students.
//
// Like `pages/admin/students.vue` - manages school students with create,
// edit, delete, search, multi-filter (class, gender, grade level, guardian
// status), infinite scroll pagination, and Excel import/export.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/excel_operations_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/filter_helper_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_actions_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/tour_helper_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_card.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_management_header.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

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
/// Key state (like Vue `data()`):
/// - [_students] - paginated student list from API
/// - [_classList] - available classes for filtering
/// - Filter states: [_selectedStatusFilter], [_selectedClassIds], etc.
/// - Pagination: [_currentPage], [_hasMoreData], [_isLoadingMore]
///
/// Listens to [AcademicYearProvider] changes to reload data when year
/// changes. setState() triggers re-render like Vue's reactivity system.
class StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen>
    with
        SingleTickerProviderStateMixin,
        DataLoadingMixin,
        FilterHelperMixin,
        ExcelOperationsMixin,
        StudentActionsMixin,
        TourHelperMixin {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _students = [];
  List<dynamic> _classList = [];
  bool _isLoading = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  int _currentPage = 1;
  int _perPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  String? _selectedStatusFilter;
  List<String> _selectedClassIds = [];
  String? _selectedGenderFilter;
  String? _selectedGradeLevel;
  String? _selectedGuardian;
  bool _hasActiveFilter = false;

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  // Public property accessors for mixin access
  @override
  ScrollController get scrollController => _scrollController;
  @override
  int get currentPage => _currentPage;
  @override
  set currentPage(int value) => _currentPage = value;
  @override
  int get perPage => _perPage;
  @override
  set perPage(int value) => _perPage = value;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  set isLoadingMore(bool value) => _isLoadingMore = value;
  @override
  bool get hasMoreData => _hasMoreData;
  @override
  set hasMoreData(bool value) => _hasMoreData = value;
  @override
  List<dynamic> get students => _students;
  @override
  set students(List<dynamic> value) => _students = value;
  @override
  List<String> get selectedClassIds => _selectedClassIds;
  @override
  set selectedClassIds(List<String> value) => _selectedClassIds = value;
  @override
  String? get selectedGradeLevel => _selectedGradeLevel;
  @override
  set selectedGradeLevel(String? value) => _selectedGradeLevel = value;
  @override
  String? get selectedGenderFilter => _selectedGenderFilter;
  @override
  set selectedGenderFilter(String? value) => _selectedGenderFilter = value;
  @override
  String? get selectedGuardian => _selectedGuardian;
  @override
  set selectedGuardian(String? value) => _selectedGuardian = value;
  @override
  String? get selectedStatusFilter => _selectedStatusFilter;
  @override
  set selectedStatusFilter(String? value) => _selectedStatusFilter = value;
  @override
  String get searchText => _searchController.text;
  @override
  set searchText(String value) => _searchController.text = value;
  @override
  TextEditingController get searchController => _searchController;
  @override
  bool get isLoading => _isLoading;
  @override
  List<dynamic> get classList => _classList;
  @override
  set classList(List<dynamic> value) => _classList = value;
  @override
  bool get hasActiveFilter => _hasActiveFilter;
  @override
  set hasActiveFilter(bool value) => _hasActiveFilter = value;
  @override
  GlobalKey get menuKey => _menuKey;
  @override
  set menuKey(GlobalKey value) =>
      throw UnsupportedError('menuKey cannot be set');
  @override
  GlobalKey get searchKey => _searchKey;
  @override
  set searchKey(GlobalKey value) =>
      throw UnsupportedError('searchKey cannot be set');
  @override
  GlobalKey get filterKey => _filterKey;
  @override
  set filterKey(GlobalKey value) =>
      throw UnsupportedError('filterKey cannot be set');
  @override
  GlobalKey get fabKey => _fabKey;
  @override
  set fabKey(GlobalKey value) => throw UnsupportedError('fabKey cannot be set');

  /// Like Vue's `mounted()` - sets up academic year listener, applies
  /// initial class filter if provided, and loads data.
  @override
  void initState() {
    super.initState();

    final academicYearProvider = ref.read(academicYearRiverpod);
    academicYearProvider.addListener(onAcademicYearChanged);

    if (widget.initialClassId != null) {
      _selectedClassIds = [widget.initialClassId!];
      _hasActiveFilter = true;
    }

    loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Implementation of abstract loadData for mixin contracts.
  @override
  Future<void> loadData({bool resetPage = true}) =>
      _loadData(resetPage: resetPage);

  /// Internal load data implementation - called by loadData().
  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    final ctrl = ref.read(adminStudentControllerProvider);

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

    final result = await ctrl.loadData(
      resetPage: resetPage,
      useCache: useCache,
      currentPage: _currentPage,
      perPage: _perPage,
      selectedClassIds: _selectedClassIds,
      selectedGradeLevel: _selectedGradeLevel,
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
    } else {
      setState(() {
        _students = result.students;
        _classList = result.classList;
        _hasMoreData = result.hasMoreData;
        _isLoading = false;
        _errorMessage = null;
      });
    }

    checkAndShowTour();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    if (_errorMessage != null) {
      return ErrorScreen(errorMessage: _errorMessage!, onRetry: loadData);
    }

    final filteredStudents = _students;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          StudentManagementHeader(
            primaryColor: ColorUtils.getRoleColor('admin'),
            languageProvider: languageProvider,
            searchController: _searchController,
            hasActiveFilter: _hasActiveFilter,
            filterChips: buildFilterChips(languageProvider),
            menuKey: _menuKey,
            searchKey: _searchKey,
            filterKey: _filterKey,
            onSearch: () {
              setState(() {
                _currentPage = 1;
              });
              loadData();
            },
            onMenuSelected: (value) {
              switch (value) {
                case 'refresh':
                  forceRefresh();
                  break;
                case 'export':
                  exportToExcel();
                  break;
                case 'import':
                  importFromExcel();
                  break;
                case 'template':
                  downloadTemplate();
                  break;
              }
            },
            onFilterTap: showFilterSheet,
            onClearFilters: clearAllFilters,
          ),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: PaginatedListView<Map<String, dynamic>>(
                items: filteredStudents.cast<Map<String, dynamic>>(),
                itemBuilder: (context, student, index) {
                  return StudentCard(
                    student: student,
                    index: index,
                    isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
                    primaryColor: ColorUtils.getRoleColor('admin'),
                    genderText: getGenderText(
                      Student.fromJson(student).gender,
                      ref.read(languageRiverpod),
                    ),
                    onTap: () => navigateToStudentDetail(student),
                    onEdit: () => showStudentDialog(student: student),
                    onDelete: () => deleteStudent(student),
                  );
                },
                onLoadMore: loadMoreData,
                hasMore: _hasMoreData,
                isLoadingMore: _isLoadingMore,
                isInitialLoading: _isLoading && filteredStudents.isEmpty,
                loadingState: const SkeletonListLoading(
                  itemCount: 6,
                  infoTagCount: 1,
                ),
                emptyState: EmptyState(
                  title: languageProvider.getTranslatedText({
                    'en': 'No students',
                    'id': 'Tidak ada siswa',
                  }),
                  subtitle: _searchController.text.isEmpty && !_hasActiveFilter
                      ? languageProvider.getTranslatedText({
                          'en': 'Tap + to add a student',
                          'id': 'Tap + untuk menambah siswa',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'No search results found',
                          'id': 'Tidak ditemukan hasil pencarian',
                        }),
                  icon: Icons.people_outline,
                ),
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                onRefresh: onRefresh,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ref.read(academicYearRiverpod).isReadOnly
          ? null
          : FloatingActionButton(
              key: _fabKey,
              onPressed: showStudentDialog,
              backgroundColor: ColorUtils.getRoleColor('admin'),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }
}
