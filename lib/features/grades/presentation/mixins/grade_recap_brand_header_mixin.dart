// Brand-migrated header for Rekap Nilai overview.
//
// Replaces the legacy `TeacherPageHeader` with `BrandPageHeader` +
// 3-cell KPI overlay (Mata Pelajaran · Kelas · Rata-rata),
// `RoleToggleChipRow` for wali/mengajar (when applicable), and a
// `BrandFilterChipStrip` for class/subject filter affordance.
//
// PER UX REQUEST: no view-toggle. The overview always renders as the
// dense list (Frame B) — matrix view has been retired.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_role_options.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';

mixin GradeRecapBrandHeaderMixin on ConsumerState<GradeRecapOverviewPage> {
  /// Brand header — title + green realtime dot, optional role chip
  /// row (only when the teacher is also a wali kelas), filter chips
  /// in the bottom slot, tune icon with badge in actionIcons.
  Widget buildBrandHeader(LanguageProvider lp) {
    return BrandPageHeader(
      role: 'guru',
      title: lp.getTranslatedText({'en': 'Grade Recap', 'id': 'Rekap Nilai'}),
      subtitle: lp.getTranslatedText({
        'en': 'Academic · Grades',
        'id': 'Akademik · Nilai',
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

  Widget? _buildRoleSelector(LanguageProvider lp) {
    final teacherState = ref.watch(teacherRiverpod);
    final homeroomClasses = teacherState.homeroomClasses;
    if (homeroomClasses.isEmpty) return null;

    // Selected id mirrors the multi-wali pattern used by Presensi /
    // Kegiatan Kelas: `wali:<classId>` when a specific homeroom class
    // is active, otherwise `mengajar`.
    final selectedId = isHomeroomView && filterClassId != null
        ? 'wali:$filterClassId'
        : 'mengajar';

    return RoleToggleChipRow(
      roles: buildMultiWaliRoleOptions(
        homeroomClasses: homeroomClasses,
        lp: lp,
      ),
      selectedRoleId: selectedId,
      accentColor: ColorUtils.brandCobalt,
      onSelected: (id) {
        if (id == 'mengajar') {
          if (!isHomeroomView &&
              filterClassId == null &&
              filterSubjectId == null) {
            return;
          }
          setState(() {
            isHomeroomView = false;
            filterClassId = null;
            filterClassName = null;
            filterSubjectId = null;
            filterSubjectName = null;
          });
          loadData();
        } else if (id.startsWith('wali:')) {
          final classId = id.substring(5);
          // Resolve the picked homeroom class so we can stash its
          // human-readable name in the filter state too — the chip
          // strip below the header reads `filterClassName`.
          Map<String, dynamic>? picked;
          for (final c in homeroomClasses) {
            if (c is Map && (c['id'] ?? '').toString() == classId) {
              picked = Map<String, dynamic>.from(c);
              break;
            }
          }
          final pickedName = (picked?['name'] ?? picked?['nama'] ?? '')
              .toString();
          if (isHomeroomView && filterClassId == classId) return;
          setState(() {
            isHomeroomView = true;
            filterClassId = classId;
            filterClassName = pickedName;
            filterSubjectId = null;
            filterSubjectName = null;
          });
          loadData();
        }
      },
    );
  }

  /// Two filter chips — Kelas + Mapel — both opening the same filter
  /// sheet. Each chip shows its current value when set, "+ Label"
  /// placeholder otherwise.
  List<BrandFilterChip> _buildFilterChips(LanguageProvider lp) {
    void tap() => showFilterDialog(lp);
    return [
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
        value: filterClassName,
        onTap: tap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}),
        value: filterSubjectName,
        onTap: tap,
      ),
    ];
  }

  /// 3-cell KPI overlap card — Mata Pelajaran · Kelas · Rata-rata.
  /// Reads from the backend `summary` block when present, falls back
  /// to client-side aggregates over `groupedData` so cold-start +
  /// legacy cached responses still render meaningful values.
  Widget buildBrandKpiCard(LanguageProvider lp) {
    final stats = _resolveKpiStats();
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
                'en': 'Subjects',
                'id': 'Mata Pelajaran',
              }),
              value: '${stats.subjectCount}',
              color: ColorUtils.info600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Classes', 'id': 'Kelas'}),
              value: '${stats.classCount}',
              color: ColorUtils.violet700,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({
                'en': 'Avg score',
                'id': 'Rata-rata',
              }),
              value: stats.avgScore == null
                  ? '—'
                  : stats.avgScore!.toStringAsFixed(0),
              color: ColorUtils.success600,
            ),
          ],
        ),
      ),
    );
  }

  _BrandKpiStats _resolveKpiStats() {
    // Prefer backend-computed totals so they stay accurate under any
    // future client-side pagination/filtering.
    final summary = recapSummary;
    int? subjectCount = (summary['total_subjects'] as num?)?.toInt();
    int? classCount = (summary['total_classes'] as num?)?.toInt();
    double? avg = (summary['overall_avg_score'] as num?)?.toDouble();

    if (subjectCount == null || classCount == null || avg == null) {
      // Fall back to aggregates derived from the loaded groupedData.
      final seenSubjects = <String>{};
      double scoreSum = 0;
      int scoreCount = 0;
      for (final g in groupedData) {
        if (g is! Map) continue;
        final subjects = (g['subjects'] as List?) ?? [];
        for (final s in subjects) {
          if (s is! Map) continue;
          final sid = (s['id'] ?? '').toString();
          if (sid.isNotEmpty) seenSubjects.add(sid);
          final a = s['avg_final_score'] ?? s['avg_score'];
          if (a is num) {
            scoreSum += a.toDouble();
            scoreCount++;
          }
        }
      }
      subjectCount ??= seenSubjects.length;
      classCount ??= groupedData.length;
      avg ??= scoreCount > 0 ? (scoreSum / scoreCount) : null;
    }

    return _BrandKpiStats(
      subjectCount: subjectCount,
      classCount: classCount,
      avgScore: avg,
    );
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _kpiDivider() =>
      Container(width: 1, height: 28, color: ColorUtils.slate100);

  // Required state accessors — provided by sibling mixins.
  late TextEditingController searchController;
  late bool isHomeroomView;
  late String? filterClassId;
  late String? filterClassName;
  late String? filterSubjectId;
  late String? filterSubjectName;
  late int activeFilterCount;
  Map<String, dynamic> get recapSummary;
  List<dynamic> get groupedData;

  Future<void> loadData({bool useCache = true});
  void showFilterDialog(LanguageProvider lp);
}

class _BrandKpiStats {
  final int subjectCount;
  final int classCount;
  final double? avgScore;
  const _BrandKpiStats({
    required this.subjectCount,
    required this.classCount,
    required this.avgScore,
  });
}
