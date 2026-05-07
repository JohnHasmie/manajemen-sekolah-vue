// Builds the teacher Presensi screen with the parent-role brand
// pattern: BrandPageLayout (header + KPI overlay + scrollable body),
// multi-wali RoleToggleChipRow in childSelector, BrandFilterChipStrip
// in bottomSlot, and Column-style body widgets that slot into the
// layout's outer ListView.
//
// Pagination
// ----------
// The screen historically attached its scroll listener to its own
// ScrollController. Inside BrandPageLayout that controller is
// detached, so pagination uses a NotificationListener that watches
// scroll-end notifications bubbling up from the layout's internal
// ListView. When the user reaches within 200 dp of the bottom and
// there's more data, we fire `loadMoreGroupedAttendance`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_embedded_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_body_mixin.dart';

mixin AttendanceUIBuilderMixin
    on
        ConsumerState<AttendancePage>,
        AttendanceUIEmbeddedMixin,
        AttendanceUIBodyMixin {
  // ── Abstract state accessors ──

  @override
  Color get primaryColor;
  bool get isHomeroomView;
  set isHomeroomView(bool v);
  @override
  TextEditingController get searchController;
  @override
  bool get hasActiveFilter;
  List<dynamic> get homeroomClassesList;
  Map<String, dynamic>? get selectedHomeroomClass;
  set selectedHomeroomClass(Map<String, dynamic>? v);

  /// KPI bundle returned by the backend summary endpoint. Carries
  /// `sessions_today`, `sessions_completed`, `sessions_pending`. Empty
  /// before the first response — the KPI card falls back to client-side
  /// computation from `groupedAttendance` until the backend lands.
  Map<String, dynamic> get kpiSummary;

  // Methods to call
  void showAddAttendanceFlow(LanguageProvider lp);
  @override
  Future<void> refreshGroupedAttendance();
  Future<void> loadMoreGroupedAttendance();
  bool get hasMoreData;
  void showFilterDialog(LanguageProvider lp);
  List<BrandFilterChip> buildBrandFilterChips({
    required LanguageProvider lp,
    required VoidCallback onTap,
  });
  int get activeFilterCount;
  String currentPeriodLabel(LanguageProvider lp);
  void clearAllFilters();

  // ═══════════════════════════════════════════
  // MAIN BUILD METHODS
  // ═══════════════════════════════════════════

  Widget buildEmbedded(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            buildEmbeddedHeader(lp),
            Expanded(child: buildInputMode()),
          ],
        ),
      ),
    );
  }

  Widget buildMainScreen(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEndForPagination,
          child: BrandPageLayout(
            role: 'guru',
            onRefresh: forceRefresh,
            header: _brandHeader(lp),
            kpiCard: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildKpiCard(lp),
            ),
            bodyChildren: [buildGroupedBodyForBrand(lp)],
          ),
        ),
        floatingActionButton: isHomeroomView
            ? null
            : FloatingActionButton(
                onPressed: () => showAddAttendanceFlow(lp),
                backgroundColor: primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }

  /// Triggers infinite-scroll pagination when the user reaches within
  /// 200 dp of the bottom of `BrandPageLayout`'s outer ListView.
  ///
  /// Two guards before firing `loadMore`:
  ///   1. The list must actually be longer than the threshold —
  ///      otherwise on a short list (e.g. only 1 row visible) the
  ///      `maxScrollExtent - 200` becomes negative and the
  ///      `pixels < negative` check is always false, slipping
  ///      through to a spurious `loadMore` call.
  ///   2. The user must have scrolled — `pixels > 0`. A pull-to-
  ///      refresh emits a `ScrollEndNotification` with `pixels = 0`
  ///      that would otherwise satisfy guard 1 alone.
  bool _onScrollEndForPagination(ScrollEndNotification n) {
    final m = n.metrics;
    if (m.maxScrollExtent <= 200) return false;
    if (m.pixels <= 0) return false;
    if (m.pixels < m.maxScrollExtent - 200) return false;
    if (hasMoreData) loadMoreGroupedAttendance();
    return false;
  }

  // ═══════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════

  Widget _brandHeader(LanguageProvider lp) {
    return BrandPageHeader(
      role: 'guru',
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      subtitle: lp.getTranslatedText({
        'en': 'Academic · Attendance',
        'id': 'Akademik · Kehadiran',
      }),
      title: lp.getTranslatedText({'en': 'Attendance', 'id': 'Presensi'}),
      isRealtimeFresh: true,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => showFilterDialog(lp),
          badgeCount: activeFilterCount > 0 ? activeFilterCount : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      childSelector: _buildRoleSelector(lp),
      // Always-visible filter strip — three dimension chips
      // (Periode · Kelas · Mapel) that show their current value when
      // applied, and a `+ Label` placeholder when not. Tapping any
      // chip opens the same filter sheet, so the gear icon and the
      // chip strip are interchangeable entry-points to filtering.
      // Mirrors `parent_billing_screen` exactly.
      bottomSlot: BrandFilterChipStrip(
        chips: buildBrandFilterChips(lp: lp, onTap: () => showFilterDialog(lp)),
      ),
    );
  }

  /// Multi-wali-kelas role chip row. Hides itself when the teacher has
  /// no homeroom assignments. Otherwise shows
  /// `Mengajar | Wali 7B | Wali 8A | …`.
  Widget? _buildRoleSelector(LanguageProvider lp) {
    if (homeroomClassesList.isEmpty) return null;
    final roles = <RoleOption>[
      RoleOption.mengajar(
        subLabel: lp.getTranslatedText({
          'en': 'Teaching schedule',
          'id': 'Jadwal mengajar',
        }),
      ),
      for (final hc in homeroomClassesList)
        RoleOption.waliKelas(
          classId: (hc['id'] ?? '').toString(),
          className: (hc['name'] ?? hc['nama'] ?? '').toString(),
          subLabel: lp.getTranslatedText({
            'en': 'Homeroom',
            'id': 'Kelas perwalian',
          }),
        ),
    ];

    final selectedId = isHomeroomView
        ? 'wali:${selectedHomeroomClass?['id'] ?? ''}'
        : 'mengajar';

    return RoleToggleChipRow(
      roles: roles,
      selectedRoleId: selectedId,
      accentColor: ColorUtils.brandCobalt,
      onSelected: (id) {
        if (id == 'mengajar') {
          setState(() => isHomeroomView = false);
        } else if (id.startsWith('wali:')) {
          final classId = id.substring(5);
          final picked = homeroomClassesList.firstWhere(
            (c) => (c['id'] ?? '').toString() == classId,
            orElse: () => homeroomClassesList.first,
          );
          setState(() {
            isHomeroomView = true;
            selectedHomeroomClass = Map<String, dynamic>.from(picked as Map);
          });
        }
        forceRefresh();
      },
    );
  }

  // ═══════════════════════════════════════════
  // KPI CARD
  // ═══════════════════════════════════════════

  /// "Hari ini · Selesai · Belum" — three stats sourced from the
  /// backend `kpi` field on the attendance summary response when
  /// available, with a client-side fallback computed from the loaded
  /// grouped-attendance payload (best-effort; won't reflect data on
  /// pages the teacher hasn't scrolled into yet).
  Widget _buildKpiCard(LanguageProvider lp) {
    final (sessionsToday, completed, pending) = _resolveKpi();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _kpiCell(
              // Period label flips with the active filter — `Hari ini`
              // by default, `Minggu ini` / `Bulan ini` when the
              // teacher tapped the Periode chip in the filter sheet.
              label: currentPeriodLabel(lp),
              value: sessionsToday.toString(),
              caption: lp.getTranslatedText({'en': 'sessions', 'id': 'sesi'}),
              accent: ColorUtils.brandCobalt,
            ),
          ),
          _kpiDivider(),
          Expanded(
            child: _kpiCell(
              label: lp.getTranslatedText({'en': 'Done', 'id': 'Selesai'}),
              value: completed.toString(),
              caption: lp.getTranslatedText({
                'en': 'recorded',
                'id': 'tercatat',
              }),
              accent: const Color(0xFF15803D),
              pillBg: const Color(0xFFDCFCE7),
            ),
          ),
          _kpiDivider(),
          Expanded(
            child: _kpiCell(
              label: lp.getTranslatedText({'en': 'Pending', 'id': 'Belum'}),
              value: pending.toString(),
              caption: lp.getTranslatedText({
                'en': 'unsubmitted',
                'id': 'menunggu',
              }),
              accent: pending > 0
                  ? const Color(0xFFB45309)
                  : ColorUtils.slate500,
              pillBg: pending > 0
                  ? const Color(0xFFFEF3C7)
                  : ColorUtils.slate100,
            ),
          ),
        ],
      ),
    );
  }

  /// Read KPI values from the backend summary's `kpi` map first, then
  /// fall back to the client-side computation from `groupedAttendance`.
  (int, int, int) _resolveKpi() {
    int asInt(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    if (kpiSummary.isNotEmpty) {
      return (
        asInt(kpiSummary['sessions_today']),
        asInt(kpiSummary['sessions_completed']),
        asInt(kpiSummary['sessions_pending']),
      );
    }

    final today = DateTime.now();
    int sessionsToday = 0;
    int completed = 0;
    int pending = 0;
    for (final raw in groupedAttendance) {
      if (raw is! Map) continue;
      final dateStr = (raw['date'] ?? raw['tanggal'] ?? '').toString();
      final d = DateTime.tryParse(dateStr);
      if (d == null) continue;
      if (d.year != today.year ||
          d.month != today.month ||
          d.day != today.day) {
        continue;
      }
      sessionsToday++;
      final recorded =
          (raw['recorded_count'] ?? raw['attendance_count'] ?? 0) as num? ?? 0;
      if (recorded > 0) {
        completed++;
      } else {
        pending++;
      }
    }
    return (sessionsToday, completed, pending);
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required String caption,
    required Color accent,
    Color? pillBg,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: pillBg != null
              ? BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(999),
                )
              : null,
          child: Text(
            caption,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: pillBg != null ? accent : ColorUtils.slate500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiDivider() =>
      Container(width: 1, height: 36, color: ColorUtils.slate100);

  // ═══════════════════════════════════════════
  // ABSTRACT METHOD HOOKS
  // ═══════════════════════════════════════════

  @override
  Future<void> forceRefresh();
  @override
  void setState(VoidCallback fn);

  @override
  Widget buildEmbeddedHeader(LanguageProvider lp);
  @override
  Widget buildInputMode();
  @override
  Widget buildBody(LanguageProvider lp);
}
