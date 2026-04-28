import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_hero_section.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_quick_actions_section.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_todays_overview.dart';

/// Provides content building methods for Dashboard UI.
/// Handles scaffold construction, scrollable content layout, and state
/// rendering for loaded, loading, and error states.
mixin ContentBuildersMixin on ConsumerState<Dashboard> {
  /// Builds the main dashboard content when data is loaded.
  /// Returns a Scaffold with CustomScrollView containing app bar,
  /// hero section, quick actions, and overview cards. The legacy
  /// categorized menu grid was retired in P1 closeout — tab roots
  /// (Mengajar / Nilai / Lainnya for guru, Akademik / Kehadiran /
  /// Keuangan for wali) are the canonical destinations now.
  Widget buildDashboardContent(
    BuildContext context,
    LanguageProvider languageProvider,
    DashboardState state,
    GlobalKey profileHeaderKey,
    GlobalKey heroSectionKey,
    GlobalKey quickActionsKey,
    GlobalKey statsSectionKey,
    Color primaryColor,
    String effectiveRole,
    void Function() onLanguageTap,
    void Function() onNotificationTap,
    void Function(DashboardState) onAccountTap,
    void Function() onAcademicYearTap,
    List<Widget> Function(DashboardState) getTodaysOverviewCards,
    List<Widget> Function(DashboardState) getQuickActions, {
    Future<void> Function()? onRefresh,
  }) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: onRefresh ?? () async {},
        role: effectiveRole,
        edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            DashboardAppBar(
              schoolName: state.userData['nama_sekolah'],
              primaryColor: primaryColor,
              unreadNotifications: state.stats['unread_notifications'],
              unreadAnnouncements: state.stats['unread_announcements'],
              profileHeaderKey: profileHeaderKey,
              onLanguageTap: onLanguageTap,
              onNotificationTap: onNotificationTap,
              onAccountTap: () => onAccountTap(state),
            ),
            SliverToBoxAdapter(
              child: DashboardHeroSection(
                primaryColor: primaryColor,
                effectiveRole: effectiveRole,
                state: state,
                heroSectionKey: heroSectionKey,
                onAcademicYearTap: onAcademicYearTap,
              ),
            ),
            SliverToBoxAdapter(
              child: DashboardQuickActionsSection(
                actions: getQuickActions(state),
                isLoaded: state.isStatsLoaded,
                quickActionsKey: quickActionsKey,
              ),
            ),
            SliverToBoxAdapter(
              child: DashboardTodaysOverview(
                cards: getTodaysOverviewCards(state),
                isLoaded: state.isStatsLoaded,
                statsSectionKey: statsSectionKey,
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  /// Builds error state UI when dashboard data loading fails.
  Widget buildErrorState(Object error) {
    return Scaffold(body: Center(child: Text('Error: $error')));
  }

  /// Builds loading skeleton state UI while dashboard data is loading.
  /// Uses empty DashboardState with isStatsLoaded=false to trigger
  /// skeleton placeholders in child widgets.
  Widget buildLoadingState(
    BuildContext context,
    LanguageProvider languageProvider,
    GlobalKey profileHeaderKey,
    GlobalKey heroSectionKey,
    GlobalKey quickActionsKey,
    GlobalKey statsSectionKey,
    Color primaryColor,
    String effectiveRole,
    void Function() onLanguageTap,
    void Function() onNotificationTap,
    void Function(DashboardState) onAccountTap,
    void Function() onAcademicYearTap,
  ) {
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
            profileHeaderKey: profileHeaderKey,
            onLanguageTap: onLanguageTap,
            onNotificationTap: () => onNotificationTap(),
            onAccountTap: () => onAccountTap(emptyState),
          ),
          SliverToBoxAdapter(
            child: DashboardHeroSection(
              primaryColor: primaryColor,
              effectiveRole: effectiveRole,
              state: emptyState,
              heroSectionKey: heroSectionKey,
              onAcademicYearTap: onAcademicYearTap,
            ),
          ),
          SliverToBoxAdapter(
            child: DashboardQuickActionsSection(
              actions: const [],
              isLoaded: false,
              quickActionsKey: quickActionsKey,
            ),
          ),
          SliverToBoxAdapter(
            child: DashboardTodaysOverview(
              cards: const [],
              isLoaded: false,
              statsSectionKey: statsSectionKey,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }

}
