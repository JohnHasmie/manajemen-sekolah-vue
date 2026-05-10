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
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_role_options.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_embedded_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_body_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_student_item.dart';

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
    // Take-attendance shares the brand layout pattern with the
    // detail screen: gradient header (with subject/class context
    // strip in the bottom slot) + KPI overlay card that overlaps
    // the gradient and scrolls with the body. Submit lives in the
    // Scaffold's bottomNavigationBar so it stays pinned regardless
    // of scroll position.
    final hasSubject = (selectedSubjectId ?? '').isNotEmpty;
    final hasStudents = filteredStudentList.isNotEmpty;
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: BrandPageLayout(
          role: 'guru',
          header: buildEmbeddedHeader(lp),
          kpiCard: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: buildEmbeddedKpiStrip(lp),
          ),
          // Pin the KPI strip — Hadir / Sakit / Izin / Alpa counts
          // are the teacher's primary feedback while marking, so
          // they stay visible regardless of how far the student
          // list has scrolled. Other screens keep the default
          // scroll-with-body behaviour.
          kpiSticky: true,
          bodyChildren: _buildEmbeddedBodyChildren(
            lp: lp,
            hasSubject: hasSubject,
            hasStudents: hasStudents,
          ),
          bottomPadding: 12,
        ),
      ),
      bottomNavigationBar: hasSubject && hasStudents
          ? _buildEmbeddedSubmitBar(lp)
          : null,
    );
  }

  /// Body content for the embedded BrandPageLayout. Each child
  /// becomes one item in the layout's outer ListView, which lets
  /// the KPI card overlap the gradient header and scroll with the
  /// list (matches the main Presensi + detail screen pattern).
  ///
  /// Layout:
  ///   • compact toolbar (search + Aksi cepat trigger)
  ///   • section head ("Daftar Siswa · N siswa")
  ///   • student tiles spread directly so no nested viewport conflicts
  ///   • placeholder / empty state when subject or roster is missing
  List<Widget> _buildEmbeddedBodyChildren({
    required LanguageProvider lp,
    required bool hasSubject,
    required bool hasStudents,
  }) {
    if (!hasSubject) {
      return [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _embeddedNoSubjectState(lp),
        ),
      ];
    }

    return [
      const SizedBox(height: 8),
      _buildEmbeddedToolbar(lp),
      if (hasStudents) ...[
        buildEmbeddedSectionHead(lp),
        for (var i = 0; i < filteredStudentList.length; i++)
          AttendanceStudentItem(
            student: filteredStudentList[i],
            // Empty status → no pill highlighted. The form starts
            // every student unmarked so the teacher must tap.
            currentStatus: attendanceStatus[filteredStudentList[i].id] ?? '',
            languageProvider: lp,
            onStatusChanged: (studentId, status) {
              setState(() => attendanceStatus[studentId] = status);
            },
            index: i,
          ),
        const SizedBox(height: 16),
      ] else ...[
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: EmptyState(
            title: lp.getTranslatedText({
              'en': 'No Students',
              'id': 'Tidak ada siswa',
            }),
            subtitle: lp.getTranslatedText({
              'en': 'No students found for selected class',
              'id': 'Tidak ada siswa untuk kelas yang dipilih',
            }),
            icon: Icons.people_outline,
          ),
        ),
      ],
    ];
  }

  /// Compact 40dp toolbar — search field + Aksi cepat trigger.
  /// Inlined here (rather than reusing AttendanceInputMode's mixin
  /// version) because the embedded path no longer renders that
  /// widget — it goes straight into BrandPageLayout's body list.
  Widget _buildEmbeddedToolbar(LanguageProvider lp) {
    final tr = lp.getTranslatedText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: TextField(
                controller: searchInputController,
                onChanged: (_) => filterStudents(),
                onSubmitted: (_) =>
                    FocusScope.of(context).unfocus(),
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tr({
                    'en': 'Search student...',
                    'id': 'Cari siswa...',
                  }),
                  hintStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: primaryColor,
                    size: 18,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            width: 40,
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                onTap: () => showQuickActionsSheet(lp),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  alignment: Alignment.center,
                  child: Tooltip(
                    message: tr({
                      'en': 'Quick Attendance',
                      'id': 'Presensi Cepat',
                    }),
                    child: Icon(
                      Icons.checklist_rtl,
                      color: primaryColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky bottom save button. Wrapped in SafeArea so it sits above
  /// the system gesture bar on edge-to-edge devices, and follows the
  /// keyboard inset thanks to Scaffold.resizeToAvoidBottomInset.
  Widget _buildEmbeddedSubmitBar(LanguageProvider lp) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate200)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: isSubmitting ? null : submitAttendance,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(
              isSubmitting
                  ? lp.getTranslatedText({
                      'en': 'Saving...',
                      'id': 'Menyimpan...',
                    })
                  : lp.getTranslatedText({
                      'en': 'Save Attendance',
                      'id': 'Simpan Absensi',
                    }),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _embeddedNoSubjectState(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 48,
            color: ColorUtils.slate300,
          ),
          const SizedBox(height: 12),
          Text(
            lp.getTranslatedText({
              'en': 'Please select Class and Subject first',
              'id': 'Silakan pilih Kelas dan Mapel terlebih dahulu',
            }),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            lp.getTranslatedText({
              'en':
                  'Or ensure you have a schedule for the selected date',
              'id':
                  'Atau pastikan anda memiliki jadwal pada tanggal '
                  'yang dipilih',
            }),
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
            textAlign: TextAlign.center,
          ),
        ],
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
    final roles = buildMultiWaliRoleOptions(
      homeroomClasses: homeroomClassesList,
      lp: lp,
    );

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
          // Plain loop instead of `firstWhere` — when
          // `homeroomClassesList` is declared `List<dynamic>` but the
          // runtime list contains `Map<String, dynamic>` values, the
          // analyzer types `firstWhere`'s orElse closure as
          // `() => dynamic` while the runtime list expects
          // `() => Map<String, dynamic>`, throwing TypeError on tap.
          Map<String, dynamic>? picked;
          for (final c in homeroomClassesList) {
            if (c is Map && (c['id'] ?? '').toString() == classId) {
              picked = Map<String, dynamic>.from(c);
              break;
            }
          }
          picked ??= homeroomClassesList.isNotEmpty
              ? Map<String, dynamic>.from(homeroomClassesList.first as Map)
              : <String, dynamic>{};
          setState(() {
            isHomeroomView = true;
            selectedHomeroomClass = picked;
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
  Widget buildEmbeddedKpiStrip(LanguageProvider lp);
  @override
  Widget buildEmbeddedSectionHead(LanguageProvider lp);
  @override
  Widget buildInputMode();
  @override
  Widget buildBody(LanguageProvider lp);
}
