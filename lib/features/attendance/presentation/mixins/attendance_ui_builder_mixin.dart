// Builds the teacher Presensi screen using the brand visual language
// (`BrandPageHeader` + KPI card overlay + multi-wali `RoleToggleChipRow` +
// `BrandFilterChipStrip`).
//
// Why we don't wrap with `BrandPageLayout`
// ----------------------------------------
// The existing body (`buildBody` / `buildTimelineBody`) carries its own
// `ListView.builder` with pagination + scroll listener. `BrandPageLayout`
// owns its outer `ListView`, which would conflict. To keep the inner
// pagination flow intact, this screen lays out the header + KPI + body
// manually as a Column. The KPI card uses a negative top margin to
// overlap the gradient by `BrandPageLayout.kpiOverlapHeight`, matching
// what the real layout does.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
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
  bool get isTimelineView;
  @override
  bool get hasActiveFilter;
  List<dynamic> get homeroomClassesList;
  Map<String, dynamic>? get selectedHomeroomClass;
  set selectedHomeroomClass(Map<String, dynamic>? v);

  // Methods to call
  void showAddAttendanceFlow(LanguageProvider lp);
  @override
  Future<void> refreshGroupedAttendance();
  void showFilterDialog(LanguageProvider lp);
  List<ActiveFilter> buildActiveFilterChips(LanguageProvider lp);
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
    final activeFilters = buildActiveFilterChips(lp);
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(
          children: [
            _brandHeader(lp, activeFilters),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Body fills the remaining space starting from the
                  // KPI card's mid-height, so the card visually overlaps
                  // the gradient like `BrandPageLayout` does.
                  Positioned.fill(
                    top: _kpiOverlapBodyOffset,
                    child: isTimelineView
                        ? buildTimelineBody(lp)
                        : buildBody(lp),
                  ),
                  // KPI card — overlaps the gradient.
                  Positioned(
                    top: -BrandPageLayout.kpiOverlapHeight,
                    left: 12,
                    right: 12,
                    child: _buildKpiCard(lp),
                  ),
                ],
              ),
            ),
          ],
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

  // ═══════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════

  /// Cached body-offset for the KPI overlap. Kept as a constant getter
  /// so the build method reads cleanly. Equals the KPI card's height
  /// (~80 dp) minus the overlap so the body starts BELOW the card.
  double get _kpiOverlapBodyOffset => 80 - BrandPageLayout.kpiOverlapHeight;

  Widget _brandHeader(LanguageProvider lp, List<ActiveFilter> activeFilters) {
    final filterCount = activeFilters.length;
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
          badgeCount: filterCount > 0 ? filterCount : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
        BrandHeaderIconButton(
          icon: isTimelineView
              ? Icons.grid_view_rounded
              : Icons.view_list_rounded,
          onTap: toggleView,
        ),
      ],
      childSelector: _buildRoleSelector(lp),
      bottomSlot: _buildFilterStrip(lp, activeFilters),
    );
  }

  /// Multi-wali-kelas role chip row. Shows nothing if the teacher only
  /// has the Mengajar identity (no homeroom classes); shows
  /// `Mengajar | Wali 7B | Wali 8A | …` otherwise.
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

  /// Active-filter chip strip rendered in the header bottomSlot.
  /// Each chip opens the same filter sheet — the body just previews
  /// the active values so the teacher can see what's filtered without
  /// opening the sheet.
  Widget? _buildFilterStrip(
    LanguageProvider lp,
    List<ActiveFilter> activeFilters,
  ) {
    if (activeFilters.isEmpty) return null;
    return BrandFilterChipStrip(
      chips: [
        for (final f in activeFilters)
          BrandFilterChip(
            label: f.label,
            value: f.value,
            onTap: () => showFilterDialog(lp),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // KPI CARD
  // ═══════════════════════════════════════════

  /// "Sesi hari ini · Selesai · Belum" — three stats computed from the
  /// loaded grouped-attendance payload. The numbers are best-effort:
  /// when the screen first paints (cache hit) the counts may be zero
  /// until the API responds. A backend bundle endpoint is planned to
  /// return these directly so the card is correct on first paint.
  Widget _buildKpiCard(LanguageProvider lp) {
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
      final hasRecords =
          (raw['recorded_count'] ?? raw['attendance_count'] ?? 0) is num &&
          ((raw['recorded_count'] ?? raw['attendance_count'] ?? 0) as num) > 0;
      if (hasRecords) {
        completed++;
      } else {
        pending++;
      }
    }

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
              label: lp.getTranslatedText({'en': 'Today', 'id': 'Hari ini'}),
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

  void toggleView();
  @override
  Future<void> forceRefresh();
  @override
  void setState(VoidCallback fn);

  @override
  Widget buildEmbeddedHeader(LanguageProvider lp);
  @override
  Widget buildInputMode();
  @override
  Widget buildTimelineBody(LanguageProvider lp);
  @override
  Widget buildBody(LanguageProvider lp);
}
