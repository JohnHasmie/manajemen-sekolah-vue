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
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_router.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/lesson_plan_status_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/material_slider_card.dart';
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
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:shimmer/shimmer.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
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
  bool _tourShown = false;

  // Global Keys for Tour & Animations
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
      duration: const Duration(milliseconds: 800),
    );

    _animationController.forward();

    // Listen to background sync triggers (e.g. from FCM)
    FCMService().syncTrigger.addListener(_handleSyncTrigger);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dashboardProvider.notifier).initialize(widget.role);
      }
    });
  }

  // ==================== REFRESH & SYNC ====================

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_handleSyncTrigger);
    _animationController.dispose();
    super.dispose();
  }

  void _handleSyncTrigger() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null) {
      if (trigger['type'] == 'refresh_announcements') {
        AppLogger.debug(
          'dashboard',
          'Dashboard refreshing data due to background/foreground sync',
        );
        // Refresh full state reactively
        if (mounted) {
          ref.read(dashboardProvider.notifier).initialize(widget.role);
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
    final dashboardState = ref.watch(dashboardProvider);

    return dashboardState.when(
      data: (state) => _buildDashboardContent(context, languageProvider, state),
      error: (e, st) => _buildErrorState(e),
      loading: () => _buildLoadingState(context, languageProvider),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    LanguageProvider languageProvider,
    DashboardState state,
  ) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(context, languageProvider, state),
          SliverToBoxAdapter(child: _buildHeroSection(state)),
          SliverToBoxAdapter(child: _buildQuickActions(state)),
          SliverToBoxAdapter(child: _buildTodaysOverview(state)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
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
          _buildSliverGridMenu(context, state),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Scaffold(
      body: Center(child: Text('Error: $error')),
    );
  }

  Widget _buildLoadingState(BuildContext context, LanguageProvider languageProvider) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          _buildModernAppBar(context, languageProvider, const DashboardState()),
          SliverToBoxAdapter(child: _buildHeroSection(const DashboardState(isStatsLoaded: false))),
          SliverToBoxAdapter(child: _buildQuickActions(const DashboardState(isStatsLoaded: false))),
          SliverToBoxAdapter(child: _buildTodaysOverview(const DashboardState(isStatsLoaded: false))),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
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
    DashboardState state,
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
                    state.userData['nama_sekolah'] ?? AppLocalizations.appTitle.tr,
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
                    if (state.stats['unread_announcements'] != null &&
                        state.stats['unread_announcements'] > 0)
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
                            state.stats['unread_announcements'] > 9
                                ? '9+'
                                : state.stats['unread_announcements'].toString(),
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
                  onPressed: () => _showAccountBottomSheet(context, state),
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
  Widget _buildHeroSection(DashboardState state) {
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
                            final semester = state.currentSemesterLabel ?? '-';
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
                    state.userData['name'] ?? state.userData['nama'] ?? 'User',
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
                    children: state.isStatsLoaded
                        ? _buildFourColumnStats(state)
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

  List<Widget> _buildFourColumnStats(DashboardState state) {
    final lp = languageProvider;
    if (_effectiveRole == 'admin') {
      return [
        _buildHeroStat(
          Icons.people_outline,
          state.stats['total_students']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
        ),
        _buildHeroStat(
          Icons.school_outlined,
          state.stats['total_teachers']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Teachers', 'id': 'Guru'}),
        ),
        _buildHeroStat(
          Icons.class_outlined,
          state.stats['total_classes']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
        ),
        _buildHeroStat(
          Icons.book_outlined,
          state.stats['total_subjects']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Subjects', 'id': 'Mapel'}),
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        _buildHeroStat(
          Icons.people_outline,
          state.stats['total_students']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
        ),
        _buildHeroStat(
          Icons.class_outlined,
          state.stats['total_classes']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
        ),
        _buildHeroStat(
          Icons.schedule_outlined,
          state.stats['classes_today']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}),
        ),
        _buildHeroStat(
          Icons.assignment_outlined,
          state.stats['total_rpps']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Plans', 'id': 'RPP'}),
        ),
      ];
    } else {
      return [
        _buildHeroStat(
          Icons.child_care_outlined,
          state.stats['children_registered']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Children', 'id': 'Anak'}),
        ),
        _buildHeroStat(
          Icons.announcement_outlined,
          state.stats['unread_announcements']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'News', 'id': 'Info'}),
        ),
        _buildHeroStat(
          Icons.grade_outlined,
          state.stats['unread_grades']?.toString() ?? '0',
          lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}),
        ),
        _buildHeroStat(
          Icons.calendar_today_outlined,
          state.stats['unread_presence']?.toString() ?? '0',
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
  Widget _buildQuickActions(DashboardState state) {
    final List<Widget> actions = _getQuickActions(state);

    if (actions.isEmpty && state.isStatsLoaded) {
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
            child: state.isStatsLoaded
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
  Widget _buildTodaysOverview(DashboardState state) {
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
            children: state.isStatsLoaded
                ? _getTodaysOverviewCards(state)
                : List.generate(4, (_) => _buildOverviewCardSkeleton()),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTodaysOverviewCards(DashboardState state) {
    if (_effectiveRole == 'admin') {
      return [
        if (state.financeChartData.isNotEmpty)
          FinanceBarChartCard(
            title: AppLocalizations.finance.tr,
            icon: Icons.account_balance_wallet_outlined,
            accentColor: ColorUtils.success600,
            semestersData: state.financeChartData,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) =>
                    FinancePopupDialog(semestersData: state.financeChartData),
              );
            },
          ),
        if (state.attendanceChartData.isNotEmpty)
          AttendanceBarChartCard(
            title: AppLocalizations.attendance.tr,
            icon: Icons.ssid_chart_outlined,
            accentColor: ColorUtils.warning600,
            classesData: state.attendanceChartData,
            onTap: () {
              // Extract the selected academic year right before showing dialog
              final selectedYearId = ref
                  .read(academicYearRiverpod)
                  .selectedAcademicYear?['id']
                  ?.toString();

              showDialog(
                context: context,
                builder: (context) => AttendancePopupDialog(
                  semesterLabel: state.currentSemesterLabel,
                  initialData: state.attendanceChartData,
                  academicYearId: selectedYearId,
                ),
              );
            },
          ),
        OverviewCard(
          title: AppLocalizations.activeTeachers.tr,
          value: state.stats['total_teachers']?.toString() ?? '0',
          subtitle: AppLocalizations.currentlyTeaching.tr,
          icon: Icons.people_alt_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            // Navigate to teachers
          },
        ),
        OverviewCard(
          title: AppLocalizations.announcements.tr,
          value: state.stats['unread_announcements']?.toString() ?? '0',
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
          schedules: state.todaysSchedule,
          onTap: () {
            AppNavigator.push(context, TeachingScheduleScreen());
          },
        ),
        AttendanceOverviewCard(
          hadir: (state.stats['attendance_summary'] is Map)
              ? (state.stats['attendance_summary']['hadir'] ?? 0)
              : 0,
          izin: (state.stats['attendance_summary'] is Map)
              ? (state.stats['attendance_summary']['izin'] ?? 0)
              : 0,
          sakit: (state.stats['attendance_summary'] is Map)
              ? (state.stats['attendance_summary']['sakit'] ?? 0)
              : 0,
          alpha: (state.stats['attendance_summary'] is Map)
              ? (state.stats['attendance_summary']['alpha'] ?? 0)
              : 0,
          total: (state.stats['attendance_summary'] is Map)
              ? (state.stats['attendance_summary']['total'] ?? 0)
              : 0,
          onTap: () {
            AppNavigator.push(context, PresencePage(teacher: state.userData));
          },
        ),
        MaterialSliderCard(
          materials: state.materialOverview,
          onTap: () {
            AppNavigator.push(context, MateriPage(teacher: state.userData));
          },
        ),
        LessonPlanStatusCard(
          approved: state.stats['rpp_approved'] ?? 0,
          rejected: state.stats['rpp_rejected'] ?? 0,
          pending: state.stats['rpp_pending'] ?? 0,
          onTap: () {
            AppNavigator.push(
              context,
              LessonPlanScreen(
                teacherId: (state.userData['teacher_id'] ?? state.userData['id']).toString(),
                teacherName: state.userData['name'] ?? 'Guru',
              ),
            );
          },
        ),
      ];
    } else {
      return [
        OverviewCard(
          title: AppLocalizations.myChildren.tr,
          value: state.stats['children_registered']?.toString() ?? '0',
          subtitle: AppLocalizations.registeredStudents.tr,
          icon: Icons.family_restroom_outlined,
          accentColor: ColorUtils.corporateBlue600,
          onTap: () {
            // Navigate to children
          },
        ),
        OverviewCard(
          title: AppLocalizations.newGrades.tr,
          value: state.stats['unread_grades']?.toString() ?? '0',
          subtitle: AppLocalizations.recentUpdates.tr,
          icon: Icons.grade_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            // Navigate to grades
          },
        ),
        if (state.attendanceChartData.isNotEmpty)
          AttendanceBarChartCard(
            title: AppLocalizations.childAttendance.tr,
            icon: Icons.ssid_chart_outlined,
            accentColor: ColorUtils.warning600,
            classesData: state.attendanceChartData,
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
                  semesterLabel: state.currentSemesterLabel,
                  initialData: state.attendanceChartData,
                  academicYearId: selectedYearId,
                ),
              );
            },
          )
        else
          OverviewCard(
            title: AppLocalizations.attendance.tr,
            value: state.stats['unread_presence']?.toString() ?? '0',
            subtitle: AppLocalizations.newRecords.tr,
            icon: Icons.calendar_month_outlined,
            accentColor: ColorUtils.warning600,
            onTap: () {
              // Navigate to attendance
            },
          ),
        OverviewCard(
          title: AppLocalizations.announcements.tr,
          value: state.stats['unread_announcements']?.toString() ?? '0',
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

  List<Widget> _getQuickActions(DashboardState state) {
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
          badgeCount: state.unverifiedPaymentCount > 0
              ? state.unverifiedPaymentCount
              : null,
          onTap: () => AppNavigator.push(context, FinanceScreen()),
        ),
        QuickActionButton(
          label: AppLocalizations.announcements.tr,
          icon: Icons.announcement_outlined,
          color: ColorUtils.warning600,
          badgeCount: state.stats['unread_announcements'],
          onTap: () async {
            await AppNavigator.push(context, AdminAnnouncementScreen());
            ref.read(dashboardProvider.notifier).refreshStats();
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
              AppNavigator.push(context, PresencePage(teacher: state.userData)),
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
            final teacherData = {
              'id': (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
              'nama': state.userData['nama'] ?? 'Teacher',
              'email': state.userData['email'] ?? '',
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
          badgeCount: state.stats['unread_announcements'],
          onTap: () async {
            await AppNavigator.push(context, AnnouncementScreen());
            ref.read(dashboardProvider.notifier).refreshStats();
          },
        ),
        QuickActionButton(
          label: AppLocalizations.billing.tr,
          icon: Icons.account_balance_wallet_outlined,
          color: ColorUtils.error600,
          badgeCount: state.stats['unread_billings'],
          onTap: () async {
            await AppNavigator.push(context, ParentBillingScreen());
            ref.read(dashboardProvider.notifier).refreshStats();
          },
        ),
      ];
    }
  }

  // ==================== END NEW UI COMPONENTS ====================

  /// Builds the main navigation menu grid with role-specific items.
  /// Like a Vue component rendering a grid of `<MenuItemCard>` with `v-for`,
  /// where each card navigates to a different admin/teacher/parent feature screen.
  Widget _buildSliverGridMenu(BuildContext context, DashboardState state) {
    // All roles now use professional MenuItemCard design
    return SliverPadding(
      key: _menuGridKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(_buildCategorizedMenu(context, state)),
      ),
    );
  }

  List<Widget> _buildCategorizedMenu(BuildContext context, DashboardState state) {
    final primaryColor = _getPrimaryColor();

    if (_effectiveRole == 'admin') {
      return [
        CategorySection(
          title: '📊 ${AppLocalizations.categoryDataManagement.tr}',
          icon: Icons.folder_shared,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminDataManagementItems(context, state),
        ),
        CategorySection(
          title: '📢 ${AppLocalizations.categoryAcademicCommunication.tr}',
          icon: Icons.school,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminAcademicItems(context, state),
        ),
        CategorySection(
          title: '💰 ${AppLocalizations.categoryFinanceSettings.tr}',
          icon: Icons.settings,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminFinanceItems(context, state),
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        CategorySection(
          title: '📚 ${AppLocalizations.categoryTeaching.tr}',
          icon: Icons.school,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getTeacherTeachingItems(context, state),
        ),
        CategorySection(
          title: '✏️ ${AppLocalizations.categoryAssessmentPlanning.tr}',
          icon: Icons.edit_note,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getTeacherAssessmentItems(context, state),
        ),
      ];
    } else if (_effectiveRole == 'wali') {
      // Parent role: Simple list without categories (only 5 items)
      final items = _getParentMenuItems(context, state);
      return items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
  List<MenuItem> _getAdminDataManagementItems(BuildContext context, DashboardState state) {
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
          final adminData = {
            'id': (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? 'Admin',
            'email': state.userData['email'] ?? '',
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
  List<MenuItem> _getAdminAcademicItems(BuildContext context, DashboardState state) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AdminAnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
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
  List<MenuItem> _getAdminFinanceItems(BuildContext context, DashboardState state) {
    return [
      MenuItem(
        title: AppLocalizations.finance.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: state.unverifiedPaymentCount > 0
            ? state.unverifiedPaymentCount
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
  List<MenuItem> _getTeacherTeachingItems(BuildContext context, DashboardState state) {
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
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
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
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'name': state.userData['name'] ?? state.userData['nama'] ?? 'Teacher',
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
  List<MenuItem> _getTeacherAssessmentItems(BuildContext context, DashboardState state) {
    return [
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
          final Map<String, String> teacherData = {
            'id':
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
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
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
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
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
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
                (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ?? '',
            'nama': state.userData['nama']?.toString() ?? 'Teacher',
            'email': state.userData['email']?.toString() ?? '',
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
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      if (state.homeroomClasses.isNotEmpty)
        MenuItem(
          title: AppLocalizations.learningRecommendation.tr,
          icon: Icons.auto_awesome_outlined,
          onTap: () async {
            final Map<String, String> teacherData = {
              'id':
                  (state.userData['teacher_id'] ?? state.userData['id'])?.toString() ??
                  '',
              'nama': state.userData['nama'] ?? state.userData['name'] ?? 'Teacher',
              'email': state.userData['email']?.toString() ?? '',
              'role': _effectiveRole,
            };
            if (!context.mounted) return;

            AppNavigator.push(
              context,
              LearningRecommendationClassScreen(
                teacher: teacherData,
                classes: state.homeroomClasses,
              ),
            );
          },
        ),
    ];
  }

  // Parent - Menu Items (Simple list, no categories)
  List<MenuItem> _getParentMenuItems(BuildContext context, DashboardState state) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: state.stats['unread_announcements'],
        onTap: () async {
          await AppNavigator.push(context, AnnouncementScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        badgeCount: state.stats['unread_class_activities'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();
          await AppNavigator.push(
            context,
            ParentClassActivityScreen(academicYearId: academicYearId),
          );
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.grades.tr,
        icon: Icons.grade_outlined,
        badgeCount: state.stats['unread_grades'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();
          await AppNavigator.push(
            context,
            ParentGradeScreen(academicYearId: academicYearId),
          );
          ref.read(dashboardProvider.notifier).refreshStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.presence.tr,
        icon: Icons.check_circle_outline,
        badgeCount: state.stats['unread_presence'],
        onTap: () async {
          final academicYearId = ref
              .read(academicYearRiverpod)
              .selectedAcademicYear?['id']
              ?.toString();

          // Load students by parent email instead of user_id
          final studentsData = await _getStudentDataForParent(
            state.userData['email'] ?? '',
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
                parent: state.userData,
                studentId: studentsData[0]['id'],
                academicYearId: academicYearId,
              ),
            );
            ref.read(dashboardProvider.notifier).refreshStats();
          } else {
            await _showStudentSelectionDialog(
              context,
              state.userData,
              studentsData,
              academicYearId: academicYearId,
            );
            ref.read(dashboardProvider.notifier).refreshStats();
          }
        },
      ),
      MenuItem(
        title: AppLocalizations.billing.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: state.stats['unread_billings'],
        onTap: () async {
          await AppNavigator.push(context, ParentBillingScreen());
          ref.read(dashboardProvider.notifier).refreshStats();
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
  void _showAccountBottomSheet(BuildContext context, DashboardState state) {
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
                                      state.userData['nama'] ?? _effectiveRole.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs),
                                    Text(
                                      state.userData['email'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      state.userData['nama_sekolah'] ?? '',
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

                          if (state.availableRoles.length > 1) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              AppLocalizations.switchRole.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...state.availableRoles.map((role) {
                              final isCurrent = role == state.userData['role'];
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
                                            await ref.read(dashboardProvider.notifier).switchRole(role);
                                            if (context.mounted) {
                                              AppNavigator.pop(context);
                                              final effectiveRolePath = (role == 'teacher') ? 'guru' : (role == 'parent') ? 'wali' : role;
                                              context.go('/$effectiveRolePath');
                                            }
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
                          if (state.accessibleSchools.length > 1) ...[
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  AppNavigator.pop(context);
                                  _showSchoolSelectionDialog(context, state);
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

  void _showSchoolSelectionDialog(BuildContext outerContext, DashboardState state) {
    final dashboardContext = this.context; // Stable widget context
    showDialog(
      context: dashboardContext,
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
                ...state.accessibleSchools.map((school) {
                  final isCurrent =
                      school['school_id'] == state.userData['school_id'];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isCurrent
                          ? null
                          : () async {
                              AppNavigator.pop(dialogContext);

                              try {
                                final schoolId = school['school_id'].toString();
                                final result = await ref.read(dashboardProvider.notifier).switchSchool(schoolId);

                                if (!mounted) return;

                                if (result['needsRoleSelection'] == true) {
                                  final roleList = List<String>.from(result['role_list'] ?? []);
                                  if (roleList.isEmpty) return;
                                  _showRolePickerDialog(dashboardContext, schoolId, roleList);
                                  return;
                                }

                                final newRole = result['user']?['role']?.toString() ?? widget.role;
                                await LocalCacheService.clearAll();
                                // Reset so the next dashboard page triggers a fresh initialize
                                ref.read(dashboardProvider.notifier).resetForSchoolSwitch();
                                if (mounted) {
                                  if (newRole == widget.role) {
                                    // Same role — force rebuild by invalidating the provider
                                    ref.invalidate(dashboardProvider);
                                  } else {
                                    dashboardContext.go('/$newRole');
                                  }
                                }
                              } catch (e) {
                                AppLogger.error('dashboard', 'Switch school error: $e');
                                if (mounted) {
                                  SnackBarUtils.showError(dashboardContext, e.toString().replaceAll('Exception: ', ''));
                                }
                              }
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

  void _showRolePickerDialog(BuildContext context, String schoolId, List<String> roleList) {
    final lp = ref.read(languageRiverpod);

    IconData _roleIcon(String role) {
      switch (role) {
        case 'admin': return Icons.admin_panel_settings;
        case 'guru': return Icons.school;
        case 'wali': return Icons.family_restroom;
        case 'staff': return Icons.work;
        default: return Icons.person;
      }
    }

    String _roleName(String role) {
      switch (role) {
        case 'admin': return 'Administrator';
        case 'guru': return lp.getTranslatedText({'en': 'Teacher', 'id': 'Guru'});
        case 'wali': return lp.getTranslatedText({'en': 'Parent', 'id': 'Wali Murid'});
        case 'staff': return 'Staff';
        default: return role;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: _getPrimaryColor()),
            SizedBox(width: AppSpacing.sm),
            Text(
              lp.getTranslatedText({'en': 'Select Role', 'id': 'Pilih Role'}),
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roleList.map((role) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    AppNavigator.pop(dialogContext);
                    try {
                      final result = await ref.read(dashboardProvider.notifier).switchSchool(schoolId, role: role);
                      if (!context.mounted) return;
                      final newRole = result['user']?['role']?.toString() ?? role;
                      await LocalCacheService.clearAll();
                      ref.read(dashboardProvider.notifier).resetForSchoolSwitch();
                      if (mounted) {
                        if (newRole == widget.role) {
                          ref.invalidate(dashboardProvider);
                        } else {
                          context.go('/$newRole');
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        SnackBarUtils.showError(context, e.toString().replaceAll('Exception: ', ''));
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(_roleIcon(role), color: _getPrimaryColor()),
                        SizedBox(width: AppSpacing.md),
                        Text(_roleName(role), style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(dialogContext),
            child: Text(AppLocalizations.cancel.tr, style: TextStyle(color: Colors.grey.shade600)),
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
                    ref.read(dashboardProvider.notifier).refreshStats();
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

  Future<List<dynamic>> _getStudentDataForParent(String guardianEmail) async {
    try {
      if (guardianEmail.isEmpty) return [];
      return await ApiStudentService().getStudent(guardianEmail: guardianEmail);
    } catch (e) {
      AppLogger.error('dashboard', 'Error loading students: $e');
      return [];
    }
  }
}

