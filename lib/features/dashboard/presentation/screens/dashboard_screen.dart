// Main dashboard screen - the home page after login for all roles
// (admin/guru/wali).
//
// Like `pages/dashboard.vue` or `pages/admin/index.vue` in a Vue/Nuxt
// project. This is the largest screen in the app - it renders role-specific
// content:
// - Admin: school stats, menu grid for management screens, finance overview
// - Teacher (guru): today's schedule, class activities, lesson plans
// - Parent (wali): child's grades, attendance, billing
//
// In Laravel terms, this consumes data from DashboardController which
// aggregates stats from multiple models (Students, Classes, Teachers,
// Schedules, etc.).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/shell/role_shell.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/shell/tabs/admin/admin_academic_hub.dart';
import 'package:manajemensekolah/core/shell/tabs/admin/admin_finance_tab.dart';
import 'package:manajemensekolah/core/shell/tabs/admin/admin_people_hub.dart';
import 'package:manajemensekolah/core/shell/tabs/admin/admin_system_tab.dart';
import 'package:manajemensekolah/core/shell/tabs/parent/parent_academic_hub.dart';
import 'package:manajemensekolah/core/shell/tabs/parent/parent_attendance_tab.dart';
import 'package:manajemensekolah/core/shell/tabs/parent/parent_finance_tab.dart';
import 'package:manajemensekolah/core/shell/tabs/teacher/teacher_grades_hub.dart';
import 'package:manajemensekolah/core/shell/tabs/teacher/teacher_other_hub.dart';
import 'package:manajemensekolah/core/shell/tabs/teacher/teacher_teaching_hub.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/mixins/helpers_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/mixins/content_builders_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/mixins/cards_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/mixins/dialog_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/admin_dashboard_body.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_popup_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_popup_dialog.dart';
import 'package:manajemensekolah/features/notifications/presentation/screens/notification_list_screen.dart';

export 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
export 'package:manajemensekolah/features/notifications/presentation/screens/notification_list_screen.dart'
    show NotificationListScreen;
export 'package:manajemensekolah/features/dashboard/presentation/widgets/finance_popup_dialog.dart'
    show FinancePopupDialog;
export 'package:manajemensekolah/features/dashboard/presentation/widgets/attendance_popup_dialog.dart'
    show AttendancePopupDialog;

/// The main dashboard widget. Like a Vue page component
/// (`pages/dashboard.vue`).
///
/// Takes a [role] prop ('admin', 'guru'/'teacher', 'wali'/'parent')
/// which determines what menu items, stats, and content are shown.
/// This is similar to a Vue page that renders different sections with
/// `v-if="role === 'admin'"`.
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
/// Uses [TickerProviderStateMixin] to support animations (like Vue
/// transitions).
///
/// Key state variables:
/// - [_userData] - current user profile data (from SharedPreferences/API)
/// - [_stats] - aggregated dashboard statistics (student count, class count)
/// - [_todaysScheduleList] - today's teaching schedule for the slider
/// - [_accessibleSchools] - schools the user can switch between
/// - [_isStatsLoaded] - controls skeleton loading vs real content display
///
/// Key patterns:
/// - Cache-first loading: loads from LocalCacheService first, then fetches
///   fresh data
/// - Provider pattern: uses Provider (like Vuex/Pinia) for shared state
///   (AcademicYearProvider, TeacherProvider, LanguageProvider)
/// - FCM sync: listens for push notification triggers to refresh data in
///   real-time
class _DashboardState extends ConsumerState<Dashboard>
    with
        TickerProviderStateMixin,
        HelpersMixin,
        ContentBuildersMixin,
        CardsMixin,
        DialogMixin {
  late AnimationController _animationController;

  // Global Keys for Tour & Animations
  final GlobalKey _profileHeaderKey = GlobalKey();
  final GlobalKey _heroSectionKey = GlobalKey();
  final GlobalKey _quickActionsKey = GlobalKey();
  final GlobalKey _statsSectionKey = GlobalKey();
  final GlobalKey _scheduleSectionKey = GlobalKey();

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
    FCMService().syncTrigger.addListener(handleSyncTrigger);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(dashboardProvider.notifier).initialize(widget.role);
      }
    });
  }

  // ==================== REFRESH & SYNC ====================

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(handleSyncTrigger);
    _animationController.dispose();
    super.dispose();
  }

  /// Main build method. The dashboard is wrapped in a [RoleShell] which
  /// provides the bottom-nav tab strip. The Beranda (home) tab renders
  /// the dashboard content; the other tabs dispatch to per-role tab roots
  /// under `lib/core/shell/tabs/<role>/`.
  @override
  Widget build(BuildContext context) {
    return RoleShell(
      role: effectiveRole,
      tabBuilder: _buildShellTabRoot,
    );
  }

  /// Tab-root dispatcher used by [RoleShell.tabBuilder].
  ///
  /// The Home tab renders the dashboard content tree (preserves the
  /// existing FCM listener, dialog wiring, and state). Other tabs
  /// dispatch to per-role tab files in `lib/core/shell/tabs/<role>/`.
  /// Tabs not wired for the role fall through to a "segera hadir"
  /// placeholder as a safety net.
  Widget _buildShellTabRoot(BuildContext context, ShellTab tab) {
    if (tab == ShellTab.home) {
      // Re-enter the legacy dashboard render path.
      final languageProvider = ref.watch(languageRiverpod);
      final dashboardState = ref.watch(dashboardProvider);
      return dashboardState.when(
        data: (state) => _buildLoadedState(context, languageProvider, state),
        error: (e, st) => buildErrorState(e),
        loading: () => _buildLoadingStateWrapper(context, languageProvider),
      );
    }

    // Sub-PR 2 — admin tab roots.
    if (effectiveRole == 'admin') {
      switch (tab) {
        case ShellTab.people:
          return const AdminPeopleHub();
        case ShellTab.academic:
          return const AdminAcademicHub();
        case ShellTab.finance:
          return const AdminFinanceTab();
        case ShellTab.system:
          return const AdminSystemTab();
        default:
          break;
      }
    }

    // Sub-PR 3 — teacher tab roots.
    if (effectiveRole == 'guru') {
      switch (tab) {
        case ShellTab.teaching:
          return const TeacherTeachingHub();
        case ShellTab.grades:
          return const TeacherGradesHub();
        case ShellTab.other:
          return const TeacherOtherHub();
        default:
          break;
      }
    }

    // Sub-PR 4 — parent tab roots. After this lands, the placeholder
    // fallback below is essentially dead code — kept as a safety net for
    // role/tab combinations the dispatcher misses.
    if (effectiveRole == 'wali') {
      switch (tab) {
        case ShellTab.academic:
          return const ParentAcademicHub();
        case ShellTab.attendance:
          return const ParentAttendanceTab();
        case ShellTab.finance:
          return const ParentFinanceTab();
        default:
          break;
      }
    }

    return _ShellTabPlaceholder(tab: tab);
  }

  Widget _buildLoadedState(
    BuildContext context,
    LanguageProvider languageProvider,
    DashboardState state,
  ) {
    final primaryColor = getPrimaryColor();

    // Admin fork (Phase 3 redesign). Guru and wali still go through the
    // shared content builder so their dashboards remain unchanged.
    if (effectiveRole == 'admin') {
      return AdminDashboardBody(
        primaryColor: primaryColor,
        state: state,
        profileHeaderKey: _profileHeaderKey,
        heroSectionKey: _heroSectionKey,
        quickActionsKey: _quickActionsKey,
        statsSectionKey: _statsSectionKey,
        onLanguageTap: () =>
            showLanguageDialog(context, languageProvider, primaryColor),
        onNotificationTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationListScreen(role: widget.role),
            ),
          );
          ref.read(dashboardProvider.notifier).refreshStats();
        },
        onAccountTap: () =>
            showAccountBottomSheet(context, state, primaryColor, effectiveRole),
        onSchoolSwitchTap: () => showAcademicYearDialog(context),
      );
    }

    return buildDashboardContent(
      context,
      languageProvider,
      state,
      _profileHeaderKey,
      _heroSectionKey,
      _quickActionsKey,
      _statsSectionKey,
      primaryColor,
      effectiveRole,
      () => showLanguageDialog(context, languageProvider, primaryColor),
      () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationListScreen(role: widget.role),
          ),
        );
        ref.read(dashboardProvider.notifier).refreshStats();
      },
      (state) =>
          showAccountBottomSheet(context, state, primaryColor, effectiveRole),
      () => showAcademicYearDialog(context),
      (state) => getTodaysOverviewCards(
        state,
        effectiveRole,
        _scheduleSectionKey,
        (ctx, data) {
          showDialog(
            context: ctx,
            builder: (context) => FinancePopupDialog(
              semestersData: List<Map<String, dynamic>>.from(data),
            ),
          );
        },
        (ctx, yearId, data) {
          showDialog(
            context: ctx,
            builder: (context) => AttendancePopupDialog(
              semesterLabel: state.currentSemesterLabel,
              initialData: List<Map<String, dynamic>>.from(data),
              academicYearId: yearId,
            ),
          );
        },
      ),
      (state) => getQuickActions(state, effectiveRole, primaryColor),
      onRefresh: () => ref.read(dashboardProvider.notifier).pullToRefresh(),
    );
  }

  Widget _buildLoadingStateWrapper(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    final primaryColor = getPrimaryColor();
    return buildLoadingState(
      context,
      languageProvider,
      _profileHeaderKey,
      _heroSectionKey,
      _quickActionsKey,
      _statsSectionKey,
      primaryColor,
      effectiveRole,
      () => showLanguageDialog(context, languageProvider, primaryColor),
      () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NotificationListScreen(role: widget.role),
          ),
        );
      },
      (state) =>
          showAccountBottomSheet(context, state, primaryColor, effectiveRole),
      () => showAcademicYearDialog(context),
    );
  }
}

/// Safety-net "Coming soon" surface for any role/tab combo that the
/// dispatcher misses. With the per-role tab roots fully wired this is
/// effectively unreachable, but it keeps the shell from crashing if a
/// new tab lands without its root.
class _ShellTabPlaceholder extends StatelessWidget {
  final ShellTab tab;
  const _ShellTabPlaceholder({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tab.label)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              '${tab.label} — segera hadir',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tab ini akan diisi pada Sub-PR berikutnya.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
