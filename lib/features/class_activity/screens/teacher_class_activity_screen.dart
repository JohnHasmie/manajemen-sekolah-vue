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
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/tab_switcher.dart';
import 'package:manajemensekolah/features/class_activity/services/class_activity_service.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
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

/// Teacher's class activity (teaching journal) management screen.
///
/// This is a StatefulWidget -- like a Vue page component with its own local
/// state. The constructor parameters below are like Vue `props` -- immutable
/// data passed from the parent (e.g., from navigation or deep link).
///
/// Supports deep linking via optional initial* parameters, allowing other
/// screens to navigate here with pre-selected class/subject/chapter.
/// In Vue Router terms, these are like route query params (`?classId=...`).
class ClassActifityScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialBabId;
  final String? initialSubBabId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  const ClassActifityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialBabId,
    this.initialSubBabId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
  });

  @override
  ClassActifityScreenState createState() => ClassActifityScreenState();
}

/// The mutable State for [ClassActifityScreen].
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
class ClassActifityScreenState extends ConsumerState<ClassActifityScreen>
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

  String? _buildClassesCacheKey() {
    if (_teacherId.isEmpty) return null;
    final academicYearId = ref.read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    return 'class_activity_classes_${_teacherId}_$academicYearId';
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
  /// Like a Vue `<ClassList>` component rendered when `currentStep === 0`.
  Widget _buildClassList(LanguageProvider languageProvider) {
    if (_isLoading) {
      return SkeletonListLoading(itemCount: 4, infoTagCount: 1);
    }

    if (_classList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Kelas Tidak Ditemukan',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'You do not have any assigned classes for this academic year.',
          'id':
              'Anda tidak memiliki kelas yang ditugaskan untuk tahun ajaran ini.',
        }),
        icon: Icons.class_outlined,
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 16),
      itemCount: _classList.length,
      itemBuilder: (context, index) {
        final classData = _classList[index];
        final isHomeroom = classData['is_homeroom'] == true;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                setState(() {
                  _selectedClassId = classData['id'].toString();
                  _selectedClassName = classData['name'] ?? classData['nama'];
                  _currentStep = 1;
                });
                await _loadSubjectsForClass();
              },
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ColorUtils.getColorForIndex(
                          index,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColorUtils.getColorForIndex(
                            index,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        isHomeroom
                            ? Icons.home_work_rounded
                            : Icons.class_rounded,
                        color: ColorUtils.getColorForIndex(index),
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  classData['name'] ?? classData['nama'] ?? '-',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                              ),
                              if (isHomeroom)
                                Container(
                                  margin: EdgeInsets.only(left: 8),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Wali Kelas',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.xs),
                          // Subtitle: Grade • Major
                          if ([
                            classData['tingkat'],
                            classData['jurusan'],
                          ].any((e) => e != null && e.toString().isNotEmpty))
                            Text(
                              [classData['tingkat'], classData['jurusan']]
                                  .where(
                                    (e) => e != null && e.toString().isNotEmpty,
                                  )
                                  .join(' • '),
                              style: TextStyle(
                                color: ColorUtils.slate500,
                                fontSize: 12,
                              ),
                            ),
                          // Homeroom Teacher Name
                          if (classData['homeroom_teacher_name'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Wali Kelas: ${classData['homeroom_teacher_name']}',
                                style: TextStyle(
                                  color: ColorUtils.slate500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: ColorUtils.slate500,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the subject selection list (Step 1 of the wizard).
  /// Like a Vue `<SubjectList>` component rendered when `currentStep === 1`.
  Widget _buildSubjectList(LanguageProvider languageProvider) {
    if (_isLoading) {
      return SkeletonListLoading(itemCount: 6, infoTagCount: 1);
    }

    if (_subjectList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Mata Pelajaran Tidak Ditemukan',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects suitable for this class found.',
          'id': 'Tidak ditemukan mata pelajaran yang sesuai untuk kelas ini.',
        }),
        icon: Icons.menu_book_outlined,
      );
    }

    return Column(
      children: [
        // Selection Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.lg),
          color: ColorUtils.slate50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Selected Class:',
                  'id': 'Kelas Terpilih:',
                }),
                style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
              ),
              SizedBox(height: AppSpacing.xs),
              Text(
                _selectedClassName ?? '-',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(top: 8, bottom: 16),
            itemCount: _subjectList.length,
            itemBuilder: (context, index) {
              final subject = _subjectList[index];
              final subjectName = subject['name'] ?? subject['nama'] ?? '-';
              // Check backend response for code/description
              final subjectCode = subject['code'] ?? subject['kode'] ?? '';

              return Container(
                margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      setState(() {
                        _selectedSubjectId = subject['id'].toString();
                        _selectedSubjectName = subjectName;
                        _selectedSubjectCanEdit = subject['can_edit'] == true;
                        _currentStep = 2; // Go to Activity List
                      });
                      await _loadActivities();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ColorUtils.slate200,
                          width: 1,
                        ),
                        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: ColorUtils.getColorForIndex(
                                index,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ColorUtils.getColorForIndex(
                                  index,
                                ).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: ColorUtils.getColorForIndex(index),
                              size: 22,
                            ),
                          ),
                          SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subjectName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                                SizedBox(height: AppSpacing.xs),
                                Text(
                                  subjectCode.isNotEmpty
                                      ? subjectCode
                                      : 'Ketuk untuk melihat kegiatan',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 12,
                                  ),
                                ),
                                if (subject['can_edit'] == false)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: ColorUtils.warning600.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Read Only',
                                        'id': 'Hanya Lihat',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: ColorUtils.warning600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.chevron_right,
                              color: ColorUtils.slate500,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            final cached = await LocalCacheService.load(lastCacheKey, ttl: const Duration(hours: 3));
            if (cached != null && mounted) {
              final cachedData = Map<String, dynamic>.from(cached);
              setState(() {
                _classList = List<dynamic>.from(cachedData['classes'] ?? []);
                _scheduleList = List<dynamic>.from(cachedData['schedules'] ?? []);
                if (_classList.isNotEmpty) _isLoading = false;
              });
              AppLogger.info('class_activity', 'Loaded ${_classList.length} classes from early cache');
            }
          } catch (e) {
            AppLogger.error('class_activity', 'Early cache load error: $e');
          }
        }
      }

      if (!isAdmin && teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        // ✅ Use cached data from provider — no API calls needed
        AppLogger.debug('class_activity', 'Using TeacherProvider cache (teacherId=${teacherProvider.teacherId})');

        setState(() {
          _teacherId = teacherProvider.teacherId!;
          _teacherName = teacherProvider.teacherName ?? 'Guru';
        });

        // Load classes and schedule using cached teacher ID
        await Future.wait([
          _loadClasses(teacherProvider.teacherId!, isAdmin: false),
          _loadSchedule(teacherProvider.teacherId!),
        ]);

        // If initial params provided, try to navigate deep
        await _handleInitialNavigation();
        return;
      }

      // ─── Step 2: Fallback — fetch from API (direct navigation, deep link, etc.) ───
      AppLogger.debug('class_activity', 'TeacherProvider empty, falling back to API');

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
          AppLogger.debug('class_activity', 'User is Admin/Super Admin. Loading all classes.');
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
              AppLogger.debug('class_activity', 'userData appears to be a teacher record. Using ID: $userId',);
              resolvedTeacherId = userId;
            } else {
              // Try TeacherProvider.ensureLoaded first
              String? academicYearId;
              try {
                if (mounted) {
                  academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
                }
              } catch (e) {}

              await teacherProvider.ensureLoaded(academicYearId: academicYearId);

              if (teacherProvider.teacherId != null) {
                resolvedTeacherId = teacherProvider.teacherId;
              } else {
                // Last resort: direct API call
                final teacherData = await getIt<ApiTeacherService>().getGuruByUserId(
                  userId,
                  academicYearId: academicYearId,
                );
                if (teacherData != null && teacherData['id'] != null) {
                  resolvedTeacherId = teacherData['id'].toString();
                }
              }
            }

            if (resolvedTeacherId != null) {
              AppLogger.info('class_activity', 'Resolved Teacher ID: $resolvedTeacherId');
              setState(() {
                _teacherId = resolvedTeacherId!;
              });

              await Future.wait([
                _loadClasses(resolvedTeacherId, isAdmin: false),
                _loadSchedule(resolvedTeacherId),
              ]);

              await _handleInitialNavigation();
            } else {
              // FALLBACK: Teacher resolution failed.
              AppLogger.error('class_activity', 'Failed to resolve Teacher ID. Attempting fallback as Admin...',);

              await _loadClasses(userId, isAdmin: true);

              if (_classList.isNotEmpty) {
                AppLogger.warning('class_activity', 'Fallback successful: Loaded classes as Admin');
              } else {
                AppLogger.error('class_activity', 'Fallback failed: No classes loaded or not authorized',);
                setState(() => _isLoading = false);
              }
            }
          } catch (e) {
            AppLogger.error('class_activity', 'Error during teacher resolution: $e');
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
    if (widget.initialClassId != null) {
      _selectedClassId = widget.initialClassId;
      _selectedClassName = widget.initialClassName;
      _currentStep = 1;

      await _loadSubjectsForClass();

      if (widget.initialSubjectId != null) {
        _selectedSubjectId = widget.initialSubjectId;
        _selectedSubjectName = widget.initialSubjectName;
        _currentStep = 2;
        await _loadActivities();
      }
    }
  }

  /// Fetches the list of classes assigned to the teacher.
  /// Uses a cache-first strategy with LocalCacheService (like browser localStorage).
  /// In Laravel terms, this is like `ClassController@index` with cache middleware.
  Future<void> _loadClasses(String teacherId, {bool isAdmin = false, bool useCache = true}) async {
    try {
      final academicYearId = ref.read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final cacheKey = 'class_activity_classes_${teacherId}_$academicYearId';

      // Step 1: Try loading from cache if list is still empty
      if (useCache && _classList.isEmpty) {
        try {
          final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            setState(() {
              _classList = List<dynamic>.from(cachedData['classes'] ?? []);
              _scheduleList = List<dynamic>.from(cachedData['schedules'] ?? []);
              _isLoading = false;
            });
            AppLogger.info('class_activity', 'Loaded ${_classList.length} classes from cache');
          }
        } catch (e) {
          AppLogger.error('class_activity', 'Cache load error: $e');
        }
      }

      // Step 2: Show skeleton only if still empty
      if (_classList.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      // Step 3: Fetch fresh data from API
      List<dynamic> classes = [];

      if (isAdmin) {
        final response = await getIt<ApiClassService>().getClassPaginated(
          limit: 100,
          academicYearId: academicYearId,
        );
        classes = response['data'] ?? [];
      } else {
        classes = await getIt<ApiTeacherService>().getTeacherClasses(
          teacherId,
          academicYearId: academicYearId,
        );
      }

      if (!mounted) return;

      // Step 4: Update UI with fresh data
      setState(() {
        _classList = classes;
        _isLoading = false;
      });

      // Step 5: Save to cache and persist cache key
      await LocalCacheService.save(cacheKey, {
        'classes': classes,
        'schedules': _scheduleList,
      });
      final prefs = PreferencesService();
      await prefs.setString(_prefKeyLastCacheKey, cacheKey);

      AppLogger.info('class_activity', 'Saved ${classes.length} classes to cache ($cacheKey)');
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading classes: $e');

      if (!mounted) return;

      // Only show error if no cached data available
      if (_classList.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadSchedule(String teacherId) async {
    try {
      final academicYearId = ref.read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final scheduleData = await getIt<ApiScheduleService>().getScheduleByTeacher(
        teacherId: teacherId,
        academicYear: academicYearId,
      );

      // scheduleData is already guaranteed to be a List<dynamic> by the service
      List<dynamic> schedules = scheduleData;

      if (mounted) {
        setState(() {
          _scheduleList = schedules;
        });
        AppLogger.info('class_activity', 'Loaded ${_scheduleList.length} schedules for teacher $teacherId',);

        // Update cache with schedules data
        final cacheKey = _buildClassesCacheKey();
        if (cacheKey != null && _classList.isNotEmpty) {
          LocalCacheService.save(cacheKey, {
            'classes': _classList,
            'schedules': schedules,
          });
        }
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading schedule: $e');
    }
  }

  Future<void> _loadSubjectsForClass({bool useCache = true}) async {
    if (_selectedClassId == null) return;

    final subjectCacheKey = CacheKeyBuilder.custom('class_activity_subjects', _teacherId, _selectedClassId ?? '');

    // Step 1: Try cache first
    if (useCache && _subjectList.isEmpty) {
      try {
        final cached = await LocalCacheService.load(subjectCacheKey, ttl: const Duration(hours: 3));
        if (cached != null && mounted) {
          setState(() {
            _subjectList = List<dynamic>.from(cached);
            _isLoading = false;
          });
          AppLogger.info('class_activity', 'Loaded ${_subjectList.length} subjects from cache');
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
      final academicYearId = ref.read(academicYearRiverpod)
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
      final mySchedules = await getIt<ApiScheduleService>().getSchedulesPaginated(
        limit: 100,
        teacherId: _teacherId,
        classId: _selectedClassId,
        tahunAjaran: academicYearId,
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
          var s = Map<String, dynamic>.from(subject);
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
            var s = Map<String, dynamic>.from(subject);
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
      AppLogger.info('class_activity', 'Saved ${subjects.length} subjects to cache');
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

  Widget _buildActivityTypeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
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
        onChapterSelected: _loadSubChapterMaterials,
        onActivityAdded: _loadActivities,
        initialTarget: _currentTarget,
        activityType: activityType,
        initialDate: widget.initialDate,
        initialSubjectId: widget.initialSubjectId,
        initialClassId: widget.initialClassId,
        initialBabId: widget.initialBabId,
        initialSubBabId: widget.initialSubBabId,
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
        onChapterSelected: _loadSubChapterMaterials,
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
        initialBabId: activity['chapter_id']?.toString(),
        initialSubBabId: activity['sub_chapter_id']?.toString(),
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
        await getIt<ApiClassActivityService>().deleteKegiatan(activity['id'].toString());

        if (!mounted) return;

                SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({
                'en': 'Activity deleted successfully',
                'id': 'Kegiatan berhasil dihapus',
              }));

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
            final response =
                await getIt<ApiClassActivityService>().getClassActivityPaginated(
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
            AppLogger.error('class_activity', 'Error checking material usage: $e');
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
              final subChapters = await getIt<ApiSubjectService>().getSubBabMateri(
                babId: activity['chapter_id'].toString(),
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

            AppLogger.debug('class_activity', 'Activities check complete. Unchecking ${progressItems.length} items.',);
          } catch (e) {
            AppLogger.error('class_activity', 'Error fetching sub-chapters for uncheck: $e');
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
            AppLogger.error('class_activity', 'Error parsing additional materials: $e');
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
            AppLogger.debug('class_activity', 'Auto-unchecked ${progressItems.length} materials.');
          } catch (e) {
            AppLogger.error('class_activity', 'Error auto-unchecking materials: $e');
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

  // ========== TAB SWITCHER MENGGUNAKAN KOMPONEN ==========
  Widget _buildTabSwitcher(LanguageProvider languageProvider) {
    final tabs = [
      TabItem(
        label: languageProvider.getTranslatedText({
          'en': 'All Students',
          'id': 'Semua Siswa',
        }),
        icon: Icons.group,
      ),
      TabItem(
        label: languageProvider.getTranslatedText({
          'en': 'Specific Student',
          'id': 'Khusus Siswa',
        }),
        icon: Icons.person,
      ),
    ];

    return Container(
      key: _tabSwitcherKey,
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: TabSwitcher(
        tabController: _tabController,
        tabs: tabs,
        primaryColor: _getPrimaryColor(),
      ),
    );
  }

  // ========== SEARCH AND FILTER MENGGUNAKAN KOMPONEN ==========
  Widget _buildSearchAndFilter(LanguageProvider languageProvider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        key: _searchFilterKey,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: ColorUtils.slate900),
                      decoration: InputDecoration(
                        hintText: languageProvider.getTranslatedText({
                          'en': 'Search activities...',
                          'id': 'Cari kegiatan...',
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
                        _resetAndLoadActivities();
                      },
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.search, color: _getPrimaryColor()),
                      onPressed: () {
                        _resetAndLoadActivities();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: _hasActiveFilter ? _getPrimaryColor() : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasActiveFilter
                    ? _getPrimaryColor()
                    : ColorUtils.slate300,
              ),
            ),
            child: IconButton(
              onPressed: _showFilterSheet,
              icon: Icon(
                Icons.tune,
                color: _hasActiveFilter ? Colors.white : ColorUtils.slate700,
              ),
              tooltip: languageProvider.getTranslatedText({
                'en': 'Filter',
                'id': 'Filter',
              }),
            ),
          ),
        ],
      ),
    );
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

  // ========== FILTER CHIPS ==========
  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedDateFilter != null) {
      final label = _selectedDateFilter == 'today'
          ? languageProvider.getTranslatedText({
              'en': 'Today',
              'id': 'Hari Ini',
            })
          : _selectedDateFilter == 'week'
          ? languageProvider.getTranslatedText({
              'en': 'This Week',
              'id': 'Minggu Ini',
            })
          : languageProvider.getTranslatedText({
              'en': 'This Month',
              'id': 'Bulan Ini',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDateFilter = null;
            _hasActiveFilter = false;
          });
          _resetAndLoadActivities();
        },
      });
    }

    return filterChips;
  }

  Widget _buildActivityList() {
    final languageProvider = ref.watch(languageRiverpod);
        if (_isLoading && _activityList.isEmpty) {
          return SkeletonListLoading(itemCount: 5, infoTagCount: 2);
        }

        return Column(
          children: [
            // Header removed

            // Search dan Filter Bar
            _buildSearchAndFilter(languageProvider),

            // Filter Chips
            if (_hasActiveFilter) ...[
              SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  children: _buildFilterChips(languageProvider).map((filter) {
                    return Container(
                      margin: EdgeInsets.only(right: 6),
                      child: Chip(
                        label: Text(
                          filter['label'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        deleteIcon: Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                        onDeleted: filter['onRemove'],
                        backgroundColor: _getPrimaryColor().withValues(
                          alpha: 0.7,
                        ),
                        side: BorderSide.none,
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
                  }).toList(),
                ),
              ),
              SizedBox(height: AppSpacing.sm),
            ],

            Expanded(
              child: _activityList.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No Activities',
                        'id': 'Belum ada kegiatan',
                      }),
                      subtitle:
                          _searchController.text.isEmpty && !_hasActiveFilter
                          ? languageProvider.getTranslatedText({
                              'en': 'No activities found for this subject.',
                              'id':
                                  'Tidak ada kegiatan untuk mata pelajaran ini.',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'No search results found',
                              'id': 'Tidak ditemukan hasil pencarian',
                            }),
                      icon: Icons.event_note,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(top: 8, bottom: 16),
                      itemCount:
                          _activityList.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _activityList.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.lg),
                              child: CircularProgressIndicator(
                                color: _getPrimaryColor(),
                              ),
                            ),
                          );
                        }
                        final activity = _activityList[index];
                        return _buildActivityCard(activity, context);
                      },
                    ),
            ),
          ],
        );
  }

  Widget _buildActivityInfoTag(IconData icon, String label, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ========== CARD KEGIATAN (PATTERN #8) ==========
  Widget _buildActivityCard(dynamic activity, BuildContext context) {
    final isAssignment =
        activity['jenis'] == 'tugas' ||
        activity['jenis'] == 'assignment' ||
        activity['type'] == 'assignment';
    final isSpecificTarget = activity['target_role'] == 'khusus';
    final accentColor = isAssignment
        ? ColorUtils.warning600
        : ColorUtils.success600;
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = _getPrimaryColor();

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showActivityDetail(activity),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isAssignment
                        ? Icons.assignment_outlined
                        : Icons.menu_book_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] ?? 'Judul Kegiatan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3),
                      Text(
                        '${activity['subject_name'] ?? _selectedSubjectName ?? ''} • ${activity['class_name'] ?? _selectedClassName ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _buildActivityInfoTag(
                            Icons.calendar_today_outlined,
                            '${activity['day'] ?? '-'} • ${_formatDate(activity['date'])}',
                          ),
                          _buildActivityInfoTag(
                            isAssignment
                                ? Icons.assignment_outlined
                                : Icons.menu_book_outlined,
                            isAssignment
                                ? languageProvider.getTranslatedText({
                                    'en': 'Task',
                                    'id': 'Tugas',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Material',
                                    'id': 'Materi',
                                  }),
                            tagColor: accentColor,
                          ),
                          _buildActivityInfoTag(
                            isSpecificTarget
                                ? Icons.person_outline
                                : Icons.group_outlined,
                            isSpecificTarget
                                ? languageProvider.getTranslatedText({
                                    'en': 'Specific',
                                    'id': 'Khusus',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'All',
                                    'id': 'Semua',
                                  }),
                            tagColor: isSpecificTarget
                                ? ColorUtils.violet700
                                : ColorUtils.success600,
                          ),
                          if (isAssignment && activity['batas_waktu'] != null)
                            _buildActivityInfoTag(
                              Icons.access_time_outlined,
                              _formatDate(activity['batas_waktu']),
                              tagColor: ColorUtils.error600,
                            ),
                        ],
                      ),
                      if (activity['deskripsi'] != null &&
                          activity['deskripsi'].toString().isNotEmpty) ...[
                        SizedBox(height: 6),
                        Text(
                          activity['deskripsi'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                if (_selectedSubjectCanEdit)
                  Column(
                    children: [
                      _buildCircleActionButton(
                        icon: Icons.edit_outlined,
                        color: primaryColor,
                        onTap: () => _showEditActivityDialog(activity),
                      ),
                      SizedBox(height: 6),
                      _buildCircleActionButton(
                        icon: Icons.delete_outline,
                        color: ColorUtils.error600,
                        onTap: () =>
                            _deleteActivity(activity, languageProvider),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: ColorUtils.slate500,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  void _showActivityDetail(dynamic activity) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = _getPrimaryColor();
    final isAssignment =
        activity['jenis'] == 'tugas' ||
        activity['jenis'] == 'assignment' ||
        activity['type'] == 'assignment';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
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
                    ),
                    child: Icon(
                      isAssignment
                          ? Icons.assignment_rounded
                          : Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAssignment
                              ? languageProvider.getTranslatedText({
                                  'en': 'Assignment',
                                  'id': 'Tugas',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Material',
                                  'id': 'Materi',
                                }),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activity['title'] ?? '-',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      Icons.class_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Class',
                        'id': 'Kelas',
                      }),
                      activity['class_name'] ?? _selectedClassName ?? '-',
                      primaryColor,
                    ),
                    _buildDetailRow(
                      Icons.menu_book_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mata Pelajaran',
                      }),
                      activity['subject_name'] ?? _selectedSubjectName ?? '-',
                      primaryColor,
                    ),
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Date',
                        'id': 'Tanggal',
                      }),
                      '${activity['day']} • ${_formatDate(activity['date'])}',
                      primaryColor,
                    ),
                    if (isAssignment && activity['batas_waktu'] != null)
                      _buildDetailRow(
                        Icons.access_time_rounded,
                        languageProvider.getTranslatedText({
                          'en': 'Deadline',
                          'id': 'Batas Waktu',
                        }),
                        _formatDate(activity['batas_waktu']),
                        ColorUtils.error600,
                      ),
                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].toString().isNotEmpty)
                      _buildDetailRow(
                        Icons.description_rounded,
                        languageProvider.getTranslatedText({
                          'en': 'Description',
                          'id': 'Deskripsi',
                        }),
                        activity['deskripsi'].toString(),
                        primaryColor,
                      ),
                    if (activity['bab_judul'] != null)
                      _buildDetailRow(
                        Icons.auto_stories_rounded,
                        languageProvider.getTranslatedText({
                          'en': 'Chapter',
                          'id': 'Materi',
                        }),
                        '${activity['bab_judul']}${activity['sub_bab_judul'] != null ? '\n• ${activity['sub_bab_judul']}' : ''}',
                        primaryColor,
                      ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ColorUtils.slate100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: ColorUtils.slate300),
                        foregroundColor: ColorUtils.slate700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Close',
                          'id': 'Tutup',
                        }),
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_selectedSubjectCanEdit) ...[
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          AppNavigator.pop(context);
                          _showEditActivityDialog(activity);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Edit',
                            'id': 'Edit',
                          }),
                          style: TextStyle(fontWeight: FontWeight.w600),
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

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final iconColor = _getPrimaryColor();
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);

    return WillPopScope(
      onWillPop: _handleWillPop,
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
        return _buildActivityList();
      default:
        return Container();
    }
  }

  // ========== HELPER METHODS ==========
  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.8)],
    );
  }

  // ========== HEADER BARU SEPERTI PRESENCE TEACHER ==========
  Widget _buildHeader(LanguageProvider languageProvider) {
    String title = languageProvider.getTranslatedText({
      'en': 'Class Activity',
      'id': 'Kegiatan Kelas',
    });

    String subtitle = '';
    if (_currentStep == 0) {
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select a class to manage activities',
        'id': 'Pilih kelas untuk mengelola kegiatan',
      });
    } else if (_currentStep == 1) {
      subtitle = _selectedClassName ?? '-';
    } else if (_currentStep == 2) {
      subtitle =
          '${_selectedClassName ?? '-'} • ${_selectedSubjectName ?? '-'}';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withValues(alpha: 0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final shouldPop = await _handleWillPop();
                  if (shouldPop && mounted) {
                    AppNavigator.pop(context);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'refresh') {
                    _forceRefresh();
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
                        SizedBox(width: AppSpacing.sm),
                        Text('Perbarui Data'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'help',
                    child: Row(
                      children: [
                        Icon(Icons.help_outline, size: 20),
                        SizedBox(width: AppSpacing.sm),
                        Text('Help'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_currentStep == 2) ...[
            SizedBox(height: AppSpacing.lg),
            _buildTabSwitcher(languageProvider),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    DateTime? dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      dateTime = DateTime.tryParse(date);
    }
    if (dateTime == null) return '-';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  // Method helpers for API to avoid errors if they were deleted
  Future<void> _loadMaterials(String subjectId) async {
    try {
      final materials = await getIt<ApiSubjectService>().getMateri();
      setState(() {
        _chapterList = materials;
        _subChapterList = [];
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load materials: $e');
    }
  }

  Future<void> _loadSubChapterMaterials(String chapterId) async {
    try {
      final subMaterials = await getIt<ApiSubjectService>().getSubBabMateri(
        babId: chapterId,
      );
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

      final academicYearId = ref.read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassActivityService>().getClassActivityPaginated(
        page: _currentPage,
        limit: _perPage,
        teacherId: _teacherId,
        classId: _selectedClassId,
        subjectId: _selectedSubjectId,
        target: _currentTarget,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        tanggal: _selectedDateFilter,
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
      final tourCacheKey = CacheKeyBuilder.tourStatus('class_activity_screen', 'guru');
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
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
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(name: 'class_activity_tour', role: 'guru', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('class_activity_screen', 'guru'), {'should_show': false});
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(name: 'class_activity_tour', role: 'guru', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('class_activity_screen', 'guru'), {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];

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

class AddActivityDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<dynamic> scheduleList;
  final List<dynamic> subjectList;
  final List<dynamic> chapterList;
  final List<dynamic> subChapterList;
  final Function(String) onSubjectSelected;
  final Function(String) onChapterSelected;
  final VoidCallback onActivityAdded;
  final String initialTarget;
  final String activityType;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialClassId;
  final String? initialBabId;
  final String? initialSubBabId;
  final bool isEditMode;
  final dynamic activityData;

  const AddActivityDialog({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.scheduleList,
    required this.subjectList,
    required this.chapterList,
    required this.subChapterList,
    required this.onSubjectSelected,
    required this.onChapterSelected,
    required this.onActivityAdded,
    required this.initialTarget,
    required this.activityType,
    this.initialDate,
    this.initialSubjectId,
    this.initialClassId,
    this.initialBabId,
    this.initialSubBabId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.isEditMode = false,
    this.activityData,
  });

  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;

  @override
  ConsumerState<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends ConsumerState<AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final List<String> _selectedStudents = [];

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedChapterId;
  String? _selectedSubChapterId;
  DateTime? _selectedDate;
  DateTime? _deadline;
  String? _selectedDay;
  bool _isSubmitting = false;
  bool _isLoadingStudents = false;
  List<dynamic> _studentList = [];

  // Bab & Sub Bab Materi
  bool _isLoadingBab = false;
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  String? _selectedBabId;
  String? _selectedSubBabId; // Primary selection (kept for backward compat)
  final List<String> _selectedSubBabIds = []; // Multi-selection support
  bool _useMateriTitle = false; // Toggle: use bab/sub bab or manual input

  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  void initState() {
    super.initState();

    // Set initial values from widget parameters or use defaults
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedDay = _days[_selectedDate!.weekday - 1];
    _selectedSubjectId = widget.initialSubjectId;
    _selectedClassId = widget.initialClassId;
    _selectedBabId = widget.initialBabId;
    _selectedSubBabId = widget.initialSubBabId;

    // Initialize multi-select list
    if (_selectedSubBabId != null) {
      _selectedSubBabIds.add(_selectedSubBabId!);
    }
    if (widget.initialAdditionalMaterials != null) {
      for (var item in widget.initialAdditionalMaterials!) {
        final subId = item['sub_chapter_id']?.toString();
        if (subId != null && !_selectedSubBabIds.contains(subId)) {
          _selectedSubBabIds.add(subId);
        }
      }
    }

    // If in edit mode, populate form with existing data
    if (widget.isEditMode && widget.activityData != null) {
      _judulController.text = widget.activityData['judul']?.toString() ?? '';
      _deskripsiController.text =
          widget.activityData['deskripsi']?.toString() ?? '';

      // Parse deadline if exists
      if (widget.activityData['batas_waktu'] != null) {
        _deadline = DateTime.tryParse(
          widget.activityData['batas_waktu'].toString(),
        );
      }

      // Load selected students if target is khusus
      if (widget.initialTarget == 'khusus' &&
          widget.activityData['siswa_target'] != null) {
        final siswaTarget = widget.activityData['siswa_target'];
        if (siswaTarget is List) {
          _selectedStudents.addAll(siswaTarget.map((s) => s.toString()));
        }
      }
    }

    // If initial bab is provided, enable material title mode
    if (_selectedBabId != null || _selectedSubBabId != null) {
      _useMateriTitle = true;
    }

    // Debug logging
    // if (kDebugMode) {
    //   print('===== AddActivityDialog INIT =====');
    //   print('Subject list count: ${widget.subjectList.length}');
    //   print('Schedule list count: ${widget.scheduleList.length}');
    //   print('Activity type: ${widget.activityType}');
    //   print('Initial target: ${widget.initialTarget}');
    //   print('Initial subject ID: $_selectedSubjectId');
    //   print('Initial class ID: $_selectedClassId');
    //   print('Initial bab ID: $_selectedBabId');
    //   print('Initial sub bab ID: $_selectedSubBabId');
    //   print('Use materi title: $_useMateriTitle');
    //   print('Initial date: $_selectedDate');
    // }

    // If initial subject is provided, load its data
    if (_selectedSubjectId != null) {
      Future.delayed(Duration.zero, () {
        AppLogger.debug('class_activity', 'Loading initial data for subject: $_selectedSubjectId');

        widget.onSubjectSelected(_selectedSubjectId!);
        // Load bab materi for the initial subject
        _loadBabMateri(_selectedSubjectId!).then((_) {
          // After bab list loaded, load sub bab if initial bab is provided
          if (_selectedBabId != null) {
            AppLogger.debug('class_activity', 'Loading sub bab for bab: $_selectedBabId');
            _loadSubBabMateri(_selectedBabId!).then((_) {
              // After sub bab loaded, update title
              _updateTitleFromMateri();
            });
          } else {
            // Only bab selected, update title
            _updateTitleFromMateri();
          }
        });

        // If initial class is provided and target is 'khusus', load students
        if (_selectedClassId != null && widget.initialTarget == 'khusus') {
          AppLogger.debug('class_activity', 'Loading students for class: $_selectedClassId');
          _loadStudents();
        }
      });
    } else {
      AppLogger.debug('class_activity', 'No initial subject ID - waiting for user selection');
    }

    AppLogger.debug('class_activity', '=====================================');
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;

    setState(() {
      _isLoadingStudents = true;
      _studentList = []; // Clear previous list
    });

    AppLogger.debug('class_activity', '[_loadStudents] Starting load for class: $_selectedClassId');

    try {
      final students = await getIt<ApiClassActivityService>().getSiswaByKelas(
        _selectedClassId!,
      );

      if (!mounted) {
        AppLogger.debug('class_activity', '[_loadStudents] Widget unmounted, skipping setState');
        return;
      }

      // if (kDebugMode) {
      //   print('[_loadStudents] Loaded ${students.length} students');
      // }

      setState(() {
        _studentList = students;
        _isLoadingStudents = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('class_activity', 'Error loading students: $e');
      AppLogger.error('class_activity', stackTrace);
      if (mounted) {
        setState(() {
          _studentList = [];
          _isLoadingStudents = false;
        });
        // Non-critical in a dialog, but better to show something
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadBabMateri(String subjectId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING BAB MATERI =====');
      AppLogger.debug('class_activity', 'Subject ID: $subjectId');

      setState(() {
        _isLoadingBab = true;
        _babMateriList = []; // Clear previous list while loading
      });

      // Find Master Subject ID from the selected School Subject ID
      final subject = widget.subjectList.firstWhere(
        (s) => s['id']?.toString() == subjectId,
        orElse: () => <String, dynamic>{},
      );
      final masterSubjectId = subject.isNotEmpty
          ? (subject['subject_id']?.toString() ?? subject['id']?.toString() ?? subjectId)
          : subjectId;

      final babList = await getIt<ApiSubjectService>().getBabMateri(
        subjectId: masterSubjectId,
      );

      if (kDebugMode) {
        AppLogger.debug('class_activity', 'API Response - Bab count: ${babList.length}');
        if (babList.isNotEmpty) {
          AppLogger.debug('class_activity', 'First item structure: ${babList[0]}');
          AppLogger.debug('class_activity', 'Available fields: ${babList[0].keys}');
          AppLogger.debug('class_activity', 'Judul Bab: ${babList[0]['judul_bab']}');
        }
      }

      setState(() {
        _babMateriList = babList;
        // Only reset if no initial values were provided
        if (widget.initialBabId == null) {
          _selectedBabId = null;
        }
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
        // Only clear sub bab list if no initial sub bab
        if (widget.initialSubBabId == null) {
          _subBabMateriList = [];
        }
        _isLoadingBab = false;
      });

      AppLogger.debug('class_activity', 'State updated - _babMateriList.length: ${_babMateriList.length}',);
      AppLogger.debug('class_activity', 'Current _selectedBabId: $_selectedBabId');
      AppLogger.debug('class_activity', 'Current _selectedSubBabId: $_selectedSubBabId');
      AppLogger.debug('class_activity', '=============================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _isLoadingBab = false;
        });
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadSubBabMateri(String babId) async {
    try {
      AppLogger.debug('class_activity', '===== LOADING SUB BAB MATERI =====');
      AppLogger.debug('class_activity', 'Bab ID: $babId');

      final subBabList = await getIt<ApiSubjectService>().getSubBabMateri(babId: babId);

      if (kDebugMode) {
        AppLogger.debug('class_activity', 'API Response - Sub Bab count: ${subBabList.length}');
        if (subBabList.isNotEmpty) {
          AppLogger.debug('class_activity', 'First item structure: ${subBabList[0]}');
          AppLogger.debug('class_activity', 'Available fields: ${subBabList[0].keys}');
          AppLogger.debug('class_activity', 'Judul Sub Bab: ${subBabList[0]['judul_sub_bab']}');
        }
      }

      setState(() {
        _subBabMateriList = subBabList;
        // Only reset if no initial value was provided
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
      });

      AppLogger.debug('class_activity', 'State updated - _subBabMateriList.length: ${_subBabMateriList.length}',);
      AppLogger.debug('class_activity', 'Current _selectedSubBabId: $_selectedSubBabId');
      AppLogger.debug('class_activity', '==================================');
    } catch (e) {
      AppLogger.error('class_activity', 'ERROR loading sub bab materi: $e');
      AppLogger.debug('class_activity', 'Stack trace: ${StackTrace.current}');
      if (mounted) {
                SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  String _getBabName(dynamic bab) {
    // Try multiple possible field names (backend returns 'chapter_title')
    return bab['chapter_title']?.toString() ??
        bab['judul_bab']?.toString() ??
        bab['nama']?.toString() ??
        bab['judul']?.toString() ??
        bab['title']?.toString() ??
        bab['name']?.toString() ??
        'Unknown';
  }

  String _getSubBabName(dynamic subBab) {
    // Try multiple possible field names (backend returns 'sub_chapter_title')
    return subBab['sub_chapter_title']?.toString() ??
        subBab['judul_sub_bab']?.toString() ??
        subBab['nama']?.toString() ??
        subBab['judul']?.toString() ??
        subBab['title']?.toString() ??
        subBab['name']?.toString() ??
        'Unknown';
  }

  void _updateTitleFromMateri() {
    String babName = '';
    String subBabName = '';

    // Get bab name if selected
    if (_selectedBabId != null && _babMateriList.isNotEmpty) {
      final bab = _babMateriList.firstWhere(
        (b) => b['id']?.toString() == _selectedBabId,
        orElse: () => <String, dynamic>{},
      );
      if (bab.isNotEmpty) {
        // Check if the map is not empty
        babName = _getBabName(bab);
      }
    }

    // Get sub bab name if selected
    if (_selectedSubBabId != null && _subBabMateriList.isNotEmpty) {
      final subBab = _subBabMateriList.firstWhere(
        (item) => item['id']?.toString() == _selectedSubBabId,
        orElse: () => <String, dynamic>{},
      );
      if (subBab.isNotEmpty) {
        subBabName = _getSubBabName(subBab);
      }
    }

    // Build title based on what's selected
    String title = '';
    if (babName.isNotEmpty && subBabName.isNotEmpty) {
      // Both selected: "Bab - Sub Bab"
      title = '$babName - $subBabName';
    } else if (babName.isNotEmpty) {
      // Only bab selected
      title = babName;
    } else if (subBabName.isNotEmpty) {
      // Only sub bab selected (edge case)
      title = subBabName;
    }

    if (title.isNotEmpty && title != 'Unknown') {
      _judulController.text = title;
    }
  }

  List<DropdownMenuItem<String>> _getUniqueClassItems() {
    final Map<String, Map<String, dynamic>> uniqueClasses = {};
    final now = DateTime.now();
    // Use _selectedDay if available, otherwise fallback to current day
    final String targetDay =
        _selectedDay ??
        [
          'Senin',
          'Selasa',
          'Rabu',
          'Kamis',
          'Jumat',
          'Sabtu',
          'Minggu',
        ][now.weekday - 1];

    // if (kDebugMode) {
    //   print('Getting unique classes for subject: $_selectedSubjectId');
    //   print(
    //     'Current day: $currentDay, Current time: ${now.hour}:${now.minute}',
    //   );
    //   print('Target: ${widget.initialTarget}');
    //   print('Initial class ID from widget: ${widget.initialClassId}');
    // }

    // Filter schedules by selected subject and deduplicate by class_id
    for (var schedule in widget.scheduleList) {
      final scheduleSubjectId =
          (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();

      AppLogger.debug('class_activity', 'Checking schedule: ${schedule['id']} - Subject: $scheduleSubjectId vs Selected: $_selectedSubjectId',);

      if (scheduleSubjectId == _selectedSubjectId) {
        final classId = (schedule['class_id'] ?? schedule['kelas_id'])
            .toString();

        // For SPECIFIC target: no time filter, all schedules can be selected
        if (widget.initialTarget == 'khusus') {
          if (!uniqueClasses.containsKey(classId)) {
            uniqueClasses[classId] = {
              'id': classId,
              'nama': schedule['kelas_nama'] ?? 'Unknown',
            };
          }
        }
        // For GENERAL target
        else {
          // If initialClassId exists (from teaching schedule), always include that class
          if (widget.initialClassId != null &&
              classId == widget.initialClassId) {
            if (!uniqueClasses.containsKey(classId)) {
              uniqueClasses[classId] = {
                'id': classId,
                'nama': schedule['kelas_nama'] ?? 'Unknown',
              };
              AppLogger.debug('class_activity', 'Added class from initialClassId: ${schedule['kelas_nama']}',);
            }
          }
          // Filter by time for other classes
          else {
            var scheduleDay =
                schedule['hari_nama']?.toString() ??
                schedule['day_name']?.toString() ??
                '';

            // Map English days to Indonesian if needed
            final dayMap = {
              'Monday': 'Senin',
              'Tuesday': 'Selasa',
              'Wednesday': 'Rabu',
              'Thursday': 'Kamis',
              'Friday': 'Jumat',
              'Saturday': 'Sabtu',
              'Sunday': 'Minggu',
            };

            if (dayMap.containsKey(scheduleDay)) {
              scheduleDay = dayMap[scheduleDay]!;
            }

            AppLogger.debug('class_activity', 'Schedule: ${schedule['kelas_nama']}, Day: $scheduleDay vs Target: $targetDay',);

            // Check if schedule is on the selected day
            if (scheduleDay == targetDay) {
              // Time validation removed to ensure classes always appear for the day
              // Original logic checked start_time + 23h, but this was too strict/buggy
              if (!uniqueClasses.containsKey(classId)) {
                uniqueClasses[classId] = {
                  'id': classId,
                  'nama': schedule['kelas_nama'] ?? 'Unknown',
                };
              } else {
                AppLogger.debug('class_activity', 'Class already added: $classId');
              }
            } else {
              AppLogger.debug('class_activity', 'Day mismatch: $scheduleDay != $targetDay');
            }
          }
        }
      }
    }

    // if (kDebugMode) {
    //   print('Unique classes found: ${uniqueClasses.length}');
    // }

    // Convert to dropdown items safely
    try {
      return uniqueClasses.values.map((classItem) {
        return DropdownMenuItem<String>(
          value: classItem['id'].toString(),
          child: Text(classItem['nama'] ?? 'Unknown'),
        );
      }).toList();
    } catch (e) {
      AppLogger.error('class_activity', 'Error generating class dropdown items: $e');
      return [];
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null || _selectedClassId == null) {
      _showError('Pilih mata pelajaran dan kelas terlebih dahulu');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final languageProvider = ref.read(languageRiverpod);

      final Map<String, dynamic> data = {
        'teacher_id': widget.teacherId,
        'subject_id': _selectedSubjectId,
        'class_id': _selectedClassId,
        'title': _judulController.text,
        'deskripsi': _deskripsiController.text,
        'jenis': widget.activityType,
        'target': widget.initialTarget,
        'date': _selectedDate!.toIso8601String().split('T')[0],
        'day': _selectedDay,
      };

      // Save chapter_id and sub_chapter_id if selected from materi
      if (_useMateriTitle && _selectedBabId != null) {
        data['chapter_id'] = _selectedBabId;
      } else if (_selectedChapterId != null) {
        // Fallback to old chapter props if exists
        data['chapter_id'] = _selectedChapterId;
      }

      if (_useMateriTitle && _selectedSubBabId != null) {
        data['sub_chapter_id'] = _selectedSubBabId;
      } else if (_selectedSubChapterId != null) {
        // Fallback to old sub chapter props if exists
        data['sub_chapter_id'] = _selectedSubChapterId;
      }

      // Handle Additional Material (from LIVE selection)
      if (_selectedSubBabIds.isNotEmpty) {
        final List<Map<String, dynamic>> extraMaterials = [];
        final primarySubId = data['sub_chapter_id']?.toString();

        for (var subId in _selectedSubBabIds) {
          // Skip if this is the primary sub chapter
          if (subId == primarySubId) continue;

          // Try to find full details for this sub chapter
          // 1. Check in loaded sub bab list
          var subBabData = _subBabMateriList.firstWhere(
            (s) => s['id']?.toString() == subId,
            orElse: () => <String, dynamic>{},
          );

          String? chapterIdForSub = _selectedBabId;

          // 2. If not found (maybe from initial params but not loaded in current list?), check initialAdditionalMaterials
          if (subBabData == null && widget.initialAdditionalMaterials != null) {
            final found = widget.initialAdditionalMaterials!.firstWhere(
              (m) => m['sub_chapter_id'].toString() == subId,
              orElse: () => {},
            );
            if (found.isNotEmpty) {
              // Construct a temporary object if found in initial params
              subBabData = {
                'id': subId,
                // We might not have titles here if not standard format, but we do our best
              };
              chapterIdForSub =
                  found['chapter_id']?.toString() ?? _selectedBabId;
            }
          }

          if (subBabData.isNotEmpty || chapterIdForSub != null) {
            extraMaterials.add({
              'chapter_id':
                  chapterIdForSub, // Fallback to currently selected bab
              'sub_chapter_id': subId,
            });
          } else {
            // Fallback minimal
            extraMaterials.add({'sub_chapter_id': subId});
          }
        }

        if (extraMaterials.isNotEmpty) {
          data['additional_material'] = extraMaterials;
        }
      }

      if (_deadline != null && widget.activityType == 'tugas') {
        data['batas_waktu'] = _deadline!.toIso8601String();
      }

      // Add target students for specific activities
      final Map<String, dynamic> requestData = Map<String, dynamic>.from(data);
      if (widget.initialTarget == 'khusus' && _selectedStudents.isNotEmpty) {
        requestData['siswa_target'] = _selectedStudents;
      }

      // Call appropriate API based on mode
      if (widget.isEditMode && widget.activityData != null) {
        // Update existing activity
        await getIt<ApiClassActivityService>().updateKegiatan(
          widget.activityData['id'].toString(),
          requestData,
        );
      } else {
        // Create new activity
        await getIt<ApiClassActivityService>().tambahKegiatan(requestData);
      }

      // Automatically mark material as generated (checked)
      if (data['chapter_id'] != null) {
        try {
          // Construct items list for batchSaveMateriProgress
          // Auto-mark as checked (is_checked: true)
          // Note: batchSaveMateriProgress expects different key structure ('progress_items')
          // but getIt<ApiSubjectService>().batchSaveMateriProgress helper handles the mapping from our app structure
          // We just need to match what the internal helper expects or call the API endpoint params directly?
          // Let's check getIt<ApiSubjectService>().batchSaveMateriProgress implementation again.
          // It takes {guru_id, mata_pelajaran_id, progress_items: [{bab_id, sub_bab_id, is_checked}]}

          final List<Map<String, dynamic>> progressItems = [
            {
              'bab_id': data['chapter_id'],
              'sub_bab_id': data['sub_chapter_id'],
              'is_checked': true,
              'is_generated': true,
            },
          ];

          // Add explicitly passed materials to mark as generated
          if (widget.materialsToMarkAsGenerated != null) {
            for (var item in widget.materialsToMarkAsGenerated!) {
              progressItems.add({
                'bab_id': item['bab_id'],
                'sub_bab_id': item['sub_bab_id'],
                'is_checked': true,
                'is_generated': true,
              });
            }
          }

          // Also Add manually selected IDs from the multi-select dialog
          if (_useMateriTitle &&
              _selectedSubBabIds.isNotEmpty &&
              _selectedBabId != null) {
            for (var subId in _selectedSubBabIds) {
              // Avoid duplicates
              bool exists = progressItems.any(
                (p) => p['sub_bab_id'].toString() == subId,
              );
              if (!exists) {
                progressItems.add({
                  'bab_id': _selectedBabId,
                  'sub_bab_id': subId,
                  'is_checked': true,
                  'is_generated': true,
                });
              }
            }
          }

          AppLogger.debug('class_activity', '=== BATCH SAVE PROGRESS ===');
          AppLogger.debug('class_activity', 'Progress items: ${progressItems.length}');
          AppLogger.debug('class_activity', 'First item: ${progressItems.first}');

          await getIt<ApiSubjectService>().batchSaveMateriProgress({
            'guru_id': widget.teacherId,
            'mata_pelajaran_id': _selectedSubjectId,
            'class_id': _selectedClassId,
            'progress_items': progressItems,
          });
          AppLogger.debug('class_activity', 'Auto-marked material as generated: ${data['chapter_id']}');
        } catch (e) {
          AppLogger.error('class_activity', 'Error auto-marking material: $e');
        }
      }

      if (!mounted) return;
      AppNavigator.pop(context);
      widget.onActivityAdded();

            SnackBarUtils.showSuccess(context, widget.isEditMode
                ? languageProvider.getTranslatedText({
                    'en': 'Activity updated successfully',
                    'id': 'Kegiatan berhasil diperbarui',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Activity added successfully',
                    'id': 'Kegiatan berhasil ditambahkan',
                  }));
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
        SnackBarUtils.showError(context, message);
  }

  void _openMultiSelectSubBabDialog(LanguageProvider languageProvider) {
    if (_subBabMateriList.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        // Local state for the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                languageProvider.getTranslatedText({
                  'en': 'Select Sub Chapters',
                  'id': 'Pilih Sub Bab',
                }),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: _subBabMateriList.map((subBab) {
                    final subId = subBab['id'].toString();
                    final isSelected = _selectedSubBabIds.contains(subId);
                    return CheckboxListTile(
                      title: Text(_getSubBabName(subBab)),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            if (!_selectedSubBabIds.contains(subId)) {
                              _selectedSubBabIds.add(subId);
                            }
                          } else {
                            _selectedSubBabIds.remove(subId);
                          }
                          // Update primary selection for backward compatibility
                          _selectedSubBabId = _selectedSubBabIds.isNotEmpty
                              ? _selectedSubBabIds.first
                              : null;
                        });
                        // Trigger main widget rebuild to update UI text
                        setState(() {});
                        _updateTitleFromMateri();
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => AppNavigator.pop(context),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Done',
                      'id': 'Selesai',
                    }),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    final isAssignment = widget.activityType == 'tugas';
    final primaryColor = isAssignment
        ? ColorUtils.warning600
        : ColorUtils.corporateBlue600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Gradient Header
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
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isAssignment
                            ? Icons.assignment_rounded
                            : Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        widget.isEditMode
                            ? (isAssignment
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Edit Assignment',
                                      'id': 'Edit Tugas',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Edit Material',
                                      'id': 'Edit Materi',
                                    }))
                            : (isAssignment
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Add Assignment',
                                      'id': 'Tambah Tugas',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Add Material',
                                      'id': 'Tambah Materi',
                                    })),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () => AppNavigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Box
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            widget.initialTarget == 'khusus'
                                ? Icons.people
                                : Icons.schedule,
                            color: primaryColor,
                            size: 20,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.initialTarget == 'khusus'
                                  ? languageProvider.getTranslatedText({
                                      'en':
                                          'SPECIFIC: You can select any class anytime.',
                                      'id':
                                          'KHUSUS: Anda dapat memilih kelas kapan saja.',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en':
                                          'GENERAL: Only classes from start time to +23 hours are available.',
                                      'id':
                                          'UMUM: Hanya kelas dari jam mulai sampai +23 jam yang tersedia.',
                                    }),
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Mata Pelajaran
                    Builder(
                      builder: (context) {
                        final Map<String, DropdownMenuItem<String>>
                        uniqueSubjectItems = {};
                        for (var subject in widget.subjectList) {
                          final id = subject['id']?.toString();
                          if (id != null &&
                              !uniqueSubjectItems.containsKey(id)) {
                            uniqueSubjectItems[id] = DropdownMenuItem<String>(
                              value: id,
                              child: Text(
                                subject['name'] ?? subject['nama'] ?? 'Unknown',
                              ),
                            );
                          }
                        }
                        final List<DropdownMenuItem<String>> subjectItems =
                            uniqueSubjectItems.values.toList();

                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'subject_${_selectedSubjectId}_${subjectItems.length}',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})} *',
                            prefixIcon: Icon(Icons.book),
                            border: OutlineInputBorder(),
                          ),
                          initialValue:
                              (subjectItems.any(
                                (item) => item.value == _selectedSubjectId,
                              ))
                              ? _selectedSubjectId
                              : null,
                          isExpanded: true,
                          items: subjectItems.isEmpty ? null : subjectItems,
                          onChanged: subjectItems.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedSubjectId = value;
                                    _selectedClassId = null;
                                  });
                                  if (value != null) {
                                    widget.onSubjectSelected(value);
                                    _loadBabMateri(value);
                                  }
                                },
                          validator: (value) => value == null
                              ? languageProvider.getTranslatedText({
                                  'en': 'Required',
                                  'id': 'Wajib diisi',
                                })
                              : null,
                          hint: Text(
                            subjectItems.isEmpty
                                ? languageProvider.getTranslatedText({
                                    'en': 'No subjects available',
                                    'id': 'Tidak ada mata pelajaran',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Select Subject',
                                    'id': 'Pilih Mata Pelajaran',
                                  }),
                          ),
                        );
                      },
                    ),
                    if (widget.subjectList.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en':
                                'No teaching subjects found. Please check your schedule.',
                            'id':
                                'Tidak ada mata pelajaran mengajar. Silakan periksa jadwal Anda.',
                          }),
                          style: TextStyle(
                            color: ColorUtils.error600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.md),

                    // Kelas
                    Builder(
                      builder: (context) {
                        final List<DropdownMenuItem<String>> classItems =
                            _selectedSubjectId == null
                            ? []
                            : _getUniqueClassItems();

                        return DropdownButtonFormField<String>(
                          key: ValueKey(
                            'class_${_selectedClassId}_${classItems.length}',
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})} *',
                            prefixIcon: Icon(Icons.class_),
                            border: OutlineInputBorder(),
                          ),
                          initialValue:
                              (_selectedClassId != null &&
                                  classItems.any(
                                    (item) => item.value == _selectedClassId,
                                  ))
                              ? _selectedClassId
                              : null,
                          isExpanded: true,
                          items: classItems.isEmpty ? null : classItems,
                          onChanged: _selectedSubjectId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedClassId = value;
                                  });

                                  // Defer loading students to let the dropdown update complete
                                  if (widget.initialTarget == 'khusus') {
                                    Future.delayed(
                                      Duration(milliseconds: 100),
                                      () {
                                        if (mounted) _loadStudents();
                                      },
                                    );
                                  }
                                },
                          validator: (value) => value == null
                              ? languageProvider.getTranslatedText({
                                  'en': 'Required',
                                  'id': 'Wajib diisi',
                                })
                              : null,
                          hint: Text(
                            _selectedSubjectId == null
                                ? languageProvider.getTranslatedText({
                                    'en': 'Select subject first',
                                    'id': 'Pilih mata pelajaran dulu',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Select Class',
                                    'id': 'Pilih Kelas',
                                  }),
                          ),
                        );
                      },
                    ),
                    if (_selectedSubjectId != null &&
                        _getUniqueClassItems().isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4, left: 12),
                        child: Text(
                          widget.initialTarget == 'khusus'
                              ? languageProvider.getTranslatedText({
                                  'en': 'No classes found for this subject.',
                                  'id':
                                      'Tidak ada kelas untuk mata pelajaran ini.',
                                })
                              : languageProvider.getTranslatedText({
                                  'en':
                                      'No active classes now. You can fill from class start time until +23 hours.',
                                  'id':
                                      'Tidak ada kelas aktif saat ini. Anda dapat mengisi dari jam pelajaran mulai sampai +23 jam.',
                                }),
                          style: TextStyle(
                            color: ColorUtils.warning600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    SizedBox(height: AppSpacing.md),

                    // Toggle: Select from Material or Write Manually
                    Row(
                      children: [
                        Icon(Icons.title, size: 20, color: ColorUtils.slate600),
                        SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Choose from material',
                            'id': 'Pilih dari materi',
                          }),
                          style: TextStyle(fontSize: 14),
                        ),
                        Spacer(),
                        Switch(
                          value: _useMateriTitle,
                          onChanged: _selectedSubjectId == null
                              ? null
                              : (value) {
                                  setState(() {
                                    _useMateriTitle = value;
                                    if (!value) {
                                      // Reset when switching to manual
                                      _selectedBabId = null;
                                      _selectedSubBabId = null;
                                    }
                                  });
                                },
                          activeThumbColor: primaryColor,
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.sm),

                    // Dropdown Bab Materi (if useMateriTitle = true)
                    if (_useMateriTitle) ...[
                      Builder(
                        builder: (context) {
                          final Map<String, DropdownMenuItem<String>>
                          uniqueBabItems = {};
                          for (var bab in _babMateriList) {
                            final id = bab['id']?.toString();
                            if (id != null && !uniqueBabItems.containsKey(id)) {
                              uniqueBabItems[id] = DropdownMenuItem<String>(
                                value: id,
                                child: Text(_getBabName(bab)),
                              );
                            }
                          }
                          final List<DropdownMenuItem<String>> babItems =
                              uniqueBabItems.values.toList();

                          return DropdownButtonFormField<String>(
                            key: ValueKey(
                              'bab_${_selectedBabId}_${babItems.length}',
                            ),
                            decoration: InputDecoration(
                              labelText: languageProvider.getTranslatedText({
                                'en': 'Chapter',
                                'id': 'Bab Materi',
                              }),
                              prefixIcon: Icon(Icons.menu_book),
                              border: OutlineInputBorder(),
                            ),
                            initialValue:
                                (babItems.any(
                                  (item) => item.value == _selectedBabId,
                                ))
                                ? _selectedBabId
                                : null,
                            isExpanded: true,
                            items: babItems.isEmpty ? null : babItems,
                            onChanged: babItems.isEmpty
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedBabId = value;
                                      _selectedSubBabId = null;
                                    });
                                    if (value != null) {
                                      _loadSubBabMateri(value);
                                      _updateTitleFromMateri();
                                    }
                                  },
                            hint: Text(
                              languageProvider.getTranslatedText({
                                'en': _isLoadingBab
                                    ? 'Loading chapters...'
                                    : (babItems.isEmpty
                                          ? 'No chapters found'
                                          : 'Select Chapter'),
                                'id': _isLoadingBab
                                    ? 'Memuat bab...'
                                    : (babItems.isEmpty
                                          ? 'Tidak ada bab'
                                          : 'Pilih Bab'),
                              }),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],

                    // Multi-Select Sub Bab (if bab is selected) - Custom UI
                    if (_useMateriTitle && _selectedBabId != null) ...[
                      InkWell(
                        onTap: () =>
                            _openMultiSelectSubBabDialog(languageProvider),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: languageProvider.getTranslatedText({
                              'en': 'Sub Chapters',
                              'id': 'Sub Bab Materi',
                            }),
                            prefixIcon: Icon(Icons.article),
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _selectedSubBabIds.isEmpty
                                ? languageProvider.getTranslatedText({
                                    'en': 'Select Sub Chapters (optional)',
                                    'id': 'Pilih Sub Bab (opsional)',
                                  })
                                : _selectedSubBabIds.length == 1
                                ? _getSubBabName(
                                    _subBabMateriList.firstWhere(
                                      (s) =>
                                          s['id'].toString() ==
                                          _selectedSubBabIds.first,
                                      orElse: () => {},
                                    ),
                                  )
                                : '${_selectedSubBabIds.length} ${languageProvider.getTranslatedText({'en': 'selected', 'id': 'dipilih'})}',
                            style: TextStyle(
                              color: _selectedSubBabIds.isEmpty
                                  ? ColorUtils.slate600
                                  : ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                    ],

                    // Judul Field
                    TextFormField(
                      controller: _judulController,
                      decoration: InputDecoration(
                        labelText:
                            '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                        helperText: _useMateriTitle
                            ? languageProvider.getTranslatedText({
                                'en': 'Auto-filled from chapter/sub-chapter',
                                'id': 'Otomatis dari bab/sub bab',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'Enter title manually',
                                'id': 'Tulis judul manual',
                              }),
                      ),
                      readOnly:
                          _useMateriTitle &&
                          (_selectedBabId != null || _selectedSubBabId != null),
                      validator: (value) => value == null || value.isEmpty
                          ? languageProvider.getTranslatedText({
                              'en': 'Required',
                              'id': 'Wajib diisi',
                            })
                          : null,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Deskripsi
                    TextFormField(
                      controller: _deskripsiController,
                      decoration: InputDecoration(
                        labelText: languageProvider.getTranslatedText({
                          'en': 'Description',
                          'id': 'Deskripsi',
                        }),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: AppSpacing.md),

                    // Tanggal
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.calendar_today),
                      title: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Date',
                          'id': 'Tanggal',
                        }),
                      ),
                      subtitle: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Pilih tanggal',
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _selectedDate = date;
                            _selectedDay = _days[date.weekday - 1];
                          });
                        }
                      },
                    ),

                    // Deadline (only for Assignments)
                    if (isAssignment) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.alarm),
                        title: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Deadline',
                            'id': 'Batas Waktu',
                          }),
                        ),
                        subtitle: Text(
                          _deadline != null
                              ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year} ${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                              : 'Pilih batas waktu (opsional)',
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _deadline ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              setState(() {
                                _deadline = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ],

                    // Select Students (only for specific target)
                    if (widget.initialTarget == 'khusus' &&
                        _selectedClassId != null) ...[
                      SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Select Students',
                                    'id': 'Pilih Siswa',
                                  }),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (kDebugMode)
                                  Text(
                                    'Debug: Target=${widget.initialTarget}, Count=${_studentList.length}, Loading=$_isLoadingStudents',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ColorUtils.slate400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh, size: 20),
                            onPressed: _loadStudents,
                            tooltip: 'Refresh Students',
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Container(
                        height: 200, // Increased height for better visibility
                        decoration: BoxDecoration(
                          border: Border.all(color: ColorUtils.slate400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoadingStudents
                            ? Center(child: CircularProgressIndicator())
                            : _studentList.isEmpty
                            ? Center(child: Text('Tidak ada siswa'))
                            : SingleChildScrollView(
                                child: Column(
                                  children: _studentList.map((student) {
                                    final studentId = student['id'].toString();
                                    final isSelected = _selectedStudents
                                        .contains(studentId);
                                    return ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                      dense: true,
                                      title: Text(
                                        student['name']?.toString() ??
                                            student['nama']?.toString() ??
                                            'Unknown',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      subtitle: Text(
                                        student['student_number']?.toString() ??
                                            student['nis']?.toString() ??
                                            '',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      trailing: Checkbox(
                                        value: isSelected,
                                        onChanged: (bool? checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedStudents.add(studentId);
                                            } else {
                                              _selectedStudents.remove(
                                                studentId,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedStudents.remove(studentId);
                                          } else {
                                            _selectedStudents.add(studentId);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
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
                      onPressed: _isSubmitting
                          ? null
                          : () => AppNavigator.pop(context),
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
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.isEditMode
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Update',
                                      'id': 'Simpan Perubahan',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Add',
                                      'id': 'Tambah',
                                    }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
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
  }
}
