// Main dashboard screen - the home page after login for all roles (admin/guru/wali).
//
// Like `pages/dashboard.vue` or `pages/admin/index.vue` in a Vue/Nuxt project.
// This is the largest screen in the app - it renders role-specific content:
// - Admin: school stats, menu grid for management screens, finance overview
// - Teacher (guru): today's schedule, class activities, lesson plans
// - Parent (wali): child's grades, attendance, billing
//
// In Laravel terms, this consumes data from DashboardController which aggregates
// stats from multiple models (Students, Classes, Teachers, Schedules, etc.).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/lesson_plan_status_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/material_slider_card.dart';
import 'package:manajemensekolah/core/services/secure_storage_service.dart';
import 'package:manajemensekolah/core/services/token_service.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/settings/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/admin_report_card_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/admin_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/settings/screens/school_settings_screen.dart';
import 'package:manajemensekolah/features/settings/screens/settings_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/notifications/presentation/screens/notification_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/recommendations/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/auth/data/auth_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/auth/domain/models/user.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_bar_chart_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/category_section.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_bar_chart_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_popup_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_popup_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/schedule_slider_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// The main dashboard widget. Like a Vue page component (`pages/dashboard.vue`).
///
/// Takes a [role] prop ('admin', 'guru'/'teacher', 'wali'/'parent') which determines
/// what menu items, stats, and content are shown. This is similar to a Vue page
/// that renders different sections with `v-if="role === 'admin'"`.
class Dashboard extends ConsumerStatefulWidget {
  final String role;

  const Dashboard({super.key, required this.role});

  @override
  ConsumerState<Dashboard> createState() => _DashboardState();
}

/// The mutable state for [Dashboard].
///
/// This is like a Vue page component with extensive local state
/// (`data() { return { stats: {}, userData: {}, isLoading: true, ... } }`).
///
/// Uses [TickerProviderStateMixin] to support animations (like Vue transitions).
///
/// Key state variables:
/// - [_userData] - current user profile data (from SharedPreferences/API)
/// - [_stats] - aggregated dashboard statistics (student count, class count, etc.)
/// - [_todaysScheduleList] - today's teaching schedule for the slider
/// - [_accessibleSchools] - schools the user can switch between
/// - [_isStatsLoaded] - controls skeleton loading vs real content display
///
/// Key patterns:
/// - Cache-first loading: loads from LocalCacheService first, then fetches fresh data
/// - Provider pattern: uses Provider (like Vuex/Pinia) for shared state
///   (AcademicYearProvider, TeacherProvider, LanguageProvider)
/// - FCM sync: listens for push notification triggers to refresh data in real-time
class _DashboardState extends ConsumerState<Dashboard>
    with TickerProviderStateMixin {
  String get _effectiveRole {
    if (widget.role == 'teacher') return 'guru';
    if (widget.role == 'parent') return 'wali';
    return widget.role;
  }

  late AnimationController _animationController;
  Map<String, dynamic> _userData = {};
  List<dynamic> _accessibleSchools = [];
  bool _isLoadingSchools = false;
  List<dynamic> _availableRoles = [];
  List<Map<String, dynamic>> _attendanceChartData = [];
  List<Map<String, dynamic>> _financeChartData = [];

  String? _currentSemesterLabel;

  // Data statistik
  Map<String, dynamic> _stats = {
    'total_students': 0,
    'total_teachers': 0,
    'total_classes': 0,
    'total_subjects': 0,
    'classes_today': 0,
    'total_materialsals': 0,
    'total_rppss': 0,
    'children_registered': 0,
    'latest_announcements': 0,
    'unread_billingss': 0,
  };

  User? _user; // Typed user model for English property access

  // State for Schedule Slider
  List<dynamic> _todaysScheduleList = [];
  List<dynamic> _materialOverview = [];
  List<dynamic> _homeroomClasses = [];

  // Finance Badge State
  int _unverifiedPaymentCount = 0;

  // Skeleton loading state
  bool _isStatsLoaded = false;
  bool _statsAlreadyFetched = false;

  // Stats Pagination state

  // Tour state — pre-fetched early so tour shows without delay
  Map<String, dynamic>? _pendingTourStatus;
  bool _tourShown = false;

  // Global Keys for Tour
  final GlobalKey _profileHeaderKey = GlobalKey();
  final GlobalKey _heroSectionKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();
  final GlobalKey _statsSectionKey = GlobalKey();
  final GlobalKey _scheduleSectionKey = GlobalKey();
  final GlobalKey _menuGridKey = GlobalKey();

  /// Like Vue's `mounted()` lifecycle hook.
  /// Sets up animation controllers, listens for FCM sync triggers,
  /// and kicks off the data initialization pipeline.
  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _animationController.forward();

    // Listen to background sync triggers (e.g. from FCM)
    FCMService().syncTrigger.addListener(_handleSyncTrigger);

    _initializeData();
  }

  /// Main data initialization pipeline - called from initState.
  /// Loads cached data first for instant display, then fetches fresh data.
  /// Like a Vue `mounted()` that calls multiple API endpoints in sequence.
  /// Pattern: cache-first -> show UI -> background refresh -> update UI.
  Future<void> _initializeData() async {
    // Load cached data first (fast, synchronous-like)
    await _loadCachedUserData();

    // Listen for changes immediately after loading cache
    // This ensures we catch the notification from fetchAcademicYears below
    if (mounted) {
      ref.read(academicYearRiverpod).addListener(_onYearChanged);
    }

    setState(() {});

    // ─── Pre-fetch all tours in a single API call (dashboard + child screens) ───
    final tourFuture = _prefetchAllTours();

    // ─── Load cached stats immediately (before any network call) ───
    await _loadCachedStats();

    // Try showing tour right after cached stats (UI targets exist now)
    _tryShowPendingTour();

    try {
      // Fetch fresh data in background
      // This might return early if year isn't loaded yet, which is fine
      // because _onYearChanged will call it again.
      _loadFreshTeacherData();
      await _loadAccessibleSchools();
      await _loadAvailableRoles();

      // Fetch academic years
      if (mounted) {
        await ref.read(academicYearRiverpod).fetchAcademicYears();
      }

      // Only load stats if _onYearChanged hasn't already triggered it
      if (!_statsAlreadyFetched) {
        await _loadStats();
      }
      await _loadSemesterLabel();
      _preCacheSchoolData(); // Non-blocking pre-cache for child screens
    } catch (e) {
      AppLogger.error('dashboard', 'Error during initialization: $e');
      if (mounted) {
        SnackBarUtils.showWarning(
          context,
          'Gagal memuat data dashboard: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }

    // Ensure tour future is complete, then try showing if not yet shown
    await tourFuture;
    _tryShowPendingTour();
  }

  /// Fetch completed tours in a single API call, then determine locally
  /// which tours still need to be shown (dashboard + all child screens).
  Future<void> _prefetchAllTours() async {
    try {
      // 1. Fetch all completed tours in one GET request
      final completedList = await ApiTourService.getCompletedTours(
        platform: 'mobile',
      );

      // Build a set of completed keys: "name|role" for fast lookup
      final completedSet = <String>{};
      for (final item in completedList) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String?;
          final role = item['role'] as String?;
          if (name != null && role != null) {
            completedSet.add('$name|$role');
          }
        }
      }

      // 2. Build tour list (dashboard + child screens) based on role
      final tourEntries = <({String role, String name, String cacheKey})>[];

      // Dashboard tour (included in the same flow)
      tourEntries.add((
        role: _effectiveRole,
        name: 'dashboard_tour',
        cacheKey: CacheKeyBuilder.tourStatus('dashboard', _effectiveRole),
      ));

      // ─── Admin tours ───
      if (_effectiveRole == 'admin') {
        tourEntries.addAll([
          (
            role: 'admin',
            name: 'student_management_tour',
            cacheKey: CacheKeyBuilder.tourStatus('student_management', 'admin'),
          ),
          (
            role: 'admin',
            name: 'teacher_admin_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'teacher_admin_screen',
              'admin',
            ),
          ),
          (
            role: 'admin',
            name: 'admin_class_management_tour',
            cacheKey: CacheKeyBuilder.tourStatus('class_management', 'admin'),
          ),
          (
            role: 'admin',
            name: 'subject_management_tour',
            cacheKey: CacheKeyBuilder.tourStatus('subject_management', 'admin'),
          ),
          (
            role: 'admin',
            name: 'teaching_schedule_management_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'schedule_management',
              'admin',
            ),
          ),
          (
            role: 'admin',
            name: 'admin_announcement_tour',
            cacheKey: CacheKeyBuilder.tourStatus('announcement', 'admin'),
          ),
          (
            role: 'admin',
            name: 'admin_class_activity_tour',
            cacheKey: CacheKeyBuilder.tourStatus('class_activity', 'admin'),
          ),
          (
            role: 'admin',
            name: 'admin_presence_report_tour',
            cacheKey: CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          ),
          (
            role: 'admin',
            name: 'admin_rpp_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('rpp_screen', 'admin'),
          ),
          (
            role: 'admin',
            name: 'admin_raport_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('raport_screen', 'admin'),
          ),
          (
            role: 'admin',
            name: 'admin_finance_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('finance', 'admin'),
          ),
          (
            role: 'admin',
            name: 'admin_school_settings_tour',
            cacheKey: CacheKeyBuilder.tourStatus('school_settings', 'admin'),
          ),
        ]);
      }

      // ─── Guru tours ───
      if (_effectiveRole == 'guru') {
        tourEntries.addAll([
          (
            role: 'guru',
            name: 'input_grade_tour',
            cacheKey: CacheKeyBuilder.tourStatus('input_grade_screen', 'guru'),
          ),
          (
            role: 'guru',
            name: 'teaching_schedule_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'teaching_schedule_screen',
              'guru',
            ),
          ),
          (
            role: 'guru',
            name: 'class_activity_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'class_activity_screen',
              'guru',
            ),
          ),
          (
            role: 'guru',
            name: 'presence_teacher_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'presence_teacher_screen',
              'guru',
            ),
          ),
          (
            role: 'guru',
            name: 'materi_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('materi_screen', 'guru'),
          ),
          (
            role: 'guru',
            name: 'rekap_nilai_tour',
            cacheKey: CacheKeyBuilder.tourStatus('rekap_nilai_screen', 'guru'),
          ),
          (
            role: 'guru',
            name: 'raport_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('raport_screen', 'guru'),
          ),
          (
            role: 'guru',
            name: 'raport_detail_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'raport_detail_screen',
              'guru',
            ),
          ),
          (
            role: 'guru',
            name: 'rpp_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('rpp_screen', 'guru'),
          ),
          (
            role: 'walimurid',
            name: 'announcement_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('announcement_screen', 'guru'),
          ),
          (
            role: 'guru',
            name: 'learning_recommendation_class_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'recommendation_class_screen',
              'guru',
            ),
          ),
          (
            role: 'guru',
            name: 'learning_recommendation_student_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'recommendation_student_screen',
              'guru',
            ),
          ),
          (
            role: 'guru',
            name: 'learning_recommendation_result_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'recommendation_result_screen',
              'guru',
            ),
          ),
        ]);
      }

      // ─── Wali tours ───
      if (_effectiveRole == 'wali') {
        tourEntries.addAll([
          (
            role: 'walimurid',
            name: 'announcement_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('announcement_screen', 'wali'),
          ),
          (
            role: 'wali',
            name: 'parent_class_activity_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'parent_class_activity_screen',
              'wali',
            ),
          ),
          (
            role: 'wali',
            name: 'parent_grade_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus('parent_grade_screen', 'wali'),
          ),
          (
            role: 'wali',
            name: 'parent_billing_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'parent_billing_screen',
              'wali',
            ),
          ),
          (
            role: 'wali',
            name: 'parent_presence_screen_tour',
            cacheKey: CacheKeyBuilder.tourStatus(
              'parent_presence_screen',
              'wali',
            ),
          ),
        ]);
      }

      // 3. Check each tour against the completed set and cache results
      for (final entry in tourEntries) {
        final isCompleted = completedSet.contains(
          '${entry.name}|${entry.role}',
        );
        final status = <String, dynamic>{'should_show': !isCompleted};

        // Dashboard tour: set pending status for overlay
        if (entry.name == 'dashboard_tour') {
          if (!isCompleted) {
            _pendingTourStatus = status;
            _tryShowPendingTour();
          }
          continue;
        }

        // Cache for child screens to read
        LocalCacheService.save(entry.cacheKey, status);
      }

      AppLogger.debug(
        'dashboard',
        'Fetched ${completedList.length} completed tours, '
            'pre-cached ${tourEntries.length - 1} child tour statuses',
      );
    } catch (e) {
      AppLogger.error('dashboard', 'Pre-fetch tours failed: $e');
    }
  }

  /// Show the pending tour if: status is fetched, UI targets exist, and not already shown.
  void _tryShowPendingTour() {
    if (_tourShown || _pendingTourStatus == null || !mounted) return;

    // Wait for next frame to ensure widget tree is laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tourShown || !mounted) return;
      _tourShown = true;
      _showTour();
    });
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
          name: 'dashboard_tour',
          role: _effectiveRole,
          platform: 'mobile',
        );
      },
      onClickTarget: (target) {
        // Log skip inside step if necessary
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'dashboard_tour',
          role: _effectiveRole,
          platform: 'mobile',
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "ProfileHeader",
        keyTarget: _profileHeaderKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Profil Pengguna",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Di sini Anda dapat melihat ringkasan identitas dan mengakses menu pengaturan akun dengan menekan ikon profil di kanan.",
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
        identify: "HeroSection",
        keyTarget: _heroSectionKey,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Informasi Semester",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Kartu ini menunjukkan Tahun Ajaran dan Semester yang aktif. Ketuk bagian ini untuk mengganti Tahun Ajaran secara cepat.",
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
        identify: "StatsSection",
        keyTarget: _statsSectionKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Statistik Ringkas",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Perkembangan kelas, siswa, atau berbagai indikator penting lainnya dapat Anda pantau di ringkasan statistik ini.",
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

    if (_effectiveRole == 'guru') {
      targets.add(
        TargetFocus(
          identify: "ScheduleSection",
          keyTarget: _scheduleSectionKey,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          alignSkip: Alignment.topRight,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Jadwal Hari Ini",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Daftar kelas yang harus Anda ajar hari ini. Cukup geser untuk melihat kelas-kelas berikutnya, dan bisa langsung ceklis absen atau jurnal.",
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

    targets.add(
      TargetFocus(
        identify: "MenuGrid",
        keyTarget: _menuGridKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Menu Utama",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Semua fitur sistem berkumpul di sini sesuai dengan akses role Anda.",
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

    return targets;
  }

  Future<void> _loadSemesterLabel() async {
    try {
      final result = await getIt<ApiScheduleService>().getDateBasedSemester();
      if (mounted && result.containsKey('label')) {
        setState(() {
          _currentSemesterLabel = result['label'];
        });
      }
      // Cache for other screens (teaching_schedule, etc.)
      if (result.isNotEmpty) {
        LocalCacheService.save('school_current_semester', result);
      }
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading semester label: $e');
    }
  }

  /// Pre-cache school reference data (semester list, day list) for child screens.
  /// Called once during dashboard init so sub-screens don't need to re-fetch.
  Future<void> _preCacheSchoolData() async {
    try {
      // Cache semester list if not already cached
      final cachedSemester = await LocalCacheService.load(
        'school_semester_data',
        ttl: const Duration(hours: 12),
      );
      if (cachedSemester == null) {
        final semesterData = await getIt<ApiScheduleService>().getSemester();
        if (semesterData.isNotEmpty) {
          LocalCacheService.save('school_semester_data', semesterData);
          AppLogger.debug('dashboard', 'Pre-cached semester data');
        }
      }

      // Cache day list if not already cached
      final cachedDays = await LocalCacheService.load(
        'school_day_data',
        ttl: const Duration(hours: 24),
      );
      if (cachedDays == null) {
        final dayData = await getIt<ApiScheduleService>().getDays();
        if (dayData.isNotEmpty) {
          LocalCacheService.save('school_day_data', dayData);
          AppLogger.debug('dashboard', 'Pre-cached day data');
        }
      }
    } catch (e) {
      AppLogger.error(
        'dashboard',
        'Pre-cache school data failed (non-critical): $e',
      );
    }
  }

  /// Listener callback when the academic year changes via AcademicYearProvider.
  /// Reloads stats with the new year context - like a Vue `watch` on a Vuex state.
  void _onYearChanged() {
    if (!mounted) return;
    // Don't show skeleton if we already have data — stale-while-revalidate
    _statsAlreadyFetched = true;
    _loadStats();
    _loadUserData();
  }

  /// Fetches available roles for the current user (admin/guru/wali).
  /// Enables the role-switching feature in the account bottom sheet.
  Future<void> _loadAvailableRoles() async {
    if (!mounted) return;

    try {
      final roles = await AuthService.getUserRoles();
      if (!mounted) return;
      setState(() {
        _availableRoles = roles;
      });
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading roles: $e');
    }
  }

  /// Switches the user's active role (e.g., admin -> guru) via the API.
  /// Like calling `POST /api/switch-role` in Laravel, then navigating to
  /// the new role's dashboard route. Clears cache to ensure fresh data.
  Future<void> _switchRole(String role) async {
    try {
      final response = await AuthService.switchRole(role);

      // Update token dan user data
      await SecureStorageService().saveToken(response['token']);
      final prefs = PreferencesService();
      await prefs.setString('token', response['token']);

      // Standardize user data using User model
      final User user = response['user'] != null 
          ? User.fromJson(response['user'])
          : User.fromJson(_userData).copyWith(role: role);
      
      final standardizedUser = user.toJson();

      await SecureStorageService().saveUserData(standardizedUser);
      await prefs.setString('user', json.encode(standardizedUser));

      if (!mounted) return;

      // Navigate to dashboard with new role
      AppNavigator.pushReplacementNamed(context, '/$role');
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal pindah role: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  /// Loads user data from SharedPreferences (local storage).
  /// Like reading from localStorage/Vuex persisted state in a Vue app.
  /// Called early in init to display user info before API responds.
  Future<void> _loadCachedUserData() async {
    final prefs = PreferencesService();
    final userString = prefs.getString('user');
    if (userString != null) {
      if (!mounted) return;
      final localUserMap = json.decode(userString);
      setState(() {
        _userData = localUserMap;
        _user = User.fromJson(localUserMap);
      });
    }
  }

  /// Fetches fresh teacher-specific data (homeroom classes, schedules, materials)
  /// for the 'guru' role. Updates the TeacherProvider (like a Vuex/Pinia store).
  Future<void> _loadFreshTeacherData() async {
    if (_effectiveRole != 'guru') return;

    try {
      String? academicYearId;
      if (mounted) {
        final academicYearProvider = ref.read(academicYearRiverpod);
        academicYearId = academicYearProvider.selectedAcademicYear?['id']
            ?.toString();
      }

      if (academicYearId != null && _userData['id'] != null) {
        // Use user_id if we have it (saved from previous fetch), otherwise use current id
        final String userId = (_userData['user_id'] ?? _userData['id'])
            .toString();

        AppLogger.debug(
          'dashboard',
          'Fetching data for User ID: $userId, Year: $academicYearId',
        );

        try {
          // Fetch Teacher Record
          final teacherData = await getIt<ApiTeacherService>().getGuruByUserId(
            userId,
            academicYearId: academicYearId,
          );

          if (teacherData != null && mounted) {
            final String teacherId = teacherData['id']?.toString() ?? '';
            AppLogger.info('dashboard', 'Teacher Record Found: ID=$teacherId');
            AppLogger.debug('dashboard', 'User Data Role: ${widget.role}');
            AppLogger.debug(
              'dashboard',
              '🗓️ Academic Year ID: $academicYearId',
            );

            setState(() {
              // EXTREMELY IMPORTANT: We MUST NOT overwrite 'id' with teacher ID.
              // 'id' in our app context usually refers to User ID.
              // If we do, subsequent fresh fetches of Teacher Record will fail.
              final String originalUserId = userId;

              _userData = {
                ..._userData,
                ...teacherData,
                'id': originalUserId, // Force 'id' back to User ID
                'user_id': originalUserId,
                'teacher_id': teacherId,
                'guru_id': teacherId, // for backward compatibility
              };
            });

            // Persist the clean state with separate IDs immediately
            await SecureStorageService().saveUserData(_userData);
            final prefs = PreferencesService();
            await prefs.setString('user', json.encode(_userData));

            // Fetch Homeroom Classes using specialized Teacher ID endpoint
            // This is more robust as it handles both User/Teacher IDs and returns is_homeroom flag.
            AppLogger.debug(
              'dashboard',
              'Fetching Classes via Teacher endpoint for ID: $teacherId',
            );
            final classesResponse = await getIt<ApiTeacherService>()
                .getTeacherClasses(teacherId, academicYearId: academicYearId);

            if (mounted) {
              final List<dynamic> fetchedClasses = classesResponse;
              // Filter only classes where the teacher is actually the Wali Kelas
              // Using flexible truthiness check: true, 1, or "true"
              final List<dynamic> homeroomOnly = fetchedClasses.where((cls) {
                final isH = cls['is_homeroom'];
                return isH == true || isH == 1 || isH.toString() == 'true';
              }).toList();

              if (kDebugMode) {
                AppLogger.debug(
                  'dashboard',
                  'Total Classes Found: ${fetchedClasses.length}',
                );
                AppLogger.debug(
                  'dashboard',
                  'Homeroom Classes: ${homeroomOnly.length}',
                );
                for (var cls in homeroomOnly) {
                  AppLogger.debug(
                    'dashboard',
                    '   - Class: ${cls['name']} (ID: ${cls['id']})',
                  );
                }
              }
              setState(() {
                _homeroomClasses = homeroomOnly;
              });

              // Populate TeacherProvider so other screens can reuse
              if (mounted) {
                ref
                    .read(teacherRiverpod)
                    .setTeacherData(
                      userId: userId,
                      teacherId: teacherId,
                      teacherName: _userData['nama'] ?? 'Guru',
                      teacherData: _userData,
                      allClasses: fetchedClasses,
                      homeroomClasses: homeroomOnly,
                    );
              }
            }
          } else {
            AppLogger.warning(
              'dashboard',
              'No Teacher Record found for User ID: $userId',
            );
          }
        } catch (e) {
          AppLogger.error('dashboard', 'Error in _loadFreshTeacherData: $e');
        }
      }
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading fresh teacher data: $e');
    }
  }

  // Obsolete - removed in favor of split loading
  Future<void> _loadUserData() async {
    await _loadCachedUserData();
    await _loadFreshTeacherData();
  }

  /// Fetches the list of schools this user can access (for school switching).
  /// Like calling `GET /api/user/schools` from Vue to populate a dropdown.
  Future<void> _loadAccessibleSchools() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSchools = true;
    });

    try {
      final schools = await AuthService.getUserSchools();
      if (!mounted) return;
      setState(() {
        _accessibleSchools = schools;
        _isLoadingSchools = false;
      });
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading schools: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingSchools = false;
      });
    }
  }

  /// Last known academic year ID — loaded from prefs so cache key works before provider.
  String? _lastAcademicYearId;

  /// Load only cached stats (no network). Called early to avoid skeleton.
  /// Like reading from Vuex persisted state before the API call resolves.
  Future<void> _loadCachedStats() async {
    try {
      // Restore last known academic year ID so cache key matches
      final prefs = PreferencesService();
      _lastAcademicYearId = prefs.getString('dashboard_last_year_id');

      if (_lastAcademicYearId == null) return; // First launch, no cache yet

      final cachedStats = await LocalCacheService.load(
        _dashboardCacheKey('stats'),
        ttl: const Duration(hours: 6),
      );
      if (cachedStats == null || !mounted) return;

      final cachedAttendance = await LocalCacheService.load(
        _dashboardCacheKey('attendance_chart'),
        ttl: const Duration(hours: 6),
      );
      final cachedFinance = await LocalCacheService.load(
        _dashboardCacheKey('finance_chart'),
        ttl: const Duration(hours: 6),
      );

      AppLogger.debug(
        'dashboard',
        'Dashboard displaying cached stats (yearId=$_lastAcademicYearId)',
      );

      _applyStatsData(
        Map<String, dynamic>.from(cachedStats),
        attendanceChart: cachedAttendance != null
            ? List<Map<String, dynamic>>.from(
                (cachedAttendance as List).map(
                  (e) => Map<String, dynamic>.from(e),
                ),
              )
            : null,
        financeChart: cachedFinance != null
            ? List<Map<String, dynamic>>.from(
                (cachedFinance as List).map(
                  (e) => Map<String, dynamic>.from(e),
                ),
              )
            : null,
      );
    } catch (e) {
      AppLogger.error(
        'dashboard',
        'Early cache load failed (non-critical): $e',
      );
    }
  }

  /// Cache key builder for dashboard data.
  /// Uses provider year if available, otherwise falls back to last persisted year ID.
  String _dashboardCacheKey(String suffix) {
    String? academicYearId;
    if (mounted) {
      final provider = ref.read(academicYearRiverpod);
      academicYearId = provider.selectedAcademicYear?['id']?.toString();
    }
    // Use provider value if available, otherwise fallback to last known
    final yearKey = academicYearId ?? _lastAcademicYearId ?? 'default';

    // Persist whenever we get a real ID from the provider
    if (academicYearId != null && academicYearId != _lastAcademicYearId) {
      _lastAcademicYearId = academicYearId;
      PreferencesService().setString('dashboard_last_year_id', academicYearId);
    }

    return 'dashboard_${_effectiveRole}_${yearKey}_$suffix';
  }

  /// Apply dashboard stats data to state from a raw map (cache or fresh)
  void _applyStatsData(
    Map<String, dynamic> dashboardData, {
    List<Map<String, dynamic>>? attendanceChart,
    List<Map<String, dynamic>>? financeChart,
  }) {
    if (!mounted) return;

    if (_effectiveRole == 'guru') {
      final todaysSchedule = dashboardData['todays_schedule'];
      final todaysScheduleList = todaysSchedule is List
          ? List<dynamic>.from(todaysSchedule)
          : <dynamic>[];

      final materialOverviewRaw = dashboardData['material_overview'];
      final materialOverviewList = materialOverviewRaw is List
          ? List<dynamic>.from(materialOverviewRaw)
          : <dynamic>[];

      setState(() {
        _isStatsLoaded = true;
        _todaysScheduleList = todaysScheduleList;
        _materialOverview = materialOverviewList;
        _stats = {
          'total_students': dashboardData['total_students'] ?? 0,
          'total_classes': dashboardData['total_classes'] ?? 0,
          'classes_today': dashboardData['classes_today'] ?? 0,
          'total_materials': dashboardData['total_materials'] ?? 0,
          'total_rpps': dashboardData['total_rpps'] ?? 0,
          'rpp_approved': dashboardData['rpp_approved'] ?? 0,
          'rpp_rejected': dashboardData['rpp_rejected'] ?? 0,
          'rpp_pending': dashboardData['rpp_pending'] ?? 0,
          'attendance_summary': dashboardData['attendance_summary'] ?? {},
          'unread_announcements': dashboardData['unread_announcements'] ?? 0,
          'unread_class_activities':
              dashboardData['unread_class_activities'] ?? 0,
        };
      });
    } else if (_effectiveRole == 'admin') {
      setState(() {
        _isStatsLoaded = true;
        if (attendanceChart != null) {
          _attendanceChartData = attendanceChart;
        }
        if (financeChart != null) {
          _financeChartData = financeChart;
        }
        _stats = {
          'total_students': dashboardData['total_students'] ?? 0,
          'total_teachers': dashboardData['total_teachers'] ?? 0,
          'total_classes': dashboardData['total_classes'] ?? 0,
          'total_subjects': dashboardData['total_subjects'] ?? 0,
          'unread_announcements': dashboardData['unread_announcements'] ?? 0,
          'unread_class_activities':
              dashboardData['unread_class_activities'] ?? 0,
        };
      });
    } else if (_effectiveRole == 'wali') {
      setState(() {
        _isStatsLoaded = true;
        if (attendanceChart != null) {
          _attendanceChartData = attendanceChart;
        }
        _stats = {
          'children_registered': dashboardData['children_registered'] ?? 0,
          'unread_announcements': dashboardData['unread_announcements'] ?? 0,
          'unread_class_activities':
              dashboardData['unread_class_activities'] ?? 0,
          'unread_grades': dashboardData['unread_grades'] ?? 0,
          'unread_presence': dashboardData['unread_presence'] ?? 0,
          'unread_billings': dashboardData['unread_billings'] ?? 0,
        };
      });
    }
  }

  /// Fetches fresh dashboard statistics from the API.
  /// Like calling `GET /api/dashboard/stats?role=admin` in Vue.
  /// Updates [_stats], chart data, schedule list, and saves to cache.
  Future<void> _loadStats() async {
    // ─── Fetch fresh data from API (cache already loaded by _loadCachedStats) ───
    try {
      String? academicYearId;
      if (mounted) {
        final academicYearProvider = ref.read(academicYearRiverpod);
        academicYearId = academicYearProvider.selectedAcademicYear?['id']
            ?.toString();
      }

      final dashboardData = await DashboardService.getDashboardStats(
        role: _effectiveRole,
        academicYearId: academicYearId,
      );

      AppLogger.info('dashboard', 'Dashboard fresh stats loaded');

      // Fetch chart data for admin/wali
      List<Map<String, dynamic>>? freshAttendance;
      List<Map<String, dynamic>>? freshFinance;

      if (_effectiveRole == 'admin' || _effectiveRole == 'wali') {
        final now = DateTime.now();
        final currentMonthNames = [
          'Januari',
          'Februari',
          'Maret',
          'April',
          'Mei',
          'Juni',
          'Juli',
          'Agustus',
          'September',
          'Oktober',
          'November',
          'Desember',
        ];
        final currentMonthStr = currentMonthNames[now.month - 1];
        int weekNum = (now.day / 7).ceil();
        if (weekNum > 5) weekNum = 5;
        final currentWeekStr = 'Pekan $weekNum';

        final attendanceDataList =
            await AttendanceService.getAttendanceDashboardChart(
              academicYearId: academicYearId,
              month: currentMonthStr,
              week: currentWeekStr,
              role: _effectiveRole == 'wali' ? _effectiveRole : null,
            );
        freshAttendance = List<Map<String, dynamic>>.from(attendanceDataList);

        if (_effectiveRole == 'admin') {
          final financeDataList = await FinanceService.getFinanceDashboardChart(
            academicYearId: academicYearId,
          );
          freshFinance = List<Map<String, dynamic>>.from(financeDataList);
        }
      }

      if (!mounted) return;

      // ─── Step 3: Apply fresh data & save to cache ───
      _applyStatsData(
        dashboardData,
        attendanceChart: freshAttendance,
        financeChart: freshFinance,
      );

      // Save fresh data to cache (non-blocking)
      LocalCacheService.save(_dashboardCacheKey('stats'), dashboardData);
      if (freshAttendance != null) {
        LocalCacheService.save(
          _dashboardCacheKey('attendance_chart'),
          freshAttendance,
        );
      }
      if (freshFinance != null) {
        LocalCacheService.save(
          _dashboardCacheKey('finance_chart'),
          freshFinance,
        );
      }

      // Load Finance Stats for Admin
      if (_effectiveRole == 'admin') {
        await _loadFinanceStats();
      }
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading fresh stats: $e');
      // Only show fallback if we don't already have cached data displayed
      if (!_isStatsLoaded && mounted) {
        AppLogger.warning(
          'dashboard',
          'Menggunakan fallback data (no cache available)',
        );
        setState(() {
          _isStatsLoaded = true;
          if (_effectiveRole == 'guru') {
            _stats = {
              'total_students': 24,
              'total_classes': 1,
              'classes_today': 2,
              'total_materials': 5,
              'total_rpps': 3,
            };
          } else if (_effectiveRole == 'admin') {
            _stats = {
              'total_students': 150,
              'total_teachers': 25,
              'total_classes': 12,
              'total_subjects': 15,
            };
          } else if (_effectiveRole == 'wali') {
            _stats = {
              'children_registered': 2,
              'latest_announcements': 3,
              'unread_grades': 0,
              'unread_presence': 0,
            };
          }
        });
      }
    }
  }

  // Method to get student data for parent/guardian
  Future<List<dynamic>> _getStudentDataForParent(String parentId) async {
    try {
      AppLogger.debug(
        'dashboard',
        'Mencari data siswa untuk parent: $parentId',
      );

      final userData = _userData;
      final guardianEmail = userData['email'];

      final allStudents = await getIt<ApiStudentService>().getStudent(
        userId: parentId,
        guardianEmail: guardianEmail,
      );

      AppLogger.debug(
        'dashboard',
        'Total siswa ditemukan untuk user $parentId (Email: $guardianEmail): ${allStudents.length}',
      );

      AppLogger.debug(
        'dashboard',
        'Email wali: ${userData['email']}, Nama wali: ${userData['name']}',
      );

      // Check by siswa_id in user data
      if (userData['siswa_id'] != null && userData['siswa_id'].isNotEmpty) {
        AppLogger.debug(
          'dashboard',
          'Mencari siswa dengan ID: ${userData['siswa_id']}',
        );
        final student = allStudents.firstWhere(
          (student) => student['id'] == userData['siswa_id'],
          orElse: () => null,
        );
        if (student != null) {
          AppLogger.info(
            'dashboard',
            'Siswa ditemukan via siswa_id: ${student['nama']}',
          );
          return [student];
        }
      }

      // Check by email, guardian name, or user_id (Parent User)
      final studentsWithThisParent = allStudents.where((student) {
        final emailMatch = student['guardian_email'] == userData['email'];
        // Fix: Use 'name' instead of 'nama' (based on debug logs)
        final nameMatch = student['guardian_name'] == userData['name'];
        final userIdMatch = student['user_id'].toString() == parentId;

        if (kDebugMode) {
          // Verbose debug only if needed, or just log matches
          if (emailMatch || nameMatch || userIdMatch) {
            AppLogger.info(
              'dashboard',
              'Siswa cocok: ${student['name']} (By: ${emailMatch ? 'Email' : ''} ${nameMatch ? 'Name' : ''} ${userIdMatch ? 'UserID' : ''})',
            );
          } else {
            // print('❌ Skip: ${student['name']} (GuardEmail: ${student['guardian_email']}, GuardName: ${student['guardian_name']}, UserID: ${student['user_id']})');
          }
        }

        return emailMatch || nameMatch || userIdMatch;
      }).toList();

      if (studentsWithThisParent.isNotEmpty) {
        return studentsWithThisParent;
      }

      AppLogger.warning(
        'dashboard',
        'Tidak ada data siswa ditemukan untuk parent ini',
      );
      return []; // Fix: Return empty list instead of allStudents for security/correctness
    } catch (e) {
      AppLogger.error('dashboard', 'Error getting student data for parent: $e');
      return [];
    }
  }

  // Load Finance Stats (Admin Only)
  Future<void> _loadFinanceStats() async {
    try {
      final financeStats = await FinanceService.getFinanceDashboardStats();
      if (mounted && financeStats.containsKey('pembayaran_pending')) {
        setState(() {
          _unverifiedPaymentCount =
              int.tryParse(financeStats['pembayaran_pending'].toString()) ?? 0;
        });
        AppLogger.debug(
          'dashboard',
          'Unverified Payments: $_unverifiedPaymentCount',
        );
      }
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading finance stats: $e');
    }
  }

  /// Switches the active school context via the API.
  /// Like calling `POST /api/switch-school/{id}` in Laravel.
  /// Clears all local cache/data and re-navigates to the appropriate dashboard.
  Future<void> _switchSchool(Map<String, dynamic> school) async {
    // Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await AuthService.switchSchool(school['school_id']);

      // Close Loading Indicator
      if (mounted) AppNavigator.pop(context);

      // 1. Check for Multiple Roles (`pilih_role`)
      if (response['pilih_role'] == true && response['role_list'] is List) {
        final roleList = List<String>.from(response['role_list']);

        if (!mounted) return;

        final selectedRole = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => SimpleDialog(
            title: Text('Pilih Peran Anda'),
            children: roleList.map((role) {
              // Normalize for display
              final normalizedForDisplay = role == 'parent'
                  ? 'wali'
                  : (role == 'teacher' ? 'guru' : role);
              return SimpleDialogOption(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                onPressed: () => AppNavigator.pop(
                  context,
                  role,
                ), // Return original string 'parent'/'admin'
                child: Row(
                  children: [
                    _buildRoleIcon(normalizedForDisplay),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      _getRoleDisplayName(normalizedForDisplay),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

        if (selectedRole == null) return;

        // Proceed with selectedRole
        await _processSchoolSwitch(response, school, selectedRole);
        return;
      }

      // 2. Single Role Case (Backend assigned role automatically)
      await _processSchoolSwitch(response, school, null);
    } catch (e) {
      // Close Loading Indicator if error occurs
      if (mounted) AppNavigator.pop(context);

      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal pindah sekolah: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> _processSchoolSwitch(
    Map<String, dynamic> response,
    Map<String, dynamic> schoolInfo,
    String? selectedRole,
  ) async {
    // Clear all cache to prevent stale data from previous school
    await LocalCacheService.clearAll();
    if (mounted) {
      ref.read(teacherRiverpod).clear();
    }

    // Update token
    if (response['token'] != null) {
      await SecureStorageService().saveToken(response['token']);
    }
    final prefs = PreferencesService();
    if (response['token'] != null) {
      await prefs.setString('token', response['token']);
    }

    // Update user data from backend response
    Map<String, dynamic> updatedUserData;

    if (response['user'] != null) {
      final backendUser = Map<String, dynamic>.from(response['user']);
      updatedUserData = {..._userData, ...backendUser};

      // If "pilih_role" case (selectedRole != null), we must construct some fields manually
      // because backend raw user object in this case might not have 'role' set,
      // nor 'nama_sekolah' (which comes in 'school' object).
      if (selectedRole != null) {
        updatedUserData['role'] = selectedRole;

        // Backend sends 'school' object in pilih_role response
        if (response['school'] != null) {
          final schoolObj = response['school'];
          updatedUserData['school_id'] = schoolObj['id'];
          updatedUserData['nama_sekolah'] =
              schoolObj['school_name'] ?? schoolObj['nama_sekolah'];
          updatedUserData['sekolah_alamat'] =
              schoolObj['address'] ?? schoolObj['alamat'];
          // ... other fields if needed
        }
      }
    } else {
      // Fallback manual update (should not happen with correct backend)
      updatedUserData = Map<String, dynamic>.from(_userData);
      updatedUserData['school_id'] = schoolInfo['school_id'];
      updatedUserData['nama_sekolah'] =
          schoolInfo['school_name'] ?? schoolInfo['nama_sekolah'];
    }

    await SecureStorageService().saveUserData(updatedUserData);
    await prefs.setString('user', json.encode(updatedUserData));

    if (!mounted) return;

    var newRole = updatedUserData['role'];

    // Normalize role values
    if (newRole == 'teacher') newRole = 'guru';
    if (newRole == 'parent') newRole = 'wali';

    // Update 'role' in userData to normalized value?
    // Better to strictly use normalized for Frontend routing.
    updatedUserData['role'] = newRole;
    await prefs.setString(
      'user',
      json.encode(updatedUserData),
    ); // Save normalized

    if (newRole != null) {
      // Always navigate to new dashboard to refresh state completely
      AppNavigator.pushReplacementNamed(context, '/$newRole');
    } else {
      // Role same, just reload data
      await _initializeData();
      setState(() {
        _userData = updatedUserData;
      });
    }
  }

  /// Like Vue's `beforeUnmount()` / `unmounted()` lifecycle hook.
  /// Cleans up listeners, animation controllers, and provider subscriptions
  /// to prevent memory leaks. Always pair addListener with removeListener.
  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_handleSyncTrigger);
    _animationController.dispose();
    // Guard ref access — may already be disposed during logout navigation
    if (mounted) {
      try {
        ref.read(academicYearRiverpod).removeListener(_onYearChanged);
      } catch (_) {}
    }
    super.dispose();
  }

  /// Handles real-time sync triggers from FCM (Firebase Cloud Messaging).
  /// Like a Vue WebSocket/Pusher listener that refreshes data when the
  /// backend sends a push notification (e.g., new student added, schedule changed).
  void _handleSyncTrigger() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null) {
      if (trigger['type'] == 'refresh_announcements') {
        AppLogger.debug(
          'dashboard',
          'Dashboard flushing announcement cache due to background/foreground sync',
        );
        // Reload announcements count
        if (_effectiveRole == 'wali' ||
            _effectiveRole == 'admin' ||
            _effectiveRole == 'guru') {
          AnnouncementService.getUnreadAnnouncementCount().then((count) {
            if (mounted) {
              setState(() {
                _stats['unread_announcements'] = count;
              });
            }
          });
        }
      }
    }
  }

  /// Main build method - like Vue's `<template>` section.
  /// Renders a CustomScrollView with role-specific sliver sections:
  /// app bar, hero stats, quick actions, overview cards, and menu grid.
  /// Uses `ref.watch(languageRiverpod)` to react to language changes
  /// (like a Vue `computed` property depending on an i18n store).
  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Builder(
      builder: (context) {
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              // Modern App Bar
              _buildModernAppBar(context, languageProvider),

              // Hero Section with Stats Overlay
              SliverToBoxAdapter(child: _buildHeroSection()),

              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions()),

              // Today's Overview
              SliverToBoxAdapter(child: _buildTodaysOverview()),

              // Section Divider
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Text(
                    AppLocalizations.menu.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ),

              // Navigation Menu
              _buildSliverGridMenu(context),

              // Bottom Padding
              SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        );
      },
    );
  }

  // ==================== SKELETON SHIMMER HELPERS ====================

  Widget _buildShimmerBox({
    double width = double.infinity,
    double height = 16,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildHeroStatSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.15),
      highlightColor: Colors.white.withValues(alpha: 0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 28,
            height: 17,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Container(
            width: 36,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: 36, height: 36, borderRadius: 10),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(width: 40, height: 20, borderRadius: 4),
                      SizedBox(height: AppSpacing.xs),
                      _buildShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            _buildShimmerBox(width: 100, height: 10, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionSkeleton() {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 65,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 50,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NEW MODERN UI COMPONENTS ====================

  Widget _buildModernAppBar(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return SliverAppBar(
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 50,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ColorUtils.slate200, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Logo - simpler design
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school, color: Colors.white, size: 18),
                ),
                SizedBox(width: AppSpacing.md),

                // Title - single line
                Expanded(
                  child: Text(
                    _userData['nama_sekolah'] ?? AppLocalizations.appTitle.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Actions - more compact
                IconButton(
                  icon: Icon(
                    Icons.language,
                    size: 20,
                    color: ColorUtils.slate600,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  onPressed: () =>
                      _showLanguageDialog(context, languageProvider),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: ColorUtils.slate600,
                      ),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      splashRadius: 18,
                      onPressed: () {
                        AppNavigator.push(
                          context,
                          NotificationListScreen(role: widget.role),
                        );
                      },
                    ),
                    if (_stats['unread_announcements'] != null &&
                        _stats['unread_announcements'] > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            _stats['unread_announcements'] > 9
                                ? '9+'
                                : _stats['unread_announcements'].toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  key: _profileHeaderKey,
                  icon: Icon(
                    Icons.account_circle,
                    size: 20,
                    color: ColorUtils.slate600,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  onPressed: () => _showAccountBottomSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the hero section with key stats (total students, teachers, etc.).
  /// Like a Vue dashboard header component showing KPI cards.
  Widget _buildHeroSection() {
    final primaryColor = _getPrimaryColor();

    return Container(
      key: _heroSectionKey,
      margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circle - top right
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // Decorative circle - bottom left
            Positioned(
              bottom: -25,
              left: 15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Small accent dot
            Positioned(
              top: 20,
              right: 70,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Academic Year & Semester - Top Right
            Positioned(
              top: 10,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAcademicYearDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        Builder(
                          builder: (context) {
                            final provider = ref.watch(academicYearRiverpod);
                            final academicYear =
                                provider.selectedAcademicYear?['year'] ?? '-';
                            final semester = _currentSemesterLabel ?? '-';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  academicYear,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  semester,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Greeting
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(_getGreetingEmoji(), style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    _userData['name'] ?? _userData['nama'] ?? 'User',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 14),

                  // 4-Column Stats Grid
                  Row(
                    children: _isStatsLoaded
                        ? _buildFourColumnStats()
                              .map((stat) => Expanded(child: stat))
                              .toList()
                        : List.generate(
                            4,
                            (_) => Expanded(child: _buildHeroStatSkeleton()),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcademicYearDialog(BuildContext context) {
    final provider = ref.read(academicYearRiverpod);
    final years = provider.academicYears;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Pilih Tahun Ajaran'),
        children: years.map((year) {
          final isSelected = provider.selectedAcademicYear?['id'] == year['id'];
          return SimpleDialogOption(
            onPressed: () {
              provider.setSelectedYear(year['id'].toString());
              AppNavigator.pop(context);
            },
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  year['year'] ?? '-',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? ColorUtils.corporateBlue600
                        : ColorUtils.slate900,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: ColorUtils.corporateBlue600,
                    size: 20,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 17) return '☀️';
    return '🌙';
  }

  List<Widget> _buildFourColumnStats() {
    final lp = languageProvider;
    if (_effectiveRole == 'admin') {
      return [
        _buildHeroStat(
          Icons.people_outline,
          _stats['total_students']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
        ),
        _buildHeroStat(
          Icons.school_outlined,
          _stats['total_teachers']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Teachers', 'id': 'Guru'}),
        ),
        _buildHeroStat(
          Icons.class_outlined,
          _stats['total_classes']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
        ),
        _buildHeroStat(
          Icons.book_outlined,
          _stats['total_subjects']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Subjects', 'id': 'Mapel'}),
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        _buildHeroStat(
          Icons.people_outline,
          _stats['total_students']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
        ),
        _buildHeroStat(
          Icons.class_outlined,
          _stats['total_classes']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
        ),
        _buildHeroStat(
          Icons.schedule_outlined,
          _stats['classes_today']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
        ),
        _buildHeroStat(
          Icons.assignment_outlined,
          _stats['total_rpps']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Plans', 'id': 'RPP'}),
        ),
      ];
    } else {
      return [
        _buildHeroStat(
          Icons.child_care_outlined,
          _stats['children_registered']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Children', 'id': 'Anak'}),
        ),
        _buildHeroStat(
          Icons.announcement_outlined,
          _stats['latest_announcements']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'News', 'id': 'Info'}),
        ),
        _buildHeroStat(
          Icons.grade_outlined,
          _stats['unread_grades']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}),
        ),
        _buildHeroStat(
          Icons.calendar_today_outlined,
          _stats['unread_presence']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Attendance', 'id': 'Absen'}),
        ),
      ];
    }
  }

  Widget _buildHeroStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with glass morphism effect
        Container(
          padding: EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds quick action buttons (shortcuts to common tasks).
  /// Like a Vue component rendering a row of action buttons based on role.
  Widget _buildQuickActions() {
    final List<Widget> actions = _getQuickActions();

    if (actions.isEmpty && _isStatsLoaded) {
      return SizedBox.shrink();
    }

    return Padding(
      key: _quickActionsKey,
      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.quickAccess.tr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          // Action buttons or skeleton
          SizedBox(
            height: 85,
            child: _isStatsLoaded
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    itemCount: actions.length,
                    separatorBuilder: (context, index) => SizedBox(width: 10),
                    itemBuilder: (context, index) => actions[index],
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (context, index) => SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _buildQuickActionSkeleton(),
                  ),
          ),
        ],
      ),
    );
  }

  /// Builds today's overview section with schedule slider, attendance, and charts.
  /// Renders different content per role using conditional logic (like Vue `v-if`).
  Widget _buildTodaysOverview() {
    return Padding(
      key: _statsSectionKey,
      padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.todaysOverview.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          GridView.count(
            padding: EdgeInsets.only(top: 12),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: _isStatsLoaded
                ? _getTodaysOverviewCards()
                : List.generate(4, (_) => _buildOverviewCardSkeleton()),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTodaysOverviewCards() {
    if (_effectiveRole == 'admin') {
      return [
        if (_financeChartData.isNotEmpty)
          FinanceBarChartCard(
            title: AppLocalizations.finance.tr,
            icon: Icons.account_balance_wallet_outlined,
            accentColor: ColorUtils.success600,
            semestersData: _financeChartData,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) =>
                    FinancePopupDialog(semestersData: _financeChartData),
              );
            },
          ),
        if (_attendanceChartData.isNotEmpty)
          AttendanceBarChartCard(
            title: AppLocalizations.attendance.tr,
            icon: Icons.ssid_chart_outlined,
            accentColor: ColorUtils.warning600,
            classesData: _attendanceChartData,
            onTap: () {
              // Extract the selected academic year right before showing dialog
              final selectedYearId = ref
                  .read(academicYearRiverpod)
                  .selectedAcademicYear?['id']
                  ?.toString();

              showDialog(
                context: context,
                builder: (context) => AttendancePopupDialog(
                  semesterLabel: _currentSemesterLabel,
                  initialData: _attendanceChartData,
                  academicYearId: selectedYearId,
                ),
              );
            },
          ),
        OverviewCard(
          title: AppLocalizations.activeTeachers.tr,
          value: _stats['total_teachers']?.toString() ?? '0',
          subtitle: AppLocalizations.currentlyTeaching.tr,
          icon: Icons.people_alt_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            // Navigate to teachers
          },
        ),
        OverviewCard(
          title: AppLocalizations.announcements.tr,
          value: _stats['latest_announcements']?.toString() ?? '0',
          subtitle: AppLocalizations.recentUpdates.tr,
          icon: Icons.campaign_outlined,
          accentColor: ColorUtils.info600,
          onTap: () {
            // Navigate to announcements
          },
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        ScheduleSliderCard(
          key: _scheduleSectionKey,
          schedules: _todaysScheduleList,
          onTap: () {
            AppNavigator.push(context, TeachingScheduleScreen());
          },
        ),
        AttendanceOverviewCard(
          hadir: (_stats['attendance_summary'] is Map)
              ? (_stats['attendance_summary']['hadir'] ?? 0)
              : 0,
          izin: (_stats['attendance_summary'] is Map)
              ? (_stats['attendance_summary']['izin'] ?? 0)
              : 0,
          sakit: (_stats['attendance_summary'] is Map)
              ? (_stats['attendance_summary']['sakit'] ?? 0)
              : 0,
          alpha: (_stats['attendance_summary'] is Map)
              ? (_stats['attendance_summary']['alpha'] ?? 0)
              : 0,
          total: (_stats['attendance_summary'] is Map)
              ? (_stats['attendance_summary']['total'] ?? 0)
              : 0,
          onTap: () {
            AppNavigator.push(context, PresencePage(teacher: _userData));
          },
        ),
        MaterialSliderCard(
          materials: _materialOverview,
          onTap: () {
            AppNavigator.push(context, MateriPage(teacher: _userData));
          },
        ),
        LessonPlanStatusCard(
          approved: _stats['rpp_approved'] ?? 0,
          rejected: _stats['rpp_rejected'] ?? 0,
          pending: _stats['rpp_pending'] ?? 0,
          onTap: () {
            AppNavigator.push(
              context,
              LessonPlanScreen(
                teacherId: _userData['id'].toString(),
                teacherName: _userData['name'] ?? 'Guru',
              ),
            );
          },
        ),
      ];
    } else {
      return [
        OverviewCard(
          title: AppLocalizations.myChildren.tr,
          value: _stats['children_registered']?.toString() ?? '0',
          subtitle: AppLocalizations.registeredStudents.tr,
          icon: Icons.family_restroom_outlined,
          accentColor: ColorUtils.corporateBlue600,
          onTap: () {
            // Navigate to children
          },
        ),
        OverviewCard(
          title: AppLocalizations.newGrades.tr,
          value: _stats['unread_grades']?.toString() ?? '0',
          subtitle: AppLocalizations.recentUpdates.tr,
          icon: Icons.grade_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            // Navigate to grades
          },
        ),
        if (_attendanceChartData.isNotEmpty)
          AttendanceBarChartCard(
            title: AppLocalizations.childAttendance.tr,
            icon: Icons.ssid_chart_outlined,
            accentColor: ColorUtils.warning600,
            classesData: _attendanceChartData,
            hideSubtitle:
                true, // Requested by user to hide the child's name on the card
            onTap: () {
              final selectedYearId = ref
                  .read(academicYearRiverpod)
                  .selectedAcademicYear?['id']
                  ?.toString();

              showDialog(
                context: context,
                builder: (context) => AttendancePopupDialog(
                  semesterLabel: _currentSemesterLabel,
                  initialData: _attendanceChartData,
                  academicYearId: selectedYearId,
                ),
              );
            },
          )
        else
          OverviewCard(
            title: AppLocalizations.attendance.tr,
            value: _stats['unread_presence']?.toString() ?? '0',
            subtitle: AppLocalizations.newRecords.tr,
            icon: Icons.calendar_month_outlined,
            accentColor: ColorUtils.warning600,
            onTap: () {
              // Navigate to attendance
            },
          ),
        OverviewCard(
          title: AppLocalizations.announcements.tr,
          value: _stats['latest_announcements']?.toString() ?? '0',
          subtitle: AppLocalizations.latestInformation.tr,
          icon: Icons.announcement_outlined,
          accentColor: ColorUtils.info600,
          onTap: () {
            // Navigate to announcements
          },
        ),
      ];
    }
  }

  List<Widget> _getQuickActions() {
    final primaryColor = _getPrimaryColor();

    if (_effectiveRole == 'admin') {
      return [
        QuickActionButton(
          label: AppLocalizations.data.tr,
          icon: Icons.folder_outlined,
          color: primaryColor,
          onTap: () => AppNavigator.push(context, AdminDataManagementScreen()),
        ),
        QuickActionButton(
          label: AppLocalizations.schedule.tr,
          icon: Icons.schedule_outlined,
          color: ColorUtils.info600,
          onTap: () =>
              AppNavigator.push(context, TeachingScheduleManagementScreen()),
        ),
        QuickActionButton(
          label: AppLocalizations.finance.tr,
          icon: Icons.account_balance_wallet_outlined,
          color: ColorUtils.success600,
          badgeCount: _unverifiedPaymentCount > 0
              ? _unverifiedPaymentCount
              : null,
          onTap: () => AppNavigator.push(context, FinanceScreen()),
        ),
        QuickActionButton(
          label: AppLocalizations.announcements.tr,
          icon: Icons.announcement_outlined,
          color: ColorUtils.warning600,
          badgeCount: _stats['unread_announcements'],
          onTap: () async {
            await AppNavigator.push(context, AdminAnnouncementScreen());
            _loadStats();
          },
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        QuickActionButton(
          label: AppLocalizations.schedule.tr,
          icon: Icons.schedule_outlined,
          color: primaryColor,
          onTap: () => AppNavigator.push(context, TeachingScheduleScreen()),
        ),
        QuickActionButton(
          label: AppLocalizations.attendance.tr,
          icon: Icons.how_to_reg_outlined,
          color: ColorUtils.warning600,
          onTap: () =>
              AppNavigator.push(context, PresencePage(teacher: _userData)),
        ),
        QuickActionButton(
          label: AppLocalizations.activity.tr,
          icon: Icons.local_activity_outlined,
          color: ColorUtils.info600,
          onTap: () => AppNavigator.push(context, ClassActifityScreen()),
        ),
        QuickActionButton(
          label: AppLocalizations.inputGrades.tr,
          icon: Icons.edit_note_outlined,
          color: ColorUtils.success600,
          onTap: () async {
            final prefs = PreferencesService();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final teacherData = {
              'id': userData['id'] ?? '',
              'nama': userData['nama'] ?? 'Teacher',
              'email': userData['email'] ?? '',
              'role': _effectiveRole,
            };
            if (teacherData['id']!.isEmpty) return;
            if (!context.mounted) return;
            AppNavigator.push(context, GradePage(teacher: teacherData));
          },
        ),
      ];
    } else {
      return [
        QuickActionButton(
          label: AppLocalizations.announcements.tr,
          icon: Icons.announcement_outlined,
          color: primaryColor,
          badgeCount: _stats['unread_announcements'],
          onTap: () async {
            await AppNavigator.push(context, AnnouncementScreen());
            _loadStats();
          },
        ),
        QuickActionButton(
          label: AppLocalizations.billing.tr,
          icon: Icons.account_balance_wallet_outlined,
          color: ColorUtils.error600,
          badgeCount: _stats['unread_billings'],
          onTap: () async {
            await AppNavigator.push(context, ParentBillingScreen());
            _loadStats();
          },
        ),
      ];
    }
  }

  // ==================== END NEW UI COMPONENTS ====================

  /// Builds the main navigation menu grid with role-specific items.
  /// Like a Vue component rendering a grid of `<MenuItemCard>` with `v-for`,
  /// where each card navigates to a different admin/teacher/parent feature screen.
  Widget _buildSliverGridMenu(BuildContext context) {
    // All roles now use professional MenuItemCard design
    return SliverPadding(
      key: _menuGridKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(_buildCategorizedMenu(context)),
      ),
    );
  }

  List<Widget> _buildCategorizedMenu(BuildContext context) {
    final primaryColor = _getPrimaryColor();

    if (_effectiveRole == 'admin') {
      return [
        CategorySection(
          title: '📊 ${AppLocalizations.categoryDataManagement.tr}',
          icon: Icons.folder_shared,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminDataManagementItems(context),
        ),
        CategorySection(
          title: '📢 ${AppLocalizations.categoryAcademicCommunication.tr}',
          icon: Icons.school,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminAcademicItems(context),
        ),
        CategorySection(
          title: '💰 ${AppLocalizations.categoryFinanceSettings.tr}',
          icon: Icons.settings,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminFinanceItems(context),
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        CategorySection(
          title: '📚 ${AppLocalizations.categoryTeaching.tr}',
          icon: Icons.school,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getTeacherTeachingItems(context),
        ),
        CategorySection(
          title: '✏️ ${AppLocalizations.categoryAssessmentPlanning.tr}',
          icon: Icons.edit_note,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getTeacherAssessmentItems(context),
        ),
      ];
    } else if (_effectiveRole == 'wali') {
      // Parent role: Simple list without categories (only 5 items)
      final items = _getParentMenuItems(context);
      return items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: MenuItemCard(
                title: item.title,
                icon: item.icon,
                onTap: item.onTap,
                badgeCount: item.badgeCount,
                primaryColor: primaryColor,
              ),
            ),
          )
          .toList();
    }

    return [];
  }

  // Admin - Data Management Category
  List<MenuItem> _getAdminDataManagementItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.manageData.tr,
        icon: Icons.folder_shared_outlined,
        onTap: () => AppNavigator.push(context, AdminDataManagementScreen()),
      ),
      MenuItem(
        title: AppLocalizations.manageTeachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () =>
            AppNavigator.push(context, TeachingScheduleManagementScreen()),
      ),
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
          final prefs = PreferencesService();
          final userData = json.decode(prefs.getString('user') ?? '{}');
          final adminData = {
            'id': userData['id'] ?? '',
            'nama': userData['nama'] ?? 'Admin',
            'email': userData['email'] ?? '',
            'role': _effectiveRole,
          };
          if (adminData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Admin ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, GradePage(teacher: adminData));
        },
      ),
    ];
  }

  // Admin - Academic & Communication Category
  List<MenuItem> _getAdminAcademicItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: _stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AdminAnnouncementScreen());
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () => AppNavigator.push(context, AdminClassActivityScreen()),
      ),
      MenuItem(
        title: AppLocalizations.presenceReport.tr,
        icon: Icons.check_circle_outline,
        onTap: () => AppNavigator.push(context, AdminPresenceReportScreen()),
      ),
      MenuItem(
        title: AppLocalizations.manageRpp.tr,
        icon: Icons.description_outlined,
        onTap: () => AppNavigator.push(context, AdminLessonPlanScreen()),
      ),
      MenuItem(
        title: AppLocalizations.studentReport.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => AppNavigator.push(context, const AdminRaportScreen()),
      ),
    ];
  }

  // Admin - Finance & Settings Category
  List<MenuItem> _getAdminFinanceItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.finance.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: _unverifiedPaymentCount > 0
            ? _unverifiedPaymentCount
            : null,
        onTap: () => AppNavigator.push(context, FinanceScreen()),
      ),
      MenuItem(
        title: AppLocalizations.schoolSettings.tr,
        icon: Icons.settings_applications,
        onTap: () => AppNavigator.push(context, SchoolSettingsScreen()),
      ),
    ];
  }

  // Teacher - Teaching Category
  List<MenuItem> _getTeacherTeachingItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.teachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => AppNavigator.push(context, TeachingScheduleScreen()),
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () => AppNavigator.push(context, ClassActifityScreen()),
      ),
      MenuItem(
        title: AppLocalizations.studentAttendance.tr,
        icon: Icons.check_circle_outline,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (_userData['teacher_id'] ?? _userData['id'])?.toString() ?? '',
            'nama': _userData['nama'] ?? _userData['name'] ?? 'Teacher',
            'email': _userData['email']?.toString() ?? '',
            'role': _effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Teacher ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, PresencePage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.learningMaterials.tr,
        icon: Icons.book_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (_userData['teacher_id'] ?? _userData['id'])?.toString() ?? '',
            'name': _userData['name'] ?? _userData['nama'] ?? 'Teacher',
            'role': _effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Teacher ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, MateriPage(teacher: teacherData));
        },
      ),
    ];
  }

  // Teacher - Assessment & Planning Category
  List<MenuItem> _getTeacherAssessmentItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (_userData['teacher_id'] ?? _userData['id'])?.toString() ?? '',
            'nama': _userData['nama'] ?? _userData['name'] ?? 'Teacher',
            'email': _userData['email']?.toString() ?? '',
            'role': _effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Teacher ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, GradePage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.gradeRecap.tr,
        icon: Icons.assessment_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (_userData['teacher_id'] ?? _userData['id'])?.toString() ?? '',
            'nama': _userData['nama'] ?? _userData['name'] ?? 'Teacher',
            'email': _userData['email']?.toString() ?? '',
            'role': _effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Teacher ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, GradeRecapPage(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.reportCard.tr,
        icon: Icons.contact_page_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (_userData['teacher_id'] ?? _userData['id'])?.toString() ?? '',
            'nama': _userData['nama'] ?? _userData['name'] ?? 'Teacher',
            'email': _userData['email']?.toString() ?? '',
            'role': _effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Teacher ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(context, RaportScreen(teacher: teacherData));
        },
      ),
      MenuItem(
        title: AppLocalizations.myRpp.tr,
        icon: Icons.description_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (_userData['teacher_id'] ?? _userData['id'])?.toString() ?? '',
            'nama': _userData['nama']?.toString() ?? 'Teacher',
            'email': _userData['email']?.toString() ?? '',
            'role': _effectiveRole,
          };
          if (teacherData['id']!.isEmpty) {
            if (context.mounted) {
              SnackBarUtils.showInfo(context, 'Error: Teacher ID not found');
            }
            return;
          }
          if (!context.mounted) return;
          AppNavigator.push(
            context,
            LessonPlanScreen(
              teacherId: teacherData['id']!,
              teacherName: teacherData['nama']!,
            ),
          );
        },
      ),
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: _stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AnnouncementScreen());
          _loadStats();
        },
      ),
      if (_homeroomClasses.isNotEmpty)
        MenuItem(
          title: AppLocalizations.learningRecommendation.tr,
          icon: Icons.auto_awesome_outlined,
          onTap: () async {
            final Map<String, String> teacherData = {
              'id':
                  (_userData['teacher_id'] ?? _userData['id'])?.toString() ??
                  '',
              'nama': _userData['nama'] ?? _userData['name'] ?? 'Teacher',
              'email': _userData['email']?.toString() ?? '',
              'role': _effectiveRole,
            };
            if (!context.mounted) return;

            AppNavigator.push(
              context,
              LearningRecommendationClassScreen(
                teacher: teacherData,
                classes: _homeroomClasses,
              ),
            );
          },
        ),
    ];
  }

  // Parent - Menu Items (Simple list, no categories)
  List<MenuItem> _getParentMenuItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: _stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AnnouncementScreen());
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        badgeCount: _stats['unread_class_activities'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();
          await AppNavigator.push(
            context,
            ParentClassActivityScreen(academicYearId: academicYearId),
          );
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.grades.tr,
        icon: Icons.grade_outlined,
        badgeCount: _stats['unread_grades'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();
          await AppNavigator.push(
            context,
            ParentGradeScreen(academicYearId: academicYearId),
          );
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.presence.tr,
        icon: Icons.check_circle_outline,
        badgeCount: _stats['unread_presence'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();

          final prefs = PreferencesService();
          final userData = json.decode(prefs.getString('user') ?? '{}');
          // Load students
          final studentsData = await _getStudentDataForParent(
            userData['id'] ?? '',
          );

          if (studentsData.isEmpty) {
            if (context.mounted) {
              _showNoStudentsDialog(context);
            }
            return;
          }

          if (!context.mounted) return;

          if (studentsData.length == 1) {
            await AppNavigator.push(
              context,
              PresenceParentPage(
                parent: userData,
                studentId: studentsData[0]['id'],
                academicYearId: academicYearId,
              ),
            );
            _loadStats();
          } else {
            await _showStudentSelectionDialog(
              context,
              userData,
              studentsData,
              academicYearId: academicYearId,
            );
            _loadStats();
          }
        },
      ),
      MenuItem(
        title: AppLocalizations.billing.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: _stats['unread_billings'],
        onTap: () async {
          await AppNavigator.push(context, ParentBillingScreen());
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.eRaport.tr,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();

          await AppNavigator.push(
            context,
            ParentRaportScreen(academicYearId: academicYearId),
          );
        },
      ),
    ];
  }

  void _showLanguageDialog(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.chooseLanguage.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getPrimaryColor(),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context,
              languageProvider,
              'Indonesia',
              'id',
              Colors.green,
            ),
            SizedBox(height: AppSpacing.md),
            _buildLanguageOption(
              context,
              languageProvider,
              'English',
              'en',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider languageProvider,
    String language,
    String code,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          AppNavigator.pop(context);
          await languageProvider.setLanguage(code);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.language, color: color),
              SizedBox(width: AppSpacing.md),
              Text(
                language,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Spacer(),
              if (languageProvider.currentLanguage == code)
                Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows the account bottom sheet with profile info, school/role switching, and logout.
  /// Like a Vue modal/drawer component for user account management.
  void _showAccountBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Loading states for async actions inside the bottom sheet
        bool isLoggingOut = false;
        String? switchingRole; // tracks which role is being switched to

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: EdgeInsets.all(AppSpacing.xl),
              child: Wrap(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(25),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 60,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.xl),

                          // User Info
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: _getCardGradient(),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.account_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userData['nama'] ?? _getRoleTitle(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Text(
                                      _userData['email'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      _userData['nama_sekolah'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: AppSpacing.xxl),

                          if (_availableRoles.length > 1) ...[
                            SizedBox(height: AppSpacing.lg),
                            Text(
                              AppLocalizations.switchRole.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: AppSpacing.sm),
                            ..._availableRoles.map((role) {
                              final isCurrent = role == widget.role;
                              final isSwitching = switchingRole == role;
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (isCurrent || switchingRole != null)
                                      ? null
                                      : () async {
                                          setSheetState(
                                            () => switchingRole = role,
                                          );
                                          try {
                                            await _switchRole(role);
                                          } finally {
                                            if (context.mounted) {
                                              setSheetState(
                                                () => switchingRole = null,
                                              );
                                            }
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    margin: EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? _getPrimaryColor().withValues(
                                              alpha: 0.1,
                                            )
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isCurrent
                                            ? _getPrimaryColor().withValues(
                                                alpha: 0.3,
                                              )
                                            : Colors.transparent,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (isSwitching)
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _getPrimaryColor(),
                                            ),
                                          )
                                        else
                                          _buildRoleIcon(role),
                                        SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Text(
                                            isSwitching
                                                ? '${_getRoleDisplayName(role)}...'
                                                : _getRoleDisplayName(role),
                                            style: TextStyle(
                                              fontWeight: isCurrent
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        if (isCurrent)
                                          Icon(
                                            Icons.check_circle,
                                            color: _getPrimaryColor(),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            SizedBox(height: AppSpacing.lg),
                            Divider(),
                            SizedBox(height: AppSpacing.lg),
                          ],

                          // Switch School Button
                          if (_accessibleSchools.length > 1) ...[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  AppNavigator.pop(context);
                                  _showSchoolSelectionDialog(context);
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: _getPrimaryColor().withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: _getPrimaryColor().withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        color: _getPrimaryColor(),
                                        size: 20,
                                      ),
                                      SizedBox(width: AppSpacing.sm),
                                      Text(
                                        AppLocalizations.switchSchool.tr,
                                        style: TextStyle(
                                          color: _getPrimaryColor(),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppSpacing.lg),
                            Divider(),
                            SizedBox(height: AppSpacing.lg),
                          ],

                          // Settings Button — shown for all roles
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                AppNavigator.pop(context);
                                AppNavigator.push(
                                  context,
                                  const SettingsScreen(),
                                );
                              },
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      color: ColorUtils.getRoleColor(
                                        _effectiveRole,
                                      ),
                                      size: 20,
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      AppLocalizations.settings.tr,
                                      style: TextStyle(
                                        color: ColorUtils.getRoleColor(
                                          _effectiveRole,
                                        ),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.lg),

                          // Logout Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (isLoggingOut || switchingRole != null)
                                  ? null
                                  : () async {
                                      setSheetState(() => isLoggingOut = true);
                                      try {
                                        // Call TokenService.logout to ensure backend token and FCM tokens are completely revoked
                                        await TokenService().logout();
                                        if (context.mounted) {
                                          appRouter.go('/login');
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => isLoggingOut = false,
                                          );
                                        }
                                      }
                                    },
                              borderRadius: BorderRadius.circular(15),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.red.shade100,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isLoggingOut)
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.redAccent,
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.logout_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      isLoggingOut
                                          ? 'Logging out...'
                                          : AppLocalizations.logout.tr,
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
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
          },
        );
      },
    );
  }

  Widget _buildRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(
          Icons.admin_panel_settings,
          color: _getPrimaryColor(),
          size: 20,
        );
      case 'guru':
        return Icon(Icons.school, color: _getPrimaryColor(), size: 20);
      case 'wali':
        return Icon(Icons.family_restroom, color: _getPrimaryColor(), size: 20);
      case 'staff':
        return Icon(Icons.work, color: _getPrimaryColor(), size: 20);
      default:
        return Icon(Icons.person, color: _getPrimaryColor(), size: 20);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return AppLocalizations.adminRole.tr;
      case 'guru':
      case 'teacher':
        return AppLocalizations.teacherRole.tr;
      case 'wali':
      case 'parent':
      case 'walimurid':
      case 'wali murid':
        return AppLocalizations.parentRole.tr;
      case 'staff':
        return AppLocalizations.staffRole.tr;
      default:
        if (role.isNotEmpty) {
          return role[0].toUpperCase() + role.substring(1);
        }
        return role;
    }
  }

  void _showSchoolSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.school_rounded, color: _getPrimaryColor()),
            SizedBox(width: AppSpacing.sm),
            Text(
              AppLocalizations.selectSchool.tr,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingSchools)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: CircularProgressIndicator(),
                )
              else
                ..._accessibleSchools.map((school) {
                  final isCurrent =
                      school['school_id'] == _userData['school_id'];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isCurrent
                          ? null
                          : () {
                              AppNavigator.pop(
                                dialogContext,
                              ); // Close dialog immediately
                              _switchSchool(school);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _getPrimaryColor().withValues(alpha: 0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? _getPrimaryColor().withValues(alpha: 0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.school,
                              color: isCurrent
                                  ? _getPrimaryColor()
                                  : Colors.grey,
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    school['school_name'],
                                    style: TextStyle(
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: AppSpacing.xs),
                                  Text(
                                    school['address'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Icon(
                                Icons.check_circle,
                                color: _getPrimaryColor(),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(dialogContext),
            child: Text(
              AppLocalizations.cancel.tr,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for colors and gradients
  Color _getPrimaryColor() {
    switch (_effectiveRole) {
      case 'admin':
        return ColorUtils.corporateBlue600; // Blue
      case 'guru':
        return Color(0xFF16A34A); // Teal
      case 'staff':
        return Color(0xFFFF9F1C); // Orange
      case 'wali':
        return Color(0xFF9333EA); // Purple
      default:
        return Color.fromARGB(255, 17, 19, 29);
    }
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.7)],
    );
  }

  String _getRoleTitle() {
    switch (_effectiveRole) {
      case 'admin':
        return AppLocalizations.adminRole.tr;
      case 'guru':
        return AppLocalizations.teacherRole.tr;
      case 'staff':
        return AppLocalizations.staffRole.tr;
      case 'wali':
        return AppLocalizations.parentRole.tr;
      default:
        return 'User';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppLocalizations.goodMorning.tr;
    } else if (hour < 17) {
      return AppLocalizations.goodAfternoon.tr;
    } else {
      return AppLocalizations.goodEvening.tr;
    }
  }

  Future<void> _showStudentSelectionDialog(
    BuildContext context,
    Map<String, dynamic> parent,
    List<dynamic> studentData, {
    String? academicYearId,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Pilih Anak',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: studentData.length,
            itemBuilder: (context, index) {
              final student = studentData[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      student['name'][0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    student['name'],
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    student['kelas_nama'] ?? 'Kelas tidak tersedia',
                  ),
                  onTap: () async {
                    AppNavigator.pop(context);
                    await AppNavigator.push(
                      context,
                      PresenceParentPage(
                        parent: parent,
                        studentId: student['id'],
                        academicYearId: academicYearId,
                      ),
                    );
                    _loadStats();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showNoStudentsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informasi'),
        content: Text(
          'Tidak ada data siswa yang terhubung dengan akun wali murid ini. Silakan hubungi administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
