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
          subtitle: searchController.text.isNotEmpty || activeFilterCount > 0
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
            countLabel: lp.getTranslatedText({'en': 'classes', 'id': 'kelas'}),
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

  /// Three-band card: identity (avatar + name + class + status tag) →
  /// sub-row (siswa count + optional teacher name) → stats grid (Bab ·
  /// Nilai · Rata-rata) → progress band (bar + % or "Mulai input" CTA
  /// when empty). Mirrors `_design/teacher_grade_recap_card_redesign.html`.
  Widget _buildRow(_FlatItem item, LanguageProvider lp) {
    final sn = Subject.fromJson(Map<String, dynamic>.from(item.subject)).name;
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
    // Total numeric grade entries — added to s4 of the backend
    // response. Distinct from `recap_count` (students with any
    // entry): a class with 22 students × 1 bab = 22 entries, but
    // 22 students × 8 bab = 176 entries. Drives the "Nilai" stat
    // and the bab-tuntas saturation check.
    final entriesCount = ((item.subject['entries_count'] ?? 0) as num).toInt();
    final teacherName = isHomeroomView
        ? _subjectTeacherName(item.subject)
        : null;

    final hasData = entriesCount > 0;
    // Saturation: how full is the (students × bab) matrix?
    // 1.0 = every student × every bab has a number.
    final saturation = (totalStudents > 0 && babCount > 0)
        ? entriesCount / (totalStudents * babCount)
        : 0.0;
    final progressTone = _progressTone(saturation * 100, hasData);
    final status = _statusFor(
      hasData: hasData,
      completionPct: completionPct,
      entriesCount: entriesCount,
      totalStudents: totalStudents,
      babCount: babCount,
      lp: lp,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => openRecapTable(item.classData, item.subject),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(initial, spec),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _identityBand(sn, item.className, status),
                      // Sub-row only appears in wali-kelas view to
                      // surface the subject teacher; the siswa count
                      // moves into the stats grid so we save a row in
                      // the default mengajar view.
                      if (teacherName != null) ...[
                        const SizedBox(height: 3),
                        _subRow(teacherName),
                      ],
                      const SizedBox(height: 8),
                      _statsGrid(
                        babCount: babCount,
                        entriesCount: entriesCount,
                        totalStudents: totalStudents,
                        avg: avg,
                        progressTone: progressTone,
                        lp: lp,
                      ),
                      const SizedBox(height: 8),
                      _progressBand(
                        saturation * 100,
                        hasData,
                        progressTone,
                        lp,
                      ),
                    ],
                  ),
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
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 17,
          color: spec.fg,
        ),
      ),
    );
  }

  /// Identity band — subject name + slate class pill + single status tag.
  /// Status tag drops the noisy multi-pill "Perlu input" alarm in favor
  /// of a calm, single signal: Belum mulai / Sebagian / Hampir tuntas /
  /// Tuntas.
  Widget _identityBand(String name, String className, _StatusSpec status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  className,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _statusTag(status),
      ],
    );
  }

  Widget _statusTag(_StatusSpec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        spec.label.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: spec.fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Sub-row — wali-kelas-only subject teacher line (inline person
  /// icon + name). The siswa count was dropped here because it now
  /// lives inside the stats grid as the Bab denominator, so the
  /// default mengajar card stays one row tighter.
  Widget _subRow(String teacherName) {
    return Row(
      children: [
        Icon(Icons.person_rounded, size: 12, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Flexible(
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

  /// Stats grid — 3 cells (Bab · Nilai · Rata-rata) with hairline
  /// dividers, on a soft slate-50 chip.
  ///
  /// "Nilai" now shows `entries_count` — the literal number of grade
  /// entries (not students-with-any-entry). Resolves the ambiguity the
  /// teacher flagged where 22 siswa × 1 bab and 22 siswa × 8 bab both
  /// reported "22 nilai". Bab cell shows "1/8" when only some bab are
  /// fully filled (entries_count divisible by total_students), giving
  /// teachers the at-a-glance "X bab tuntas" they asked for.
  Widget _statsGrid({
    required int babCount,
    required int entriesCount,
    required int totalStudents,
    required double? avg,
    required _ProgressTone progressTone,
    required LanguageProvider lp,
  }) {
    final isEmpty = progressTone.kind == _ProgressKind.empty;

    // "X / Y bab" when entries cleanly divide by class size — that
    // means X chapters are scored for everyone. Otherwise show the
    // total bab count alone.
    final babFilled = (totalStudents > 0 && entriesCount > 0)
        ? entriesCount ~/ totalStudents
        : 0;
    final babCleanFill =
        totalStudents > 0 &&
        entriesCount > 0 &&
        entriesCount % totalStudents == 0 &&
        babFilled <= babCount &&
        babCount > 0;
    final babValue = babCleanFill ? '$babFilled/$babCount' : '$babCount';
    final babColor = babCleanFill
        ? (babFilled == babCount
              ? ColorUtils.success600
              : ColorUtils.warning600)
        : ColorUtils.slate900;

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _statCell(
            value: babValue,
            label: lp.getTranslatedText({'en': 'Chapters', 'id': 'Bab'}),
            color: babColor,
          ),
          _statDivider(),
          _statCell(
            value: '$entriesCount',
            label: lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}),
            color: isEmpty ? ColorUtils.slate400 : progressTone.color,
          ),
          _statDivider(),
          _statCell(
            value: avg == null ? '—' : avg.toStringAsFixed(0),
            label: lp.getTranslatedText({'en': 'Avg score', 'id': 'Rata-rata'}),
            color: avg == null ? ColorUtils.slate400 : progressTone.color,
          ),
        ],
      ),
    );
  }

  Widget _statCell({
    required String value,
    required String label,
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
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(
    width: 1,
    height: 26,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: ColorUtils.slate200,
  );

  /// Progress band — paired bar + % when there's data, striped muted bar
  /// + "Mulai input ›" CTA when empty so the card reads as actionable
  /// rather than broken.
  Widget _progressBand(
    double pct,
    bool hasData,
    _ProgressTone tone,
    LanguageProvider lp,
  ) {
    if (!hasData) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: ColorUtils.slate100,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lp.getTranslatedText({
                  'en': 'Start input',
                  'id': 'Mulai input',
                }),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandCobalt,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: ColorUtils.brandCobalt,
              ),
            ],
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              color: ColorUtils.slate100,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                child: Container(color: tone.color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${pct.round()}%',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: tone.color,
          ),
        ),
      ],
    );
  }

  /// Tone for a row — drives stats colors + progress fill. `empty` is
  /// slate (not red) so a fresh card doesn't look like an alarm.
  _ProgressTone _progressTone(double pct, bool hasData) {
    if (!hasData) {
      return _ProgressTone(_ProgressKind.empty, ColorUtils.slate400);
    }
    if (pct >= 80) {
      return _ProgressTone(_ProgressKind.good, ColorUtils.success600);
    }
    if (pct >= 40) {
      return _ProgressTone(_ProgressKind.warn, ColorUtils.warning600);
    }
    return _ProgressTone(_ProgressKind.alert, ColorUtils.error600);
  }

  /// Status tag spec — picked based on the (students × bab) saturation
  /// matrix, not just completion_pct. Resolves the misleading "Tuntas"
  /// the teacher flagged: when every student has at least 1 bab entry
  /// the old logic showed Tuntas, even though only 1 of 8 bab was
  /// actually filled.
  ///
  ///   • 0 entries                                → "Belum mulai"
  ///   • Bab cleanly tuntas (e.g. 1/8 of 8 bab)    → "X bab tuntas"
  ///     (gives the teacher a precise "I've done 1 bab" signal —
  ///      green when complete, amber while in-progress)
  ///   • Some students still untouched             → "Sebagian"
  ///   • All bab × all students                    → "Tuntas"
  _StatusSpec _statusFor({
    required bool hasData,
    required double completionPct,
    required int entriesCount,
    required int totalStudents,
    required int babCount,
    required LanguageProvider lp,
  }) {
    if (!hasData) {
      return _StatusSpec(
        label: lp.getTranslatedText({'en': 'Not started', 'id': 'Belum mulai'}),
        tint: ColorUtils.slate100,
        fg: ColorUtils.slate600,
      );
    }

    final fullSaturation = totalStudents > 0 && babCount > 0
        ? entriesCount == totalStudents * babCount
        : false;
    if (fullSaturation) {
      return _StatusSpec(
        label: lp.getTranslatedText({'en': 'Done', 'id': 'Tuntas'}),
        tint: ColorUtils.success600.withValues(alpha: 0.12),
        fg: ColorUtils.success600,
      );
    }

    // Bab cleanly filled: entries divides evenly by class size and the
    // ratio fits inside bab_count. e.g. 22 students × 1 bab = 22
    // entries → "1 bab tuntas" (1 chapter is fully scored for all
    // students).
    final babFilled = totalStudents > 0 ? entriesCount ~/ totalStudents : 0;
    final babCleanFill =
        totalStudents > 0 &&
        entriesCount > 0 &&
        entriesCount % totalStudents == 0 &&
        babFilled > 0 &&
        babFilled <= babCount;
    if (babCleanFill) {
      return _StatusSpec(
        label: lp.getTranslatedText({
          'en': '$babFilled bab done',
          'id': '$babFilled bab tuntas',
        }),
        tint: ColorUtils.success600.withValues(alpha: 0.12),
        fg: ColorUtils.success600,
      );
    }

    // Otherwise — partial: at least one bab has a missing student
    // entry. Amber signals "still in progress, not all-students yet".
    return _StatusSpec(
      label: lp.getTranslatedText({'en': 'Partial', 'id': 'Sebagian'}),
      tint: ColorUtils.warning600.withValues(alpha: 0.12),
      fg: ColorUtils.warning600,
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
      return const _SubjectColor(
        tint: Color(0xFFFFE4E6),
        fg: Color(0xFFBE185D),
      );
    }
    if (lower.contains('pkn') ||
        lower.contains('agama') ||
        lower.contains('ppkn')) {
      return const _SubjectColor(
        tint: Color(0xFFE0E7FF),
        fg: Color(0xFF4338CA),
      );
    }
    // Hash-based fallback so unrecognised names still get a stable color.
    final palette = [
      _SubjectColor(tint: const Color(0xFFDBEAFE), fg: ColorUtils.info600),
      _SubjectColor(tint: const Color(0xFFEDE9FE), fg: ColorUtils.violet700),
      _SubjectColor(tint: const Color(0xFFDCFCE7), fg: ColorUtils.success600),
      _SubjectColor(tint: const Color(0xFFFEF3C7), fg: ColorUtils.warning600),
      const _SubjectColor(tint: Color(0xFFE0E7FF), fg: Color(0xFF4338CA)),
    ];
    final h = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[h % palette.length];
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

/// Drives the row's stats colors + progress fill. `empty` is the slate
/// "not started" state — kept distinct from `alert` so a fresh card
/// reads as ready-for-input, not as an error condition.
enum _ProgressKind { empty, alert, warn, good }

class _ProgressTone {
  final _ProgressKind kind;
  final Color color;
  const _ProgressTone(this.kind, this.color);
}

/// Single-pill status surfaced in the identity band — replaces the noisy
/// "Perlu input" multi-pill alarm with a calm one-shot signal.
class _StatusSpec {
  final String label;
  final Color tint;
  final Color fg;
  const _StatusSpec({
    required this.label,
    required this.tint,
    required this.fg,
  });
}
