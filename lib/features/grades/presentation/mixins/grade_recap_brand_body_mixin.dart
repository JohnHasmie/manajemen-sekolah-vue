// Brand-migrated body for Rekap Nilai overview — LIST ONLY.
//
// Replaces the legacy `TeacherAsyncView` + matrix-toggle wrapper with
// an explicit state-branching Column that fits inside
// `BrandPageLayout.bodyChildren`. Mirrors the same pattern Presensi
// and Kegiatan Kelas use:
//   • loading + empty → skeleton
//   • error           → AppErrorState
//   • empty           → EmptyState (fixed height)
//   • data            → Column of subject·class cards
//
// Each row matches Frame B from `_design/teacher_grade_recap_mockup.html`:
// subject letter avatar (color-rotated by subject family), name + class
// pill, progress bar with percentage, meta pills (Bab N · X nilai · Y siswa
// · "Perlu input" warning when behind), avg score badge, chevron.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

mixin GradeRecapBrandBodyMixin on ConsumerState<GradeRecapOverviewPage> {
  Widget buildBrandBody(LanguageProvider lp) {
    if (isLoading && groupedData.isEmpty && recapErrorMessage == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SkeletonListLoading(
          itemCount: 5,
          infoTagCount: 2,
          showActions: false,
          shrinkWrap: true,
        ),
      );
    }
    if (recapErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: AppErrorState(
          message: recapErrorMessage,
          onRetry: refresh,
          role: 'guru',
        ),
      );
    }
    final data = filteredData;
    if (data.isEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          title: isHomeroomView
              ? lp.getTranslatedText({
                  'en': 'No Homeroom Class',
                  'id': 'Bukan Wali Kelas',
                })
              : lp.getTranslatedText({
                  'en': 'No Classes Found',
                  'id': 'Tidak Ada Kelas',
                }),
          subtitle:
              searchController.text.isNotEmpty || activeFilterCount > 0
              ? lp.getTranslatedText({
                  'en': 'No classes match your filter',
                  'id': 'Tidak ada kelas sesuai filter',
                })
              : lp.getTranslatedText({
                  'en': 'No teaching assignments found',
                  'id': 'Tidak ada jadwal mengajar',
                }),
          icon: isHomeroomView
              ? Icons.class_outlined
              : Icons.assessment_outlined,
        ),
      );
    }

    // Flatten (class, subject) pairs → one row per pair, sorted so the
    // most actionable rows (low completion %) bubble to the top.
    final flat = <_FlatItem>[];
    for (final g in data) {
      if (g is! Map) continue;
      final cn = g['class_name']?.toString() ?? '-';
      final subjects = (g['subjects'] as List?) ?? [];
      for (final s in subjects) {
        if (s is! Map) continue;
        flat.add(
          _FlatItem(
            classData: Map<String, dynamic>.from(g),
            subject: Map<String, dynamic>.from(s),
            className: cn,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHead(
            title: isHomeroomView
                ? lp.getTranslatedText({
                    'en': 'Homeroom · all subjects',
                    'id': 'Wali Kelas · semua mapel',
                  })
                : lp.getTranslatedText({
                    'en': 'Teaching · all classes',
                    'id': 'Mengajar · semua kelas',
                  }),
            count: flat.length,
            countLabel: lp.getTranslatedText({
              'en': 'classes',
              'id': 'kelas',
            }),
          ),
          const SizedBox(height: 4),
          for (final item in flat) _buildRow(item, lp),
        ],
      ),
    );
  }

  Widget _sectionHead({
    required String title,
    required int count,
    required String countLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            '$count $countLabel',
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_FlatItem item, LanguageProvider lp) {
    final sn = Subject.fromJson(
      Map<String, dynamic>.from(item.subject),
    ).name;
    final initial = sn.isNotEmpty ? sn[0].toUpperCase() : '?';
    final spec = _subjectColor(sn);

    final recapCount = ((item.subject['recap_count'] ?? 0) as num).toInt();
    final totalStudents = ((item.subject['total_students'] ?? 0) as num)
        .toInt();
    final completionPct = ((item.subject['completion_pct'] ?? 0) as num)
        .toDouble();
    final avg = item.subject['avg_final_score'] is num
        ? (item.subject['avg_final_score'] as num).toDouble()
        : (item.subject['avg_score'] is num
              ? (item.subject['avg_score'] as num).toDouble()
              : null);
    final babCount = ((item.subject['bab_count'] ?? 0) as num).toInt();
    final teacherName = isHomeroomView
        ? _subjectTeacherName(item.subject)
        : null;

    final pctColor = _progressColor(completionPct);
    final classPillTint = completionPct < 40
        ? ColorUtils.error600
        : ColorUtils.info600;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => openRecapTable(item.classData, item.subject),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _avatar(initial, spec),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _headLine(sn, item.className, classPillTint),
                      if (teacherName != null) ...[
                        const SizedBox(height: 4),
                        _teacherLine(teacherName),
                      ],
                      const SizedBox(height: 6),
                      _progressLine(completionPct, pctColor),
                      const SizedBox(height: 6),
                      _metaLine(
                        babCount: babCount,
                        recapCount: recapCount,
                        totalStudents: totalStudents,
                        completionPct: completionPct,
                        lp: lp,
                      ),
                    ],
                  ),
                ),
                if (avg != null) ...[
                  const SizedBox(width: 8),
                  _scoreBadge(avg),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorUtils.slate300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String initial, _SubjectColor spec) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: spec.fg,
        ),
      ),
    );
  }

  Widget _headLine(String name, String className, Color classPillTint) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: classPillTint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            className,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: classPillTint,
            ),
          ),
        ),
      ],
    );
  }

  Widget _teacherLine(String teacherName) {
    return Row(
      children: [
        Icon(
          Icons.person_rounded,
          size: 12,
          color: ColorUtils.slate400,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            teacherName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressLine(double pct, Color color) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 5,
              color: ColorUtils.slate100,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${pct.round()}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _metaLine({
    required int babCount,
    required int recapCount,
    required int totalStudents,
    required double completionPct,
    required LanguageProvider lp,
  }) {
    final pills = <Widget>[
      if (babCount > 0)
        _pill(
          label: '${babCount} ${lp.getTranslatedText({"en": "ch", "id": "bab"})}',
          tint: ColorUtils.slate100,
          fg: ColorUtils.slate600,
        ),
      _pill(
        label:
            '$recapCount ${lp.getTranslatedText({"en": "grades", "id": "nilai"})}',
        tint: completionPct >= 80
            ? ColorUtils.success600.withValues(alpha: 0.12)
            : (completionPct < 40
                  ? ColorUtils.error600.withValues(alpha: 0.12)
                  : ColorUtils.warning600.withValues(alpha: 0.12)),
        fg: completionPct >= 80
            ? ColorUtils.success600
            : (completionPct < 40
                  ? ColorUtils.error600
                  : ColorUtils.warning600),
      ),
      _pill(
        label:
            '$totalStudents ${lp.getTranslatedText({"en": "students", "id": "siswa"})}',
        tint: ColorUtils.slate100,
        fg: ColorUtils.slate600,
      ),
      if (completionPct < 40)
        _pill(
          label: lp.getTranslatedText({
            'en': 'Needs input',
            'id': 'Perlu input',
          }),
          tint: ColorUtils.error600.withValues(alpha: 0.12),
          fg: ColorUtils.error600,
        ),
    ];
    return Wrap(spacing: 6, runSpacing: 4, children: pills);
  }

  Widget _pill({
    required String label,
    required Color tint,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _scoreBadge(double score) {
    final color = _scoreColor(score);
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'avg',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.78),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Color-rotation by subject family — same vibe as the mockup so a
  /// teacher sees consistent tints (Math = blue, Sci = violet, …)
  /// across surfaces.
  _SubjectColor _subjectColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('mat') || lower.contains('math')) {
      return _SubjectColor(
        tint: const Color(0xFFDBEAFE),
        fg: ColorUtils.info600,
      );
    }
    if (lower.contains('fisik') ||
        lower.contains('phys') ||
        lower.contains('biolog') ||
        lower.contains('kimia')) {
      return _SubjectColor(
        tint: const Color(0xFFEDE9FE),
        fg: ColorUtils.violet700,
      );
    }
    if (lower.contains('indo') ||
        lower.contains('ipa') ||
        lower.contains('ips')) {
      return _SubjectColor(
        tint: const Color(0xFFDCFCE7),
        fg: ColorUtils.success600,
      );
    }
    if (lower.contains('arab') ||
        lower.contains('inggris') ||
        lower.contains('english') ||
        lower.contains('jawa')) {
      return _SubjectColor(
        tint: const Color(0xFFFEF3C7),
        fg: ColorUtils.warning600,
      );
    }
    if (lower.contains('seni') ||
        lower.contains('musik') ||
        lower.contains('art')) {
      return _SubjectColor(
        tint: const Color(0xFFFFE4E6),
        fg: const Color(0xFFBE185D),
      );
    }
    if (lower.contains('pkn') ||
        lower.contains('agama') ||
        lower.contains('ppkn')) {
      return _SubjectColor(
        tint: const Color(0xFFE0E7FF),
        fg: const Color(0xFF4338CA),
      );
    }
    // Hash-based fallback so unrecognised names still get a stable color.
    final palette = [
      _SubjectColor(tint: const Color(0xFFDBEAFE), fg: ColorUtils.info600),
      _SubjectColor(tint: const Color(0xFFEDE9FE), fg: ColorUtils.violet700),
      _SubjectColor(tint: const Color(0xFFDCFCE7), fg: ColorUtils.success600),
      _SubjectColor(tint: const Color(0xFFFEF3C7), fg: ColorUtils.warning600),
      _SubjectColor(tint: const Color(0xFFE0E7FF), fg: const Color(0xFF4338CA)),
    ];
    final h = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[h % palette.length];
  }

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  Color _progressColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  String? _subjectTeacherName(dynamic subject) {
    final raw =
        subject['teacher_name'] ??
        subject['guru_nama'] ??
        (subject['teacher'] is Map ? subject['teacher']['name'] : null);
    final str = raw?.toString().trim();
    if (str == null || str.isEmpty || str == '-') return null;
    return str;
  }

  // Required state accessors — provided by sibling mixins.
  late bool isLoading;
  late bool isHomeroomView;
  late TextEditingController searchController;
  late int activeFilterCount;
  String? get recapErrorMessage;
  List<dynamic> get groupedData;
  List<dynamic> get filteredData;
  Future<void> refresh();
  void openRecapTable(dynamic classData, dynamic subject);
}

class _FlatItem {
  final Map<String, dynamic> classData;
  final Map<String, dynamic> subject;
  final String className;
  _FlatItem({
    required this.classData,
    required this.subject,
    required this.className,
  });
}

class _SubjectColor {
  final Color tint;
  final Color fg;
  const _SubjectColor({required this.tint, required this.fg});
}
