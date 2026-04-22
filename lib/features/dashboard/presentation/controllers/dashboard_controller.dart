import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_initializer.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_data_fetcher.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_state_transformer.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_auth_handler.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_cache_manager.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/_dashboard_data_aggregator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';

class DashboardState {
  final Map<String, dynamic> userData;
  final User? user;
  final Map<String, dynamic> stats;
  final List<dynamic> todaysSchedule;
  final List<dynamic> materialOverview;
  final List<dynamic> homeroomClasses;
  final List<dynamic> accessibleSchools;
  final List<dynamic> availableRoles;
  final List<Map<String, dynamic>> attendanceChartData;
  final List<Map<String, dynamic>> financeChartData;
  final int unverifiedPaymentCount;
  final String? currentSemesterLabel;
  final bool isLoading;
  final bool isStatsLoaded;

  const DashboardState({
    this.userData = const {},
    this.user,
    this.stats = const {
      'total_students': 0,
      'total_teachers': 0,
      'total_classes': 0,
      'total_subjects': 0,
      'classes_today': 0,
      'total_materials': 0,
      'total_rpps': 0,
    },
    this.todaysSchedule = const [],
    this.materialOverview = const [],
    this.homeroomClasses = const [],
    this.accessibleSchools = const [],
    this.availableRoles = const [],
    this.attendanceChartData = const [],
    this.financeChartData = const [],
    this.unverifiedPaymentCount = 0,
    this.currentSemesterLabel,
    this.isLoading = true,
    this.isStatsLoaded = false,
  });

  DashboardState copyWith({
    Map<String, dynamic>? userData,
    User? user,
    Map<String, dynamic>? stats,
    List<dynamic>? todaysSchedule,
    List<dynamic>? materialOverview,
    List<dynamic>? homeroomClasses,
    List<dynamic>? accessibleSchools,
    List<dynamic>? availableRoles,
    List<Map<String, dynamic>>? attendanceChartData,
    List<Map<String, dynamic>>? financeChartData,
    int? unverifiedPaymentCount,
    String? currentSemesterLabel,
    bool? isLoading,
    bool? isStatsLoaded,
  }) {
    return DashboardState(
      userData: userData ?? this.userData,
      user: user ?? this.user,
      stats: stats ?? this.stats,
      todaysSchedule: todaysSchedule ?? this.todaysSchedule,
      materialOverview: materialOverview ?? this.materialOverview,
      homeroomClasses: homeroomClasses ?? this.homeroomClasses,
      accessibleSchools: accessibleSchools ?? this.accessibleSchools,
      availableRoles: availableRoles ?? this.availableRoles,
      attendanceChartData: attendanceChartData ?? this.attendanceChartData,
      financeChartData: financeChartData ?? this.financeChartData,
      unverifiedPaymentCount:
          unverifiedPaymentCount ?? this.unverifiedPaymentCount,
      currentSemesterLabel: currentSemesterLabel ?? this.currentSemesterLabel,
      isLoading: isLoading ?? this.isLoading,
      isStatsLoaded: isStatsLoaded ?? this.isStatsLoaded,
    );
  }
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  bool _isInitializing = false;
  late DashboardDataFetcher _dataFetcher;
  late DashboardAuthHandler _authHandler;
  late DashboardInitializer _initializer;

  @override
  Future<DashboardState> build() async {
    ref.keepAlive();
    _dataFetcher = DashboardDataFetcher(ref);
    _authHandler = DashboardAuthHandler(
      getState: () => state.value ?? const DashboardState(),
    );
    _initializer = DashboardInitializer(ref);
    return const DashboardState();
  }

  String get _effectiveRole {
    final role = state.value?.userData['role']?.toString() ?? 'admin';
    if (role == 'teacher') return 'guru';
    if (role == 'parent') return 'wali';
    return role;
  }

  /// Force re-initialization (e.g., after switching school).
  Future<void> reinitialize(String role) async {
    _isInitializing = false;
    await initialize(role);
  }

  /// Reset state for school switch.
  void resetForSchoolSwitch() {
    _isInitializing = false;
  }

  /// Re-fetch all data for current academic year.
  Future<void> reloadForYearChange() async {
    _isInitializing = false;
    state = const AsyncValue.loading();
    try {
      await _fetchFreshData(_effectiveRole);
    } finally {
      _isInitializing = false;
    }
  }

  /// Initialize dashboard with role.
  Future<void> initialize(String role) async {
    if (_isInitializing) return;
    _isInitializing = true;

    state = const AsyncValue.loading();

    try {
      await _initializer.ensureAcademicYearLoaded();
      final initialState = await _initializer.prepareInitialState(role);
      state = AsyncValue.data(initialState);
      await _fetchFreshData(role);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _fetchFreshData(String role) async {
    try {
      final normalizedRole = DashboardStateTransformer.normalizeRole(role);
      final academicYearId = _getSelectedAcademicYearId();

      // Consolidated: 1 call for core data + parallel calls for charts & finance
      final results = await Future.wait([
        _dataFetcher.fetchDashboardFull(normalizedRole, academicYearId),
        _dataFetcher.fetchChartData(normalizedRole, academicYearId),
        _dataFetcher.fetchFinanceStats(normalizedRole),
      ]);

      final fullData = results[0] as Map<String, dynamic>;
      final charts = results[1] as Map<String, dynamic>;
      final financeCount = results[2] as int?;

      // Extract consolidated fields
      final stats = Map<String, dynamic>.from(fullData['stats'] ?? {});
      final schools = List<dynamic>.from(fullData['schools'] ?? []);
      final roles = List<dynamic>.from(fullData['available_roles'] ?? []);
      final semesterLabel = fullData['semester_label'] as String?;

      // Process teacher-specific data from consolidated response
      final teacherResult = _dataFetcher.processTeacherData(
        fullData,
        state.value?.userData,
      );

      final newState = DashboardDataAggregator.applyFetchResults(
        state.value,
        stats,
        charts,
        schools,
        roles,
        teacherResult,
        semesterLabel,
        financeCount,
        normalizedRole,
      );

      state = AsyncValue.data(newState);
      _saveDataToCache(normalizedRole, academicYearId, stats, charts);

      // Prefetch tours and schedule data in the background without waiting
      _dataFetcher.prefetchTours(normalizedRole).ignore();
      if (normalizedRole == 'guru') {
        _dataFetcher.prefetchScheduleData(academicYearId).ignore();
      }
    } catch (e) {
      AppLogger.error(
        'dashboard_controller',
        'Error fetching fresh dashboard data: $e',
      );
    }
  }

  void _saveDataToCache(
    String normalizedRole,
    String? academicYearId,
    Map<String, dynamic> dashboardData,
    Map<String, dynamic> charts,
  ) {
    final schoolId =
        state.value?.userData['school_id']?.toString() ?? 'default';
    DashboardCacheManager.saveToCache(
      normalizedRole,
      schoolId,
      academicYearId,
      dashboardData,
      charts,
    );
    if (academicYearId != null) {
      DashboardCacheManager.updateLastAcademicYear(academicYearId);
    }
  }

  String? _getSelectedAcademicYearId() {
    return ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
  }

  /// Full pull-to-refresh: clears all feature caches, then re-fetches
  /// everything. Preserves UI preferences (view modes, tour states).
  /// Shows skeleton placeholders while data reloads.
  Future<void> pullToRefresh() async {
    try {
      // 1. Show skeletons in content areas while keeping page structure
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(
          currentState.copyWith(isStatsLoaded: false),
        );
      }

      // 2. Clear all feature caches
      await CacheInvalidationService.onPullToRefresh();

      // 3. Re-fetch everything fresh
      await _fetchFreshData(_effectiveRole);
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Pull-to-refresh error: $e');
      // Restore loaded state on error so UI doesn't stay in skeleton
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(
          currentState.copyWith(isStatsLoaded: true),
        );
      }
    }
  }

  /// Lightweight refresh — only stats.
  Future<void> refreshStats() async {
    try {
      final role = _effectiveRole;
      final academicYearId = _getSelectedAcademicYearId();
      final dashboardData = await _dataFetcher.getDashboardStats(
        role,
        academicYearId,
      );
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(
          DashboardStateTransformer.applyStatsToState(
            currentState,
            dashboardData,
            role,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error refreshing stats: $e');
    }
  }

  /// Switch to a different role.
  Future<void> switchRole(String role) async {
    await _authHandler.switchRole(role);
  }

  /// Switch to a different school.
  Future<Map<String, dynamic>> switchSchool(
    String schoolId, {
    String? role,
  }) async {
    return _authHandler.switchSchool(schoolId, role: role);
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardState>(
      DashboardNotifier.new,
      isAutoDispose: true,
    );
