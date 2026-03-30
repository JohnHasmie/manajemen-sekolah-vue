// Admin student management screen - full CRUD for students.
//
// Like `pages/admin/students.vue` - manages school students with create, edit,
// delete, search, multi-filter (class, gender, grade level, guardian status),
// infinite scroll pagination, and Excel import/export.
//
// In Laravel terms, this is the Blade View; all data/logic lives in
// AdminStudentController (admin_student_controller.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/student_detail_screen.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_add_edit_dialog.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_card.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_filter_sheet.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_management_header.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Admin student management screen with full CRUD, search, filters, and Excel import/export.
///
/// Optionally accepts [initialClassId] to pre-filter by class (e.g., when navigating
/// from a class detail screen). Like a Vue route with optional query params.
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
/// - [_selectedStatusFilter] / [_selectedClassIds] / [_selectedGenderFilter] etc. - filter states
/// - Pagination: [_currentPage], [_hasMoreData], [_isLoadingMore] for infinite scroll
///
/// Listens to [AcademicYearProvider] changes to reload data when year changes.
/// setState() triggers re-render like Vue's reactivity system.
class StudentManagementScreenState
    extends ConsumerState<StudentManagementScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _students = [];
  List<dynamic> _classList = [];
  bool _isLoading = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  String? _selectedStatusFilter;
  List<String> _selectedClassIds = [];
  String? _selectedGenderFilter;
  String? _selectedGradeLevel;
  String? _selectedGuardian;
  bool _hasActiveFilter = false;

  // Timer? _searchDebounce; // Removed debounce

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  /// Like Vue's `mounted()` - sets up academic year listener, scroll listener
  /// for infinite scroll, applies initial class filter if provided, and loads data.
  @override
  void initState() {
    super.initState();

    // _searchController.addListener(_onSearchChanged); // Removed auto-search listener

    // Listen to academic year changes
    final academicYearProvider = ref.read(academicYearRiverpod);
    academicYearProvider.addListener(_onAcademicYearChanged);

    _scrollController.addListener(_onScroll);

    // Apply initial class filter if provided
    if (widget.initialClassId != null) {
      _selectedClassIds = [widget.initialClassId!];
      _hasActiveFilter = true;
    }

    _loadData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // _searchDebounce?.cancel(); // Removed debounce
    // Remove provider listener
    // Note: Provider listeners are usually auto-removed if the widget is disposed,
    // but explicit removal from the ChangeNotifier is safer if we added it manually.
    // However, we can't easily access context in dispose safely to get the provider if listen:false.
    // A better pattern is to use a late variable for the provider if we need to remove listener,
    // or just rely on the fact that if this widget is unmounted, _onAcademicYearChanged checks mounted.
    // But to be clean:
    // We didn't store the provider reference.
    // Let's just ensure _onAcademicYearChanged checks mounted.
    super.dispose();
  }

  void _onAcademicYearChanged() {
    if (mounted) {
      _loadData(resetPage: true);
    }
  }

  void _onSearchChanged() {
    // Removed debounce logic
  }

  // ---------------------------------------------------------------------------
  // Data loading — delegate to controller, apply result with setState
  // ---------------------------------------------------------------------------

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    final ctrl = ref.read(adminStudentControllerProvider);

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;
      // Show skeleton only when list is empty (no stale data to show)
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
      // Hard error and nothing to show — display error screen
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
      if (result.errorMessage != null) {
        // Soft error — data loaded from cache but fresh fetch failed
        SnackBarUtils.showError(context, result.errorMessage!);
      }
    }

    _checkAndShowTour();
  }

  Future<void> _forceRefresh() async {
    await ref.read(adminStudentControllerProvider).forceRefreshCaches(
      currentPage: _currentPage,
      selectedClassIds: _selectedClassIds,
      selectedGradeLevel: _selectedGradeLevel,
      selectedGenderFilter: _selectedGenderFilter,
      selectedGuardian: _selectedGuardian,
      selectedStatusFilter: _selectedStatusFilter,
      searchText: _searchController.text,
    );
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() => _isLoadingMore = true);

    final result = await ref.read(adminStudentControllerProvider).loadMoreData(
      nextPage: _currentPage + 1,
      perPage: _perPage,
      selectedClassIds: _selectedClassIds,
      selectedGradeLevel: _selectedGradeLevel,
      selectedGenderFilter: _selectedGenderFilter,
      selectedGuardian: _selectedGuardian,
      selectedStatusFilter: _selectedStatusFilter,
      searchText: _searchController.text,
    );

    if (!mounted) return;

    if (result == null) {
      // Load failed — roll back page counter
      setState(() => _isLoadingMore = false);
    } else {
      _currentPage++;
      setState(() {
        _students.addAll(result.additionalStudents);
        _hasMoreData = result.hasMoreData;
        _isLoadingMore = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Filter helpers — pure state mutations, delegate label/chip building to ctrl
  // ---------------------------------------------------------------------------

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = ref
          .read(adminStudentControllerProvider)
          .checkActiveFilter(
            selectedStatusFilter: _selectedStatusFilter,
            selectedClassIds: _selectedClassIds,
            selectedGenderFilter: _selectedGenderFilter,
            selectedGradeLevel: _selectedGradeLevel,
            selectedGuardian: _selectedGuardian,
            searchText: _searchController.text,
          );
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedClassIds.clear();
      _selectedGenderFilter = null;
      _selectedGradeLevel = null;
      _selectedGuardian = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData();
  }

  /// Builds filter chip data for the header.
  /// onRemove callbacks mutate local state then call _loadData — that's UI
  /// orchestration, so it lives here rather than in the controller.
  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    return ref.read(adminStudentControllerProvider).buildFilterChips(
      selectedStatusFilter: _selectedStatusFilter,
      selectedClassIds: _selectedClassIds,
      selectedGenderFilter: _selectedGenderFilter,
      selectedGuardian: _selectedGuardian,
      classList: _classList,
      languageProvider: languageProvider,
      onFilterChanged: () {
        // Each chip's onRemove calls this; the caller already mutated state
        // via setState before invoking the callback returned by buildFilterChips.
        // We just need to sync _hasActiveFilter and reload.
        _checkActiveFilter();
        _loadData();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI actions — dialogs, navigation, export/import
  // ---------------------------------------------------------------------------

  // Delegates to the extracted StudentFilterSheet widget.
  void _showFilterSheet() {
    showStudentFilterSheet(
      context: context,
      classList: _classList,
      primaryColor: _getPrimaryColor(),
      initialStatus: _selectedStatusFilter,
      initialClassIds: _selectedClassIds,
      initialGender: _selectedGenderFilter,
      initialGuardian: _selectedGuardian,
      translate: ref.read(languageRiverpod).getTranslatedText,
      onApply: ({
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
        _checkActiveFilter();
        _loadData();
      },
    );
  }

  // Delegates to the extracted StudentAddEditDialog widget.
  void _showStudentDialog({Map<String, dynamic>? student}) {
    showStudentAddEditDialog(
      context: context,
      ref: ref,
      classList: _classList,
      primaryColor: _getPrimaryColor(),
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
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Student successfully deleted',
          'id': 'Siswa berhasil dihapus',
        }),
      );
    }
  }

  Future<void> _exportToExcel() async {
    await ref.read(adminStudentControllerProvider).exportToExcel(
      context: context,
      selectedClassIds: _selectedClassIds,
      selectedGradeLevel: _selectedGradeLevel,
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
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Students imported successfully',
          'id': 'Data siswa berhasil diimpor',
        }),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    await ref.read(adminStudentControllerProvider).downloadTemplate(context);
  }

  void _navigateToStudentDetail(Map<String, dynamic> student) {
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    AppNavigator.push(
      context,
      StudentDetailScreen(
        student: student,
        onEdit: isReadOnly ? null : () => _showStudentDialog(student: student),
      ),
    );
  }

  String _getGenderText(String? gender, LanguageProvider languageProvider) {
    return ref
        .read(adminStudentControllerProvider)
        .getGenderText(gender, languageProvider);
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }


  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    // if (_isLoading) {
    //   return LoadingScreen(
    //     message: languageProvider.getTranslatedText({
    //       'en': 'Loading student data...',
    //       'id': 'Memuat data siswa...',
    //     }),
    //   );
    // }

    if (_errorMessage != null) {
      return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
    }

    final filteredStudents = _students;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          StudentManagementHeader(
            primaryColor: _getPrimaryColor(),
            languageProvider: languageProvider,
            searchController: _searchController,
            hasActiveFilter: _hasActiveFilter,
            filterChips: _buildFilterChips(languageProvider),
            menuKey: _menuKey,
            searchKey: _searchKey,
            filterKey: _filterKey,
            onSearch: () {
              setState(() {
                _currentPage = 1;
              });
              _loadData();
            },
            onMenuSelected: (value) {
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
            onFilterTap: _showFilterSheet,
            onClearFilters: _clearAllFilters,
          ),

          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: _isLoading
                  ? SkeletonListLoading(itemCount: 6, infoTagCount: 1)
                  : filteredStudents.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No students',
                        'id': 'Tidak ada siswa',
                      }),
                      subtitle:
                          _searchController.text.isEmpty && !_hasActiveFilter
                          ? languageProvider.getTranslatedText({
                              'en': 'Tap + to add a student',
                              'id': 'Tap + untuk menambah siswa',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'No search results found',
                              'id': 'Tidak ditemukan hasil pencarian',
                            }),
                      icon: Icons.people_outline,
                    )
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.only(top: 8, bottom: 16),
                        itemCount:
                            filteredStudents.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading indicator at bottom
                          if (index == filteredStudents.length) {
                            return Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }

                          final student = filteredStudents[index];
                          return StudentCard(
                            student: student,
                            index: index,
                            isReadOnly: ref.read(academicYearRiverpod).isReadOnly,
                            primaryColor: _getPrimaryColor(),
                            genderText: _getGenderText(student['gender'], ref.read(languageRiverpod)),
                            onTap: () => _navigateToStudentDetail(student),
                            onEdit: () => _showStudentDialog(student: student),
                            onDelete: () => _deleteStudent(student),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: ref.read(academicYearRiverpod).isReadOnly
          ? null
          : FloatingActionButton(
              key: _fabKey,
              onPressed: _showStudentDialog,
              backgroundColor: _getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'student_management',
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
      AppLogger.error('student', 'Error checking tour status: $e');
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
          name: 'student_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('student_management', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'student_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('student_management', 'admin'),
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
        identify: "StudentMenu",
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
                      'en': 'Export & Import',
                      'id': 'Ekspor & Impor',
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
                            'Use this menu to export student data to Excel, import from files, or download the template.',
                        'id':
                            'Gunakan menu ini untuk mengekspor data siswa ke Excel, mengimpor dari file, atau mengunduh template.',
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
        identify: "StudentSearch",
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
                      'en': 'Quick Search',
                      'id': 'Pencarian Cepat',
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
                            'Type student names here to find them quickly across the database.',
                        'id':
                            'Ketik nama siswa di sini untuk menemukannya dengan cepat di seluruh database.',
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
        identify: "StudentFilter",
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
                            'Filter students by class, grade level, gender, or guardian name.',
                        'id':
                            'Filter siswa berdasarkan kelas, tingkat kelas, jenis kelamin, atau nama wali.',
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
        identify: "AddStudent",
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
                      'en': 'Add New Student',
                      'id': 'Tambah Siswa Baru',
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
                            'Click here to manually add a new student to the system.',
                        'id':
                            'Klik di sini untuk menambahkan siswa baru secara manual ke dalam sistem.',
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
