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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_bar_chart_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_popup_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_account_sheet.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_categorized_menu.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_hero_section.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_quick_actions_section.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_school_selection_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_todays_overview.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_bar_chart_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_popup_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/language_option_tile.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/lesson_plan_status_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/material_slider_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/overview_card.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/schedule_slider_card.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/notifications/presentation/screens/notification_list_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';

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
    final primaryColor = _getPrimaryColor();
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          DashboardAppBar(
            schoolName: state.userData['nama_sekolah'],
            primaryColor: primaryColor,
            unreadNotifications: state.stats['unread_notifications'],
            unreadAnnouncements: state.stats['unread_announcements'],
            profileHeaderKey: _profileHeaderKey,
            onLanguageTap: () => _showLanguageDialog(context, languageProvider),
            onNotificationTap: () async {
              await AppNavigator.push(
                context,
                NotificationListScreen(role: widget.role),
              );
              ref.read(dashboardProvider.notifier).refreshStats();
            },
            onAccountTap: () => _showAccountBottomSheet(context, state),
          ),
          SliverToBoxAdapter(
            child: DashboardHeroSection(
              primaryColor: primaryColor,
              effectiveRole: _effectiveRole,
              state: state,
              heroSectionKey: _heroSectionKey,
              onAcademicYearTap: () => _showAcademicYearDialog(context),
            ),
          ),
          SliverToBoxAdapter(
            child: DashboardQuickActionsSection(
              actions: _getQuickActions(state),
              isLoaded: state.isStatsLoaded,
              quickActionsKey: _quickActionsKey,
            ),
          ),
          SliverToBoxAdapter(
            child: DashboardTodaysOverview(
              cards: _getTodaysOverviewCards(state),
              isLoaded: state.isStatsLoaded,
              statsSectionKey: _statsSectionKey,
            ),
          ),
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
    final primaryColor = _getPrimaryColor();
    const emptyState = DashboardState(isStatsLoaded: false);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          DashboardAppBar(
            schoolName: null,
            primaryColor: primaryColor,
            unreadNotifications: null,
            unreadAnnouncements: null,
            profileHeaderKey: _profileHeaderKey,
            onLanguageTap: () => _showLanguageDialog(context, languageProvider),
            onNotificationTap: () => AppNavigator.push(
              context,
              NotificationListScreen(role: widget.role),
            ),
            onAccountTap: () => _showAccountBottomSheet(context, emptyState),
          ),
          SliverToBoxAdapter(
            child: DashboardHeroSection(
              primaryColor: primaryColor,
              effectiveRole: _effectiveRole,
              state: emptyState,
              heroSectionKey: _heroSectionKey,
              onAcademicYearTap: () => _showAcademicYearDialog(context),
            ),
          ),
          SliverToBoxAdapter(
            child: DashboardQuickActionsSection(
              actions: const [],
              isLoaded: false,
              quickActionsKey: _quickActionsKey,
            ),
          ),
          SliverToBoxAdapter(
            child: DashboardTodaysOverview(
              cards: const [],
              isLoaded: false,
              statsSectionKey: _statsSectionKey,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

  // ==================== DIALOGS & HELPERS ====================

  void _showAcademicYearDialog(BuildContext context) {
    final provider = ref.read(academicYearRiverpod);
    final years = provider.academicYears;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(AppLocalizations.selectAcademicYear.tr),
        children: years.map((year) {
          final isSelected = provider.selectedAcademicYear?['id'] == year['id'];
          return SimpleDialogOption(
            onPressed: () {
              provider.setSelectedYear(year['id'].toString());
              ref.read(dashboardProvider.notifier).reloadForYearChange();
              AppNavigator.pop(context);
            },
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
            AppNavigator.push(context, AttendancePage(teacher: state.userData));
          },
        ),
        MaterialSliderCard(
          materials: state.materialOverview,
          onTap: () {
            AppNavigator.push(context, TeacherMaterialScreen(teacher: state.userData));
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
              AppNavigator.push(context, AttendancePage(teacher: state.userData)),
        ),
        QuickActionButton(
          label: AppLocalizations.activity.tr,
          icon: Icons.local_activity_outlined,
          color: ColorUtils.info600,
          onTap: () => AppNavigator.push(context, ClassActivityScreen()),
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
  /// Delegates to [DashboardCategorizedMenu] which owns all menu-item logic.
  Widget _buildSliverGridMenu(BuildContext context, DashboardState state) {
    return SliverPadding(
      key: _menuGridKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: DashboardCategorizedMenu(
          effectiveRole: _effectiveRole,
          state: state,
          primaryColor: _getPrimaryColor(),
          onShowNoStudentsDialog: () => _showNoStudentsDialog(context),
          onShowStudentSelectionDialog: (parent, studentsData, {academicYearId}) =>
              _showStudentSelectionDialog(
                context,
                parent,
                studentsData,
                academicYearId: academicYearId,
              ),
        ),
      ),
    );
  }

  // DELETED: _buildCategorizedMenu, _getAdminDataManagementItems,
  // _getAdminAcademicItems, _getAdminFinanceItems, _getTeacherTeachingItems,
  // _getTeacherAssessmentItems, _getParentMenuItems — all moved to
  // DashboardCategorizedMenu in widgets/dashboard_categorized_menu.dart


  void _showLanguageDialog(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20))),
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
            LanguageOptionTile(
              languageProvider: languageProvider,
              language: 'Indonesia',
              code: 'id',
              color: Colors.green,
            ),
            const SizedBox(height: AppSpacing.md),
            LanguageOptionTile(
              languageProvider: languageProvider,
              language: 'English',
              code: 'en',
              color: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the account bottom sheet. Widget tree lives in [DashboardAccountSheet].
  void _showAccountBottomSheet(BuildContext context, DashboardState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DashboardAccountSheet(
        state: state,
        primaryColor: _getPrimaryColor(),
        effectiveRole: _effectiveRole,
        onShowSchoolSelection: () => _showSchoolSelectionDialog(context, state),
      ),
    );
  }

  /// Shows the school-selection dialog. Logic lives in [showDashboardSchoolSelectionDialog].
  void _showSchoolSelectionDialog(BuildContext ctx, DashboardState state) {
    showDashboardSchoolSelectionDialog(
      context: ctx,
      ref: ref,
      state: state,
      currentRole: widget.role,
      primaryColor: _getPrimaryColor(),
      onNeedsRoleSelection: _showRolePickerDialog,
    );
  }

  /// Shows the role-picker dialog after a school switch that exposes multiple roles.
  /// Delegated to [showDashboardSchoolSelectionDialog]'s onNeedsRoleSelection callback.
  void _showRolePickerDialog(
    BuildContext ctx,
    String schoolId,
    List<String> roleList,
  ) {
    showDashboardRolePickerDialog(
      context: ctx,
      ref: ref,
      schoolId: schoolId,
      roleList: roleList,
      currentRole: widget.role,
      primaryColor: _getPrimaryColor(),
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
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20))),
        title: Text(
          AppLocalizations.selectChild.tr,
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
                    student['kelas_nama'] ?? AppLocalizations.classNotAvailable.tr,
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
        title: Text(AppLocalizations.information.tr),
        content: Text(AppLocalizations.noStudentLinked.tr),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context),
            child: Text(AppLocalizations.ok.tr),
          ),
        ],
      ),
    );
  }

}

