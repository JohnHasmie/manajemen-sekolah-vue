import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
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
      unverifiedPaymentCount: unverifiedPaymentCount ?? this.unverifiedPaymentCount,
      currentSemesterLabel: currentSemesterLabel ?? this.currentSemesterLabel,
      isLoading: isLoading ?? this.isLoading,
      isStatsLoaded: isStatsLoaded ?? this.isStatsLoaded,
    );
  }
}

class DashboardNotifier extends AsyncNotifier<DashboardState> {
  bool _isInitializing = false;

  @override
  Future<DashboardState> build() async {
    // Keep provider alive during navigation to prevent re-initialization
    ref.keepAlive();
    // Initial load will be triggered by the UI calling initialize()
    return const DashboardState();
  }

  String get _effectiveRole {
    // We assume role will be passed or can be read from current state
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

  /// Reset state so the next initialize() runs fresh (used before navigation on school switch).
  void resetForSchoolSwitch() {
    _isInitializing = false;
  }

  /// Re-fetches all dashboard data for the currently selected academic year.
  /// Call this after the user changes the academic year selector.
  Future<void> reloadForYearChange() async {
    _isInitializing = false;
    state = const AsyncValue.loading();
    try {
      await _fetchFreshData(_effectiveRole);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> initialize(String role) async {
    // Prevent duplicate initialization from multiple callers
    if (_isInitializing) return;
    _isInitializing = true;

    state = const AsyncValue.loading();

    // 0. Ensure academic year is loaded (needed by all API calls)
    final academicYearProvider = ref.read(academicYearRiverpod);
    if (academicYearProvider.selectedAcademicYear == null) {
      await academicYearProvider.fetchAcademicYears();
    }

    // 1. Initial Local Cache Load
    DashboardState initialState = await _loadLocalCache(role);
    
    // Resolve true teacher_id from backend if missing to prevent ModelNotFound 404s
    if (role == 'guru' && initialState.userData['teacher_id'] == null && initialState.userData['id'] != null) {
      try {
        final teacherInfo = await ApiTeacherService().getTeacherByUserId(initialState.userData['id'].toString());
        if (teacherInfo != null && teacherInfo['id'] != null) {
          final updatedUserData = Map<String, dynamic>.from(initialState.userData);
          updatedUserData['teacher_id'] = teacherInfo['id'].toString();
          initialState = initialState.copyWith(userData: updatedUserData);
        }
      } catch (e) {
        AppLogger.error('dashboard', 'Failed to resolve teacher_id: $e');
      }
    }

    state = AsyncValue.data(initialState);

    // 2. Fetch Fresh Data (Stale-while-revalidate)
    try {
      await _fetchFreshData(role);
    } finally {
      _isInitializing = false;
    }
  }

  Future<DashboardState> _loadLocalCache(String role) async {
    final prefs = PreferencesService();
    final userString = prefs.getString('user');
    final lastYearId = prefs.getString('dashboard_last_year_id');
    
    Map<String, dynamic> userData = {};
    User? user;
    if (userString != null) {
      userData = json.decode(userString);
      user = User.fromJson(userData);
    }

    final schoolId = userData['school_id']?.toString() ?? 'default';
    final cacheKeyBase = 'dashboard_${_normalizeRole(role)}_${schoolId}_${lastYearId ?? 'default'}';
    
    final cachedStats = await LocalCacheService.load('${cacheKeyBase}_stats');
    final cachedAttendance = await LocalCacheService.load('${cacheKeyBase}_attendance_chart');
    final cachedFinance = await LocalCacheService.load('${cacheKeyBase}_finance_chart');

    DashboardState cachedState = DashboardState(
      userData: userData,
      user: user,
      isLoading: false,
    );

    if (cachedStats != null) {
      cachedState = _applyStatsToState(cachedState, Map<String, dynamic>.from(cachedStats));
    }

    if (cachedAttendance != null) {
      cachedState = cachedState.copyWith(
        attendanceChartData: List<Map<String, dynamic>>.from(
          (cachedAttendance as List).map((e) => Map<String, dynamic>.from(e)),
        ),
      );
    }

    if (cachedFinance != null) {
      cachedState = cachedState.copyWith(
        financeChartData: List<Map<String, dynamic>>.from(
          (cachedFinance as List).map((e) => Map<String, dynamic>.from(e)),
        ),
      );
    }

    return cachedState;
  }

  Future<void> _fetchFreshData(String role) async {
    try {
      final normalizedRole = _normalizeRole(role);
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

      // Parallelize non-dependent requests
      final results = await Future.wait([
        DashboardService.getDashboardStats(role: normalizedRole, academicYearId: academicYearId),
        _fetchChartData(normalizedRole, academicYearId),
        AuthService.getUserSchools(),
        AuthService.getUserRoles(),
        _fetchTeacherSpecificData(normalizedRole, academicYearId),
        _fetchTermLabel(),
        _prefetchTours(normalizedRole),
        _fetchFinanceStats(normalizedRole),
      ]);

      final dashboardData = results[0] as Map<String, dynamic>;
      final charts = results[1] as Map<String, dynamic>;
      final schools = results[2] as List<dynamic>;
      final roles = results[3] as List<dynamic>;
      final teacherResult = results[4] as Map<String, dynamic>?;
      final semesterLabel = results[5] as String?;
      // results[6] is tours (unused), results[7] is finance stats
      final financeCount = results[7] as int?;

      var newState = state.value?.copyWith(
        accessibleSchools: schools,
        availableRoles: roles,
        attendanceChartData: charts['attendance'],
        financeChartData: charts['finance'],
        isStatsLoaded: true,
      ) ?? const DashboardState();

      // Apply teacher data if available
      if (teacherResult != null) {
        newState = newState.copyWith(
          userData: teacherResult['userData'] as Map<String, dynamic>,
          user: User.fromJson(teacherResult['userData'] as Map<String, dynamic>),
          homeroomClasses: teacherResult['homeroomClasses'] as List<dynamic>,
        );
      }

      // Apply semester label
      if (semesterLabel != null) {
        newState = newState.copyWith(currentSemesterLabel: semesterLabel);
      }

      // Apply finance stats
      if (financeCount != null) {
        newState = newState.copyWith(unverifiedPaymentCount: financeCount);
      }

      newState = _applyStatsToState(newState, dashboardData, normalizedRole);
      state = AsyncValue.data(newState);

      // Save to cache
      final schoolId = state.value?.userData['school_id']?.toString() ?? 'default';
      final cacheKeyBase = 'dashboard_${normalizedRole}_${schoolId}_${academicYearId ?? 'default'}';
      LocalCacheService.save('${cacheKeyBase}_stats', dashboardData);
      if (charts['attendance'] != null) LocalCacheService.save('${cacheKeyBase}_attendance_chart', charts['attendance']);
      if (charts['finance'] != null) LocalCacheService.save('${cacheKeyBase}_finance_chart', charts['finance']);
      
      if (academicYearId != null) {
        PreferencesService().setString('dashboard_last_year_id', academicYearId);
      }

    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error fetching fresh dashboard data: $e');
      // If we have cached data, we don't necessarily want to show an error screen
    }
  }

  Future<Map<String, dynamic>> _fetchChartData(String role, String? yearId) async {
    List<Map<String, dynamic>>? attendance;
    List<Map<String, dynamic>>? finance;

    if (role == 'admin' || role == 'wali') {
      final now = DateTime.now();
      final month = _getMonthName(now.month);
      final week = 'Pekan ${(now.day / 7).ceil().clamp(1, 5)}';

      final attendanceData = await AttendanceService.getAttendanceDashboardChart(
        academicYearId: yearId,
        month: month,
        week: week,
        role: role == 'wali' ? role : null,
      );
      attendance = List<Map<String, dynamic>>.from(attendanceData);

      if (role == 'admin') {
        final financeData = await FinanceService.getFinanceDashboardChart(academicYearId: yearId);
        finance = List<Map<String, dynamic>>.from(financeData);
      }
    }
    return {'attendance': attendance, 'finance': finance};
  }

  /// Returns teacher data map or null. Does NOT mutate state directly.
  Future<Map<String, dynamic>?> _fetchTeacherSpecificData(String role, String? yearId) async {
    if (role != 'guru') return null;
    final userData = state.value?.userData;
    if (userData == null) return null;

    final userId = (userData['user_id'] ?? userData['id']).toString();
    try {
      final teacherData = await getIt<ApiTeacherService>().getTeacherByUserId(userId, academicYearId: yearId);
      if (teacherData != null) {
        final teacherId = teacherData['id']?.toString() ?? '';
        final updatedUserData = {...userData, ...teacherData, 'id': userId, 'user_id': userId, 'teacher_id': teacherId};

        final classesResponse = await getIt<ApiTeacherService>().getTeacherClasses(teacherId, academicYearId: yearId);
        final List<dynamic> homeroomOnly = classesResponse.where((cls) {
          final isH = cls['is_homeroom'];
          return isH == true || isH == 1 || isH.toString() == 'true';
        }).toList();

        // Update TeacherProvider
        ref.read(teacherRiverpod).setTeacherData(
          userId: userId,
          teacherId: teacherId,
          teacherName: updatedUserData['nama'] ?? 'Guru',
          teacherData: updatedUserData,
          allClasses: classesResponse,
          homeroomClasses: homeroomOnly,
        );

        return {'userData': updatedUserData, 'homeroomClasses': homeroomOnly};
      }
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error fetching teacher data: $e');
    }
    return null;
  }

  /// Returns semester label or null. Does NOT mutate state directly.
  Future<String?> _fetchTermLabel() async {
    try {
      final result = await getIt<ApiScheduleService>().getDateBasedSemester();
      if (result.containsKey('label')) {
        return result['label'] as String?;
      }
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error fetching semester: $e');
    }
    return null;
  }

  /// Returns unverified payment count or null. Does NOT mutate state directly.
  Future<int?> _fetchFinanceStats(String role) async {
    if (role != 'admin') return null;
    try {
      final financeStats = await FinanceService.getFinanceDashboardStats();
      return int.tryParse(financeStats['pembayaran_pending']?.toString() ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error fetching finance stats: $e');
    }
    return null;
  }

  Future<void> _prefetchTours(String role) async {
    try {
      await ApiTourService.getCompletedTours(platform: 'mobile');
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error prefetching tours: $e');
    }
  }

  /// Safely parse a value to int (handles String, int, double, null).
  int _toInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  DashboardState _applyStatsToState(DashboardState currentState, Map<String, dynamic> data, [String? role]) {
    final effectiveRole = role ?? _effectiveRole;
    var stats = {...currentState.stats};
    List<dynamic> todaysSchedule = currentState.todaysSchedule;
    List<dynamic> materialOverview = currentState.materialOverview;

    if (effectiveRole == 'guru') {
      todaysSchedule = List<dynamic>.from(data['todays_schedule'] ?? []);
      materialOverview = List<dynamic>.from(data['material_overview'] ?? []);
      stats = {
        'total_students': _toInt(data['total_students'] ?? data['total_siswa']),
        'total_classes': _toInt(data['total_classes'] ?? data['total_kelas']),
        'classes_today': _toInt(data['classes_today'] ?? data['kelas_hari_ini']),
        'total_materials': _toInt(data['total_materials'] ?? data['total_materi']),
        'total_rpps': _toInt(data['total_rpps'] ?? data['total_rpp']),
        'rpp_approved': _toInt(data['rpp_approved']),
        'rpp_rejected': _toInt(data['rpp_rejected']),
        'rpp_pending': _toInt(data['rpp_pending']),
        'attendance_summary': data['attendance_summary'] is Map ? data['attendance_summary'] : {},
        'unread_announcements': _toInt(data['unread_announcements']),
        'unread_class_activities': _toInt(data['unread_class_activities']),
      };
    } else if (effectiveRole == 'admin') {
      stats = {
        'total_students': _toInt(data['total_students'] ?? data['total_siswa']),
        'total_teachers': _toInt(data['total_teachers'] ?? data['total_guru']),
        'total_classes': _toInt(data['total_classes'] ?? data['total_kelas']),
        'total_subjects': _toInt(data['total_subjects'] ?? data['total_mapel']),
        'unread_announcements': _toInt(data['unread_announcements']),
        'unread_class_activities': _toInt(data['unread_class_activities']),
      };
    } else if (effectiveRole == 'wali') {
      stats = {
        'children_registered': _toInt(data['children_registered'] ?? data['anak_terdaftar']),
        'unread_announcements': _toInt(data['unread_announcements']),
        'unread_class_activities': _toInt(data['unread_class_activities']),
        'unread_grades': _toInt(data['unread_grades']),
        'unread_presence': _toInt(data['unread_presence']),
        'unread_billings': _toInt(data['unread_billings'] ?? data['unread_billing']),
      };
    }

    return currentState.copyWith(
      stats: stats,
      todaysSchedule: todaysSchedule,
      materialOverview: materialOverview,
    );
  }

  String _normalizeRole(String role) {
    if (role == 'teacher') return 'guru';
    if (role == 'parent') return 'wali';
    return role;
  }

  String _getMonthName(int month) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return months[month - 1];
  }

  /// Lightweight refresh — only re-fetches stats to update badge counts.
  /// Use this after returning from a sub-screen instead of full initialize().
  Future<void> refreshStats() async {
    try {
      final role = _effectiveRole;
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
      final dashboardData = await DashboardService.getDashboardStats(role: role, academicYearId: academicYearId);
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(_applyStatsToState(currentState, dashboardData, role));
      }
    } catch (e) {
      AppLogger.error('dashboard_controller', 'Error refreshing stats: $e');
    }
  }

  // --- Actions ---

  Future<void> switchRole(String role) async {
    // Logic from _switchRole in Dashboard screen
    final response = await AuthService.switchRole(role);
    await _updateAuthData(response, role);
  }

  Future<Map<String, dynamic>> switchSchool(String schoolId, {String? role}) async {
    final response = await AuthService.switchSchool(schoolId, role: role);

    AppLogger.debug('dashboard', 'switchSchool response keys: ${response.keys.toList()}');
    AppLogger.debug('dashboard', 'needsRoleSelection: ${response['needsRoleSelection']}');
    AppLogger.debug('dashboard', 'user role: ${response['user']?['role']}');

    if (response['needsRoleSelection'] == true) {
      return response;
    }
    if (response['needsSchoolSelection'] == true) {
      return response;
    }

    final newRole = response['user']?['role']?.toString() ?? role ?? _effectiveRole;
    await _updateAuthData(response, newRole);
    return response;
  }

  Future<void> _updateAuthData(Map<String, dynamic> response, String role) async {
    final token = response['token'];
    if (token == null) throw Exception('No token in response');

    await SecureStorageService().saveToken(token);
    final prefs = PreferencesService();
    await prefs.setString('token', token);

    final currentUserData = state.value?.userData ?? {};
    final User user = response['user'] != null
        ? User.fromJson(response['user'])
        : User.fromJson(currentUserData).copyWith(role: role);

    final standardizedUser = user.toJson();
    await SecureStorageService().saveUserData(standardizedUser);
    await prefs.setString('user', json.encode(standardizedUser));
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardState>(
  DashboardNotifier.new,
  isAutoDispose: true,
);
