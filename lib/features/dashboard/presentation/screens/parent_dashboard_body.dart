// Parent dashboard body (wali) — mirrors admin Phase 3 redesign with brand-azure gradient.
//
// Shape of the screen (top-to-bottom)
// -----------------------------------
//   1. DashboardAppBar         — school name, lang, bell, profile
//   2. Brand-azure gradient hero — SchoolPill.expanded + realtime indicator
//   3. KPI carousel (per-anak cycle, 4 cards) — Kehadiran, Tagihan, Rata-rata, Pengumuman
//      Driven by `BrandKpiCarousel` + `activeSliceProvider('parent_dashboard')`.
//      Backend payload: `state.stats['slices']` is a list of `_ParentSlice`
//      bundles (see bottom of file) produced by
//      `DashboardController::buildParentChildSlices`.
//   4. Perlu perhatian — 4 inbox rows (Tagihan jatuh tempo, Nilai baru anak, etc.)
//   5. Aksi cepat      — 4 quick action tiles (Pengumuman, Tagihan, Nilai, Kehadiran)
//   6. Modul lain strip — horizontal with overflow sheet
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/shell/shell_nav.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/academic_year_chip.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_carousel.dart';
import 'package:manajemensekolah/core/widgets/hero_stats_card.dart';
import 'package:manajemensekolah/core/widgets/pending_inbox_card.dart';
import 'package:manajemensekolah/core/widgets/quick_action_grid.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/modul_lain_strip.dart';

import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_billing_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/parent_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/dashboard/presentation/screens/parent_inbox_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/academic_year_picker_sheet.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/dashboard_app_bar.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/parent_dashboard_hero_widgets.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/parent_recommendation_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';

// Parent role uses the Kamil Edu brand Azzure Blue. The hero gradient
// goes from brand azure → a slightly darker shade so the gradient still
// reads as "depth" while staying inside the brand swatch. Tokens live in
// `ColorUtils.brandAzure` / `ColorUtils.brandAzureDeep` so deep-tab parent
// screens share the same gradient endpoints via `ColorUtils.brandGradient('wali')`.
final Color _parentBrandAzure = ColorUtils.brandAzure;
final Color _parentBrandAzureDeep = ColorUtils.brandAzureDeep;
const Duration _pollInterval = Duration(seconds: 60);

/// Parent dashboard body.
class ParentDashboardBody extends ConsumerStatefulWidget {
  final Color primaryColor;
  final DashboardState state;
  final GlobalKey profileHeaderKey;
  final GlobalKey heroSectionKey;
  final GlobalKey quickActionsKey;
  final GlobalKey statsSectionKey;

  final VoidCallback onLanguageTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onAccountTap;
  final VoidCallback onSchoolSwitchTap;

  const ParentDashboardBody({
    super.key,
    required this.primaryColor,
    required this.state,
    required this.profileHeaderKey,
    required this.heroSectionKey,
    required this.quickActionsKey,
    required this.statsSectionKey,
    required this.onLanguageTap,
    required this.onNotificationTap,
    required this.onAccountTap,
    required this.onSchoolSwitchTap,
  });

  @override
  ConsumerState<ParentDashboardBody> createState() =>
      _ParentDashboardBodyState();
}

class _ParentDashboardBodyState extends ConsumerState<ParentDashboardBody> {
  Timer? _pollTimer;
  DateTime _lastSync = DateTime.now();
  bool _isFresh = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStats());
  }

  Future<void> _pollStats() async {
    if (!mounted) return;
    try {
      await ref.read(dashboardProvider.notifier).refreshStats();
      if (!mounted) return;
      setState(() {
        _lastSync = DateTime.now();
        _isFresh = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFresh = false);
    }
  }

  Future<void> _manualRefresh() async {
    try {
      await ref.read(dashboardProvider.notifier).pullToRefresh();
      if (!mounted) return;
      setState(() {
        _lastSync = DateTime.now();
        _isFresh = true;
      });
      _startPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFresh = false);
      rethrow;
    }
  }

  String get _schoolName {
    final ud = widget.state.userData;
    final raw = (ud['school_name'] ?? ud['nama_sekolah'])?.toString().trim();
    if (raw == null || raw.isEmpty) return AppLocalizations.dbSchool.tr;
    return raw;
  }

  String get _greetingSubtitle {
    final year = widget.state.userData['academic_year']?.toString();
    if (year == null || year.isEmpty) return AppLocalizations.pdParent.tr;
    return '${AppLocalizations.pdParent.tr} · TP $year';
  }

  String get _userName {
    final raw = widget.state.userData['name']?.toString().trim();
    return (raw == null || raw.isEmpty) ? AppLocalizations.pdParent.tr : raw;
  }

  // KPI counts
  int get _childrenCount => _asInt(widget.state.stats['children_count']);
  int get _attendanceRate => _asInt(widget.state.stats['attendance_rate']);
  int get _newGradesCount => _asInt(widget.state.stats['new_grades_7days']);
  int get _overdueBillsCount =>
      _asInt(widget.state.stats['overdue_bills_count']);

  // Inbox counts
  int get _overdueBills => _asInt(widget.state.stats['overdue_bills_count']);
  int get _newGrades => _asInt(widget.state.stats['unread_grades']);
  int get _newAnnouncements =>
      _asInt(widget.state.stats['unread_announcements']);
  int get _attendanceAlpha => _asInt(widget.state.stats['unread_presence']);

  static int _asInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // Navigation handlers — every parent quick-action / inbox row routes
  // through `ShellNav.goTo` so the bottom-nav shell highlights the
  // correct tab AND pushes the deep screen on top. Mirrors the
  // `cards_mixin` pattern so dashboard and worklist links behave
  // identically.

  String? get _academicYearId =>
      ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

  /// Display label for the academic year chip in the hero. Watches
  /// `academicYearRiverpod` so the chip updates when the user picks a
  /// different year via [showAcademicYearPickerSheet].
  String get _academicYearLabel {
    final year = ref.watch(academicYearRiverpod).selectedAcademicYear;
    return year?['year']?.toString() ?? '—';
  }

  void _openAnnouncements() {
    AppNavigator.push(context, const ParentAnnouncementScreen());
  }

  void _openGrades() {
    AppNavigator.push(
      context,
      ParentGradeScreen(academicYearId: _academicYearId),
    );
  }

  void _openAttendance() {
    final ud = widget.state.userData;
    // Resolve student ID from slices or userData
    final slices = _parseSlices(widget.state.stats['slices']);
    final studentId = slices.isNotEmpty
        ? slices.first.studentId
        : (ud['student_id'] ?? '').toString();
    if (studentId.isEmpty) {
      // Last resort: switch to tab which handles its own resolution
      ShellNav.goTo(ref, role: 'wali', tab: ShellTab.attendance);
      return;
    }
    AppNavigator.push(
      context,
      ParentAttendanceScreen(
        parent: Map<String, dynamic>.from(ud),
        studentId: studentId,
        academicYearId: _academicYearId,
        showBackButton: true,
      ),
    );
  }

  void _openBilling() {
    AppNavigator.push(context, const ParentBillingScreen(showBackButton: true));
  }

  /// Phase-5 surface B — full Perlu Perhatian inbox screen reached
  /// from the "Lihat semua" link in the dashboard inbox card.
  void _openInbox() {
    AppNavigator.push(context, const ParentInboxScreen());
  }

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when language changes.
    ref.watch(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _manualRefresh,
        color: widget.primaryColor,
        edgeOffset: MediaQuery.of(context).padding.top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              key: widget.heroSectionKey,
              child: _buildHeroWithKpiOverlay(context),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            SliverToBoxAdapter(child: _buildInboxCard()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              key: widget.quickActionsKey,
              child: _buildQuickActions(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: _buildModulLain()),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  /// Combined hero + KPI section matching the Phase 3 mockup pattern.
  /// Edge-to-edge violet gradient under the system status bar with rounded
  /// bottom corners; greeting + name + icon row at top, then realtime,
  /// school pill, and KPI cards floating onto the bottom edge.
  Widget _buildHeroWithKpiOverlay(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;
    final notifBadge =
        _asInt(widget.state.userData['unread_notifications_count']) +
        _asInt(widget.state.stats['unread_announcements']);
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_parentBrandAzure, _parentBrandAzureDeep],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _parentBrandAzure.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  statusBarHeight + AppSpacing.md,
                  AppSpacing.md,
                  // Extra space below the school pill so the floating KPI
                  // cards overlap an empty violet band rather than the pill.
                  48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppLocalizations.greeting(DateTime.now().hour),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.72),
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.1,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ParentDashboardHeroIconButton(
                          icon: Icons.language_outlined,
                          onTap: widget.onLanguageTap,
                          gradientBg: _parentBrandAzure,
                        ),
                        const SizedBox(width: 6),
                        ParentDashboardHeroIconButton(
                          icon: Icons.notifications_outlined,
                          onTap: widget.onNotificationTap,
                          gradientBg: _parentBrandAzure,
                          showDot: notifBadge > 0,
                        ),
                        const SizedBox(width: 6),
                        ParentDashboardHeroIconButton(
                          icon: Icons.person_outline,
                          onTap: widget.onAccountTap,
                          gradientBg: _parentBrandAzure,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ParentDashboardRealtimePill(
                      isFresh: _isFresh,
                      lastSync: _lastSync,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // School pill + tahun-ajaran chip side-by-side. The
                    // school pill takes the available space and the chip
                    // is a fixed-width sidekick. On narrow screens the
                    // pill ellipsises; the chip stays legible.
                    //
                    // No `crossAxisAlignment: stretch` — that would ask
                    // Flutter to bound the Row's height to the children
                    // but neither parent (the hero Column) nor the chip
                    // give a height constraint upward, so layout asserts.
                    // Both children carry their own intrinsic height; the
                    // default `start` alignment is correct here.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: SchoolPill.expanded(
                              schoolName: _schoolName,
                              subtitle: _greetingSubtitle,
                              onTap: widget.onSchoolSwitchTap,
                              accentColor: _parentBrandAzure,
                              actionLabel: AppLocalizations.dbSwitch.tr,
                              onDarkSurface: true,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: AcademicYearChip(
                              yearLabel: _academicYearLabel,
                              semesterLabel: widget.state.currentSemesterLabel
                                  ?.replaceAll(
                                    RegExp(r'\s*[-\u2013\u2014·].*'),
                                    '',
                                  )
                                  .trim(),
                              onTap: () => showAcademicYearPickerSheet(
                                context: context,
                                ref: ref,
                                currentSemesterLabel:
                                    widget.state.currentSemesterLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            key: widget.statsSectionKey,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildKpiCarousel(),
          ),
        ],
      ),
    );
  }

  /// Build the KPI carousel. When the parent has multiple anak the
  /// carousel auto-cycles per `BrandKpiCarousel`'s default 6 s dwell;
  /// each card renders a Stories-style progress strip on its top edge
  /// driven by `activeSliceProvider('parent_dashboard')`. Single-anak
  /// (or no-data) parents see a flat 4-card layout (no progress
  /// strip, no cycle) — but the four mockup KPIs are always present.
  ///
  /// Backend shape — `widget.state.stats['slices']` is a list of
  /// per-child KPI bundles produced by `DashboardController::buildParentChildSlices`.
  Widget _buildKpiCarousel() {
    final parsed = _parseSlices(widget.state.stats['slices']);

    // No-data fallback — backend returned an empty list (children not
    // yet enrolled, or backend pre-deploy). Synthesise a single
    // placeholder slice with zero/null values so the carousel still
    // renders the four mockup KPIs (Kehadiran / Tagihan / Rata-rata /
    // Pengumuman). With sliceCount = 1 the carousel skips the
    // progress strip and auto-cycle automatically.
    final slices = parsed.isEmpty ? [_ParentSlice.placeholder()] : parsed;

    return BrandKpiCarousel(
      scope: 'parent_dashboard',
      sliceCount: slices.length,
      autoSlideCards: true,
      cardBuilder: (sliceIndex) {
        final s = slices[sliceIndex.clamp(0, slices.length - 1)];
        final ctxLabel = s.isPlaceholder
            ? AppLocalizations.pdNoDataYet.tr
            : '${s.name} · ${s.classLabel}';

        return [
          // 1. Kehadiran 30 hari
          HeroStatsCard(
            label: AppLocalizations.pdPresence.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: s.isPlaceholder,
            value: s.isPlaceholder ? '—' : '${s.attendanceRate}%',
            icon: Icons.directions_run_rounded,
            accentColor: ColorUtils.success600,
            caption: s.isPlaceholder
                ? '30 ${AppLocalizations.day.tr.toLowerCase()}'
                : '${s.attendanceBreakdown['sakit'] ?? 0} ${AppLocalizations.pdSick.tr.toLowerCase()} · ${s.attendanceBreakdown['izin'] ?? 0} ${AppLocalizations.pdPermission.tr.toLowerCase()} · ${s.attendanceBreakdown['alpa'] ?? 0} ${AppLocalizations.pdAlpha.tr.toLowerCase()}',
            trend: (!s.isPlaceholder && s.attendanceDelta != 0)
                ? StatTrend(
                    direction: s.attendanceDelta > 0
                        ? StatTrendDirection.up
                        : StatTrendDirection.down,
                    label:
                        '${s.attendanceDelta > 0 ? '+' : ''}${s.attendanceDelta}% ${AppLocalizations.pdThisMonth.tr}',
                  )
                : null,
            onTap: s.isPlaceholder ? null : _openAttendance,
          ),
          // 2. Tugas
          HeroStatsCard(
            label: AppLocalizations.pdTasks.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: s.isPlaceholder,
            value: s.isPlaceholder ? '—' : '${s.tugasPending}',
            icon: Icons.assignment_outlined,
            accentColor: ColorUtils.warning600,
            caption: s.isPlaceholder
                ? AppLocalizations.pdWaiting.tr
                : (s.tugasOverdue > 0
                      ? '${s.tugasOverdue} ${AppLocalizations.pdNotCollected.tr}'
                      : '${s.tugasTotal} ${AppLocalizations.pdTotalTasks.tr}'),
            trend: (s.tugasOverdue > 0)
                ? StatTrend(
                    direction: StatTrendDirection.down,
                    label:
                        '${s.tugasOverdue} ${AppLocalizations.pdNotCollected.tr}',
                    inverse: true,
                  )
                : null,
            onTap: s.isPlaceholder ? null : _openGrades,
          ),
          // 3. Tagihan jatuh tempo
          HeroStatsCard(
            label: AppLocalizations.pdBilling.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: s.isPlaceholder,
            value: s.isPlaceholder
                ? '—'
                : (s.overdueTotal > 0
                      ? 'Rp ${_formatRupiahShort(s.overdueTotal)}'
                      : AppLocalizations.pdVerified.tr),
            icon: Icons.account_balance_wallet_outlined,
            accentColor: ColorUtils.error600,
            caption: s.isPlaceholder
                ? AppLocalizations.pdDue.tr
                : (s.overdueCount > 0
                      ? '${s.overdueCount} ${AppLocalizations.billing.tr.toLowerCase()}'
                      : AppLocalizations.pdNoArrears.tr),
            onTap: s.isPlaceholder ? null : _openBilling,
          ),
          // 4. Rata-rata nilai
          HeroStatsCard(
            label: AppLocalizations.pdAverage.tr,
            sliceLabel: ctxLabel,
            sliceLabelMuted: s.isPlaceholder,
            value: s.avgGradeTerm != null
                ? s.avgGradeTerm!.toStringAsFixed(1)
                : '—',
            icon: Icons.bar_chart_rounded,
            accentColor: const Color(0xFF6366F1),
            caption: s.avgGradeTerm != null
                ? '${s.avgGradeSubjectCount} ${AppLocalizations.pdSubjectsCount.tr}'
                : (s.isPlaceholder
                      ? AppLocalizations.pdActiveSemester.tr
                      : AppLocalizations.pdNoDataYet.tr),
            trend: (s.avgGradeTerm != null && s.avgGradeDelta.abs() >= 0.1)
                ? StatTrend(
                    direction: s.avgGradeDelta > 0
                        ? StatTrendDirection.up
                        : StatTrendDirection.down,
                    label:
                        '${s.avgGradeDelta > 0 ? '+' : ''}${s.avgGradeDelta.toStringAsFixed(1)} ${AppLocalizations.pdLastSemester.tr}',
                  )
                : null,
            onTap: s.isPlaceholder ? null : _openGrades,
          ),
        ];
      },
    );
  }

  /// Parse the raw `slices` array from [DashboardState.stats] into
  /// strongly-typed [_ParentSlice] entries. Defensive: missing fields
  /// flatten to safe zero / null defaults so the carousel still
  /// renders during partial backend rollouts.
  List<_ParentSlice> _parseSlices(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => _ParentSlice.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// Format a Rupiah amount to a compact "K"/"jt" suffix used in the
  /// KPI value field. The full amount lives in the detail screen.
  String _formatRupiahShort(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}jt';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return '${k.toStringAsFixed(k % 1 == 0 ? 0 : 0)}K';
    }
    return _formatNumber(amount);
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final remain = s.length - i;
      buf.write(s[i]);
      if (remain > 1 && (remain - 1) % 3 == 0) buf.write('.');
    }
    return buf.toString();
  }

  Widget _buildInboxCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PendingInboxCard(
        title: 'Perlu perhatian',
        // Phase-5 surface B — "Lihat semua" opens the full inbox
        // screen instead of jumping to the billing tab. The billing
        // category remains reachable from there via the Tagihan
        // filter chip.
        onSeeAll: _openInbox,
        seeAllLabel: 'Lihat semua',
        totalLabel: 'total menunggu',
        accentColor: _parentBrandAzure,
        entries: [
          PendingInboxEntry(
            icon: Icons.warning_amber_outlined,
            label: 'Tagihan jatuh tempo',
            count: _overdueBills,
            color: ColorUtils.error600,
            subtitle: _overdueBills > 0
                ? 'Beberapa tagihan belum dibayar'
                : 'Tidak ada tunggakan aktif',
            onTap: _openBilling,
          ),
          PendingInboxEntry(
            icon: Icons.grade_outlined,
            label: AppLocalizations.dbGradesAndReportCards.tr,
            count: _newGrades,
            color: ColorUtils.success600,
            subtitle: _newGrades > 0
                ? 'Ada nilai terbaru untuk dilihat'
                : 'Belum ada nilai terbaru',
            onTap: _openGrades,
          ),
          PendingInboxEntry(
            icon: Icons.announcement_outlined,
            label: AppLocalizations.announcements.tr,
            count: _newAnnouncements,
            color: ColorUtils.info600,
            subtitle: _newAnnouncements > 0
                ? 'Informasi terbaru dari sekolah'
                : 'Tidak ada pengumuman baru',
            onTap: _openAnnouncements,
          ),
          PendingInboxEntry(
            icon: Icons.check_circle_outline,
            label: AppLocalizations.pdPresence.tr,
            count: _attendanceAlpha,
            color: ColorUtils.warning600,
            subtitle: _attendanceAlpha > 0
                ? 'Data kehadiran terbaru tersedia'
                : 'Kehadiran anak terdokumentasi',
            onTap: _openAttendance,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return QuickActionGrid(
      columnsPerRow: 4,
      actions: [
        QuickAction(
          icon: Icons.announcement_outlined,
          label: AppLocalizations.announcements.tr,
          color: widget.primaryColor,
          caption: AppLocalizations.information.tr,
          showBadge: _newAnnouncements > 0,
          onTap: _openAnnouncements,
        ),
        QuickAction(
          icon: Icons.account_balance_wallet_outlined,
          label: AppLocalizations.billing.tr,
          color: ColorUtils.error600,
          caption: AppLocalizations.pdPayment.tr,
          showBadge: _overdueBills > 0,
          onTap: _openBilling,
        ),
        QuickAction(
          icon: Icons.grade_outlined,
          label: AppLocalizations.grades.tr,
          color: ColorUtils.success600,
          caption: AppLocalizations.pdAcademic.tr,
          showBadge: _newGrades > 0,
          onTap: _openGrades,
        ),
        QuickAction(
          icon: Icons.check_circle_outline,
          label: AppLocalizations.pdPresence.tr,
          color: ColorUtils.warning600,
          caption: AppLocalizations.presence.tr,
          showBadge: _attendanceAlpha > 0,
          onTap: _openAttendance,
        ),
      ],
    );
  }

  void _openReportCard() {
    AppNavigator.push(
      context,
      ParentReportCardScreen(academicYearId: _academicYearId),
    );
  }

  void _openClassActivity() {
    AppNavigator.push(
      context,
      ParentClassActivityScreen(academicYearId: _academicYearId),
    );
  }

  /// "Modul lain → Rekomendasi" entry. The shared rec screen needs the
  /// authenticated parent's user id (the kamiledu-ai backend scopes
  /// every parent query by `parent_user_id` from the body — the bearer
  /// token alone isn't enough because the parent role is shared by
  /// many users at the same school).
  ///
  /// We read the id from the `'user'` blob `PreferencesService` caches
  /// at login — same source `parent_attendance_screen.dart`,
  /// `parent_grade_screen.dart`, and `fcm_notification_router.dart`
  /// already use, so we don't introduce a new auth surface here.
  void _openRecommendations() {
    final raw = PreferencesService().getString('user');
    String parentUserId = '';
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          parentUserId = decoded['id']?.toString() ?? '';
        }
      } catch (_) {
        /* fall through to the empty-id branch below */
      }
    }

    if (parentUserId.isEmpty) {
      // Defensive — should never happen for a logged-in parent, but
      // bail with a friendly message instead of pushing a screen that
      // would 422 on every fetch.
      SnackBarUtils.showError(
        context,
        'Sesi tidak ditemukan. Silakan masuk ulang.',
      );
      return;
    }

    AppNavigator.push(
      context,
      ParentRecommendationScreen(parentUserId: parentUserId),
    );
  }

  void _openAccount() {
    AppNavigator.push(context, const SettingsScreen());
  }

  Widget _buildModulLain() {
    // Rekomendasi sits in the visible strip (slot 1) because wali-kelas
    // recommendations are time-sensitive — parents need to see new
    // suggestions at a glance, the same priority as Raport / Kegiatan
    // / Kehadiran. We promote *down* (Kehadiran → overflow) rather
    // than adding a 5th visible tile so the row stays at 4 slots
    // (4 visible + the "+N Lainnya" overflow tile = 5 cells, the
    // documented max for `ModulLainStrip`).
    return ModulLainStrip(
      title: 'Modul lain',
      totalLabel: '8 modul',
      accentColor: _parentBrandAzureDeep,
      visibleItems: [
        ModulLainStripItem(
          label: 'Rekomendasi',
          icon: Icons.lightbulb_outline_rounded,
          onTap: _openRecommendations,
        ),
        ModulLainStripItem(
          label: 'Raport',
          icon: Icons.school_outlined,
          onTap: _openReportCard,
        ),
        ModulLainStripItem(
          label: 'Kegiatan\nKelas',
          icon: Icons.event_outlined,
          onTap: _openClassActivity,
        ),
      ],
      overflowItems: [
        ModulLainStripItem(
          label: 'Kehadiran',
          icon: Icons.check_circle_outline,
          onTap: _openAttendance,
        ),
        ModulLainStripItem(
          label: 'Nilai',
          icon: Icons.grade_outlined,
          onTap: _openGrades,
        ),
        ModulLainStripItem(
          label: 'Pengumuman',
          icon: Icons.announcement_outlined,
          onTap: _openAnnouncements,
        ),
        ModulLainStripItem(
          label: 'Tagihan',
          icon: Icons.account_balance_wallet_outlined,
          onTap: _openBilling,
        ),
        ModulLainStripItem(
          label: 'Akun',
          icon: Icons.account_circle_outlined,
          onTap: _openAccount,
        ),
      ],
    );
  }
}

/// One per-anak KPI bundle as returned by
/// `DashboardController::buildParentChildSlices`. Strongly-typed so the
/// card builder can read fields without repeated null/coercion checks.
@immutable
class _ParentSlice {
  final String studentId;
  final String name;
  final String classLabel;
  final int attendanceRate;
  final int attendanceDelta;
  final Map<String, int> attendanceBreakdown;
  final int overdueTotal;
  final int overdueCount;
  final double? avgGradeTerm;
  final double avgGradeDelta;
  final int avgGradeSubjectCount;
  final int tugasTotal;
  final int tugasPending;
  final int tugasOverdue;
  final String? tugasNextTitle;

  /// True when this slice is a synthesised "no data" placeholder used
  /// to keep the four mockup KPIs visible before the parent has
  /// children enrolled or before the backend slice payload is wired.
  /// Cards render `—` for the value and disable taps.
  final bool isPlaceholder;

  const _ParentSlice({
    required this.studentId,
    required this.name,
    required this.classLabel,
    required this.attendanceRate,
    required this.attendanceDelta,
    required this.attendanceBreakdown,
    required this.overdueTotal,
    required this.overdueCount,
    required this.avgGradeTerm,
    required this.avgGradeDelta,
    required this.avgGradeSubjectCount,
    required this.tugasTotal,
    required this.tugasPending,
    required this.tugasOverdue,
    this.tugasNextTitle,
    this.isPlaceholder = false,
  });

  /// Empty-state slice. Carousel renders 4 mockup KPIs with `—`
  /// values and disabled taps. Used when the parent has no children
  /// linked yet or the backend hasn't returned a slices array.
  factory _ParentSlice.placeholder() => const _ParentSlice(
    studentId: '',
    name: '',
    classLabel: '',
    attendanceRate: 0,
    attendanceDelta: 0,
    attendanceBreakdown: {'sakit': 0, 'izin': 0, 'alpa': 0},
    overdueTotal: 0,
    overdueCount: 0,
    avgGradeTerm: null,
    avgGradeDelta: 0,
    avgGradeSubjectCount: 0,
    tugasTotal: 0,
    tugasPending: 0,
    tugasOverdue: 0,
    isPlaceholder: true,
  );

  factory _ParentSlice.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    return _ParentSlice(
      studentId: json['student_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      classLabel: json['class_label']?.toString() ?? '',
      attendanceRate: asInt(json['attendance_rate_30d']),
      attendanceDelta: asInt(json['attendance_delta_pct']),
      attendanceBreakdown: {
        'sakit': asInt((json['attendance_breakdown'] as Map?)?['sakit']),
        'izin': asInt((json['attendance_breakdown'] as Map?)?['izin']),
        'alpa': asInt((json['attendance_breakdown'] as Map?)?['alpa']),
      },
      overdueTotal: asInt(json['overdue_total']),
      overdueCount: asInt(json['overdue_count']),
      avgGradeTerm: asDouble(json['avg_grade_term']),
      avgGradeDelta: asDouble(json['avg_grade_delta']) ?? 0.0,
      avgGradeSubjectCount: asInt(json['avg_grade_subject_count']),
      tugasTotal: asInt(json['tugas_total']),
      tugasPending: asInt(json['tugas_pending']),
      tugasOverdue: asInt(json['tugas_overdue']),
      tugasNextTitle: json['tugas_next_title']?.toString(),
    );
  }
}
