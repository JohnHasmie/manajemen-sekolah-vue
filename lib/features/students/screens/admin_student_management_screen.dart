// Admin student management screen - full CRUD for students.
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
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/students/screens/student_detail_screen.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/students/exports/student_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/dashboard_typography.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Admin student management screen with full CRUD, search, filters, and Excel import/export.
///
/// Optionally accepts [initialClassId] to pre-filter by class (e.g., when navigating
/// from a class detail screen). Like a Vue route with optional query params.
class StudentManagementScreen extends StatefulWidget {
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
class StudentManagementScreenState extends State<StudentManagementScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _students = [];
  List<dynamic> _classList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiStudentService apiStudentService = ApiStudentService();

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
  String? _tourId;

  /// Like Vue's `mounted()` - sets up academic year listener, scroll listener
  /// for infinite scroll, applies initial class filter if provided, and loads data.
  @override
  void initState() {
    super.initState();

    // _searchController.addListener(_onSearchChanged); // Removed auto-search listener

    // Listen to academic year changes
    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
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
      const cacheKey = 'student_filter_options';
      final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 6));
      if (cached != null && cached is Map<String, dynamic>) {
        if (!mounted) return;
        _applyFilterOptions(cached);
        return;
      }

      final response = await ApiStudentService.getStudentFilterOptions();

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
      _availableGradeLevels = List<String>.from(
        data['grade_levels'] ?? [],
      );
      _availableClass = data['kelas'] ?? [];
    });
    AppLogger.info('student', 'Filter options loaded: ${_availableGradeLevels.length} grades, ${_availableClass.length} kelas',);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Preparing export...',
              'id': 'Menyiapkan export...',
            }),
          ),
          duration: Duration(seconds: 1),
        ),
      );

      final response = await ApiStudentService.getStudentPaginated(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Failed to export: ${ErrorUtils.getFriendlyMessage(e)}',
              'id': 'Gagal mengexport: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          ),
          backgroundColor: ColorUtils.error600,
        ),
      );
    }
  }

  Future<void> _importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await ApiStudentService.importStudentsFromExcel(
          File(result.files.single.path!),
        );

        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en': 'Students imported successfully',
                  'id': 'Data siswa berhasil diimpor',
                }),
              ),
              backgroundColor: ColorUtils.success600,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('student', 'Import from Excel error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en':
                  'Failed to import file: ${ErrorUtils.getFriendlyMessage(e)}',
              'id': 'Gagal mengimpor file: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          ),
          backgroundColor: ColorUtils.error600,
        ),
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

    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final yearId = academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'default';
    return 'student_list_$yearId';
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
                  _classList = List<dynamic>.from(cachedData['classList'] ?? []);
                  _hasMoreData = cachedData['pagination']?['has_next_page'] ?? false;
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
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiStudentService.getStudentPaginated(
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

      final classData = await ApiClassService.getClass();

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en':
                  'Failed to load student/class data: ${ErrorUtils.getFriendlyMessage(e)}',
              'id':
                  'Gagal memuat data siswa/kelas: ${ErrorUtils.getFriendlyMessage(e)}',
            }),
          ),
          backgroundColor: ColorUtils.error600,
        ),
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
    await LocalCacheService.invalidate('student_filter_options');
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

      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      final response = await ApiStudentService.getStudentPaginated(
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

      AppLogger.info('student', 'Loaded more data: Page $_currentPage, Total items: ${_students.length}',);
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
    List<Map<String, dynamic>> filterChips = [];

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
    final languageProvider = context.read<LanguageProvider>();

    String? tempSelectedStatus = _selectedStatusFilter;
    List<String> tempSelectedClass = List.from(_selectedClassIds);
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
                    padding: EdgeInsets.all(20),
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
                            SizedBox(width: 12),
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
                      padding: EdgeInsets.all(20),
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
                                SizedBox(width: 8),
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
                          SizedBox(height: 12),
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length < 2) {
                                    return const Iterable<String>.empty();
                                  }
                                  return await ApiStudentService.getGuardians(
                                    textEditingValue.text,
                                  );
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
                          SizedBox(height: 20),

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
                                SizedBox(width: 8),
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
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedStatus,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedStatus = null;
                                  });
                                },
                              ),
                              _buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Active',
                                  'id': 'Aktif',
                                }),
                                value: 'active',
                                selectedValue: tempSelectedStatus,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedStatus = 'active';
                                  });
                                },
                              ),
                              _buildStatusChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Inactive',
                                  'id': 'Tidak Aktif',
                                }),
                                value: 'inactive',
                                selectedValue: tempSelectedStatus,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedStatus = 'inactive';
                                  });
                                },
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

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
                                SizedBox(width: 8),
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
                            children: _classList.map((kelas) {
                              final classId = kelas['id'].toString();
                              final isSelected = tempSelectedClass.contains(
                                classId,
                              );

                              return FilterChip(
                                label: Text(
                                  kelas['name'] ?? kelas['nama'] ?? 'Unknown',
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

                          SizedBox(height: 24),

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
                                SizedBox(width: 8),
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
                          SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildGenderChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                                value: null,
                                selectedValue: tempSelectedGender,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedGender = null;
                                  });
                                },
                              ),
                              _buildGenderChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Male',
                                  'id': 'Laki-laki',
                                }),
                                value: 'M',
                                selectedValue: tempSelectedGender,
                                onSelected: () {
                                  setModalState(() {
                                    tempSelectedGender = 'M';
                                  });
                                },
                              ),
                              _buildGenderChip(
                                label: languageProvider.getTranslatedText({
                                  'en': 'Female',
                                  'id': 'Perempuan',
                                }),
                                value: 'F',
                                selectedValue: tempSelectedGender,
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
                    padding: EdgeInsets.all(20),
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
                            onPressed: () => Navigator.pop(context),
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
                        SizedBox(width: 12),
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
                              Navigator.pop(context);
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

  Widget _buildStatusChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate300,
      ),
    );
  }

  Widget _buildGenderChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : ColorUtils.slate300,
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
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
                        // Header dengan gradient
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
                                              'en':
                                                  'Update student information',
                                              'id': 'Perbarui data siswa',
                                            })
                                          : languageProvider.getTranslatedText({
                                              'en':
                                                  'Fill in student information',
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
                                onTap: () => Navigator.pop(context),
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
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDialogTextField(
                                  controller: nameController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Name',
                                    'id': 'Nama',
                                  }),
                                  icon: Icons.person,
                                ),
                                SizedBox(height: 12),
                                _buildDialogTextField(
                                  controller: nisController,
                                  label: 'NIS',
                                  icon: Icons.badge,
                                  keyboardType: TextInputType.number,
                                ),
                                SizedBox(height: 12),
                                _buildDialogDropdown(
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
                                            classItem['name'] ??
                                                'Unknown Class',
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
                                SizedBox(height: 12),
                                _buildDialogTextField(
                                  controller: addressController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Address',
                                    'id': 'Alamat',
                                  }),
                                  icon: Icons.location_on,
                                  maxLines: 2,
                                ),
                                SizedBox(height: 12),
                                _buildDialogTextField(
                                  controller: birthDateController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Birth Date',
                                    'id': 'Tanggal Lahir',
                                  }),
                                  icon: Icons.cake,
                                  hintText: 'YYYY-MM-DD',
                                  readOnly: true,
                                  onTap: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
                                          context: context,
                                          initialDate:
                                              student != null &&
                                                  student['date_of_birth'] !=
                                                      null
                                              ? DateTime.parse(
                                                  student['date_of_birth']
                                                      .toString(),
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
                                SizedBox(height: 12),
                                _buildDialogDropdown(
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
                                SizedBox(height: 12),
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
                                _buildDialogTextField(
                                  controller: parentNameController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Parent Name',
                                    'id': 'Nama Wali Murid',
                                  }),
                                  icon: Icons.family_restroom,
                                ),
                                SizedBox(height: 12),
                                _buildDialogTextField(
                                  controller: emailParentController,
                                  label: languageProvider.getTranslatedText({
                                    'en': 'Parent Email',
                                    'id': 'Email Wali Murid',
                                  }),
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  hintText: 'wali@example.com',
                                ),
                                SizedBox(height: 12),
                                _buildDialogTextField(
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
                          padding: EdgeInsets.all(20),
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
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(
                                      color: ColorUtils.slate300,
                                    ),
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
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    final nis = nisController.text.trim();
                                    final address = addressController.text
                                        .trim();
                                    final birthDate = birthDateController.text
                                        .trim();
                                    final nameParent = parentNameController.text
                                        .trim();
                                    final noPhone = phoneController.text.trim();
                                    final emailParent = emailParentController
                                        .text
                                        .trim();

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
                                              'en': 'All fields must be filled',
                                              'id': 'Semua field harus diisi',
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
                                              'id': 'Format email tidak valid',
                                            }),
                                          ),
                                          backgroundColor:
                                              ColorUtils.warning600,
                                        ),
                                      );
                                      return;
                                    }

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
                                        await ApiStudentService.updateStudent(
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
                                          Navigator.pop(context);
                                        }
                                      } else {
                                        await ApiStudentService.addStudent(
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
                                          Navigator.pop(context);
                                        }
                                      }
                                    } catch (e) {
                                      AppLogger.error('student', 'Save/Update student error: $e');
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
                                                  color: ColorUtils.error600,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  languageProvider
                                                      .getTranslatedText({
                                                        'en': 'Error',
                                                        'id': 'Gagal',
                                                      }),
                                                  style: TextStyle(
                                                    color: ColorUtils.error600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Text(
                                              '${languageProvider.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(e)}',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: Text(
                                                  'OK',
                                                  style: TextStyle(
                                                    color: _getPrimaryColor(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _getPrimaryColor(),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    elevation: 2,
                                    shadowColor: _getPrimaryColor().withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  child: Text(
                                    isEdit
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Update',
                                            'id': 'Perbarui',
                                          })
                                        : languageProvider.getTranslatedText({
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
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          hintText: hintText,
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _getPrimaryColor(), width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        keyboardType: keyboardType,
        maxLines: maxLines,
        onTap: onTap,
        readOnly: readOnly,
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _getPrimaryColor(), width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(12),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete Student',
          'id': 'Hapus Siswa',
        }),
        content: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Are you sure you want to delete this student?',
          'id': 'Yakin ingin menghapus siswa ini?',
        }),
        confirmText: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: ColorUtils.error600,
      ),
    );

    if (confirmed == true) {
      try {
        await ApiStudentService.deleteStudent(student['id']);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Student successfully deleted',
                  'id': 'Siswa berhasil dihapus',
                }),
              ),
              backgroundColor: ColorUtils.success600,
            ),
          );
        }
      } catch (e) {
        AppLogger.error('student', 'Delete student error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en':
                      'Failed to delete student: ${ErrorUtils.getFriendlyMessage(e)}',
                  'id':
                      'Gagal menghapus siswa: ${ErrorUtils.getFriendlyMessage(e)}',
                }),
              ),
              backgroundColor: ColorUtils.error600,
            ),
          );
        }
      }
    }
  }

  void _navigateToStudentDetail(Map<String, dynamic> student) {
    final isReadOnly = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).isReadOnly;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          student: student,
          onEdit: isReadOnly
              ? null
              : () => _showStudentDialog(student: student),
        ),
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

  Widget _buildStudentCard(Map<String, dynamic> student, int index) {
    final languageProvider = context.read<LanguageProvider>();
    final avatarColor = ColorUtils.getColorForIndex(index);
    final isReadOnly = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).isReadOnly;
    final className = student['class']?['name'] ?? '-';
    final genderText = _getGenderText(student['gender'], languageProvider);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToStudentDetail(student),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                // Compact Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    (student['name'] ?? 'N')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Student Info (expanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Text(
                        student['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      // Compact info chips
                      Row(
                        children: [
                          // Class chip
                          _buildInfoTag(Icons.school_outlined, className),
                          SizedBox(width: 6),
                          // Gender chip
                          _buildInfoTag(Icons.person_outline, genderText),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),

                // Right side: status + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Status dot
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.success600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.success600.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: ColorUtils.success600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: ColorUtils.success600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isReadOnly) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          // Edit button
                          InkWell(
                            onTap: () => _showStudentDialog(student: student),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: _getPrimaryColor(),
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          // Delete button
                          InkWell(
                            onTap: () => _deleteStudent(student),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: ColorUtils.error600.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: ColorUtils.error600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildGradientHeader(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return GradientPageHeader(
      title: languageProvider.getTranslatedText({
        'en': 'Student Management',
        'id': 'Manajemen Siswa',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Manage and monitor students',
        'id': 'Kelola dan pantau siswa',
      }),
      primaryColor: _getPrimaryColor(),
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
                SizedBox(width: 8),
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
                SizedBox(width: 8),
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
                SizedBox(width: 8),
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
                SizedBox(width: 8),
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
                          'en': 'Search students...',
                          'id': 'Cari siswa...',
                        }),
                        hintStyle: TextStyle(color: ColorUtils.slate400),
                        prefixIcon: Icon(
                          Icons.search,
                          color: ColorUtils.slate400,
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
          SizedBox(width: 8),
          Container(
            key: _filterKey,
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
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600,
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
                  padding: EdgeInsets.all(8),
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
                SizedBox(width: 8),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._buildFilterChips(languageProvider).map((filter) {
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
                              color: ColorUtils.error600,
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
                SizedBox(width: 8),
                InkWell(
                  onTap: _clearAllFilters,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600,
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
          ) : null,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
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
              _buildGradientHeader(context, languageProvider),

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
                              _searchController.text.isEmpty &&
                                  !_hasActiveFilter
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
                                filteredStudents.length +
                                (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Show loading indicator at bottom
                              if (index == filteredStudents.length) {
                                return Container(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  alignment: Alignment.center,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              final student = filteredStudents[index];
                              return _buildStudentCard(student, index);
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
          floatingActionButton:
              Provider.of<AcademicYearProvider>(context).isReadOnly
              ? null
              : FloatingActionButton(
                  key: _fabKey,
                  onPressed: () => _showStudentDialog(),
                  backgroundColor: _getPrimaryColor(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 20),
                ),
        );
      },
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      const tourCacheKey = 'tour_student_management_admin';
      // Only use cache (pre-fetched by dashboard), no API call
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id'];
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
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = context.read<LanguageProvider>();

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
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_student_management_admin', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_student_management_admin', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

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
