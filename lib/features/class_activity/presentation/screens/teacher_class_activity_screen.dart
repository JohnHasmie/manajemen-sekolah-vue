// Class activity (journal) management screen for teachers.
// Like `pages/teacher/ClassActivity.vue` in a Vue app.
//
// This is one of the largest screens in the app. It provides a multi-step
// wizard flow: Step 0 (select class) -> Step 1 (select subject) -> Step 2
// (view/manage activities). It supports CRUD operations on class activities,
// tab switching between "umum" (general) and "khusus" (specific) targets,
// pagination with infinite scroll, search/filter, caching, and an onboarding
// tour. In Laravel terms, this is like a complex Livewire component that
// combines ClassController, SubjectController, and ActivityController logic.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_dialog.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_list_view.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_tab_switcher.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_option_tile.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_activity_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_selector_list.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/subject_selection_list.dart';

/// Teacher's class activity (teaching journal) management screen.
///
/// This is a StatefulWidget -- like a Vue page component with its own local
/// state. The constructor parameters below are like Vue `props` -- immutable
/// data passed from the parent (e.g., from navigation or deep link).
///
/// Supports deep linking via optional initial* parameters, allowing other
/// screens to navigate here with pre-selected class/subject/chapter.
/// In Vue Router terms, these are like route query params (`?classId=...`).
class ClassActivityScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  const ClassActivityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
  });

  @override
  ClassActivityScreenState createState() => ClassActivityScreenState();
}

/// The mutable State for [ClassActivityScreen].
///
/// This is like a Vue page component with its own local state
/// (`data() { return {...} }`). Uses `TickerProviderStateMixin` because it
/// has a TabController for animations (like Vue transition hooks).
///
/// Key state variables (equivalent to Vue `data()` properties):
/// - [_currentStep] -- wizard step (0=classes, 1=subjects, 2=activities)
/// - [_classList] / [_subjectList] / [_activityList] -- data arrays from API
/// - [_selectedClassId] / [_selectedSubjectId] -- current selections
/// - [_isLoading] / [_isLoadingMore] -- loading states
/// - [_currentPage] / [_hasMoreData] -- pagination state for infinite scroll
/// - [_currentTarget] -- tab selection ('umum' or 'khusus')
///
/// The `TickerProviderStateMixin` is needed for TabController animations.
/// In Vue, you would just use CSS transitions; in Flutter, animations
/// need a "ticker" (frame callback provider).
class ClassActivityScreenState extends ConsumerState<ClassActivityScreen>
    with TickerProviderStateMixin {
  static const String _prefKeyLastCacheKey = 'class_activity_last_cache_key';

  List<dynamic> _scheduleList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _chapterList = [];
  List<dynamic> _subChapterList = [];
  List<dynamic> _activityList = [];
  bool _isLoading = true;
  String _teacherId = '';
  String _teacherName = '';

  // New Navigation State
  // 0: Class List, 1: Subject List, 2: Activity List
  int _currentStep = 0;
  String? _selectedClassId;
  String? _selectedClassName;
  // Map<String, dynamic>? _selectedClassData; // If full object needed
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _selectedSubjectCanEdit = false;

  // Data Lists
  List<dynamic> _classList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;

  bool _hasActiveFilter = false;

  // Pagination
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Scroll controller for infinite scroll
  final ScrollController _scrollController = ScrollController();

  // Search debouncing

  late TabController _tabController;
  String _currentTarget = 'umum';

  // Tour properties
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _tabSwitcherKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  /// Like Vue's `mounted()` lifecycle hook. Initializes the tab controller,
  /// sets up scroll/tab listeners, and kicks off initial data loading.
  /// In Laravel terms, this is like the controller constructor that sets up
  /// dependencies before handling a request.
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_onScroll);
    _loadUserData();
  }

  /// Like Vue's `beforeUnmount()` -- disposes controllers to prevent memory leaks.
  /// Every controller created in initState should be disposed here.
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  /// Handles tab switch between "umum" (general) and "khusus" (specific).
  /// Like a Vue `@change` handler on a `<el-tabs>` component.
  /// Resets pagination and reloads activities for the new tab.
  void _handleTabSelection() {
    // TabController listener fires twice (animation start + end).
    // Only react once — after the animation settles.
    if (_tabController.indexIsChanging) return;

    setState(() {
      _currentTarget = _tabController.index == 0 ? 'umum' : 'khusus';
    });
    // Reset pagination when switching tabs
    _resetAndLoadActivities();
  }

  /// Infinite scroll listener -- loads more data when user scrolls near bottom.
  /// Like a Vue `@scroll` directive or Intersection Observer pattern.
  /// Triggers [_loadMoreActivities] when within 200px of the bottom.
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreActivities();
      }
    }
  }

  /// Resets pagination to page 1 and reloads activities from scratch.
  /// Called when filters change, tabs switch, or subject selection changes.
  /// Like calling `this.currentPage = 1; this.fetchActivities()` in Vue.
  void _resetAndLoadActivities() {
    setState(() {
      _currentPage = 1;
      _activityList.clear();
      _hasMoreData = true;
      _isLoading = true;
    });
    _loadActivities();
  }

  /// Clears all cached data and reloads from the API.
  /// Like a Vue method that clears Vuex store and re-fetches,
  /// or hitting a "refresh" button that bypasses browser cache.
  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('class_activity_');
    final prefs = PreferencesService();
    await prefs.remove(_prefKeyLastCacheKey);
    if (_currentStep == 0) {
      setState(() => _isLoading = true);
      _loadUserData();
    } else if (_currentStep == 1) {
      setState(() {
        _subjectList.clear();
        _isLoading = true;
      });
      _loadSubjectsForClass(useCache: false);
    } else if (_currentStep == 2) {
      _resetAndLoadActivities();
    }
  }

  /// Loads the next page of activities for infinite scroll.
  /// Like a Vue method that increments `currentPage` and appends results.
  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _currentPage++;
      _isLoadingMore = true;
    });

    await _loadActivities();
  }

  // ========== VIEW BUILDERS ==========

  /// Builds the class selection list (Step 0 of the wizard).
  /// Delegates to [ClassSelectorList]; the callback owns the setState calls.
  Widget _buildClassList(LanguageProvider languageProvider) {
    return ClassSelectorList(
      isLoading: _isLoading,
      classList: _classList,
      languageProvider: languageProvider,
      onClassSelected: (classData) async {
        setState(() {
          _selectedClassId = classData['id'].toString();
          _selectedClassName = classData['name'] ?? classData['nama'];
          _currentStep = 1;
        });
        await _loadSubjectsForClass();
      },
    );
  }

  /// Builds the subject selection list (Step 1 of the wizard).
  /// Delegates to [SubjectSelectionList]; the widget fires [onSubjectSelected]
  /// and this method owns the state mutations.
  Widget _buildSubjectList(LanguageProvider languageProvider) {
    return SubjectSelectionList(
      isLoading: _isLoading,
      subjectList: _subjectList,
      selectedClassName: _selectedClassName,
      languageProvider: languageProvider,
      onSubjectSelected: (subject) async {
        setState(() {
          _selectedSubjectId = subject['id'].toString();
          _selectedSubjectName = subject['name'] ?? subject['nama'] ?? '-';
          _selectedSubjectCanEdit = subject['can_edit'] == true;
          _currentStep = 2; // Go to Activity List
        });
        await _loadActivities();
      },
    );
  }

  /// Loads the current teacher's profile and their class list.
  /// This is the entry-point data loader called from [initState].
  /// Like a Vue `mounted()` that calls `await this.fetchTeacherProfile()`
  /// then `await this.fetchClasses()`. Uses a multi-layer cache strategy:
  /// 1. Try SharedPreferences (instant, last known data)
  /// 2. Try LocalCacheService (with TTL)
  /// 3. Fall back to API call
  Future<void> _loadUserData() async {
    AppLogger.debug('class_activity', '===== _loadUserData STARTED =====');
    try {
      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      final teacherProvider = ref.read(teacherRiverpod);

      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final role = userData['role']?.toString().toLowerCase() ?? '';
      final isAdmin = role == 'admin' || role == 'super_admin';

      // Early cache load using persisted last cache key
      if (_classList.isEmpty) {
        final lastCacheKey = prefs.getString(_prefKeyLastCacheKey);
        if (lastCacheKey != null) {
          try {
            final cached = await LocalCacheService.load(
              lastCacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cached != null && mounted) {
              final cachedData = Map<String, dynamic>.from(cached);
              setState(() {
                _classList = List<dynamic>.from(cachedData['classes'] ?? []);
                _scheduleList = List<dynamic>.from(
                  cachedData['schedules'] ?? [],
                );
                if (_classList.isNotEmpty) _isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Loaded ${_classList.length} classes from early cache',
              );
            }
          } catch (e) {
            AppLogger.error('class_activity', 'Early cache load error: $e');
          }
        }
      }

      if (!isAdmin &&
          teacherProvider.isLoaded &&
          teacherProvider.teacherId != null) {
        // ✅ Use cached data from provider — no API calls needed
        AppLogger.debug(
          'class_activity',
          'Using TeacherProvider cache (teacherId=${teacherProvider.teacherId})',
        );

        setState(() {
          _teacherId = teacherProvider.teacherId!;
          _teacherName = teacherProvider.teacherName ?? 'Guru';
        });

        // Load classes and schedule using cached teacher ID
        await _loadClassesAndSchedule(teacherProvider.teacherId!, isAdmin: false);

        // If initial params provided, try to navigate deep
        await _handleInitialNavigation();
        return;
      }

      // ─── Step 2: Fallback — fetch from API (direct navigation, deep link, etc.) ───
      AppLogger.debug(
        'class_activity',
        'TeacherProvider empty, falling back to API',
      );

      final userId = userData['id']?.toString() ?? '';

      setState(() {
        _teacherId = userId; // Initially set to userId
        _teacherName = userData['nama']?.toString() ?? 'Guru';
      });

      AppLogger.debug('class_activity', 'User ID from prefs: $userId');
      AppLogger.debug('class_activity', 'User Role: $role');

      if (userId.isNotEmpty) {
        if (isAdmin) {
          // Admin Case: Load ALL classes
          AppLogger.debug(
            'class_activity',
            'User is Admin/Super Admin. Loading all classes.',
          );
          await _loadClasses(userId, isAdmin: true);
        } else {
          // Teacher Case: Resolve Teacher ID
          try {
            String? resolvedTeacherId;

            final looksLikeTeacher =
                userData.containsKey('employee_number') ||
                userData.containsKey('nip') ||
                userData.containsKey('user_id');

            if (looksLikeTeacher) {
              AppLogger.debug(
                'class_activity',
                'userData appears to be a teacher record. Using ID: $userId',
              );
              resolvedTeacherId = userId;
            } else {
              // Try TeacherProvider.ensureLoaded first
              String? academicYearId;
              try {
                if (mounted) {
                  academicYearId = ref
                      .read(academicYearRiverpod)
                      .selectedAcademicYear?['id']
                      ?.toString();
                }
              } catch (e) {}

              await teacherProvider.ensureLoaded(
                academicYearId: academicYearId,
              );

              if (teacherProvider.teacherId != null) {
                resolvedTeacherId = teacherProvider.teacherId;
              } else {
                // Last resort: direct API call
                final teacherData = await getIt<ApiTeacherService>()
                    .getTeacherByUserId(userId, academicYearId: academicYearId);
                if (teacherData != null && teacherData['id'] != null) {
                  resolvedTeacherId = teacherData['id'].toString();
                }
              }
            }

            if (resolvedTeacherId != null) {
              AppLogger.info(
                'class_activity',
                'Resolved Teacher ID: $resolvedTeacherId',
              );
              setState(() {
                _teacherId = resolvedTeacherId!;
              });

              await _loadClassesAndSchedule(resolvedTeacherId, isAdmin: false);

              await _handleInitialNavigation();
            } else {
              // FALLBACK: Teacher resolution failed.
              AppLogger.error(
                'class_activity',
                'Failed to resolve Teacher ID. Attempting fallback as Admin...',
              );

              await _loadClasses(userId, isAdmin: true);

              if (_classList.isNotEmpty) {
                AppLogger.warning(
                  'class_activity',
                  'Fallback successful: Loaded classes as Admin',
                );
              } else {
                AppLogger.error(
                  'class_activity',
                  'Fallback failed: No classes loaded or not authorized',
                );
                setState(() => _isLoading = false);
              }
            }
          } catch (e) {
            AppLogger.error(
              'class_activity',
              'Error during teacher resolution: $e',
            );
            if (mounted) {
              _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
            }
            setState(() => _isLoading = false);
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error in _loadUserData: $e');
      if (mounted) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
      setState(() => _isLoading = false);
    }
  }

  /// Handle deep navigation from initial parameters (extracted to avoid duplication).
  /// Like Vue Router's `beforeRouteEnter` guard that reads query params and
  /// auto-selects class/subject if they were passed via navigation.
  Future<void> _handleInitialNavigation() async {
    if (widget.initialClassId == null) return;
    if (!mounted) return;

    setState(() {
      _selectedClassId = widget.initialClassId;
      _selectedClassName = widget.initialClassName;
      _currentStep = 1;
    });

    await _loadSubjectsForClass();

    if (widget.initialSubjectId != null && mounted) {
      setState(() {
        _selectedSubjectId = widget.initialSubjectId;
        _selectedSubjectName = widget.initialSubjectName;
        _currentStep = 2;
      });
      await _loadActivities();
    }
  }

  /// Fetches the list of classes assigned to the teacher.
  /// Uses a cache-first strategy with LocalCacheService (like browser localStorage).
  /// In Laravel terms, this is like `ClassController@index` with cache middleware.
  /// Loads classes and schedule in parallel, then applies a single setState.
  /// Prevents rapid-fire rebuilds of the large widget tree.
  Future<void> _loadClassesAndSchedule(
    String teacherId, {
    bool isAdmin = false,
    bool useCache = true,
  }) async {
    final academicYearId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    final cacheKey = 'class_activity_classes_${teacherId}_$academicYearId';

    // Step 1: Try cache first (single setState)
    if (useCache && _classList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          setState(() {
            _classList = List<dynamic>.from(cachedData['classes'] ?? []);
            _scheduleList = List<dynamic>.from(cachedData['schedules'] ?? []);
            _isLoading = false;
          });
          AppLogger.info(
            'class_activity',
            'Loaded ${_classList.length} classes from cache',
          );
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Cache load error: $e');
      }
    }

    // Step 2: Show skeleton only if still empty
    if (_classList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    // Step 3: Fetch both in parallel — NO setState inside these futures
    try {
      final results = await Future.wait([
        _fetchClasses(teacherId, isAdmin: isAdmin, academicYearId: academicYearId),
        _fetchSchedule(teacherId, academicYearId: academicYearId),
      ]);

      final classes = results[0];
      final schedules = results[1];

      if (!mounted) return;

      // Step 4: Single setState for both results
      setState(() {
        _classList = classes;
        _scheduleList = schedules;
        _isLoading = false;
      });

      AppLogger.info('class_activity', 'Loaded ${classes.length} classes and ${schedules.length} schedules');

      // Step 5: Save to cache
      await LocalCacheService.save(cacheKey, {
        'classes': classes,
        'schedules': schedules,
      });
      final prefs = PreferencesService();
      await prefs.setString(_prefKeyLastCacheKey, cacheKey);
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading classes/schedule: $e');
      if (!mounted) return;
      if (_classList.isEmpty) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Pure data fetch — no setState. Returns classes list.
  Future<List<dynamic>> _fetchClasses(
    String teacherId, {
    bool isAdmin = false,
    String? academicYearId,
  }) async {
    if (isAdmin) {
      final response = await getIt<ApiClassService>().getClassPaginated(
        limit: 100,
        academicYearId: academicYearId,
      );
      return response['data'] ?? [];
    } else {
      return await getIt<ApiTeacherService>().getTeacherClasses(
        teacherId,
        academicYearId: academicYearId,
      );
    }
  }

  /// Pure data fetch — no setState. Returns schedule list.
  Future<List<dynamic>> _fetchSchedule(
    String teacherId, {
    String? academicYearId,
  }) async {
    return await getIt<ApiScheduleService>().getScheduleByTeacher(
      teacherId: teacherId,
      academicYear: academicYearId,
    );
  }

  /// Standalone _loadClasses for admin-only paths that don't need schedule.
  Future<void> _loadClasses(
    String teacherId, {
    bool isAdmin = false,
    bool useCache = true,
  }) async {
    await _loadClassesAndSchedule(teacherId, isAdmin: isAdmin, useCache: useCache);
  }

  Future<void> _loadSubjectsForClass({bool useCache = true}) async {
    if (_selectedClassId == null) return;

    final subjectCacheKey = CacheKeyBuilder.custom(
      'class_activity_subjects',
      _teacherId,
      _selectedClassId ?? '',
    );

    // Step 1: Try cache first
    if (useCache && _subjectList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(
          subjectCacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          setState(() {
            _subjectList = List<dynamic>.from(cached);
            _isLoading = false;
          });
          AppLogger.info(
            'class_activity',
            'Loaded ${_subjectList.length} subjects from cache',
          );
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Subject cache load error: $e');
      }
    }

    // Step 2: Show skeleton only if still empty
    if (_subjectList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    // Step 3: Fetch fresh from API
    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final selectedClass = _classList.firstWhere(
        (c) => c['id'].toString() == _selectedClassId,
        orElse: () => {},
      );
      final isHomeroom = selectedClass['is_homeroom'] == true;

      // Get user role from SharedPreferences
      final prefs = PreferencesService();
      final userJson = prefs.getString('user');
      String userRole = '';
      if (userJson != null) {
        final userData = json.decode(userJson);
        userRole = userData['role'] ?? '';
      }
      final isAdmin = userRole == 'admin';

      // 1. Fetch MY subjects (subjects I teach in this class)
      final mySchedules = await getIt<ApiScheduleService>()
          .getSchedulesPaginated(
            limit: 100,
            teacherId: _teacherId,
            classId: _selectedClassId,
            academicYearId: academicYearId,
          );
      final myData = mySchedules['data'] ?? [];
      final mySubjectIds = <String>{};
      for (var item in myData) {
        final subject = item['subject'] ?? item['mata_pelajaran'];
        if (subject != null) {
          mySubjectIds.add(subject['id'].toString());
        }
      }

      List<dynamic> subjects = [];

      if (isHomeroom || isAdmin) {
        // 2. If Homeroom or Admin, fetch ALL subjects assigned to this class
        final response = await dioClient.get(
          '/class/$_selectedClassId/subjects',
        );

        final allSubjects = response.data is List ? response.data as List : [];
        final uniqueSubjects = <String, Map<String, dynamic>>{};

        for (var subject in allSubjects) {
          final subjectId = subject['id'].toString();
          final s = Map<String, dynamic>.from(subject);
          s['can_edit'] = isAdmin || mySubjectIds.contains(subjectId);
          uniqueSubjects[subjectId] = s;
        }
        subjects = uniqueSubjects.values.toList();
      } else {
        // 3. If Not Homeroom, only show MY subjects
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var item in myData) {
          final subject = item['subject'] ?? item['mata_pelajaran'];
          if (subject != null) {
            final subjectId = subject['id'].toString();
            final s = Map<String, dynamic>.from(subject);
            s['can_edit'] = true;
            uniqueSubjects[subjectId] = s;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      // Sort alphabetically
      subjects.sort((a, b) {
        final nameA = (a['name'] ?? a['nama'] ?? '').toString();
        final nameB = (b['name'] ?? b['nama'] ?? '').toString();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _isLoading = false;
        });
      }

      // Save to cache
      await LocalCacheService.save(subjectCacheKey, subjects);
      AppLogger.info(
        'class_activity',
        'Saved ${subjects.length} subjects to cache',
      );
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading subjects: $e');
      if (mounted) {
        if (_subjectList.isEmpty) {
          _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
        }
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to handle back button
  Future<bool> _handleWillPop() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep == 1) {
          _selectedSubjectId = null;
          _selectedSubjectName = null;
        } else if (_currentStep == 0) {
          _selectedClassId = null;
          _selectedClassName = null;
        }
      });
      return false; // Don't pop route
    }
    return true; // Pop route
  }

  void _showActivityTypeDialog() {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = _getPrimaryColor();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.add_circle_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Select Activity Type',
                          'id': 'Pilih Jenis Kegiatan',
                        }),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                children: [
                  _buildActivityTypeOption(
                    icon: Icons.assignment_rounded,
                    title: languageProvider.getTranslatedText({
                      'en': 'Assignment',
                      'id': 'Tugas',
                    }),
                    description: languageProvider.getTranslatedText({
                      'en': 'Create an assignment for students',
                      'id': 'Buat tugas untuk siswa',
                    }),
                    color: ColorUtils.warning600,
                    onTap: () {
                      AppNavigator.pop(context);
                      _showAddActivityDialog('tugas');
                    },
                  ),
                  SizedBox(height: AppSpacing.md),
                  _buildActivityTypeOption(
                    icon: Icons.menu_book_rounded,
                    title: languageProvider.getTranslatedText({
                      'en': 'Material',
                      'id': 'Materi',
                    }),
                    description: languageProvider.getTranslatedText({
                      'en': 'Share learning materials',
                      'id': 'Bagikan materi pembelajaran',
                    }),
                    color: ColorUtils.corporateBlue600,
                    onTap: () {
                      AppNavigator.pop(context);
                      _showAddActivityDialog('materi');
                    },
                  ),
                  SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
            SafeArea(top: false, child: SizedBox(height: AppSpacing.sm)),
          ],
        ),
      ),
    );
  }

  /// Delegates to [ActivityTypeOptionTile].
  Widget _buildActivityTypeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ActivityTypeOptionTile(
      icon: icon,
      title: title,
      description: description,
      color: color,
      onTap: onTap,
    );
  }

  void _showAddActivityDialog(String activityType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivityDialog(
        teacherId: _teacherId,
        teacherName: _teacherName,
        scheduleList: _scheduleList,
        subjectList: _subjectList,
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterContent,
        onActivityAdded: _loadActivities,
        initialTarget: _currentTarget,
        activityType: activityType,
        initialDate: widget.initialDate,
        initialSubjectId: widget.initialSubjectId,
        initialClassId: widget.initialClassId,
        initialChapterId: widget.initialChapterId,
        initialSubChapterId: widget.initialSubChapterId,
        initialAdditionalMaterials: widget.initialAdditionalMaterials,
        materialsToMarkAsGenerated: widget.materialsToMarkAsGenerated,
      ),
    );
  }

  void _showEditActivityDialog(dynamic activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivityDialog(
        teacherId: _teacherId,
        teacherName: _teacherName,
        scheduleList: _scheduleList,
        subjectList: _subjectList,
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterContent,
        onActivityAdded: _loadActivities,
        initialTarget: activity['target_role'] ?? 'umum',
        activityType: activity['jenis'] ?? 'tugas',
        isEditMode: true,
        activityData: activity,
        initialDate: activity['date'] != null
            ? DateTime.tryParse(activity['date'].toString())
            : null,
        initialSubjectId: activity['subject_id']?.toString(),
        initialClassId: activity['class_id']?.toString(),
        initialChapterId: activity['chapter_id']?.toString(),
        initialSubChapterId: activity['sub_chapter_id']?.toString(),
        initialAdditionalMaterials: activity['additional_material'] is List
            ? (activity['additional_material'] as List)
                  .map((e) => e as Map<String, dynamic>)
                  .toList()
            : [],
      ),
    );
  }

  Future<void> _deleteActivity(
    dynamic activity,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Activity',
            'id': 'Hapus Kegiatan',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete "${activity['title']}"? This action cannot be undone.',
            'id':
                'Apakah Anda yakin ingin menghapus "${activity['title']}"? Tindakan ini tidak dapat dibatalkan.',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            onPressed: () => AppNavigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.error600,
              foregroundColor: Colors.white,
            ),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await getIt<ApiClassActivityService>().deleteActivity(
          activity['id'].toString(),
        );

        if (!mounted) return;

        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Activity deleted successfully',
            'id': 'Kegiatan berhasil dihapus',
          }),
        );

        // Refresh list
        _loadActivities();

        // Auto-uncheck material logic
        // 1. Uncheck primary material
        final List<Map<String, dynamic>> progressItems = [];

        // Helper function to check if a specific material is used by other activities
        Future<bool> isMaterialUsed(
          String chapterId,
          String? subChapterId,
        ) async {
          try {
            final response = await getIt<ApiClassActivityService>()
                .getClassActivityPaginated(
                  page: 1,
                  limit: 1,
                  teacherId: _teacherId,
                  subjectId:
                      activity['subject_id'] ?? activity['mata_pelajaran_id'],
                  chapterId: chapterId,
                  subChapterId: subChapterId,
                );
            final totalItems = response['pagination']?['total_items'] ?? 0;
            return totalItems > 0;
          } catch (e) {
            AppLogger.error(
              'class_activity',
              'Error checking material usage: $e',
            );
            return true;
          }
        }

        if (activity['chapter_id'] != null) {
          try {
            // 1. Check Sub-Chapter ID (Specific)
            // If the deleted activity had a specific sub-chapter, we check if any others use it.
            if (activity['sub_chapter_id'] != null) {
              final inUse = await isMaterialUsed(
                activity['chapter_id'].toString(),
                activity['sub_chapter_id'].toString(),
              );
              if (!inUse) {
                progressItems.add({
                  'bab_id': activity['chapter_id'],
                  'sub_bab_id': activity['sub_chapter_id'],
                  'is_checked': false,
                });
              }
            }
            // 2. Check Whole Chapter (Implicitly all sub-chapters)
            // If the deleted activity covered the whole chapter (sub_chapter_id == null),
            // we need to check EACH sub-chapter in that chapter.
            else {
              // Get all sub-chapters for this chapter
              final subChapters = await getIt<ApiSubjectService>()
                  .getSubChapterMaterials(
                    chapterId: activity['chapter_id'].toString(),
                  );

              for (var sub in subChapters) {
                final subId = sub['id'].toString();

                // Check if this specific sub-chapter is used by any activity
                final isSpecificUsed = await isMaterialUsed(
                  activity['chapter_id'].toString(),
                  subId,
                );

                // Check if there is any activity covering the WHOLE chapter (implicitly covering this sub too)
                // We pass 'null' string to trigger IS NULL check in backend
                final isGenericUsed = await isMaterialUsed(
                  activity['chapter_id'].toString(),
                  'null',
                );

                if (!isSpecificUsed && !isGenericUsed) {
                  progressItems.add({
                    'bab_id': activity['chapter_id'],
                    'sub_bab_id': subId,
                    'is_checked': false,
                  });
                }
              }
            }

            AppLogger.debug(
              'class_activity',
              'Activities check complete. Unchecking ${progressItems.length} items.',
            );
          } catch (e) {
            AppLogger.error(
              'class_activity',
              'Error fetching sub-chapters for uncheck: $e',
            );
          }
        }

        // 2. Uncheck additional materials
        if (activity['additional_material'] != null) {
          try {
            List<dynamic> additionalMaterials = [];
            if (activity['additional_material'] is String) {
              additionalMaterials = json.decode(
                activity['additional_material'],
              );
            } else if (activity['additional_material'] is List) {
              additionalMaterials = activity['additional_material'];
            }

            for (var item in additionalMaterials) {
              if (item['chapter_id'] != null &&
                  item['sub_chapter_id'] != null) {
                final subId = item['sub_chapter_id'].toString();
                final chapId = item['chapter_id'].toString();

                final isSpecificUsed = await isMaterialUsed(chapId, subId);
                // We don't necessarily check generic (whole chapter) usage for specific additional items?
                // Or we should?
                // If Activity B covers Whole Chapter, then Sub 1 (additional in Activity A) IS covered.
                // So we must check generic too.
                final isGenericUsed = await isMaterialUsed(chapId, 'null');

                if (!isSpecificUsed && !isGenericUsed) {
                  progressItems.add({
                    'bab_id': chapId,
                    'sub_bab_id': subId,
                    'is_checked': false,
                  });
                }
              }
            }
          } catch (e) {
            AppLogger.error(
              'class_activity',
              'Error parsing additional materials: $e',
            );
          }
        }

        if (progressItems.isNotEmpty) {
          try {
            await getIt<ApiSubjectService>().batchSaveMateriProgress({
              'guru_id': _teacherId,
              'mata_pelajaran_id':
                  activity['subject_id'] ?? activity['mata_pelajaran_id'],
              'progress_items': progressItems,
            });
            AppLogger.debug(
              'class_activity',
              'Auto-unchecked ${progressItems.length} materials.',
            );
          } catch (e) {
            AppLogger.error(
              'class_activity',
              'Error auto-unchecking materials: $e',
            );
          }
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Delete activity error: $e');
        if (!mounted) return;

        _showErrorSnackBar(
          '${languageProvider.getTranslatedText({'en': 'Failed to delete activity: ', 'id': 'Gagal menghapus kegiatan: '})}${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showError(context, message);
    }
  }

  // ========== FILTER SHEET MENGGUNAKAN KOMPONEN ==========
  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);
    String? tempDateFilter = _selectedDateFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Widget buildSectionHeader(String title, IconData icon) {
            return Padding(
              padding: EdgeInsets.only(top: 20, bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: _getPrimaryColor()),
                  ),
                  SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildChip(String label, String value, String? selectedValue) {
            final isSelected = selectedValue == value;
            return GestureDetector(
              onTap: () => setModalState(
                () => tempDateFilter = isSelected ? null : value,
              ),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _getPrimaryColor().withValues(alpha: 0.1)
                      : ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? _getPrimaryColor()
                        : ColorUtils.slate200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? _getPrimaryColor()
                        : ColorUtils.slate600,
                  ),
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Filter Activities',
                                'id': 'Filter Kegiatan',
                              }),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setModalState(() => tempDateFilter = null),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Reset',
                                'id': 'Reset',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Date Range',
                            'id': 'Rentang Tanggal',
                          }),
                          Icons.calendar_today_rounded,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            buildChip(
                              languageProvider.getTranslatedText({
                                'en': 'Today',
                                'id': 'Hari Ini',
                              }),
                              'today',
                              tempDateFilter,
                            ),
                            buildChip(
                              languageProvider.getTranslatedText({
                                'en': 'This Week',
                                'id': 'Minggu Ini',
                              }),
                              'week',
                              tempDateFilter,
                            ),
                            buildChip(
                              languageProvider.getTranslatedText({
                                'en': 'This Month',
                                'id': 'Bulan Ini',
                              }),
                              'month',
                              tempDateFilter,
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                    boxShadow: [
                      BoxShadow(
                        color: ColorUtils.slate900.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: ColorUtils.slate300),
                              foregroundColor: ColorUtils.slate700,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              AppNavigator.pop(context);
                              setState(() {
                                _selectedDateFilter = tempDateFilter;
                                _hasActiveFilter = _selectedDateFilter != null;
                              });
                              _resetAndLoadActivities();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: _getPrimaryColor(),
                              foregroundColor: Colors.white,
                              elevation: 0,
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  /// Shows the activity detail dialog.
  /// Delegates entirely to [ActivityDetailDialog.show] — the widget owns
  /// all the UI, this method only passes props (like calling
  /// `this.$refs.dialog.show(activity)` in Vue).
  void _showActivityDetail(dynamic activity) {
    ActivityDetailDialog.show(
      context: context,
      activity: activity,
      primaryColor: _getPrimaryColor(),
      languageProvider: ref.read(languageRiverpod),
      canEdit: _selectedSubjectCanEdit,
      selectedClassName: _selectedClassName,
      selectedSubjectName: _selectedSubjectName,
      onEditPressed: () => _showEditActivityDialog(activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _buildHeader(languageProvider),
            Expanded(child: _buildBodyContent(languageProvider)),
          ],
        ),
        // TAB SWITCHER: Only show in Activity List (Step 2)
        // CHECK: Previous code had tab switcher inside body of step 2.
        // We can keep it there.

        // FAB: Only show in Step 2
        // FAB: Only show in Step 2 AND if editable
        floatingActionButton: _currentStep == 2 && _selectedSubjectCanEdit
            ? FloatingActionButton(
                key: _fabKey,
                onPressed: _showActivityTypeDialog,
                backgroundColor: _getPrimaryColor(),
                child: Icon(Icons.add, color: Colors.white),
              )
            : null,
      ),
    );
  }

  Widget _buildBodyContent(LanguageProvider languageProvider) {
    switch (_currentStep) {
      case 0:
        return _buildClassList(languageProvider);
      case 1:
        return _buildSubjectList(languageProvider);
      case 2:
        // TabSwitcher is now in the Header
        return ActivityListView(
          isLoading: _isLoading,
          isLoadingMore: _isLoadingMore,
          activityList: _activityList,
          hasActiveFilter: _hasActiveFilter,
          selectedDateFilter: _selectedDateFilter,
          searchController: _searchController,
          scrollController: _scrollController,
          searchFilterKey: _searchFilterKey,
          primaryColor: _getPrimaryColor(),
          canEdit: _selectedSubjectCanEdit,
          selectedSubjectName: _selectedSubjectName,
          selectedClassName: _selectedClassName,
          onSearchSubmitted: _resetAndLoadActivities,
          onFilterPressed: _showFilterSheet,
          onRemoveDateFilter: () {
            setState(() {
              _selectedDateFilter = null;
              _hasActiveFilter = false;
            });
            _resetAndLoadActivities();
          },
          onActivityTap: _showActivityDetail,
          onActivityEdit: _showEditActivityDialog,
          onActivityDelete: (activity) =>
              _deleteActivity(activity, ref.read(languageRiverpod)),
        );
      default:
        return Container();
    }
  }

  // ========== HELPER METHODS ==========
  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }


  // ========== HEADER BARU SEPERTI PRESENCE TEACHER ==========
  Widget _buildHeader(LanguageProvider languageProvider) {
    return ClassActivityHeader(
      currentStep: _currentStep,
      selectedClassName: _selectedClassName,
      selectedSubjectName: _selectedSubjectName,
      primaryColor: _getPrimaryColor(),
      languageProvider: languageProvider,
      onBackPressed: () async {
        final shouldPop = await _handleWillPop();
        if (shouldPop && mounted) {
          AppNavigator.pop(context);
        }
      },
      onRefreshPressed: _forceRefresh,
      // Pass the pre-built tab switcher so its TabController GlobalKey
      // stays in this State — same idea as a Vue named slot.
      tabSwitcherWidget: _currentStep == 2
          ? ActivityTabSwitcher(
              tabSwitcherKey: _tabSwitcherKey,
              tabController: _tabController,
              primaryColor: _getPrimaryColor(),
              allStudentsLabel: languageProvider.getTranslatedText({
                'en': 'All Students',
                'id': 'Semua Siswa',
              }),
              specificStudentLabel: languageProvider.getTranslatedText({
                'en': 'Specific Student',
                'id': 'Khusus Siswa',
              }),
            )
          : null,
    );
  }

  // Method helpers for API to avoid errors if they were deleted
  Future<void> _loadMaterials(String subjectId) async {
    try {
      final materials = await getIt<ApiSubjectService>().getMaterials();
      setState(() {
        _chapterList = materials;
        _subChapterList = [];
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load materials: $e');
    }
  }

  Future<void> _loadSubChapterContent(String chapterId) async {
    try {
      final subMaterials = await getIt<ApiSubjectService>()
          .getSubChapterMaterials(chapterId: chapterId);
      setState(() {
        _subChapterList = subMaterials;
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load sub chapter materials: $e');
    }
  }

  Future<void> _loadActivities() async {
    if (_isLoadingMore) return;

    try {
      setState(() {
        if (_currentPage == 1) {
          _isLoading = true;
        }
      });

      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassActivityService>()
          .getClassActivityPaginated(
            page: _currentPage,
            limit: _perPage,
            teacherId: _teacherId,
            classId: _selectedClassId,
            subjectId: _selectedSubjectId,
            target: _currentTarget,
            search: _searchController.text.isNotEmpty
                ? _searchController.text
                : null,
            date: _selectedDateFilter,
            academicYearId: academicYearId,
          );

      // if (kDebugMode) {
      //   print(
      //     'Loaded activities page $_currentPage: ${response['data']?.length ?? 0} items',
      //   );
      // }

      setState(() {
        if (_currentPage == 1) {
          _activityList = response['data'] ?? [];
        } else {
          _activityList.addAll(response['data'] ?? []);
        }
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // Show tour
      if (_currentPage == 1 &&
          !widget.autoShowActivityDialog &&
          _currentStep == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkAndShowTour();
          }
        });
      }

      // Auto show activity dialog if specified
      if (widget.autoShowActivityDialog && _currentPage == 1) {
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            _showActivityTypeDialog();
          }
        });
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load activities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMoreData = false;
        });
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _checkAndShowTour() async {
    if (_currentStep != 2) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_activity_screen',
        'guru',
      );
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
      AppLogger.error('class_activity', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'class_activity_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('class_activity_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'class_activity_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('class_activity_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "TabSwitcher",
        keyTarget: _tabSwitcherKey,
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
                    "Mode Tampilan",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Pilih 'Semua Siswa' untuk melihat aktivitas umum kelas, atau 'Khusus Siswa' untuk melihat histori aktivitas per murid.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
        identify: "SearchFilter",
        keyTarget: _searchFilterKey,
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
                    "Pencarian & Filter",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Cari aktivitas berdasarkan judul atau gunakan filter untuk mencari rentang waktu tertentu.",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (_selectedSubjectCanEdit) {
      targets.add(
        TargetFocus(
          identify: "AddActivity",
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
                      "Tambah Aktivitas",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Gunakan tombol ini untuk menambahkan aktivitas absensi/jurnal kelas maupun memberikan penugasan (PR / Ujian) kepada siswa.",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }
}

