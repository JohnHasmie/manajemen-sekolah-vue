// Admin student management screen - full CRUD for students.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/admin/students.vue` - manages school students with create, edit,
// delete, search, multi-filter (class, gender, grade level, guardian status),
// infinite scroll pagination, and Excel import/export.
//
// In Laravel terms, this consumes StudentController
// (GET /api/students, POST, PUT, DELETE with pagination and filters).
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/students/presentation/screens/student_detail_screen.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/students/exports/student_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/dashboard_typography.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_card.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/filter_choice_chip.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_dialog_text_field.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_dialog_dropdown.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_management_header.dart';

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
  final ApiStudentService apiStudentService = getIt<ApiStudentService>();

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

  List<String> _availableGradeLevels = [];
  List<dynamic> _availableClass = [];

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

    _loadFilterOptions();
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

  Future<void> _loadFilterOptions() async {
    try {
      // Try cache first — return early on hit
      final cacheKey = CacheKeyBuilder.custom('student', 'filter_options');
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is Map<String, dynamic>) {
        if (!mounted) return;
        _applyFilterOptions(cached);
        return;
      }

      final response = await getIt<ApiStudentService>()
          .getStudentFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        // Non-blocking save
        LocalCacheService.save(cacheKey, response['data']);
        _applyFilterOptions(response['data']);
      }
    } catch (e) {
      AppLogger.error('student', 'Error loading filter options: $e');
    }
  }

  void _applyFilterOptions(Map<String, dynamic> data) {
    setState(() {
      _availableGradeLevels = List<String>.from(data['grade_levels'] ?? []);
      _availableClass = data['kelas'] ?? [];
    });
    AppLogger.info(
      'student',
      'Filter options loaded: ${_availableGradeLevels.length} grades, ${_availableClass.length} kelas',
    );
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

  Future<void> _exportToExcel() async {
    try {
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Preparing export...',
          'id': 'Menyiapkan export...',
        }),
      );

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: 1,
        limit: 10000, // Fetch all students (up to 10000)
        classId: _selectedClassIds.isNotEmpty ? _selectedClassIds.first : null,
        gradeLevel: _selectedGradeLevel,
        gender: _selectedGenderFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      final allStudents = response['data'] ?? [];

      await ExcelService.exportStudentsToExcel(
        students: allStudents,
        context: context,
      );
    } catch (e) {
      AppLogger.error('student', 'Export to Excel error: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': '${AppLocalizations.failedToExport.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  Future<void> _importFromExcel() async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiStudentService>().importStudentsFromExcel(
          File(result.files.single.path!),
        );

        await _loadData();

        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            languageProvider.getTranslatedText({
              'en': 'Students imported successfully',
              'id': 'Data siswa berhasil diimpor',
            }),
          );
        }
      }
    } catch (e) {
      AppLogger.error('student', 'Import from Excel error: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en': 'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': '${AppLocalizations.failedToImport.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    await ExcelService.downloadTemplate(context);
  }

  /// Build a cache key based on current filters, page, and academic year.
  /// Only cache the default view (page 1, no filters, no search) for instant display.
  String? _buildStudentCacheKey() {
    // Only cache default first-page view (no filters/search) for fast reload
    if (_currentPage != 1) return null;
    if (_selectedClassIds.isNotEmpty ||
        _selectedGradeLevel != null ||
        _selectedGenderFilter != null ||
        _selectedGuardian != null ||
        _selectedStatusFilter != null ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }

    final academicYearProvider = ref.read(academicYearRiverpod);
    final yearId =
        academicYearProvider.selectedAcademicYear?['id']?.toString() ??
        'default';
    return CacheKeyBuilder.custom('student_list', yearId);
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _hasMoreData = true;

        // ─── Step 1: Try cache — return early on hit ───
        if (useCache) {
          final cacheKey = _buildStudentCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null && mounted) {
                final cachedData = Map<String, dynamic>.from(cached);
                setState(() {
                  _students = List<dynamic>.from(cachedData['students'] ?? []);
                  _classList = List<dynamic>.from(
                    cachedData['classList'] ?? [],
                  );
                  _hasMoreData =
                      cachedData['pagination']?['has_next_page'] ?? false;
                  _isLoading = false;
                  _errorMessage = null;
                });
                AppLogger.info('student', 'Students loaded from cache');
                // Return early — trigger tour immediately (cache pre-fetched by dashboard)
                _checkAndShowTour();
                return;
              }
            } catch (e) {
              AppLogger.error('student', 'Student cache load failed: $e');
            }
          }
        }

        // Show loading skeleton only if we have no data yet (no cache hit)
        if (_students.isEmpty && mounted) {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: _currentPage,
        limit: _perPage,
        classId: _selectedClassIds.isNotEmpty ? _selectedClassIds.first : null,
        gradeLevel: _selectedGradeLevel,
        gender: _selectedGenderFilter,
        academicYearId: selectedYearId,
        guardianName: _selectedGuardian,
        status: _selectedStatusFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        useCache: useCache,
      );

      final classData = await getIt<ApiClassService>().getClass();

      if (!mounted) return;

      setState(() {
        _students = response['data'] ?? [];
        _classList = classData;
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // ─── Step 3: Save to cache (non-blocking, only for default view) ───
      final cacheKey = _buildStudentCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'students': response['data'] ?? [],
          'classList': classData,
          'pagination': response['pagination'],
        });
      }
    } catch (e) {
      AppLogger.error('student', 'Load students/class error: $e');
      if (!mounted) return;

      // Only show error if we don't have cached data displayed
      if (_students.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      } else {
        // We have cached data, just show a snackbar
        setState(() => _isLoading = false);
      }

      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en':
              'Failed to load student/class data: ${ErrorUtils.getFriendlyMessage(e)}',
          'id':
              '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    } finally {
      // Trigger tour (cache pre-fetched by dashboard, no delay needed)
      _checkAndShowTour();
    }
  }

  /// Force refresh: clear cache and reload from API
  Future<void> _forceRefresh() async {
    // Invalidate student cache for current academic year
    final cacheKey = _buildStudentCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_student_management_');
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('student', 'filter_options'),
    );
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiStudentService>().getStudentPaginated(
        page: _currentPage,
        limit: _perPage,
        classId: _selectedClassIds.isNotEmpty ? _selectedClassIds.first : null,
        gradeLevel: _selectedGradeLevel,
        gender: _selectedGenderFilter,
        academicYearId: selectedYearId,
        guardianName: _selectedGuardian,
        status: _selectedStatusFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _students.addAll(response['data'] ?? []);
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      AppLogger.info(
        'student',
        'Loaded more data: Page $_currentPage, Total items: ${_students.length}',
      );
    } catch (e) {
      AppLogger.error('student', 'Load more students error: $e');
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedStatusFilter != null ||
          _selectedClassIds.isNotEmpty ||
          _selectedGenderFilter != null ||
          _selectedGradeLevel != null ||
          _selectedGuardian != null ||
          _searchController.text.trim().isNotEmpty;
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

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      final statusText = _selectedStatusFilter == 'active'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Tidak Aktif',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedClassIds.isNotEmpty) {
      for (var classId in _selectedClassIds) {
        final className = _classList.firstWhere(
          (k) => k['id'].toString() == classId,
          orElse: () => {'name': classId},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${className['name'] ?? className['nama'] ?? 'Unknown'}',
          'onRemove': () {
            setState(() {
              _selectedClassIds.remove(classId);
            });
            _checkActiveFilter();
            _loadData();
          },
        });
      }
    }

    if (_selectedGenderFilter != null) {
      final genderText = _selectedGenderFilter == 'M'
          ? languageProvider.getTranslatedText({
              'en': 'Male',
              'id': 'Laki-laki',
            })
          : languageProvider.getTranslatedText({
              'en': 'Female',
              'id': 'Perempuan',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Gender', 'id': 'Jenis Kelamin'})}: $genderText',
        'onRemove': () {
          setState(() {
            _selectedGenderFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedGuardian != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Guardian', 'id': 'Wali'})}: $_selectedGuardian',
        'onRemove': () {
          setState(() {
            _selectedGuardian = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    String? tempSelectedStatus = _selectedStatusFilter;
    final List<String> tempSelectedClass = List.from(_selectedClassIds);
    String? tempSelectedGender = _selectedGenderFilter;
    String? tempSelectedGuardian = _selectedGuardian;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Gradient Header
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getPrimaryColor(),
                          _getPrimaryColor().withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: AppSpacing.md),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Filter Students',
                                'id': 'Filter Siswa',
                              }),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedStatus = null;
                              tempSelectedClass.clear();
                              tempSelectedGender = null;
                              tempSelectedGuardian = null;
                            });
                          },
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Reset',
                              'id': 'Reset',
                            }),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Guardian Filter
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.family_restroom,
                                  size: 18,
                                  color: ColorUtils.slate700,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Guardian Name',
                                    'id': 'Nama Wali Murid',
                                  }),
                                  style: DashboardTypography.subtitle(
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length < 2) {
                                    return const Iterable<String>.empty();
                                  }
                                  return await getIt<ApiStudentService>()
                                      .getGuardians(textEditingValue.text);
                                },
                            onSelected: (String selection) {
                              setModalState(() {
                                tempSelectedGuardian = selection;
                              });
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  if (tempSelectedGuardian != null &&
                                      textEditingController.text.isEmpty) {
                                    textEditingController.text =
                                        tempSelectedGuardian!;
                                  }
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      hintText: languageProvider
                                          .getTranslatedText({
                                            'en': 'Search Guardian',
                                            'id': 'Cari Wali Murid',
                                          }),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: ColorUtils.slate300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: ColorUtils.slate300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _getPrimaryColor(),
                                        ),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.person_search,
                                        color: ColorUtils.slate400,
                                      ),
                                      suffixIcon: tempSelectedGuardian != null
                                          ? IconButton(
                                              icon: Icon(Icons.close),
                                              onPressed: () {
                                                textEditingController.clear();
                                                setModalState(() {
                                                  tempSelectedGuardian = null;
                                                });
                                                // Also clear from parent state if needed, but here we just clear temp
                                              },
                                            )
                                          : null,
                                    ),
                                  );
                                },
                          ),
                          SizedBox(height: AppSpacing.xl),

                          // Status Filter
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: ColorUtils.slate700,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Status',
                                    'id': 'Status',
                                  }),
                                  style: DashboardTypography.subtitle(
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChoiceChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedStatus,
                                primaryColor: _getPrimaryColor(),
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedStatus = null;
                                  });
                                },
                              ),
                              FilterChoiceChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Active',
                                  'id': 'Aktif',
                                }),
                                value: 'active',
                                selectedValue: tempSelectedStatus,
                                primaryColor: _getPrimaryColor(),
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedStatus = 'active';
                                  });
                                },
                              ),
                              FilterChoiceChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Inactive',
                                  'id': 'Tidak Aktif',
                                }),
                                value: 'inactive',
                                selectedValue: tempSelectedStatus,
                                primaryColor: _getPrimaryColor(),
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedStatus = 'inactive';
                                  });
                                },
                              ),
                            ],
                          ),

                          SizedBox(height: AppSpacing.xxl),

                          // Kelas Filter
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.class_outlined,
                                  size: 18,
                                  color: ColorUtils.slate700,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Class',
                                    'id': 'Kelas',
                                  }),
                                  style: DashboardTypography.subtitle(
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _classList.map((classItem) {
                              final classId = classItem['id'].toString();
                              final isSelected = tempSelectedClass.contains(
                                classId,
                              );

                              return FilterChip(
                                label: Text(
                                  classItem['name'] ??
                                      classItem['nama'] ??
                                      'Unknown',
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      tempSelectedClass.add(classId);
                                    } else {
                                      tempSelectedClass.remove(classId);
                                    }
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.15,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                side: BorderSide(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              );
                            }).toList(),
                          ),

                          SizedBox(height: AppSpacing.xxl),

                          // Gender Filter
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.transgender,
                                  size: 18,
                                  color: ColorUtils.slate700,
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Gender',
                                    'id': 'Jenis Kelamin',
                                  }),
                                  style: DashboardTypography.subtitle(
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChoiceChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedGender,
                                primaryColor: _getPrimaryColor(),
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedGender = null;
                                  });
                                },
                              ),
                              FilterChoiceChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Male',
                                  'id': 'Laki-laki',
                                }),
                                value: 'M',
                                selectedValue: tempSelectedGender,
                                primaryColor: _getPrimaryColor(),
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedGender = 'M';
                                  });
                                },
                              ),
                              FilterChoiceChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Female',
                                  'id': 'Perempuan',
                                }),
                                value: 'F',
                                selectedValue: tempSelectedGender,
                                primaryColor: _getPrimaryColor(),
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedGender = 'F';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Enhanced Footer
                  Container(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: ColorUtils.slate200),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.slate900.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatusFilter = tempSelectedStatus;
                                _selectedClassIds = tempSelectedClass;
                                _selectedGenderFilter = tempSelectedGender;
                                _selectedGuardian = tempSelectedGuardian;
                              });
                              _checkActiveFilter();
                              AppNavigator.pop(context);
                              _loadData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Apply Filter',
                                'id': 'Terapkan Filter',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStudentDialog({Map<String, dynamic>? student}) {
    final nameController = TextEditingController(text: student?['name'] ?? '');
    final nisController = TextEditingController(
      text: student?['student_number'] ?? '',
    );
    final addressController = TextEditingController(
      text: student?['address'] ?? '',
    );
    final birthDateController = TextEditingController(
      text: student != null && student['date_of_birth'] != null
          ? student['date_of_birth'].toString().substring(0, 10)
          : '',
    );
    final parentNameController = TextEditingController(
      text: student?['guardian_name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: student?['phone_number'] ?? '',
    );

    final emailParentController = TextEditingController(
      text: student?['guardian_email'] ?? student?['parent_email'] ?? '',
    );

    String? selectedClassId = student?['class']?['id'] ?? student?['class_id'];
    String? selectedGender = student?['gender'];

    final isEdit = student != null;

    bool isChangeUserMode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final languageProvider = ref.watch(languageRiverpod);
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.92,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Header with gradient
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                        decoration: BoxDecoration(
                          gradient: _getCardGradient(),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                isEdit
                                    ? Icons.edit_rounded
                                    : Icons.person_add_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Edit Student',
                                            'id': 'Edit Siswa',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'Add Student',
                                            'id': 'Tambah Siswa',
                                          }),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    isEdit
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Update student information',
                                            'id': 'Perbarui data siswa',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'Fill in student information',
                                            'id': 'Isi data siswa baru',
                                          }),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => AppNavigator.pop(context),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: nameController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Name',
                                  'id': 'Nama',
                                }),
                                icon: Icons.person,
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: nisController,
                                label: 'NIS',
                                icon: Icons.badge,
                                keyboardType: TextInputType.number,
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogDropdown(
                                primaryColor: _getPrimaryColor(),
                                value: selectedClassId,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Class',
                                  'id': 'Kelas',
                                }),
                                icon: Icons.school,
                                items: _classList
                                    .where(
                                      (classItem) => classItem['id'] != null,
                                    )
                                    .map((classItem) {
                                      return DropdownMenuItem<String>(
                                        value: classItem['id'].toString(),
                                        child: Text(
                                          classItem['name'] ?? 'Unknown Class',
                                        ),
                                      );
                                    })
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedClassId = value;
                                  });
                                },
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: addressController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Address',
                                  'id': 'Alamat',
                                }),
                                icon: Icons.location_on,
                                maxLines: 2,
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: birthDateController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Birth Date',
                                  'id': 'Tanggal Lahir',
                                }),
                                icon: Icons.cake,
                                hintText: 'YYYY-MM-DD',
                                readOnly: true,
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        student != null &&
                                            student['date_of_birth'] != null
                                        ? DateTime.parse(
                                            student['date_of_birth'].toString(),
                                          )
                                        : DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: _getPrimaryColor(),
                                            onPrimary: Colors.white,
                                            onSurface: Colors.black,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      birthDateController.text =
                                          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogDropdown(
                                primaryColor: _getPrimaryColor(),
                                value: selectedGender,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Gender',
                                  'id': 'Jenis Kelamin',
                                }),
                                icon: Icons.transgender,
                                items: [
                                  DropdownMenuItem(
                                    value: 'L',
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Male',
                                        'id': 'Laki-laki',
                                      }),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'P',
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Female',
                                        'id': 'Perempuan',
                                      }),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    selectedGender = value;
                                  });
                                },
                              ),
                              SizedBox(height: AppSpacing.md),
                              if (isEdit)
                                Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.warning600.withValues(
                                      alpha: 0.05,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: SwitchListTile(
                                    title: Text(
                                      languageProvider.getTranslatedText({
                                        'en':
                                            'Use Another User / Change Guardian Account',
                                        'id':
                                            'Ganti Akun Wali / Gunakan User Wali Lain',
                                      }),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: ColorUtils.warning600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      languageProvider.getTranslatedText({
                                        'en':
                                            'Link this student to a different user account based on the email below (does not edit the current linked user).',
                                        'id':
                                            'Pindahkan siswa ini ke akun wali lain berdasarkan email di bawah (tidak merubah data user saat ini).',
                                      }),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ColorUtils.slate600,
                                      ),
                                    ),
                                    value: isChangeUserMode,
                                    activeThumbColor: ColorUtils.warning600,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        isChangeUserMode = val;
                                      });
                                    },
                                  ),
                                ),
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: parentNameController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Parent Name',
                                  'id': 'Nama Wali Murid',
                                }),
                                icon: Icons.family_restroom,
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: emailParentController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Parent Email',
                                  'id': 'Email Wali Murid',
                                }),
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                hintText: 'wali@example.com',
                              ),
                              SizedBox(height: AppSpacing.md),
                              StudentDialogTextField(
                                primaryColor: _getPrimaryColor(),
                                controller: phoneController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Phone Number',
                                  'id': 'No. Telepon',
                                }),
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Enhanced Footer (Matches _showFilterSheet)
                      Container(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: ColorUtils.slate200),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: ColorUtils.slate900.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 8,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => AppNavigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  side: BorderSide(color: ColorUtils.slate300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Cancel',
                                    'id': 'Batal',
                                  }),
                                  style: TextStyle(
                                    color: ColorUtils.slate700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        final name = nameController.text.trim();
                                        final nis = nisController.text.trim();
                                        final address = addressController.text
                                            .trim();
                                        final birthDate = birthDateController
                                            .text
                                            .trim();
                                        final nameParent = parentNameController
                                            .text
                                            .trim();
                                        final noPhone = phoneController.text
                                            .trim();
                                        final emailParent =
                                            emailParentController.text.trim();

                                        if (name.isEmpty ||
                                            nis.isEmpty ||
                                            selectedClassId == null ||
                                            address.isEmpty ||
                                            birthDate.isEmpty ||
                                            selectedGender == null ||
                                            nameParent.isEmpty ||
                                            noPhone.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en':
                                                      'All fields must be filled',
                                                  'id':
                                                      'Semua field harus diisi',
                                                }),
                                              ),
                                              backgroundColor:
                                                  ColorUtils.warning600,
                                            ),
                                          );
                                          return;
                                        }

                                        if (emailParent.isNotEmpty &&
                                            !RegExp(
                                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                            ).hasMatch(emailParent)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en': 'Invalid email format',
                                                  'id':
                                                      'Format email tidak valid',
                                                }),
                                              ),
                                              backgroundColor:
                                                  ColorUtils.warning600,
                                            ),
                                          );
                                          return;
                                        }

                                        setDialogState(() => isSaving = true);

                                        try {
                                          final data = {
                                            'name': name,
                                            'student_number': nis,
                                            'class_id': selectedClassId,
                                            'address': address,
                                            'date_of_birth': birthDate,
                                            'gender': selectedGender,
                                            'guardian_name': nameParent,
                                            'phone_number': noPhone,
                                            'guardian_email': emailParent,
                                            if (isEdit && isChangeUserMode)
                                              'use_another_user': true,
                                          };

                                          if (isEdit) {
                                            await getIt<ApiStudentService>()
                                                .updateStudent(
                                                  student['id'],
                                                  data,
                                                );
                                            await _loadData();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    languageProvider.getTranslatedText({
                                                          'en':
                                                              'Student successfully updated',
                                                          'id':
                                                              'Siswa berhasil diperbarui',
                                                        }) +
                                                        (emailParent.isNotEmpty
                                                            ? languageProvider
                                                                  .getTranslatedText({
                                                                    'en':
                                                                        '\nParent user linked/created. Default password for new user is password123',
                                                                    'id':
                                                                        '\nData wali terkait & Akun wali (User) ikut diperbarui/dibuat. Password akun baru: password123',
                                                                  })
                                                            : ''),
                                                  ),
                                                  backgroundColor:
                                                      ColorUtils.success600,
                                                ),
                                              );
                                              AppNavigator.pop(context);
                                            }
                                          } else {
                                            await getIt<ApiStudentService>()
                                                .addStudent(data);
                                            await _loadData();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    languageProvider.getTranslatedText({
                                                          'en':
                                                              'Student successfully added',
                                                          'id':
                                                              'Siswa berhasil ditambahkan',
                                                        }) +
                                                        (emailParent.isNotEmpty
                                                            ? languageProvider
                                                                  .getTranslatedText({
                                                                    'en':
                                                                        '\nParent user linked/created. Default password for new user is password123',
                                                                    'id':
                                                                        '\nData wali terkait & Akun wali (User) ikut diperbarui/dibuat. Password akun baru: password123',
                                                                  })
                                                            : ''),
                                                  ),
                                                  backgroundColor:
                                                      ColorUtils.success600,
                                                ),
                                              );
                                              AppNavigator.pop(context);
                                            }
                                          }
                                        } catch (e) {
                                          AppLogger.error(
                                            'student',
                                            'Save/Update student error: $e',
                                          );
                                          if (context.mounted) {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                title: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      color:
                                                          ColorUtils.error600,
                                                    ),
                                                    SizedBox(
                                                      width: AppSpacing.sm,
                                                    ),
                                                    Text(
                                                      languageProvider
                                                          .getTranslatedText({
                                                            'en': 'Error',
                                                            'id': 'Gagal',
                                                          }),
                                                      style: TextStyle(
                                                        color:
                                                            ColorUtils.error600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Text(
                                                  '${languageProvider.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(e)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        AppNavigator.pop(ctx),
                                                    child: Text(
                                                      'OK',
                                                      style: TextStyle(
                                                        color:
                                                            _getPrimaryColor(),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            setDialogState(
                                              () => isSaving = false,
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getPrimaryColor(),
                                  disabledBackgroundColor: _getPrimaryColor()
                                      .withValues(alpha: 0.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  elevation: 2,
                                  shadowColor: _getPrimaryColor().withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                                child: isSaving
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isEdit
                                            ? languageProvider
                                                  .getTranslatedText({
                                                    'en': 'Update',
                                                    'id': 'Perbarui',
                                                  })
                                            : languageProvider
                                                  .getTranslatedText({
                                                    'en': 'Save',
                                                    'id': 'Simpan',
                                                  }),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete Student',
          'id': 'Hapus Siswa',
        }),
        content: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Are you sure you want to delete this student?',
          'id': 'Yakin ingin menghapus siswa ini?',
        }),
        confirmText: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: ColorUtils.error600,
      ),
    );

    if (confirmed == true) {
      try {
        await getIt<ApiStudentService>().deleteStudent(student['id']);
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
      } catch (e) {
        AppLogger.error('student', 'Delete student error: $e');
        if (mounted) {
          SnackBarUtils.showError(
            context,
            ref.read(languageRiverpod).getTranslatedText({
              'en':
                  'Failed to delete student: ${ErrorUtils.getFriendlyMessage(e)}',
              'id':
                  '${AppLocalizations.failedToDelete.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          );
        }
      }
    }
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
    switch (gender) {
      case 'M':
      case 'L':
        return languageProvider.getTranslatedText({
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'F':
      case 'P':
        return languageProvider.getTranslatedText({
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
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
