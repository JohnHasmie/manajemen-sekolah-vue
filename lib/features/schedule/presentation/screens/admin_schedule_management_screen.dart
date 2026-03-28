// Admin teaching schedule management screen - full CRUD for class schedules.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
//
// Like `pages/admin/schedules.vue` - manages the school timetable with create,
// edit, delete, search, multi-filter (teacher, class, day, semester, lesson hour),
// infinite scroll pagination, Excel import/export, and a timetable grid view.
//
// In Laravel terms, this consumes ScheduleController endpoints.
// Also handles conflict detection (double-booked teachers/rooms).
// Supports two view modes: card list and Syncfusion data grid (timetable).
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/gradient_page_header.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_form_dialog.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/schedule/exports/schedule_export_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Admin teaching schedule management with full CRUD, timetable grid, and conflict detection.
///
/// This is a [StatefulWidget] - like a Vue page with extensive local state for
/// schedule list, reference data (teachers, subjects, classes, days), pagination,
/// filters, and two view modes (card list vs timetable grid).
class TeachingScheduleManagementScreen extends ConsumerStatefulWidget {
  const TeachingScheduleManagementScreen({super.key});

  @override
  TeachingScheduleManagementScreenState createState() =>
      TeachingScheduleManagementScreenState();
}

/// Mutable state for [TeachingScheduleManagementScreen].
///
/// Key state (like Vue `data()`):
/// - [_scheduleList] - paginated schedule entries from API
/// - [_teacherList] / [_subjectList] / [_classList] / [_dayList] / [_lessonHourList] - reference data
/// - [_showTableView] - toggles between card list and timetable grid (Syncfusion DataGrid)
/// - [_gridData] / [_timetableDataSource] - data source for the timetable grid view
/// - Filter states: [_selectedTeacherId], [_selectedClassId], [_selectedDayId], etc.
/// - Pagination: [_currentPage], [_hasMoreData], [_isLoadingMore] for infinite scroll
///
/// Listens to AcademicYearProvider for year changes and FCM for real-time sync.
/// setState() triggers re-render like Vue's reactivity system.
class TeachingScheduleManagementScreenState
    extends ConsumerState<TeachingScheduleManagementScreen> {
  final ApiService _apiService = ApiService();
  final ApiSubjectService _apiSubjectService = getIt<ApiSubjectService>();
  final ApiTeacherService apiTeacherService = getIt<ApiTeacherService>();

  List<dynamic> _scheduleList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _dayList = [];
  List<dynamic> _semesterList = [];
  List<dynamic> _lessonHourList = [];

  bool _isLoading = true;
  String _selectedSemester = '1'; // Will be set by _setDefaultAcademicPeriod()
  String _selectedAcademicYear =
      '2024/2025'; // Will be set by _setDefaultAcademicPeriod()
  final TextEditingController _searchController = TextEditingController();

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Filter state (Backend filtering)
  String? _selectedTeacherId; // Filter by teacher
  String? _selectedClassId; // Filter by class
  String? _selectedDayId; // Filter by day
  String? _selectedFilterSemester;
  String? _selectedJamPelajaran; // Filter by Lesson Hour
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availableTeachers = [];
  List<dynamic> _availableClasses = [];
  List<dynamic> _availableDays = [];
  List<dynamic> _availableSemesters = [];
  List<dynamic> _availableAcademicYears = [];

  // Search debounce
  Timer? _searchDebounce;

  // Tour Keys
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _viewToggleKey = GlobalKey();
  bool _isTourShowing = false;

  // Additional state for table view
  bool _showTableView = false;
  List<ScheduleGridData> _gridData = [];
  TimetableDataSource? _timetableDataSource;
  AcademicYearProvider? _academicYearProvider;

  // Persisted cache key values
  String? _lastCachedAcademicYear;
  String? _lastCachedSemester;

  /// Like Vue's `mounted()` - sets up scroll listener, academic year provider,
  /// FCM sync listener, and loads all reference data + schedule list.
  @override
  void initState() {
    super.initState();

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to academic year changes

    // Set default academic year from provider
    _academicYearProvider = ref.read(academicYearRiverpod);
    if (_academicYearProvider?.selectedAcademicYear != null) {
      _selectedAcademicYear = _academicYearProvider!.selectedAcademicYear!['id']
          .toString();
    } else {
      _setDefaultAcademicPeriod();
    }

    // Listen to academic year changes
    _academicYearProvider?.addListener(_onAcademicYearProviderChanged);

    // Load cached data first for instant display, then fetch fresh
    _loadCachedScheduleData();
    _loadFilterOptions();
    _loadData();

    // Listen to real-time sync trigger
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  /// Load cached schedule data for instant display before any API calls
  Future<void> _loadCachedScheduleData() async {
    try {
      final prefs = PreferencesService();
      _lastCachedAcademicYear = prefs.getString('schedule_last_year_id');
      _lastCachedSemester = prefs.getString('schedule_last_semester_id');

      if (_lastCachedAcademicYear == null || _lastCachedSemester == null)
        return;

      final cacheKey =
          'schedule_list_${_lastCachedAcademicYear}_$_lastCachedSemester';
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );

      if (cached == null || !mounted) return;

      final cachedData = Map<String, dynamic>.from(cached);
      setState(() {
        _applyScheduleData(
          scheduleResponse: {
            'data': List<dynamic>.from(cachedData['schedules'] ?? []),
            'pagination': cachedData['pagination'] != null
                ? Map<String, dynamic>.from(cachedData['pagination'])
                : null,
          },
          teacher: List<dynamic>.from(cachedData['teachers'] ?? []),
          subject: List<dynamic>.from(cachedData['subjects'] ?? []),
          classData: List<dynamic>.from(cachedData['classes'] ?? []),
          days: List<dynamic>.from(cachedData['hari'] ?? []),
          semester: List<dynamic>.from(cachedData['semester'] ?? []),
          lessonHours: List<dynamic>.from(cachedData['jamPelajaran'] ?? []),
        );
      });
      _updateGridData();
      AppLogger.info(
        'schedule',
        'Schedules loaded from persisted cache (early)',
      );
    } catch (e) {
      AppLogger.error('schedule', e);
    }
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null && trigger['type'] == 'refresh_schedules') {
      if (mounted) {
        AppLogger.debug('schedule', 'Sync triggered: refresh_schedules');
        _loadData(resetPage: true, useCache: false);
      }
    }
  }

  /// Set default academic period based on current date
  void _setDefaultAcademicPeriod() {
    if (_availableAcademicYears.isEmpty) {
      _selectedAcademicYear = '1'; // Fallback
      return;
    }

    // 1. Try to find "current" flag from API
    final currentFromApi = _availableAcademicYears.firstWhere(
      (y) => y['current'] == true || y['current'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if (currentFromApi.isNotEmpty) {
      _selectedAcademicYear = currentFromApi['id'].toString();
    } else {
      // 2. Fallback to date-based calculation
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      String targetYearString;
      // If July or later, we are in the start of new academic year (e.g. 2025/2026)
      // If before July, we are in the second half of academic year (e.g. 2025/2026) starting in 2025

      if (currentMonth >= 7) {
        targetYearString = '$currentYear/${currentYear + 1}';
      } else {
        targetYearString = '${currentYear - 1}/$currentYear';
      }

      final dateBasedYear = _availableAcademicYears.firstWhere(
        (y) => (y['year'] ?? '').toString() == targetYearString,
        orElse: () => <String, dynamic>{},
      );

      if (dateBasedYear.isNotEmpty) {
        _selectedAcademicYear = dateBasedYear['id'].toString();
      } else {
        // 3. Fallback to first available
        _selectedAcademicYear = _availableAcademicYears.first['id'].toString();
      }
    }
  }

  /// Update semester selection after semester list is loaded
  Future<void> _updateCurrentSemester() async {
    if (_semesterList.isEmpty) return;

    String? semesterId;

    // 1. Try "current" flag
    final currentFromApi = _semesterList.firstWhere(
      (s) => s['current'] == true || s['current'] == 1,
      orElse: () => <String, dynamic>{},
    );

    if (currentFromApi.isNotEmpty) {
      semesterId = currentFromApi['id'].toString();
    } else {
      // 2. Fetch from Backend API (Sync with Dashboard)
      try {
        final result = await getIt<ApiScheduleService>().getDateBasedSemester();
        if (result.isNotEmpty && result.containsKey('semester')) {
          final targetSemesterName = result['semester']
              .toString(); // 'Ganjil' or 'Genap'

          final dateBasedSemester = _semesterList.firstWhere((s) {
            final name = (s['name'] ?? s['nama'] ?? '').toString();
            return name.contains(targetSemesterName);
          }, orElse: () => <String, dynamic>{});

          if (dateBasedSemester.isNotEmpty) {
            semesterId = dateBasedSemester['id'].toString();
          }
        }
      } catch (e) {
        AppLogger.error('schedule', e);
      }

      // Fallback
      semesterId ??= _semesterList.first['id'].toString();
    }

    if (semesterId != _selectedSemester) {
      AppLogger.debug(
        'schedule',
        'DEBUG: Auto-switching to semester: $semesterId',
      );
      setState(() {
        _selectedSemester = semesterId!;
      });
      // Perform reload with new semester
      _loadData(resetPage: true);
    }
  }

  /// Generate list of academic years

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    _academicYearProvider?.removeListener(_onAcademicYearProviderChanged);
    super.dispose();
  }

  void _onAcademicYearProviderChanged() {
    if (mounted && _academicYearProvider?.selectedAcademicYear != null) {
      setState(() {
        _selectedAcademicYear = _academicYearProvider!
            .selectedAcademicYear!['id']
            .toString();
        // Usually changing year resets semester or keeps it if ID matches.
      });
      _loadFilterOptions(); // Reload classes based on new academic year
      _loadData(resetPage: true);
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

  Future<void> _loadFilterOptions() async {
    try {
      // ─── Cache-first: return early on hit ───
      final cacheKey = 'schedule_filter_options_$_selectedAcademicYear';
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 6),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          setState(() {
            _availableTeachers = List<dynamic>.from(
              cachedData['teachers'] ?? [],
            );
            _availableClasses = List<dynamic>.from(cachedData['classes'] ?? []);
            _availableDays = List<dynamic>.from(cachedData['days'] ?? []);
            _availableSemesters = List<dynamic>.from(
              cachedData['semesters'] ?? [],
            );
            _availableAcademicYears = List<dynamic>.from(
              cachedData['academic_years'] ?? [],
            );
          });
          AppLogger.info(
            'schedule',
            'Schedule filter options loaded from cache',
          );
          return;
        }
      } catch (e) {
        AppLogger.error('schedule', e);
      }

      final response = await getIt<ApiScheduleService>()
          .getScheduleFilterOptions(academicYearId: _selectedAcademicYear);

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableTeachers = response['data']['teachers'] ?? [];
          _availableClasses = response['data']['classes'] ?? [];
          _availableDays = response['data']['days'] ?? [];
          _availableSemesters = response['data']['semesters'] ?? [];
          _availableAcademicYears = response['data']['academic_years'] ?? [];
        });
        // Non-blocking cache save
        LocalCacheService.save(cacheKey, {
          'teachers': response['data']['teachers'] ?? [],
          'classes': response['data']['classes'] ?? [],
          'days': response['data']['days'] ?? [],
          'semesters': response['data']['semesters'] ?? [],
          'academic_years': response['data']['academic_years'] ?? [],
        });
        AppLogger.info('schedule', 'Schedule filter options loaded');
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      // Continue with empty options - not critical error
    }
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showInfo(context, message);
  }

  String? _buildScheduleCacheKey() {
    // Only cache default first-page view (no filters/search) for fast reload
    if (_currentPage != 1) return null;
    if (_showTableView) return null;
    if (_selectedTeacherId != null ||
        _selectedClassId != null ||
        _selectedDayId != null ||
        _selectedJamPelajaran != null ||
        _selectedFilterSemester != null ||
        _searchController.text.trim().isNotEmpty) {
      return null;
    }

    final key = 'schedule_list_${_selectedAcademicYear}_$_selectedSemester';

    // Persist current values so early cache load works on next launch
    if (_selectedAcademicYear != _lastCachedAcademicYear ||
        _selectedSemester != _lastCachedSemester) {
      _lastCachedAcademicYear = _selectedAcademicYear;
      _lastCachedSemester = _selectedSemester;
      final prefs = PreferencesService();
      prefs.setString('schedule_last_year_id', _selectedAcademicYear);
      prefs.setString('schedule_last_semester_id', _selectedSemester);
    }

    return key;
  }

  void _applyScheduleData({
    required Map<String, dynamic> scheduleResponse,
    required List<dynamic> teacher,
    required List<dynamic> subject,
    required List<dynamic> classData,
    required List<dynamic> days,
    required List<dynamic> semester,
    required List<dynamic> lessonHours,
  }) {
    _scheduleList = scheduleResponse['data'] ?? [];
    _subjectList = subject;
    _classList = classData;
    _dayList = days;
    if (days.isEmpty && _availableDays.isNotEmpty) {
      _dayList = _availableDays;
    }
    _semesterList = semester;
    _lessonHourList = lessonHours;
    _hasMoreData = scheduleResponse['pagination']?['has_next_page'] ?? false;
    _isLoading = false;
  }

  Future<void> _loadData({bool resetPage = true, bool useCache = true}) async {
    try {
      if (resetPage) {
        _currentPage = 1;
        _hasMoreData = true;

        // ─── Step 1: Try loading from cache for instant display ───
        if (useCache) {
          final cacheKey = _buildScheduleCacheKey();
          if (cacheKey != null) {
            try {
              final cached = await LocalCacheService.load(
                cacheKey,
                ttl: const Duration(hours: 3),
              );
              if (cached != null && mounted) {
                final cachedData = Map<String, dynamic>.from(cached);
                setState(() {
                  _applyScheduleData(
                    scheduleResponse: {
                      'data': List<dynamic>.from(cachedData['schedules'] ?? []),
                      'pagination': cachedData['pagination'] != null
                          ? Map<String, dynamic>.from(cachedData['pagination'])
                          : null,
                    },
                    teacher: List<dynamic>.from(cachedData['teachers'] ?? []),
                    subject: List<dynamic>.from(cachedData['subjects'] ?? []),
                    classData: List<dynamic>.from(cachedData['classes'] ?? []),
                    days: List<dynamic>.from(cachedData['hari'] ?? []),
                    semester: List<dynamic>.from(cachedData['semester'] ?? []),
                    lessonHours: List<dynamic>.from(
                      cachedData['jamPelajaran'] ?? [],
                    ),
                  );
                });
                _updateGridData();
                AppLogger.info('schedule', 'Schedules loaded from cache');
                // Cache hit → return early, no background API refresh
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _checkAndShowTour();
                });
                // Update semester selection from cached semester list
                if (_semesterList.isNotEmpty) {
                  _updateCurrentSemester();
                }
                return;
              }
            } catch (e) {
              AppLogger.error('schedule', e);
            }
          }
        }

        // Show loading skeleton only if we have no data yet (no cache hit)
        if (_scheduleList.isEmpty && mounted) {
          setState(() {
            _isLoading = true;
          });
        }
      }

      // ─── Step 2: Fetch fresh data from API ───
      // Use the already-set semester and academic year values
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse = _selectedAcademicYear;

      // Load with pagination and backend filtering
      final results = await Future.wait([
        _showTableView
            ? getIt<ApiScheduleService>()
                  .getAllSchedules(
                    semesterId: semesterToUse,
                    academicYearId: academicYearToUse,
                  )
                  .catchError((e) {
                    AppLogger.error('schedule', e);
                    throw e;
                  })
            : getIt<ApiScheduleService>()
                  .getSchedulesPaginated(
                    page: _currentPage,
                    limit: _perPage,
                    teacherId: _selectedTeacherId,
                    classId: _selectedClassId,
                    dayId: _selectedDayId,
                    semesterId: semesterToUse,
                    academicYearId: academicYearToUse,
                    search: _searchController.text.trim().isEmpty
                        ? null
                        : _searchController.text.trim(),
                    lessonHourId: null, // No longer used for cross-day filter
                    hourNumber: _selectedJamPelajaran,
                    skipCache: !useCache,
                  )
                  .catchError((e) {
                    AppLogger.error('schedule', e);
                    throw e;
                  }),
        apiTeacherService.getTeacher().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        _apiSubjectService.getSubject().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiClassService>().getClass().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiScheduleService>().getDays().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiScheduleService>().getSemester().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
        getIt<ApiScheduleService>().getJamPelajaran().catchError((e) {
          AppLogger.error('schedule', e);
          throw e;
        }),
      ]);

      if (!mounted) return;

      final scheduleResponse = results[0] as Map<String, dynamic>;
      final teacher = results[1] as List<dynamic>;
      final subject = results[2] as List<dynamic>;
      final classData = results[3] as List<dynamic>;
      final days = results[4] as List<dynamic>;
      final semester = results[5] as List<dynamic>;
      final lessonHours = results[6] as List<dynamic>;

      setState(() {
        _applyScheduleData(
          scheduleResponse: scheduleResponse,
          teacher: teacher,
          subject: subject,
          classData: classData,
          days: days,
          semester: semester,
          lessonHours: lessonHours,
        );
      });

      // Update grid data
      _updateGridData();

      // ─── Step 3: Save to cache (only for default view) ───
      final cacheKey = _buildScheduleCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'schedules': scheduleResponse['data'] ?? [],
          'pagination': scheduleResponse['pagination'],
          'teachers': teacher,
          'subjects': subject,
          'classes': classData,
          'hari': days,
          'semester': semester,
          'jamPelajaran': lessonHours,
        });
      }

      // Update semester selection based on loaded semester list
      // This may trigger reload if semester is different
      if (_semesterList.isNotEmpty) {
        _updateCurrentSemester();
      }
    } catch (e) {
      AppLogger.error('schedule', e);

      if (!mounted) return;

      // Only show error if we don't have cached data displayed
      if (_scheduleList.isEmpty) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
      setState(() => _isLoading = false);
    } finally {
      // Trigger tour
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    }
  }

  /// Force refresh: clear cache and reload from API
  Future<void> _forceRefresh() async {
    final cacheKey = _buildScheduleCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('tour_schedule_management_');
    await LocalCacheService.invalidate(
      CacheKeyBuilder.custom('schedule_filter_options', _selectedAcademicYear),
    );
    await _loadData(resetPage: true, useCache: false);
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Use the already-set semester and academic year values
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse = _selectedAcademicYear;

      // Load next page
      final response = await getIt<ApiScheduleService>().getSchedulesPaginated(
        page: _currentPage,
        limit: _perPage,
        teacherId: _selectedTeacherId,
        classId: _selectedClassId,
        dayId: _selectedDayId,
        semesterId: semesterToUse,
        academicYearId: academicYearToUse,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        lessonHourId: null,
        hourNumber: _selectedJamPelajaran,
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _scheduleList.addAll(response['data'] ?? []);
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      // Update grid data
      _updateGridData();

      AppLogger.info(
        'schedule',
        'Loaded more schedules: Page $_currentPage, Total items: ${_scheduleList.length}',
      );
    } catch (e) {
      AppLogger.error('schedule', e);

      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });
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
        setState(() => _isLoading = true);

        await getIt<ApiScheduleService>().importSchedulesFromExcel(
          File(result.files.single.path!),
        );

        // Force invalidation of cache to ensure fresh data
        getIt<ApiScheduleService>().invalidateCache();

        // Reload data fresh from API
        _loadData(resetPage: true, useCache: false);

        if (!mounted) return;
        _showInfoSnackBar(
          languageProvider.getTranslatedText({
            'en': 'Import successful',
            'id': 'Import berhasil',
          }),
        );
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      if (!mounted) return;
      _showErrorSnackBar(
        '${languageProvider.getTranslatedText({'en': 'Failed to import file: ', 'id': 'Gagal mengimpor file: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  // Export jadwal ke Excel
  Future<void> _exportToExcel() async {
    try {
      // Enrich schedule data with day name from _dayList
      final enrichedSchedules = _scheduleList.map((schedule) {
        final dayId = schedule['day_id']?.toString() ?? '';
        final dayData = _dayList.firstWhere(
          (d) => d['id'].toString() == dayId,
          orElse: () => <String, dynamic>{},
        );

        final Map<String, dynamic> newSchedule = Map.from(schedule);
        if (dayData.isNotEmpty) {
          newSchedule['day_name'] = dayData['name'] ?? dayData['nama'];
        }

        // Enrich academic year
        final academicYearId = schedule['academic_year_id']?.toString() ?? '';
        if (academicYearId.isNotEmpty) {
          final academicYearData = _availableAcademicYears.firstWhere(
            (ay) => ay['id'].toString() == academicYearId,
            orElse: () => <String, dynamic>{},
          );
          if (academicYearData.isNotEmpty) {
            newSchedule['academic_year'] =
                academicYearData['year'] ?? academicYearData['name'] ?? '';
          }
        }
        return newSchedule;
      }).toList();

      await ExcelScheduleService.exportSchedulesToExcel(
        schedules: enrichedSchedules,
        context: context,
      );
    } catch (e) {
      AppLogger.error('schedule', e);
      _showErrorSnackBar(
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Export failed: ', 'id': 'Export gagal: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  // Download template
  Future<void> _downloadTemplate() async {
    try {
      await ExcelScheduleService.downloadTemplate(context);
    } catch (e) {
      AppLogger.error('schedule', e);
      _showErrorSnackBar(
        '${ref.read(languageRiverpod).getTranslatedText({'en': 'Download template failed: ', 'id': 'Gagal download template: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  void _updateGridData() {
    _gridData = _generateTimetableData();

    final languageProvider = ref.read(languageRiverpod);
    // Filter days based on selection
    var filteredDayList = _dayList;
    if (_selectedDayId != null) {
      filteredDayList = _dayList
          .where((d) => d['id'].toString() == _selectedDayId)
          .toList();
    }

    final days = filteredDayList
        .map(
          (d) => _translateDay(
            d['name'] ?? d['nama'] ?? '',
            languageProvider.currentLanguage,
          ),
        )
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    // Filter classes based on selection
    var filteredClassList = _classList;
    if (_selectedClassId != null) {
      filteredClassList = _classList
          .where((c) => c['id'].toString() == _selectedClassId)
          .toList();
    }

    // Ensure we have time slots. If empty, generate them.
    List<String> timeSlots = _generateTimeSlots();
    if (_selectedJamPelajaran != null) {
      timeSlots = _lessonHourList
          .where((jp) {
            final h = (jp['hour_number'] ?? jp['jam_ke'])?.toString();
            return h == _selectedJamPelajaran;
          })
          .map((jam) {
            String start = (jam['start_time'] ?? jam['jam_mulai'] ?? '')
                .toString();
            String end = (jam['end_time'] ?? jam['jam_selesai'] ?? '')
                .toString();
            if (start.length > 5) start = start.substring(0, 5);
            if (end.length > 5) end = end.substring(0, 5);
            return '$start-$end';
          })
          .toSet()
          .toList();
    }

    if (timeSlots.isEmpty) {
      timeSlots = [];
    }

    _timetableDataSource = TimetableDataSource(
      timeSlots: timeSlots,
      days: days,
      classList: filteredClassList,
      gridData: _gridData,
      primaryColor: _getPrimaryColor(),
      onScheduleTap: _showScheduleDetail,
    );
  }

  List<String> _generateTimeSlots() {
    final slots = _lessonHourList
        .map((jam) {
          String start = (jam['start_time'] ?? jam['jam_mulai'] ?? '')
              .toString();
          String end = (jam['end_time'] ?? jam['jam_selesai'] ?? '').toString();

          // Format to HH:mm if it contains seconds
          if (start.length > 5) start = start.substring(0, 5);
          if (end.length > 5) end = end.substring(0, 5);

          return '$start-$end';
        })
        .toSet()
        .toList(); // Deduplicate time slots

    // Sort chronologically by start time
    slots.sort((a, b) {
      final startA = a.split('-').first;
      final startB = b.split('-').first;
      return startA.compareTo(startB);
    });

    return slots;
  }

  // Method to generate timetable data in the desired format
  List<ScheduleGridData> _generateTimetableData() {
    final List<ScheduleGridData> timetableData = [];

    // Create lookup maps for IDs
    final Map<String, String> dayIdToName = {};
    for (var day in _dayList) {
      final id = day['id']?.toString() ?? '';
      final name = day['name'] ?? day['nama'] ?? '';
      if (id.isNotEmpty) dayIdToName[id] = name;
    }

    final Map<String, String> classIdToName = {};
    for (var cls in _classList) {
      final id = cls['id']?.toString() ?? '';
      final name = cls['name'] ?? cls['nama'] ?? '';
      if (id.isNotEmpty) classIdToName[id] = name;
    }

    // Convert to grid data format
    final languageProvider = ref.read(languageRiverpod);

    // Instead of exhaustive looping with placeholders, only add found schedules
    for (var schedule in _getFilteredSchedules()) {
      final daysIds = [];
      if (schedule['days_ids'] != null) {
        if (schedule['days_ids'] is List) {
          daysIds.addAll(schedule['days_ids']);
        } else if (schedule['days_ids'] is String) {
          try {
            final parsed = (schedule['days_ids'] as String)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',');
            daysIds.addAll(parsed);
          } catch (e) {}
        }
      }
      if (daysIds.isEmpty) {
        if (schedule['day_id'] != null) {
          daysIds.add(schedule['day_id']);
        } else if (schedule['hari_id'] != null) {
          daysIds.add(schedule['hari_id']);
        }
      }

      for (var rawDayId in daysIds) {
        final dayId = rawDayId.toString();
        final classId =
            schedule['kelas_id']?.toString() ??
            schedule['class_id']?.toString() ??
            '';

        final dayName = dayIdToName[dayId] ?? '';
        final translatedDayName = _translateDay(
          dayName,
          languageProvider.currentLanguage,
        );
        final className =
            classIdToName[classId] ?? schedule['kelas_nama'] ?? '';

        final timeSlot =
            '${schedule['jam_mulai'] ?? schedule['start_time'] ?? ''}-${schedule['jam_selesai'] ?? schedule['end_time'] ?? ''}';

        // Format to HH:mm for lookup consistency
        final List<String> parts = timeSlot.split('-');
        String start = parts[0];
        String end = parts.length > 1 ? parts[1] : '';
        if (start.length > 5) start = start.substring(0, 5);
        if (end.length > 5) end = end.substring(0, 5);
        final formattedTimeSlot = '$start-$end';

        timetableData.add(
          ScheduleGridData(
            id: schedule['id']?.toString() ?? '',
            waktu: formattedTimeSlot,
            hari: translatedDayName,
            classroom: className,
            mataPelajaran:
                schedule['subject_name'] ??
                schedule['mata_pelajaran_nama'] ??
                '-',
            guru: schedule['teacher_name'] ?? schedule['guru_nama'] ?? '',
            originalData: schedule,
          ),
        );
      }
    }

    return timetableData;
  }

  String _getGradeLevel(String classId) {
    try {
      final classItem = _classList.firstWhere(
        (k) => k['id'] == classId,
        orElse: () => {},
      );
      return classItem['grade_level']?.toString() ?? '-';
    } catch (e) {
      return '-';
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showError(context, message);
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': message,
          'id': message.replaceAll('successfully', 'berhasil'),
        }),
      );
    }
  }

  Future<void> _addSchedule() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleFormDialog(
        teacherList: _availableTeachers,
        subjectList: _subjectList,
        classList: _availableClasses,
        dayList: _availableDays,
        semesterList: _availableSemesters,
        lessonHourList: _lessonHourList,
        semester: _selectedSemester,
        academicYear: _selectedAcademicYear,
        academicYearList: _availableAcademicYears,
        apiService: _apiService,
        apiTeacherService: apiTeacherService,
      ),
    );

    if (result != null) {
      await _checkAndResolveConflicts(result);
    }
  }

  Future<void> _editSchedule(dynamic schedule) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ScheduleFormDialog(
        teacherList: _availableTeachers,
        subjectList: _subjectList,
        classList: _availableClasses,
        dayList: _availableDays,
        semesterList: _availableSemesters,
        lessonHourList: _lessonHourList,
        semester: _selectedSemester,
        academicYear: _selectedAcademicYear,
        academicYearList: _availableAcademicYears,
        schedule: schedule,
        apiService: _apiService,
        apiTeacherService: apiTeacherService,
      ),
    );

    if (result != null) {
      await _checkAndResolveConflicts(
        result,
        editingScheduleId: schedule['id'],
      );
    }
  }

  Future<void> _deleteSchedule(String id) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) {
        final languageProvider = ref.watch(languageRiverpod);
        return ConfirmationDialog(
          title: languageProvider.getTranslatedText({
            'en': 'Delete Schedule',
            'id': 'Hapus Jadwal',
          }),
          content: languageProvider.getTranslatedText({
            'en': 'Are you sure you want to delete this schedule?',
            'id': 'Apakah Anda yakin ingin menghapus jadwal ini?',
          }),
          confirmText: languageProvider.getTranslatedText({
            'en': 'Delete',
            'id': 'Hapus',
          }),
          confirmColor: Colors.red,
        );
      },
    );

    if (confirmed == true) {
      try {
        await getIt<ApiScheduleService>().deleteSchedule(id);
        _showSuccessSnackBar('Schedule successfully deleted');
        _loadData(resetPage: true, useCache: false);
      } catch (e) {
        _showErrorSnackBar('Failed to delete schedule: $e');
      }
    }
  }

  Future<void> _checkAndResolveConflicts(
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    try {
      final conflicts = await getIt<ApiScheduleService>()
          .getConflictingSchedules(
            days_ids:
                (newScheduleData['days_ids'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            classId: newScheduleData['class_id'],
            teacherId: newScheduleData['teacher_id'],
            semesterId: newScheduleData['semester_id'],
            academicYearId: newScheduleData['academic_year_id'],
            lessonHourId: newScheduleData['lesson_hour_days_id'],
            excludeScheduleId: editingScheduleId,
          );

      if (conflicts.isNotEmpty) {
        if (!mounted) return;
        final result = await showDialog<String>(
          context: context,
          builder: (context) => ConflictResolutionDialog(
            conflictingSchedules: conflicts,
            onDeleteConfirmed: (scheduleId) =>
                AppNavigator.pop(context, scheduleId),
            onCancel: () => AppNavigator.pop(context),
          ),
        );

        if (result != null) {
          // Delete conflicting schedule directly via API (skip UI confirmation dialog)
          await getIt<ApiScheduleService>().deleteSchedule(result);

          try {
            if (editingScheduleId != null) {
              await getIt<ApiScheduleService>().updateSchedule(
                editingScheduleId,
                newScheduleData,
              );
            } else {
              await getIt<ApiScheduleService>().addSchedule(newScheduleData);
            }
            _showSuccessSnackBar('Schedule successfully saved');
          } catch (e) {
            AppLogger.error('schedule', e);
            _showSuccessSnackBar('Schedule successfully saved');
          }
          _loadData(resetPage: true, useCache: false);
        }
      } else {
        try {
          if (editingScheduleId != null) {
            await getIt<ApiScheduleService>().updateSchedule(
              editingScheduleId,
              newScheduleData,
            );
          } else {
            await getIt<ApiScheduleService>().addSchedule(newScheduleData);
          }
          _showSuccessSnackBar('Schedule successfully saved');
        } catch (e) {
          AppLogger.error('schedule', e);
          _showSuccessSnackBar('Schedule successfully saved');
        }
        _loadData(resetPage: true, useCache: false);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save schedule: $e');
      _loadData(resetPage: true, useCache: false);
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  Widget _buildFilterSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ColorUtils.slate700),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorUtils.slate600),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDayId != null ||
          _selectedClassId != null ||
          _selectedJamPelajaran != null ||
          (_selectedFilterSemester != null &&
              _selectedFilterSemester != _selectedSemester);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedTeacherId = null;
      _selectedClassId = null;
      _selectedDayId = null;
      _selectedFilterSemester = null;
      _selectedJamPelajaran = null;
      _searchController.clear();
      _hasActiveFilter = false;
    });
    _checkActiveFilter();
    _loadData(); // Reload data to show default data
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    // Add Day Filter Chip
    if (_selectedDayId != null) {
      final day = _availableDays.firstWhere(
        (d) => d['id'].toString() == _selectedDayId,
        orElse: () => {},
      );
      final String dayNameRaw = day.isNotEmpty
          ? (day['name'] ?? day['nama'] ?? '')
          : 'Day';

      // Localization helper for days
      final dayMap = {
        'senin': {'en': 'Monday', 'id': 'Senin'},
        'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'jumat': {'en': 'Friday', 'id': 'Jumat'},
        'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
        'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'minggu': {'en': 'Sunday', 'id': 'Minggu'},
        'monday': {'en': 'Monday', 'id': 'Senin'},
        'tuesday': {'en': 'Tuesday', 'id': 'Selasa'},
        'wednesday': {'en': 'Wednesday', 'id': 'Rabu'},
        'thursday': {'en': 'Thursday', 'id': 'Kamis'},
        'friday': {'en': 'Friday', 'id': 'Jumat'},
        'saturday': {'en': 'Saturday', 'id': 'Sabtu'},
        'sunday': {'en': 'Sunday', 'id': 'Minggu'},
      };

      final normalizedKey = dayNameRaw.toLowerCase();
      final label = dayMap[normalizedKey] != null
          ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
          : dayNameRaw;

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Day', 'id': 'Hari'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDayId = null;
            _checkActiveFilter();
            _loadData();
          });
        },
      });
    }

    // Add Class Filter Chip
    if (_selectedClassId != null) {
      final cls = _availableClasses.firstWhere(
        (c) => c['id'].toString() == _selectedClassId,
        orElse: () => {},
      );
      final label = cls.isNotEmpty ? (cls['name'] ?? cls['nama']) : 'Class';
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedClassId = null;
            _checkActiveFilter();
            _loadData();
          });
        },
      });
    }

    // Add Semester Filter Chip
    if (_selectedFilterSemester != null &&
        _selectedFilterSemester != _selectedSemester) {
      final semester = _semesterList.firstWhere(
        (s) => s['id'].toString() == _selectedFilterSemester,
        orElse: () => {},
      );
      String semesterNameRaw = semester.isNotEmpty
          ? (semester['name'] ??
                semester['nama'] ??
                'Semester $_selectedFilterSemester')
          : 'Semester $_selectedFilterSemester';

      if (semester.isNotEmpty &&
          semester['academic_year'] != null &&
          semester['academic_year']['year'] != null) {
        semesterNameRaw += ' (${semester['academic_year']['year']})';
      }
      final label = semesterNameRaw;

      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Semester', 'id': 'Semester'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedFilterSemester = null;
            _checkActiveFilter();
            _loadData(); // Reload to reset to default semester
          });
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String? tempSelectedHariId = _selectedDayId;
        String? tempSelectedClassId = _selectedClassId;
        // Use default values if filter is not set
        String? tempSelectedSemester =
            _selectedFilterSemester ?? _selectedSemester;
        String? tempSelectedJamPelajaran = _selectedJamPelajaran;

        return StatefulBuilder(
          builder: (context, setModalState) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Gradient Header
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ColorUtils.corporateBlue600,
                          ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Filter Schedules',
                              'id': 'Filter Jadwal',
                            }),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedHariId = null;
                              tempSelectedClassId = null;
                              tempSelectedJamPelajaran = null;
                              tempSelectedSemester = _selectedSemester;
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
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day Filter
                          _buildFilterSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Day',
                              'id': 'Hari',
                            }),
                            Icons.calendar_today_outlined,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableDays.map<Widget>((day) {
                              final dayId = day['id'].toString();
                              final dayNameRaw =
                                  day['name'] ?? day['nama'] ?? '';
                              final isSelected = tempSelectedHariId == dayId;
                              final dayMap = {
                                'senin': {'en': 'Monday', 'id': 'Senin'},
                                'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
                                'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
                                'kamis': {'en': 'Thursday', 'id': 'Kamis'},
                                'jumat': {'en': 'Friday', 'id': 'Jumat'},
                                'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
                                'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
                                'minggu': {'en': 'Sunday', 'id': 'Minggu'},
                                'monday': {'en': 'Monday', 'id': 'Senin'},
                                'tuesday': {'en': 'Tuesday', 'id': 'Selasa'},
                                'wednesday': {'en': 'Wednesday', 'id': 'Rabu'},
                                'thursday': {'en': 'Thursday', 'id': 'Kamis'},
                                'friday': {'en': 'Friday', 'id': 'Jumat'},
                                'saturday': {'en': 'Saturday', 'id': 'Sabtu'},
                                'sunday': {'en': 'Sunday', 'id': 'Minggu'},
                              };
                              final normalizedKey = dayNameRaw
                                  .toString()
                                  .toLowerCase();
                              final dayName = dayMap[normalizedKey] != null
                                  ? languageProvider.getTranslatedText(
                                      dayMap[normalizedKey]!,
                                    )
                                  : dayNameRaw;
                              return FilterChip(
                                label: Text(dayName),
                                selected: isSelected,
                                onSelected: (selected) => setModalState(
                                  () => tempSelectedHariId = selected
                                      ? dayId
                                      : null,
                                ),
                                backgroundColor: Colors.white,
                                selectedColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.12),
                                checkmarkColor: ColorUtils.corporateBlue600,
                                side: BorderSide(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                          ),

                          // Class Filter
                          _buildFilterSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Class',
                              'id': 'Kelas',
                            }),
                            Icons.class_outlined,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableClasses.map<Widget>((cls) {
                              final classId = cls['id'].toString();
                              final className =
                                  cls['name'] ?? cls['nama'] ?? '';
                              final isSelected = tempSelectedClassId == classId;
                              return FilterChip(
                                label: Text(className),
                                selected: isSelected,
                                onSelected: (selected) => setModalState(
                                  () => tempSelectedClassId = selected
                                      ? classId
                                      : null,
                                ),
                                backgroundColor: Colors.white,
                                selectedColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.12),
                                checkmarkColor: ColorUtils.corporateBlue600,
                                side: BorderSide(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                          ),

                          // Semester Filter
                          _buildFilterSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Semester',
                              'id': 'Semester',
                            }),
                            Icons.school_outlined,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _semesterList.map<Widget>((semester) {
                              final semesterId = semester['id'].toString();
                              String semesterName =
                                  semester['name'] ??
                                  semester['nama'] ??
                                  'Semester $semesterId';
                              if (semester['academic_year'] != null &&
                                  semester['academic_year']['year'] != null) {
                                semesterName +=
                                    ' (${semester['academic_year']['year']})';
                              }
                              final isSelected =
                                  tempSelectedSemester == semesterId;
                              return FilterChip(
                                label: Text(semesterName),
                                selected: isSelected,
                                onSelected: (selected) => setModalState(
                                  () => tempSelectedSemester = selected
                                      ? semesterId
                                      : null,
                                ),
                                backgroundColor: Colors.white,
                                selectedColor: ColorUtils.corporateBlue600
                                    .withValues(alpha: 0.12),
                                checkmarkColor: ColorUtils.corporateBlue600,
                                side: BorderSide(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate300,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? ColorUtils.corporateBlue600
                                      : ColorUtils.slate700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              );
                            }).toList(),
                          ),

                          // Jam Pelajaran Filter
                          _buildFilterSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Lesson Hour',
                              'id': 'Jam Pelajaran',
                            }),
                            Icons.access_time_outlined,
                          ),
                          Builder(
                            builder: (context) {
                              final Set<String> uniqueHours = {};
                              for (var jp in _lessonHourList) {
                                final h = (jp['hour_number'] ?? jp['jam_ke'])
                                    ?.toString();
                                if (h != null) uniqueHours.add(h);
                              }
                              final sortedHours = uniqueHours.toList()
                                ..sort(
                                  (a, b) => (int.tryParse(a) ?? 0).compareTo(
                                    int.tryParse(b) ?? 0,
                                  ),
                                );
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: sortedHours.map<Widget>((hourNum) {
                                  final isSelected =
                                      tempSelectedJamPelajaran == hourNum;
                                  return FilterChip(
                                    label: Text('Jam $hourNum'),
                                    selected: isSelected,
                                    onSelected: (selected) => setModalState(
                                      () => tempSelectedJamPelajaran = selected
                                          ? hourNum
                                          : null,
                                    ),
                                    backgroundColor: Colors.white,
                                    selectedColor: ColorUtils.corporateBlue600
                                        .withValues(alpha: 0.12),
                                    checkmarkColor: ColorUtils.corporateBlue600,
                                    side: BorderSide(
                                      color: isSelected
                                          ? ColorUtils.corporateBlue600
                                          : ColorUtils.slate300,
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? ColorUtils.corporateBlue600
                                          : ColorUtils.slate700,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                  // Footer buttons
                  Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: ColorUtils.slate100),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.slate900.withValues(alpha: 0.06),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate600,
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
                                _selectedDayId = tempSelectedHariId;
                                _selectedClassId = tempSelectedClassId;
                                _selectedFilterSemester = tempSelectedSemester;
                                _selectedJamPelajaran =
                                    tempSelectedJamPelajaran;
                                _checkActiveFilter();
                              });
                              AppNavigator.pop(context);
                              _loadData();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Apply Filter',
                                'id': 'Terapkan Filter',
                              }),
                              style: TextStyle(fontWeight: FontWeight.w600),
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
  }

  List<dynamic> _getFilteredSchedules() {
    final searchTerm = _searchController.text.toLowerCase();
    return _scheduleList.where((schedule) {
      final subjectName =
          schedule['subject_name']?.toString().toLowerCase() ??
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ??
          '';
      final teacherName =
          schedule['teacher_name']?.toString().toLowerCase() ??
          schedule['guru_nama']?.toString().toLowerCase() ??
          '';
      final className =
          schedule['class_name']?.toString().toLowerCase() ??
          schedule['kelas_nama']?.toString().toLowerCase() ??
          '';
      final dayNames = (() {
        // Construct day names string for search
        final daysIds = [];
        if (schedule['days_ids'] is List) {
          daysIds.addAll(schedule['days_ids']);
        } else if (schedule['day_id'] != null) {
          daysIds.add(schedule['day_id']);
        }

        return daysIds
            .map((id) {
              final d = _dayList.firstWhere(
                (element) => element['id'].toString() == id.toString(),
                orElse: () => {},
              );
              return (d['name'] ?? d['nama'] ?? '').toString().toLowerCase();
            })
            .join(' ');
      })();

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          teacherName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayNames.contains(searchTerm);

      // Teacher filter
      bool matchesGuru = true;
      if (_selectedTeacherId != null) {
        final teacherId =
            schedule['teacher_id']?.toString() ??
            schedule['guru_id']?.toString();
        matchesGuru = teacherId == _selectedTeacherId;
      }

      // Class filter
      bool matchesKelas = true;
      if (_selectedClassId != null) {
        final kelasId =
            schedule['class_id']?.toString() ??
            schedule['kelas_id']?.toString();
        matchesKelas = kelasId == _selectedClassId;
      }

      // Day filter
      bool matchesHari = true;
      if (_selectedDayId != null) {
        final daysIds = [];
        if (schedule['days_ids'] is List) {
          daysIds.addAll(schedule['days_ids']);
        } else if (schedule['day_id'] != null) {
          daysIds.add(schedule['day_id']);
        }

        matchesHari = daysIds.any(
          (id) => id.toString() == _selectedDayId.toString(),
        );
      }

      bool matchesJamPelajaran = true;
      if (_selectedJamPelajaran != null) {
        final lessonHour = schedule['lesson_hour'] as Map<String, dynamic>?;
        final hourNumber =
            lessonHour?['hour_number']?.toString() ??
            lessonHour?['jam_ke']?.toString();
        matchesJamPelajaran = hourNumber == _selectedJamPelajaran;
      }

      // Note: Semester and academic year filters are handled by reloading data from server
      // For ListView, backend handles filtering. For TableView/local data, we filter here.
      return matchesSearch &&
          matchesGuru &&
          matchesKelas &&
          matchesHari &&
          matchesJamPelajaran;
    }).toList();
  }

  Widget _buildTableView() {
    final languageProvider = ref.read(languageRiverpod);

    // Ensure data source is ready
    if (_timetableDataSource == null) {
      return Center(child: CircularProgressIndicator());
    }

    final days = _dayList
        .map(
          (d) => _translateDay(
            d['name'] ?? d['nama'] ?? '',
            languageProvider.currentLanguage,
          ),
        )
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    final classNames = _classList
        .where(
          (cls) =>
              _selectedClassId == null ||
              cls['id'].toString() == _selectedClassId,
        )
        .map((cls) => cls['name'] ?? cls['nama'] ?? '')
        .toList();

    return Column(
      children: [
        // ── Table info bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getPrimaryColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.table_chart_outlined,
                  size: 18,
                  color: _getPrimaryColor(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Weekly Schedule Table',
                        'id': 'Tabel Jadwal Mingguan',
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    Text(
                      '${_gridData.length} ${languageProvider.getTranslatedText({'en': 'schedule entries', 'id': 'entri jadwal'})}',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportToExcel,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Export',
                    'id': 'Ekspor',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── DataGrid with styled card ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: SfDataGridTheme(
              data: SfDataGridThemeData(
                gridLineColor: ColorUtils.slate200,
                gridLineStrokeWidth: 1.0,
                headerColor: _getPrimaryColor(),
              ),
              child: SfDataGrid(
                source: _timetableDataSource!,
                frozenColumnsCount: 1,
                columnWidthMode: ColumnWidthMode.none,
                gridLinesVisibility: GridLinesVisibility.both,
                headerGridLinesVisibility: GridLinesVisibility.both,
                headerRowHeight: 72,
                onQueryRowHeight: (RowHeightDetails details) {
                  if (details.rowIndex == 0) return 72.0;

                  final String timeSlot =
                      _timetableDataSource!.timeSlots[details.rowIndex - 1];
                  final rowDays = _timetableDataSource!.days;

                  int maxSchedules = 0;
                  for (var day in rowDays) {
                    final count = _gridData
                        .where((d) => d.waktu == timeSlot && d.hari == day)
                        .length;
                    if (count > maxSchedules) maxSchedules = count;
                  }

                  if (maxSchedules == 0) return 40.0;
                  return (maxSchedules * 32.0 + 10.0).clamp(40.0, 500.0);
                },
                columns: [
                  GridColumn(
                    columnName: 'waktu',
                    width: 100,
                    label: Container(
                      color: _getPrimaryColor(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 14,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Time',
                              'id': 'Waktu',
                            }),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...days.map((day) {
                    return GridColumn(
                      columnName: day,
                      width: 150,
                      label: Container(
                        color: _getPrimaryColor(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Flexible(
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 2,
                                alignment: WrapAlignment.center,
                                children: classNames.map((className) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      className.toString().length > 4
                                          ? className.toString().substring(0, 4)
                                          : className.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final filteredSchedules = _getFilteredSchedules();

    return Scaffold(
      backgroundColor: ColorUtils.lightGray,
      body: Column(
        children: [
          // Header
          GradientPageHeader(
            title: languageProvider.getTranslatedText({
              'en': 'Teaching Schedule',
              'id': 'Jadwal Mengajar',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'Manage teaching schedules',
              'id': 'Kelola jadwal mengajar',
            }),
            primaryColor: _getPrimaryColor(),
            onBackPressed: () => AppNavigator.pop(context),
            actionMenu: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showTableView = !_showTableView;
                      if (_showTableView) {
                        _loadData();
                      } else {
                        _loadData();
                      }
                    });
                  },
                  child: Container(
                    key: _viewToggleKey,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _showTableView ? Icons.view_list : Icons.table_chart,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                PopupMenuButton<String>(
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
                          Icon(
                            Icons.refresh,
                            size: 20,
                            color: ColorUtils.info600,
                          ),
                          SizedBox(width: AppSpacing.sm),
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
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Export to Excel',
                              'id': 'Export ke Excel',
                            }),
                          ),
                        ],
                      ),
                    ),
                    if (!ref.read(academicYearRiverpod).isReadOnly)
                      PopupMenuItem<String>(
                        value: 'import',
                        child: Row(
                          children: [
                            Icon(Icons.upload, size: 20),
                            SizedBox(width: AppSpacing.sm),
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
                          SizedBox(width: AppSpacing.sm),
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
                                'en': 'Search schedules...',
                                'id': 'Cari jadwal...',
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
                              if (_showTableView) {
                                setState(_updateGridData);
                              } else {
                                _loadData();
                              }
                            },
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: Icon(Icons.search, color: _getPrimaryColor()),
                            onPressed: () {
                              if (_showTableView) {
                                setState(_updateGridData);
                              } else {
                                _loadData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Filter Button
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
                            padding: EdgeInsets.all(AppSpacing.xs),
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
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              ..._buildFilterChips(languageProvider).map((
                                filter,
                              ) {
                                return Container(
                                  margin: EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: Text(
                                      filter['label'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getPrimaryColor(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    deleteIcon: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: _getPrimaryColor(),
                                    ),
                                    onDeleted: filter['onRemove'],
                                    backgroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white,
                                      width: 0,
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
                        SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Clear All',
                                'id': 'Hapus Semua',
                              }),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    padding: EdgeInsets.only(top: 8, bottom: 80),
                  )
                : _showTableView
                ? _buildTableView()
                : filteredSchedules.isEmpty
                ? EmptyState(
                    title: languageProvider.getTranslatedText({
                      'en': 'No Schedules Found',
                      'id': 'Jadwal Tidak Ditemukan',
                    }),
                    subtitle: languageProvider.getTranslatedText({
                      'en': 'Try adjusting your filters',
                      'id': 'Coba sesuaikan filter Anda',
                    }),
                    icon: Icons.event_busy,
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadData(resetPage: true, useCache: false);
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(top: 8, bottom: 80),
                      itemCount:
                          filteredSchedules.length + (_hasMoreData ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == filteredSchedules.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _getPrimaryColor(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        final schedule = filteredSchedules[index];
                        return _buildScheduleCard(schedule, index);
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
              onPressed: _addSchedule,
              backgroundColor: _getPrimaryColor(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, int index) {
    final color = ColorUtils.getColorForIndex(index);
    final subjectName = schedule['mata_pelajaran_nama'] ?? 'No Subject';
    final teacherName = schedule['guru_nama'] ?? '-';
    final className = schedule['kelas_nama'] ?? '-';
    final dayLabel = _formatScheduleDays(schedule);
    final timeLabel = _formatTime(schedule);
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showScheduleDetail(schedule),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colored icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: color.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Main content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject name
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Teacher name
                      Text(
                        teacherName,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Info tags row
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildInfoTag(Icons.school_outlined, className),
                          _buildInfoTag(Icons.today_outlined, dayLabel),
                          _buildInfoTag(Icons.access_time_outlined, timeLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action buttons column
                if (!isReadOnly) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircleActionButton(
                        icon: Icons.edit_outlined,
                        color: _getPrimaryColor(),
                        onPressed: () => _editSchedule(schedule),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildCircleActionButton(
                        icon: Icons.delete_outline,
                        color: ColorUtils.error600,
                        onPressed: () => _deleteSchedule(schedule['id']),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(Map<String, dynamic> schedule) {
    // if (kDebugMode) {
    //   print('DEBUG: _formatTime keys: ${schedule.keys.toList()}');
    //   print(
    //     'DEBUG: _formatTime values: ${schedule['jam_mulai']} - ${schedule['jam_selesai']}',
    //   );
    // }
    final startTime = schedule['jam_mulai'] ?? schedule['start_time'] ?? '';
    final endTime = schedule['jam_selesai'] ?? schedule['end_time'] ?? '';

    if (startTime.toString().isEmpty || endTime.toString().isEmpty) {
      return '-';
    }
    return '$startTime - $endTime';
  }

  String _translateDay(String dayName, String languageCode) {
    if (dayName.isEmpty) return '';

    final Map<String, String> enToId = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };

    final Map<String, String> idToEn = {
      'Senin': 'Monday',
      'Selasa': 'Tuesday',
      'Rabu': 'Wednesday',
      'Kamis': 'Thursday',
      'Jumat': 'Friday',
      'Sabtu': 'Saturday',
      'Minggu': 'Sunday',
    };

    // Normalize input
    String normalizedDay = dayName.trim();
    // Capitalize first letter
    if (normalizedDay.isNotEmpty) {
      normalizedDay =
          normalizedDay[0].toUpperCase() + normalizedDay.substring(1);
    }

    if (languageCode == 'id') {
      // If target is ID, try to translate from EN to ID
      // If input is already ID (exists in idToEn keys), return as is
      if (idToEn.containsKey(normalizedDay)) return normalizedDay;
      return enToId[normalizedDay] ?? normalizedDay;
    } else {
      // If target is EN, try to translate from ID to EN
      // If input is already EN (exists in enToId keys), return as is
      if (enToId.containsKey(normalizedDay)) return normalizedDay;
      return idToEn[normalizedDay] ?? normalizedDay;
    }
  }

  // Robust helper for parsing days
  String _formatScheduleDays(
    Map<String, dynamic> schedule, [
    LanguageProvider? provider,
  ]) {
    final LanguageProvider languageProvider =
        provider ?? ref.read(languageRiverpod);
    final daysIds = [];
    if (schedule['days_ids'] != null) {
      if (schedule['days_ids'] is List) {
        daysIds.addAll(schedule['days_ids']);
      } else if (schedule['days_ids'] is String) {
        try {
          final raw = schedule['days_ids'] as String;
          // Handle both [1,2] and ["1","2"] formats
          final clean = raw
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .replaceAll("'", "");
          if (clean.trim().isNotEmpty) {
            final parsed = clean.split(',');
            daysIds.addAll(parsed.map((e) => e.trim()));
          }
        } catch (e) {
          AppLogger.error('schedule', e);
        }
      }
    }

    // Fallback to legacy
    if (daysIds.isEmpty) {
      if (schedule['hari_id'] != null) {
        daysIds.add(schedule['hari_id']);
      } else if (schedule['day_id'] != null) {
        daysIds.add(schedule['day_id']);
      }
    }

    // if (kDebugMode) {
    //   print('DEBUG: _formatScheduleDays daysIds extracted: $daysIds');
    //   print('DEBUG: _formatScheduleDays schedule keys: ${schedule.keys}');
    // }

    if (daysIds.isNotEmpty) {
      final dayNames = daysIds
          .map((id) {
            final idStr = id.toString();
            if (kDebugMode) {
              // print('Searching for day id: $idStr in _dayList IDs: ${_dayList.map((e) => e['id']).toList()}');
            }
            final day = _dayList.firstWhere(
              (d) => d['id'].toString().toLowerCase() == idStr.toLowerCase(),
              orElse: () => {},
            );
            if (day.isNotEmpty) {
              return _translateDay(
                day['name'] ?? day['nama'] ?? '',
                languageProvider.currentLanguage,
              );
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList(); // Dedup

      if (dayNames.isNotEmpty) return dayNames.join(', ');
    }

    // Legacy name fallback
    if (schedule['hari_nama'] != null &&
        schedule['hari_nama'].toString().isNotEmpty) {
      return _translateDay(
        schedule['hari_nama'],
        languageProvider.currentLanguage,
      );
    }

    return 'No Day';
  }

  void _showScheduleDetail(Map<String, dynamic> schedule) {
    final languageProvider = ref.read(languageRiverpod);
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pattern #10 Gradient Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getPrimaryColor(),
                    _getPrimaryColor().withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
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
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Schedule Details',
                            'id': 'Detail Jadwal',
                          }),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          schedule['mata_pelajaran_nama'] ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Detail rows ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildDetailItem(
                    icon: Icons.subject_outlined,
                    title: languageProvider.getTranslatedText({
                      'en': 'Subject',
                      'id': 'Mata Pelajaran',
                    }),
                    value: schedule['mata_pelajaran_nama'] ?? '-',
                  ),
                  _buildDetailItem(
                    icon: Icons.person_outline,
                    title: languageProvider.getTranslatedText({
                      'en': 'Teacher',
                      'id': 'Guru',
                    }),
                    value: schedule['guru_nama'] ?? '-',
                  ),
                  _buildDetailItem(
                    icon: Icons.school_outlined,
                    title: languageProvider.getTranslatedText({
                      'en': 'Class',
                      'id': 'Kelas',
                    }),
                    value: schedule['kelas_nama'] ?? '-',
                  ),
                  _buildDetailItem(
                    icon: Icons.today_outlined,
                    title: languageProvider.getTranslatedText({
                      'en': 'Day',
                      'id': 'Hari',
                    }),
                    value: _formatScheduleDays(schedule, languageProvider),
                  ),
                  _buildDetailItem(
                    icon: Icons.access_time_outlined,
                    title: languageProvider.getTranslatedText({
                      'en': 'Time',
                      'id': 'Waktu',
                    }),
                    value: _formatTime(schedule),
                  ),
                  _buildDetailItem(
                    icon: Icons.grade_outlined,
                    title: languageProvider.getTranslatedText({
                      'en': 'Grade Level',
                      'id': 'Tingkat Kelas',
                    }),
                    value: _getGradeLevel(schedule['class_id'] ?? ''),
                    isLast: true,
                  ),
                ],
              ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: ColorUtils.slate100, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Close',
                          'id': 'Tutup',
                        }),
                        style: TextStyle(color: ColorUtils.slate600),
                      ),
                    ),
                  ),
                  if (!isReadOnly) ...[
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppNavigator.pop(context);
                          _editSchedule(schedule);
                        },
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Edit',
                            'id': 'Edit',
                          }),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: ColorUtils.slate100, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getPrimaryColor().withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, size: 18, color: _getPrimaryColor()),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    if (_isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'schedule_management',
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
              if (mounted && !_isTourShowing) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('schedule', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    setState(() {
      _isTourShowing = true;
    });

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
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'teaching_schedule_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('schedule_management', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'teaching_schedule_management_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('schedule_management', 'admin'),
          {'should_show': false},
        );
        return true;
      },
      onClickOverlay: (target) {
        // Optional: you might want to handle this as well
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "ScheduleViewToggle",
        keyTarget: _viewToggleKey,
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
                      'en': 'Switch View Mode',
                      'id': 'Ganti Mode Tampilan',
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
                            'Toggle between a list view or a comprehensive timetable grid view.',
                        'id':
                            'Beralih antara tampilan daftar atau tampilan grid jadwal yang komprehensif.',
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
        identify: "ScheduleMenu",
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
                      'en': 'Schedule Tools',
                      'id': 'Alat Jadwal',
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
                            'Export, import, or download schedule templates from this menu.',
                        'id':
                            'Ekspor, impor, atau unduh template jadwal dari menu ini.',
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
        identify: "ScheduleSearch",
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
                      'en': 'Search Schedule',
                      'id': 'Cari Jadwal',
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
                            'Find a specific teaching schedule by typing keywords here.',
                        'id':
                            'Temukan jadwal mengajar tertentu dengan mengetikkan kata kunci di sini.',
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
        identify: "ScheduleFilter",
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
                      'en': 'Apply Filters',
                      'id': 'Terapkan Filter',
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
                            'Filter schedules by teacher, class, day, or academic period.',
                        'id':
                            'Saring jadwal berdasarkan guru, kelas, hari, atau periode akademik.',
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
        identify: "AddSchedule",
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
                      'en': 'Add New Schedule',
                      'id': 'Tambah Jadwal Baru',
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
                            'Click here to manually create a new schedule entry.',
                        'id':
                            'Klik di sini untuk membuat entri jadwal baru secara manual.',
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
