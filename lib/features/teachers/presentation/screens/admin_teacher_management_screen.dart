// Admin teacher management screen - full CRUD for teachers.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/admin/teachers.vue` - manages school teachers with create, edit,
// delete, search, multi-filter (class, gender, homeroom status, employment status),
// infinite scroll pagination, and Excel import/export.
//
// In Laravel terms, this consumes TeacherController endpoints.
// Listens for FCM sync triggers and academic year changes.
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/teacher_detail_screen.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_filter_sheet.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/teachers/exports/teacher_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Admin teacher management screen with full CRUD, search, filters, and Excel import/export.
///
/// This is a [StatefulWidget] - like a Vue page component with extensive local state
/// for teacher list, pagination, filters, and real-time sync via FCM.
class TeacherAdminScreen extends ConsumerStatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  TeacherAdminScreenState createState() => TeacherAdminScreenState();
}

/// Mutable state for [TeacherAdminScreen].
///
/// Key state (like Vue `data()`):
/// - [_teachers] - paginated teacher list from API
/// - [_subjects] / [_classes] - reference data for dropdowns in create/edit forms
/// - Filter states: [_selectedClassId], [_selectedGender], [_selectedEmploymentStatus]
/// - Pagination: [_currentPage], [_hasMoreData], [_isLoadingMore] for infinite scroll
///
/// Listens to AcademicYearProvider and FCM sync triggers.
/// setState() triggers re-render like Vue's reactivity system.
class TeacherAdminScreenState extends ConsumerState<TeacherAdminScreen> {
  final ApiTeacherService _teacherService = getIt<ApiTeacherService>();
  final ApiSubjectService _subjectService = getIt<ApiSubjectService>();
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  String? _selectedClassId;
  String? _selectedHomeroomFilter;
  String? _selectedGender;
  String? _selectedEmploymentStatus;
  String? _selectedTeachingClassId;
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availableClass = [];
  List<dynamic> _availableGenders = [];
  List<dynamic> _availableEmploymentStatus = [];

  // Search debounce
  Timer? _searchDebounce;

  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  /// Like Vue's `mounted()` - sets up scroll listener, academic year listener,
  /// FCM sync listener, and loads initial data (filter options + teachers).
  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // _searchController.addListener(_onSearchChanged); // Removed auto-search listener

    // Listen to academic year changes
    final academicYearProvider = ref.read(academicYearRiverpod);
    academicYearProvider.addListener(_onAcademicYearChanged);

    _loadFilterOptions();
    _loadData();

    // Listen to real-time sync trigger
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null &&
        (trigger['type'] == 'refresh_teachers' ||
            trigger['type'] == 'refresh_schedules')) {
      if (mounted) {
        AppLogger.debug('teacher', 'Sync triggered: ${trigger['type']}');
        _loadData(useCache: false);
      }
    }
  }

  /// Like Vue's `beforeUnmount()` - cleans up all listeners and controllers.
  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // _searchController.removeListener(_onSearchChanged); // Removed auto-search listener
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onAcademicYearChanged() {
    if (mounted) {
      _loadFilterOptions(); // Refresh class options
      _loadData(); // Refresh teacher list
    }
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  // void _onSearchChanged() { ... } // Removed entire method to prevent auto-search

  bool _showAllTeachers = false; // Filter to show all teachers

  Future<void> _loadFilterOptions() async {
    try {
      String? academicYearId;
      if (mounted) {
        try {
          final academicYearProvider = ref.read(academicYearRiverpod);
          academicYearId = academicYearProvider.selectedAcademicYear?['id']
              ?.toString();
        } catch (e) {
          // provider might not be available or other error
        }
      }

      // ─── Cache-first: return early on hit ───
      final cacheKey = CacheKeyBuilder.custom(
        'teacher_filter_options',
        academicYearId ?? 'default',
      );
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          setState(() {
            _availableClass = List<dynamic>.from(cachedData['kelas'] ?? []);
            _availableGenders = List<dynamic>.from(
              cachedData['gender_options'] ?? [],
            );
            _availableEmploymentStatus = List<dynamic>.from(
              cachedData['employment_status_options'] ?? [],
            );
          });
          AppLogger.info('teacher', 'Teacher filter options loaded from cache');
          return;
        }
      } catch (e) {
        AppLogger.error('teacher', 'Teacher filter cache load failed: $e');
      }

      final response = await getIt<ApiTeacherService>().getTeacherFilterOptions(
        academicYearId: academicYearId,
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableClass = response['data']['kelas'] ?? [];
          _availableGenders = response['data']['gender_options'] ?? [];
          _availableEmploymentStatus =
              response['data']['employment_status_options'] ?? [];
        });
        // Non-blocking cache save
        LocalCacheService.save(cacheKey, {
          'kelas': response['data']['kelas'] ?? [],
          'gender_options': response['data']['gender_options'] ?? [],
          'employment_status_options':
              response['data']['employment_status_options'] ?? [],
        });
        AppLogger.info(
          'teacher',
          'Filter options loaded: ${_availableClass.length} kelas, ${_availableGenders.length} gender, ${_availableEmploymentStatus.length} employment status',
        );
      }
    } catch (e) {
      AppLogger.error('teacher', 'Error loading filter options: $e');
      // Continue with empty options - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedHomeroomFilter != null ||
          _selectedClassId != null ||
          _selectedGender != null ||
          _selectedEmploymentStatus != null ||
          _selectedTeachingClassId != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedClassId = null;
      _selectedHomeroomFilter = null;
      _selectedGender = null;
      _selectedEmploymentStatus = null;
      _selectedTeachingClassId = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    if (_selectedHomeroomFilter != null) {
      final statusText = _selectedHomeroomFilter == 'wali_kelas'
          ? languageProvider.getTranslatedText({
              'en': 'Homeroom Teacher',
              'id': 'Wali Kelas',
            })
          : languageProvider.getTranslatedText({
              'en': 'Regular Teacher',
              'id': 'Guru Biasa',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedHomeroomFilter = null;
          });
          _checkActiveFilter();
          _loadData(); // Reload data setelah remove filter
        },
      });
    }

    if (_selectedGender != null) {
      final genderText = _selectedGender == 'L'
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
            _selectedGender = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedEmploymentStatus != null) {
      final statusLabel = _availableEmploymentStatus.firstWhere(
        (s) => s['value'].toString() == _selectedEmploymentStatus,
        orElse: () => {'label': _selectedEmploymentStatus},
      )['label'];
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Employment', 'id': 'Status Kepegawaian'})}: $statusLabel',
        'onRemove': () {
          setState(() {
            _selectedEmploymentStatus = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedTeachingClassId != null) {
      final className = _availableClass.firstWhere(
        (c) => c['id'].toString() == _selectedTeachingClassId,
        orElse: () => {'name': _selectedTeachingClassId},
      )['name'];
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Teaching', 'id': 'Kelas Ajar'})}: $className',
        'onRemove': () {
          setState(() {
            _selectedTeachingClassId = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherFilterSheet(
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
          _checkActiveFilter();
          _loadData();
        },
      ),
    );
  }


  /// Build cache key — only cache default view (page 1, no filters/search).
  String? _buildTeacherCacheKey() {
    if (_currentPage != 1) return null;
    if (_selectedClassId != null ||
        _selectedHomeroomFilter != null ||
        _selectedGender != null ||
        _selectedEmploymentStatus != null ||
        _selectedTeachingClassId != null ||
        _showAllTeachers ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return CacheKeyBuilder.custom('teacher_list', yearId);
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _hasMoreData = true;

        // ─── Step 1: Load from cache for instant display ───
        if (useCache) {
          final cacheKey = _buildTeacherCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null && mounted) {
                final cachedData = Map<String, dynamic>.from(cached);
                setState(() {
                  _teachers = List<dynamic>.from(cachedData['teachers'] ?? []);
                  _subjects = List<dynamic>.from(cachedData['subjects'] ?? []);
                  _classes = List<dynamic>.from(cachedData['classes'] ?? []);
                  _hasMoreData =
                      cachedData['pagination']?['has_next_page'] ?? false;
                  _isLoading = false;
                  _errorMessage = null;
                });
                AppLogger.info('teacher', 'Teachers loaded from cache');
                // Cache hit → trigger tour immediately (cache pre-fetched by dashboard)
                _checkAndShowTour();
                return;
              }
            } catch (e) {
              AppLogger.error('teacher', 'Teacher cache load failed: $e');
            }
          }
        }

        // Show skeleton only if no cached data displayed
        if (_teachers.isEmpty && mounted) {
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

      // Load subjects and classes (for dropdown/reference)
      final subjectData = await _subjectService.getSubject();
      final classData = await getIt<ApiClassService>().getClass(
        academicYearId: selectedYearId,
      );

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = _showAllTeachers ? null : selectedYearId;

      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        classId: _selectedHomeroomFilter == 'wali_kelas'
            ? _selectedClassId
            : null,
        gender: _selectedGender,
        employmentStatus: _selectedEmploymentStatus,
        teachingClassId: _selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        useCache: useCache,
      );

      if (!mounted) return;

      setState(() {
        _teachers = response['data'] ?? [];
        _subjects = subjectData;
        _classes = classData;
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // ─── Step 3: Save to cache (only for default view) ───
      final cacheKey = _buildTeacherCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'teachers': response['data'] ?? [],
          'subjects': subjectData,
          'classes': classData,
          'pagination': response['pagination'],
        });
      }
    } catch (e) {
      AppLogger.error('teacher', 'Load teachers error: $e');
      if (!mounted) return;

      // Only show error if no cached data displayed
      if (_teachers.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      } else {
        setState(() => _isLoading = false);
      }

      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Failed to load data: ${ErrorUtils.getFriendlyMessage(e)}',
          'id': '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        }),
      );
    } finally {
      // Trigger tour (cache pre-fetched by dashboard, no delay needed)
      _checkAndShowTour();
    }
  }

  /// Force refresh: clear cache and reload from API
  Future<void> _forceRefresh() async {
    final cacheKey = _buildTeacherCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_teacher_admin_');
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('teacher_filter_options', yearId),
    );
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> onRefresh() async {
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Load next page
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = _showAllTeachers ? null : selectedYearId;

      // Load next page
      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        classId: _selectedHomeroomFilter == 'wali_kelas'
            ? _selectedClassId
            : null,
        gender: _selectedGender,
        employmentStatus: _selectedEmploymentStatus,
        teachingClassId: _selectedTeachingClassId,
        academicYearId: effectiveAcademicYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _teachers.addAll(response['data'] ?? []);
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      AppLogger.info(
        'teacher',
        'Loaded more data: Page $_currentPage, Total items: ${_teachers.length}',
      );
    } catch (e) {
      AppLogger.error('teacher', 'Error loading more data: $e');
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });
    }
  }

  // Export teachers to Excel
  Future<void> exportToExcel() async {
    try {
      if (!mounted) return;
      SnackBarUtils.showInfo(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Preparing export...',
          'id': 'Menyiapkan export...',
        }),
      );

      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // If showing all teachers, ignore academic year
      final effectiveAcademicYearId = _showAllTeachers ? null : selectedYearId;

      // Fetch all teachers with current filters
      final response = await getIt<ApiTeacherService>().getTeachersPaginated(
        page: 1,
        limit: 10000, // Fetch all data
        classId: _selectedClassId,
        gender: null,
        academicYearId: effectiveAcademicYearId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      final allTeachers = response['data'] ?? [];

      await ExcelTeacherService.exportTeachersToExcel(
        teachers: allTeachers,
        context: context,
      );
    } catch (e) {
      AppLogger.error('teacher', 'Export teachers error: $e');
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

  // Import teachers from Excel
  Future<void> importFromExcel() async {
    final languageProvider = ref.read(languageRiverpod);

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final pickedFile = File(result.files.single.path!);
        AppLogger.debug(
          'teacher',
          'Import teachers - picked file: ${pickedFile.path}, size: ${await pickedFile.length()} bytes',
        );

        try {
          final response = await getIt<ApiTeacherService>()
              .importTeachersFromExcel(pickedFile);
          AppLogger.debug('teacher', 'Import response: $response');

          // If backend returned structured errors, show them to user
          // show errors array if present
          if (response['errors'] != null &&
              response['errors'] is List &&
              (response['errors'] as List).isNotEmpty) {
            final errors = (response['errors'] as List).take(10).join('\n');
            if (!mounted) return;
            SnackBarUtils.showWarning(
              context,
              'Import finished with errors:\n$errors',
            );
          } else if (response['error'] != null) {
            if (!mounted) return;
            SnackBarUtils.showError(
              context,
              'Import failed: ${response['error']}',
            );
          } else {
            if (!mounted) return;
            SnackBarUtils.showSuccess(
              context,
              languageProvider.getTranslatedText({
                'en': 'Import completed',
                'id': 'Import selesai',
              }),
            );
          }

          // Refresh data setelah import
          await _loadData();
        } catch (apiError) {
          AppLogger.error('teacher', 'Error calling import API: $apiError');
          if (!mounted) return;
          SnackBarUtils.showError(
            context,
            languageProvider.getTranslatedText({
              'en':
                  'Failed to import file: ${ErrorUtils.getFriendlyMessage(apiError)}',
              'id':
                  '${AppLocalizations.failedToImport.tr}: ${ErrorUtils.getFriendlyMessage(apiError)}',
            }),
          );
        }
      }
    } catch (e) {
      AppLogger.error('teacher', 'Import from Excel picker/process error: $e');
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

  // Download template
  Future<void> downloadTemplate() async {
    await ExcelTeacherService.downloadTemplate(context);
  }

  void _openTeacherFormDialog({Map<String, dynamic>? teacher}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherFormDialog(
        teacher: teacher,
        subjects: _subjects,
        classes: _classes,
        onSaved: _loadData,
      ),
    );
  }



  Future<void> deleteTeacher(Map<String, dynamic> teacher) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete Teacher',
          'id': 'Hapus Guru',
        }),
        content: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Are you sure you want to delete this teacher?',
          'id': 'Apakah Anda yakin ingin menghapus guru ini?',
        }),
        confirmText: ref.read(languageRiverpod).getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        final teacherId = teacher['id']?.toString();
        if (teacherId != null && teacherId.isNotEmpty) {
          await _teacherService.deleteTeacher(teacherId);
          if (mounted) {
            SnackBarUtils.showSuccess(
              context,
              ref.read(languageRiverpod).getTranslatedText({
                'en': 'Teacher successfully deleted',
                'id': 'Guru berhasil dihapus',
              }),
            );
          }
          _loadData();
        }
      } catch (error) {
        AppLogger.error('teacher', 'Delete teacher error: $error');
        if (mounted) {
          SnackBarUtils.showError(
            context,
            '${ref.read(languageRiverpod).getTranslatedText({'en': 'Failed to delete teacher: ', 'id': 'Gagal menghapus guru: '})}${ErrorUtils.getFriendlyMessage(error)}',
          );
        }
      }
    }
  }

  void navigateToDetail(Map<String, dynamic> teacher) {
    AppNavigator.push(context, TeacherDetailScreen(teacher: teacher));
  }



  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.7)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    if (_errorMessage != null) {
      return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
    }

    // Local filtering removed - relying on backend search
    final displayedTeachers = _teachers;

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          // Header
          GradientPageHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Teacher Management',
              'id': 'Manajemen Guru',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'Manage and monitor teachers',
              'id': 'Kelola dan pantau guru',
            }),
            primaryColor: getPrimaryColor(),
            actionMenu: PopupMenuButton<String>(
              key: _menuKey,
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _forceRefresh();
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
              icon: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(Icons.more_vert, color: Colors.white, size: 20),
              ),
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                      const SizedBox(width: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.sm),
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
                      const SizedBox(width: AppSpacing.sm),
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
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Search teachers...',
                                'id': 'Cari guru...',
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
                          margin: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Icon(Icons.search, color: getPrimaryColor()),
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
                const SizedBox(width: AppSpacing.sm),
                // Filter Button
                Container(
                  key: _filterKey,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                              ? getPrimaryColor()
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
                            padding: const EdgeInsets.all(AppSpacing.xs),
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
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                          ),
                          child: Icon(
                            Icons.filter_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ..._buildFilterChips(languageProvider).map((
                                filter,
                              ) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      filter['label'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: getPrimaryColor(),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: getPrimaryColor(),
                                    ),
                                    onDeleted: filter['onRemove'],
                                    backgroundColor: getPrimaryColor()
                                        .withValues(alpha: 0.1),
                                    side: BorderSide(
                                      color: getPrimaryColor().withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    labelPadding: const EdgeInsets.only(left: 4),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
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
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _isLoading && _teachers.isEmpty
                ? SkeletonListLoading(itemCount: 6, infoTagCount: 2)
                : displayedTeachers.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No teachers',
                      'id': 'Tidak ada guru',
                    }),
                    subtitle:
                        _searchController.text.isEmpty && !_hasActiveFilter
                        ? languageProvider.getTranslatedText({
                            'en': 'Tap + to add a teacher',
                            'id': 'Tap + untuk menambah guru',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'No search results found',
                            'id': 'Tidak ditemukan hasil pencarian',
                          }),
                    icon: Icons.person_outline,
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount:
                          displayedTeachers.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Show loading indicator at bottom
                        if (index == displayedTeachers.length) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        final teacher = displayedTeachers[index];
                        return TeacherCard(
                          teacher: teacher,
                          index: index,
                          onTap: () => navigateToDetail(teacher),
                          onEdit: () => _openTeacherFormDialog(teacher: teacher),
                          onDelete: () => deleteTeacher(teacher),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: ref.read(academicYearRiverpod).isReadOnly
          ? null
          : FloatingActionButton(
              key: _fabKey,
              onPressed: _openTeacherFormDialog,
              backgroundColor: getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'teacher_admin_screen',
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
      AppLogger.error('teacher', 'Error checking tour status: $e');
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
          name: 'teacher_admin_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('teacher_admin_screen', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'teacher_admin_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('teacher_admin_screen', 'admin'),
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
        identify: "TeacherMenu",
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
                      'en': 'Teacher Data Tools',
                      'id': 'Alat Data Guru',
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
                            'Export, import, or download teacher templates from this menu.',
                        'id':
                            'Ekspor, impor, atau unduh template data guru dari menu ini.',
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
        identify: "TeacherSearch",
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
                      'en': 'Find Teachers',
                      'id': 'Cari Guru',
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
                            'Search by name or email to quickly find a specific teacher.',
                        'id':
                            'Cari berdasarkan nama atau email untuk menemukan guru tertentu dengan cepat.',
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
        identify: "TeacherFilter",
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
                        'en': 'Filter by class, gender, or employment status.',
                        'id':
                            'Filter berdasarkan kelas, jenis kelamin, atau status kepegawaian.',
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
        identify: "AddTeacher",
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
                      'en': 'Add Teacher',
                      'id': 'Tambah Guru',
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
                        'en': 'Tap here to add a new teacher record.',
                        'id': 'Ketuk di sini untuk menambahkan data guru baru.',
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
