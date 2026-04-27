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

/// Feature flag for the P1 bottom-nav shell rollout.
///
/// When `false` (default), `Dashboard.build` returns the legacy
/// per-role dashboard body unchanged — zero behavior delta in
/// production until we flip this on.
///
/// When `true`, `Dashboard` is wrapped in a `RoleShell` whose tab roots
/// are stubs (Sub-PR 1) → real screens (Sub-PR 2/3/4) → cleaned-up
/// landing surface (Sub-PR 5/6).
///
/// Wire to `--dart-define=ENABLE_SHELL=true` once we want internal
/// builds to flip it without source edits.
const bool kEnableShell = bool.fromEnvironment(
  'ENABLE_SHELL',
  defaultValue: false,
);

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

  /// Main build method - like Vue's `<template>` section.
  /// Renders a CustomScrollView with role-specific sliver sections:
  /// app bar, hero stats, quick actions, overview cards, and menu grid.
  /// Uses `ref.watch(languageRiverpod)` to react to language changes
  /// (like a Vue `computed` property depending on an i18n store).
  ///
  /// When `kEnableShell` is true (P1 rollout), the dashboard body is
  /// wrapped in a [RoleShell] that provides the bottom-nav tab strip.
  /// Tab roots are stub builders for now (Sub-PR 1); Sub-PR 2/3/4 wire
  /// real per-role tab content. The legacy path stays intact under the
  /// `else` branch so production users see no change until the flag flips.
  @override
  Widget build(BuildContext context) {
    if (kEnableShell) {
      return RoleShell(
        role: effectiveRole,
        tabBuilder: _buildShellTabRoot,
      );
    }

    final languageProvider = ref.watch(languageRiverpod);
    final dashboardState = ref.watch(dashboardProvider);

    return dashboardState.when(
      data: (state) => _buildLoadedState(context, languageProvider, state),
      error: (e, st) => buildErrorState(e),
      loading: () => _buildLoadingStateWrapper(context, languageProvider),
    );
  }

  /// Tab-root stub builder for P1 Sub-PR 1.
  ///
  /// Beranda intentionally renders the legacy dashboard tree verbatim so
  /// the existing screen state, FCM listener, and dialog wiring keep
  /// working — Sub-PR 2 will refactor admin's Beranda specifically.
  /// Other tabs render a placeholder until Sub-PR 2/3/4 wire them.
  Widget _buildShellTabRoot(BuildContext context, ShellTab tab) {
    if (tab == ShellTab.beranda) {
      // Re-enter the legacy dashboard render path.
      final languageProvider = ref.watch(languageRiverpod);
      final dashboardState = ref.watch(dashboardProvider);
      return dashboardState.when(
        data: (state) => _buildLoadedState(context, languageProvider, state),
        error: (e, st) => buildErrorState(e),
        loading: () => _buildLoadingStateWrapper(context, languageProvider),
      );
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
        menuGridKey: _menuGridKey,
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
        onShowNoStudentsDialog: () => showNoStudentsDialog(context),
        onShowStudentSelectionDialog: (parent, students, {academicYearId}) =>
            showStudentSelectionDialog(
              context,
              parent,
              students,
              academicYearId: academicYearId,
            ),
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
      _menuGridKey,
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
      (ctx, state) => buildSliverGridMenu(
        ctx,
        state,
        _menuGridKey,
        effectiveRole,
        primaryColor,
        () => showNoStudentsDialog(ctx),
        (parent, students, {academicYearId}) => showStudentSelectionDialog(
          ctx,
          parent,
          students,
          academicYearId: academicYearId,
        ),
      ),
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

/// Temporary "Coming soon" surface for tabs whose real screens land in
/// later P1 sub-PRs (Sub-PR 2: admin tabs, 3: teacher, 4: parent).
/// Only visible when `kEnableShell` is true — production builds with the
/// flag off never render this.
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
