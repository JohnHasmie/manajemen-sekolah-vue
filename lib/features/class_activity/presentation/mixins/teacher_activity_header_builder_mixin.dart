// Brand-migrated header for Kegiatan Kelas — replaces the legacy
// TeacherPageHeader with BrandPageHeader + 3-cell KPI overlay
// (Pekan ini · Bulan ini · Tugas), the multi-wali RoleToggleChipRow,
// and a BrandFilterChipStrip in bottomSlot. Mirrors the same scaffold
// the Presensi screen uses so the two surfaces feel like one app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_role_options.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityHeaderBuilderMixin
    on ConsumerState<TeacherClassActivityScreen> {
  /// Brand header. Title + kicker + green realtime dot,
  /// multi-role chip row in `childSelector`, filter chips in
  /// `bottomSlot`, gear icon with badge in `actionIcons`.
  Widget buildBrandHeader(LanguageProvider lp) {
    return BrandPageHeader(
      role: 'guru',
      title: lp.getTranslatedText({
        'en': 'Class Activity',
        'id': 'Kegiatan Kelas',
      }),
      subtitle: lp.getTranslatedText({
        'en': 'Academic · Activity',
        'id': 'Akademik · Kegiatan',
      }),
      isRealtimeFresh: true,
      kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => showFilterDialog(lp),
          badgeCount: activeFilterCount > 0 ? activeFilterCount : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      childSelector: _buildRoleSelector(lp),
      bottomSlot: BrandFilterChipStrip(chips: _buildFilterChips(lp)),
    );
  }

  /// Multi-wali role row — `Mengajar | Wali 7B | Wali 8A` style.
  /// Hidden when teacher has no homeroom assignments.
  Widget? _buildRoleSelector(LanguageProvider lp) {
    if (homeroomClassesList.isEmpty) return null;
    final roles = buildMultiWaliRoleOptions(
      homeroomClasses: homeroomClassesList,
      lp: lp,
    );

    final selectedId = isHomeroomView
        ? 'wali:${(selectedHomeroomClass?['id'] ?? '').toString()}'
        : 'mengajar';

    return RoleToggleChipRow(
      roles: roles,
      selectedRoleId: selectedId,
      accentColor: ColorUtils.brandCobalt,
      onSelected: (id) {
        if (id == 'mengajar') {
          updateHomeroomView(false);
          refreshGroupedActivities();
        } else if (id.startsWith('wali:')) {
          final classId = id.substring(5);
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
          setSelectedHomeroomClass(picked);
          updateHomeroomView(true);
          refreshGroupedActivities();
        }
      },
    );
  }

  /// Filter chips strip — Periode · Kelas · Mapel. Each chip shows
  /// its current value when set, "+ Label" placeholder otherwise.
  /// All chips share one tap handler that opens the filter sheet.
  List<BrandFilterChip> _buildFilterChips(LanguageProvider lp) {
    void tap() => showFilterDialog(lp);

    return [
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Period', 'id': 'Periode'}),
        value: filterDateOption == null ? null : _periodLabel(lp),
        onTap: tap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
        value: filterClassId == null ? null : _classLabel(),
        onTap: tap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}),
        value: filterSubjectId == null ? null : _subjectLabel(),
        onTap: tap,
      ),
    ];
  }

  String _periodLabel(LanguageProvider lp) {
    switch (filterDateOption) {
      case 'today':
        return lp.getTranslatedText({'en': 'Today', 'id': 'Hari ini'});
      case 'week':
        return lp.getTranslatedText({'en': 'This week', 'id': 'Pekan ini'});
      case 'month':
        return lp.getTranslatedText({'en': 'This month', 'id': 'Bulan ini'});
      default:
        return '';
    }
  }

  String _classLabel() {
    for (final c in classList) {
      if (c is Map && (c['id'] ?? '').toString() == filterClassId) {
        return (c['name'] ?? '-').toString();
      }
    }
    return '-';
  }

  String _subjectLabel() {
    for (final s in filterSubjectList) {
      if (s is Map && (s['id'] ?? '').toString() == filterSubjectId) {
        return (s['name'] ?? '-').toString();
      }
    }
    return '-';
  }

  /// 3-cell KPI overlay card — `Pekan ini · Bulan ini · Tugas`.
  /// Values come from `kpiSummary` (set by data-loading mixin) when
  /// present; falls back to a client-side computation off
  /// `groupedActivities` so the card never renders empty.
  Widget buildBrandKpiCard(LanguageProvider lp) {
    final wkRaw =
        kpiSummary['weekly_count'] ??
        kpiSummary['this_week'] ??
        kpiSummary['pekan_ini'];
    final mnRaw =
        kpiSummary['monthly_count'] ??
        kpiSummary['this_month'] ??
        kpiSummary['bulan_ini'];
    final tgRaw =
        kpiSummary['assignment_count'] ??
        kpiSummary['tugas_count'] ??
        kpiSummary['tugas'];
    final fallback = _fallbackKpis();
    final wk = (wkRaw is num ? wkRaw.toInt() : null) ?? fallback['weekly']!;
    final mn = (mnRaw is num ? mnRaw.toInt() : null) ?? fallback['monthly']!;
    final tg = (tgRaw is num ? tgRaw.toInt() : null) ?? fallback['tugas']!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Row(
          children: [
            _kpiCell(
              label: lp.getTranslatedText({
                'en': 'This week',
                'id': 'Pekan ini',
              }),
              value: wk,
              color: ColorUtils.success600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({
                'en': 'This month',
                'id': 'Bulan ini',
              }),
              value: mn,
              color: ColorUtils.info600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Assignments', 'id': 'Tugas'}),
              value: tg,
              color: ColorUtils.violet700,
            ),
          ],
        ),
      ),
    );
  }

  /// Compute KPI counts off `groupedActivities` when the backend
  /// hasn't returned them yet.
  Map<String, int> _fallbackKpis() {
    final today = DateTime.now();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(today.year, today.month, 1);
    int weekly = 0, monthly = 0, tugas = 0;
    for (final raw in groupedActivities) {
      if (raw is! Map) continue;
      final latest = (raw['latest_activities'] as List?) ?? const [];
      for (final a in latest) {
        if (a is! Map) continue;
        final dateStr = (a['date'] ?? a['tanggal'] ?? '').toString();
        final d = DateTime.tryParse(dateStr);
        if (d == null) continue;
        if (!d.isBefore(monthStart)) monthly++;
        if (!d.isBefore(weekStart)) weekly++;
        final type = (a['type'] ?? a['tipe'] ?? '').toString().toLowerCase();
        if (type == 'tugas' || type == 'assignment') tugas++;
      }
    }
    return {'weekly': weekly, 'monthly': monthly, 'tugas': tugas};
  }

  Widget _kpiCell({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 28, color: ColorUtils.slate100);
  }

  // ── Required state accessors (already provided by sibling mixins) ──
  bool get isHomeroomView;
  bool get isTimelineView;
  List<dynamic> get homeroomClassesList;
  Map<String, dynamic>? get selectedHomeroomClass;
  void setSelectedHomeroomClass(Map<String, dynamic>? v);
  TextEditingController get searchController;
  bool get hasActiveFilter;
  Color get primaryColor;
  List<dynamic> get classList;
  List<dynamic> get groupedActivities;
  String? get filterClassId;
  String? get filterSubjectId;
  String? get filterDateOption;
  List<dynamic> get filterSubjectList;
  int get activeFilterCount;
  Map<String, dynamic> get kpiSummary;

  void toggleViewMode();
  void onSearch();
  void showFilterDialog(LanguageProvider lp);
  void updateHomeroomView(bool value);
  Future<void> refreshGroupedActivities();
  void updateFilters({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  });
  Future<void> forceRefresh();
}
