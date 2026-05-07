// Stateless presentation widgets for the parent report-card detail screen.
//
// Why this exists
// ---------------
// The detail screen used to inline 16 sub-widgets — KPI strip, sikap card,
// per-subject card, ekstra/prestasi cards, attendance breakdown, decision
// banner, and so on — making the file 1700+ lines and hostile to change.
// All of them are stateless and depend only on the rapor payload, so they
// pull cleanly into a single co-located widgets file.
//
// Naming convention
// -----------------
// Each widget is prefixed `ParentRapor` to avoid collisions with the
// admin/teacher rapor screens, which carry their own card families.
// Imports from outside the report-cards feature should be considered
// internal — this file is not a shared design-system surface.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// Hero chip — used in the BrandPageHeader bottomSlot
// =====================================================================

/// Translucent white chip rendered on the brand gradient. The
/// "filled" variant sits at 18% alpha (used for the semester chip);
/// the unfilled variant uses 14% bg + dashed white border (used for
/// UTS / UAS toggle chips). The active state flips the fill so the
/// chip reads as selected without going opaque.
class ParentRaporHeroChip extends StatelessWidget {
  const ParentRaporHeroChip({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.active = false,
    this.width,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool active;
  final double? width;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final fillAlpha = filled ? 0.22 : (active ? 0.32 : 0.14);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          height: 36,
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: fillAlpha),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: filled
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: active ? 0.6 : 0.32),
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Section primitives
// =====================================================================

class ParentRaporSectionHeader extends StatelessWidget {
  const ParentRaporSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate500,
              ),
            ),
        ],
      ),
    );
  }
}

class ParentRaporCardShell extends StatelessWidget {
  const ParentRaporCardShell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: child,
    );
  }
}

class ParentRaporEmptyHint extends StatelessWidget {
  const ParentRaporEmptyHint({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// KPI strip
// =====================================================================

class ParentRaporKpiStrip extends StatelessWidget {
  const ParentRaporKpiStrip({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  double? _avg() {
    final subjects =
        (reportCardData['raportSubjects'] ??
                reportCardData['raport_subjects'] ??
                const [])
            as List<dynamic>;
    if (subjects.isEmpty) return null;
    var sum = 0.0;
    var count = 0;
    for (final raw in subjects) {
      final s = raw as Map;
      final k = _toDouble(s['knowledge_score']);
      final sk = _toDouble(s['skill_score']);
      if (k != null && sk != null) {
        sum += (k + sk) / 2;
        count++;
      } else if (k != null) {
        sum += k;
        count++;
      } else if (sk != null) {
        sum += sk;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  double? _attendance() {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final total = toInt(reportCardData['attendance_total']);
    final sick = toInt(reportCardData['attendance_sick']);
    final permit = toInt(reportCardData['attendance_permit']);
    final absent = toInt(reportCardData['attendance_absent']);
    final present = toInt(reportCardData['attendance_present']);
    final denom = total > 0 ? total : (present + sick + permit + absent);
    if (denom == 0) return null;
    return ((denom - sick - permit - absent) / denom) * 100;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _avgPredikat(double? avg) {
    if (avg == null) return '–';
    if (avg >= 85) return 'Sangat Baik';
    if (avg >= 75) return 'Baik';
    if (avg >= 65) return 'Cukup';
    return 'Perlu Dukungan';
  }

  Color _avgFg(double? avg) {
    if (avg == null) return ColorUtils.slate500;
    if (avg >= 85) return const Color(0xFF15803D);
    if (avg >= 75) return const Color(0xFF1D4ED8);
    if (avg >= 65) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  Color _avgBg(double? avg) {
    if (avg == null) return ColorUtils.slate100;
    if (avg >= 85) return const Color(0xFFDCFCE7);
    if (avg >= 75) return const Color(0xFFDBEAFE);
    if (avg >= 65) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avg();
    final att = _attendance();
    final sikap =
        (reportCardData['social_predicate'] ??
                reportCardData['spiritual_predicate'] ??
                '')
            .toString();

    return ParentRaporCardShell(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: _kpiCell(
              label: 'Rata-rata',
              value: avg == null
                  ? '–'
                  : avg.toStringAsFixed(1).replaceAll('.', ','),
              accent: _avgFg(avg),
              pillBg: _avgBg(avg),
              pillFg: _avgFg(avg),
              pillText: _avgPredikat(avg),
            ),
          ),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(
            child: _kpiCell(
              label: 'Sikap',
              value: _sikapLetter(sikap),
              accent: _sikapAccent(sikap),
              pillBg: _sikapBg(sikap),
              pillFg: _sikapAccent(sikap),
              pillText: sikap.isEmpty ? '–' : sikap,
            ),
          ),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(
            child: _kpiCell(
              label: 'Kehadiran',
              value: att == null ? '–' : '${att.toStringAsFixed(0)}%',
              accent: att == null
                  ? ColorUtils.slate500
                  : (att >= 90
                        ? const Color(0xFF15803D)
                        : (att >= 80
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFB45309))),
              pillBg: att == null
                  ? ColorUtils.slate100
                  : (att >= 90
                        ? const Color(0xFFDCFCE7)
                        : (att >= 80
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFFEF3C7))),
              pillFg: att == null
                  ? ColorUtils.slate500
                  : (att >= 90
                        ? const Color(0xFF15803D)
                        : (att >= 80
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFB45309))),
              pillText: att == null ? '–' : 'Hadir reguler',
            ),
          ),
        ],
      ),
    );
  }

  String _sikapLetter(String pred) {
    if (pred.isEmpty) return '–';
    final p = pred.toLowerCase();
    if (p.contains('sangat baik')) return 'A';
    if (p.contains('baik')) return 'B';
    if (p.contains('cukup')) return 'C';
    return 'D';
  }

  Color _sikapAccent(String pred) {
    final l = _sikapLetter(pred);
    if (l == 'A') return const Color(0xFF15803D);
    if (l == 'B') return const Color(0xFF1D4ED8);
    if (l == 'C') return const Color(0xFFB45309);
    return ColorUtils.slate500;
  }

  Color _sikapBg(String pred) {
    final l = _sikapLetter(pred);
    if (l == 'A') return const Color(0xFFDCFCE7);
    if (l == 'B') return const Color(0xFFDBEAFE);
    if (l == 'C') return const Color(0xFFFEF3C7);
    return ColorUtils.slate100;
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color accent,
    required Color pillBg,
    required Color pillFg,
    required String pillText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            height: 1.1,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
          ),
          child: Text(
            pillText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: pillFg,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Sikap card
// =====================================================================

class ParentRaporSikapCard extends StatelessWidget {
  const ParentRaporSikapCard({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            label: 'Spiritual',
            predikat: (reportCardData['spiritual_predicate'] ?? '–').toString(),
            description: (reportCardData['spiritual_description'] ?? '')
                .toString(),
            bg: const Color(0xFFEDE9FE),
            fg: const Color(0xFF7C3AED),
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: ColorUtils.slate100),
          const SizedBox(height: 12),
          _row(
            label: 'Sosial',
            predikat: (reportCardData['social_predicate'] ?? '–').toString(),
            description: (reportCardData['social_description'] ?? '')
                .toString(),
            bg: const Color(0xFFDBEAFE),
            fg: const Color(0xFF1D4ED8),
            icon: Icons.people_alt_outlined,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String label,
    required String predikat,
    required String description,
    required Color bg,
    required Color fg,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: fg),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                predikat.isEmpty ? '–' : predikat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Subject card with knowledge/skill split + KKM verdict
// =====================================================================

class ParentRaporSubjectCard extends StatelessWidget {
  const ParentRaporSubjectCard({super.key, required this.subject});

  final Map subject;

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = (subject['subject'] is Map)
        ? ((subject['subject'] as Map)['name']?.toString() ?? 'Mata Pelajaran')
        : 'Mata Pelajaran';
    final teacher =
        (subject['teacher_name'] ??
                (subject['subject'] is Map
                    ? (subject['subject'] as Map)['teacher_name']
                    : null) ??
                '')
            .toString();
    final predikat =
        (subject['knowledge_predicate'] ?? subject['skill_predicate'] ?? '–')
            .toString();

    final knowledge = _toDouble(subject['knowledge_score']);
    final skill = _toDouble(subject['skill_score']);
    final kkm = _toDouble(subject['kkm']) ?? 75;

    final letter = _bandLetter(_avgOf(knowledge, skill));
    final palette = _letterPalette(letter);

    final knowledgeFailing = knowledge != null && knowledge < kkm;
    final skillFailing = skill != null && skill < kkm;
    final allFailing = knowledgeFailing && skillFailing;
    final partialFailing = !allFailing && (knowledgeFailing || skillFailing);

    return ParentRaporCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.fg,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (teacher.isNotEmpty) teacher,
                        if (predikat.trim().isNotEmpty && predikat != '–')
                          predikat,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: ColorUtils.slate500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _scoreCell(
                  label: 'Pengetahuan',
                  score: knowledge,
                  failing: knowledgeFailing,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _scoreCell(
                  label: 'Keterampilan',
                  score: skill,
                  failing: skillFailing,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            allFailing
                ? 'KKM ${kkm.toStringAsFixed(0)} · Belum tuntas'
                : partialFailing
                ? 'KKM ${kkm.toStringAsFixed(0)} · Belum tuntas '
                      '(${knowledgeFailing ? 'pengetahuan' : 'keterampilan'})'
                : 'KKM ${kkm.toStringAsFixed(0)} · Tuntas',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: (allFailing || partialFailing)
                  ? const Color(0xFFB91C1C)
                  : ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreCell({
    required String label,
    required double? score,
    required bool failing,
  }) {
    final text = score == null ? '–' : score.toStringAsFixed(0);
    final fg = failing
        ? const Color(0xFFB91C1C)
        : (score == null ? ColorUtils.slate500 : _bandFg(_bandLetter(score)));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  double _avgOf(double? a, double? b) {
    if (a != null && b != null) return (a + b) / 2;
    return a ?? b ?? 0;
  }

  String _bandLetter(double v) {
    if (v >= 90) return 'A';
    if (v >= 80) return 'B';
    if (v >= 70) return 'C';
    if (v >= 60) return 'D';
    return 'E';
  }

  ({Color bg, Color fg}) _letterPalette(String letter) {
    switch (letter) {
      case 'A':
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
      case 'B':
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case 'C':
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
      case 'D':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
      default:
        return (bg: ColorUtils.slate100, fg: ColorUtils.slate500);
    }
  }

  Color _bandFg(String letter) => _letterPalette(letter).fg;
}

// =====================================================================
// Ekstrakurikuler / Prestasi cards
// =====================================================================

class ParentRaporExtrasCard extends StatelessWidget {
  const ParentRaporExtrasCard({super.key, required this.extras});

  final List<dynamic> extras;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Column(
        children: [
          for (var i = 0; i < extras.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: ColorUtils.slate100),
              const SizedBox(height: 10),
            ],
            _row(extras[i] as Map),
          ],
        ],
      ),
    );
  }

  Widget _row(Map ex) {
    final score = (ex['score'] ?? '').toString().trim();
    final palette = score.isEmpty
        ? (bg: ColorUtils.slate100, fg: ColorUtils.slate500)
        : _palette(score);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(
            score.isEmpty ? '–' : score.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.fg,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (ex['name'] ?? 'Ekstrakurikuler').toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              if ((ex['description'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ex['description'].toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  ({Color bg, Color fg}) _palette(String score) {
    final s = score.toUpperCase();
    if (s.startsWith('A')) {
      return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
    }
    if (s.startsWith('B')) {
      return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
    }
    return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
  }
}

class ParentRaporAchievementsCard extends StatelessWidget {
  const ParentRaporAchievementsCard({super.key, required this.achievements});

  final List<dynamic> achievements;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Column(
        children: [
          for (var i = 0; i < achievements.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: ColorUtils.slate100),
              const SizedBox(height: 12),
            ],
            _row(achievements[i] as Map),
          ],
        ],
      ),
    );
  }

  Widget _row(Map ach) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.emoji_events_rounded,
            size: 16,
            color: const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((ach['type'] ?? '').toString().trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    ach['type'].toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                (ach['name'] ?? 'Prestasi').toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              if ((ach['description'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ach['description'].toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Attendance breakdown
// =====================================================================

class ParentRaporAttendanceCard extends StatelessWidget {
  const ParentRaporAttendanceCard({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final sick = _toInt(reportCardData['attendance_sick']);
    final permit = _toInt(reportCardData['attendance_permit']);
    final absent = _toInt(reportCardData['attendance_absent']);
    final total = _toInt(reportCardData['attendance_total']);
    final presentRaw = _toInt(reportCardData['attendance_present']);
    final present = total > 0 ? (total - sick - permit - absent) : presentRaw;

    return ParentRaporCardShell(
      child: Row(
        children: [
          Expanded(child: _cell('Hadir', present, const Color(0xFF15803D))),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(child: _cell('Sakit', sick, ColorUtils.slate900)),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(child: _cell('Izin', permit, ColorUtils.slate900)),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(
            child: _cell(
              'Alpa',
              absent,
              absent > 0 ? const Color(0xFFB91C1C) : ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, int value, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'hari',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate400,
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Notes / Decision
// =====================================================================

class ParentRaporNotesCard extends StatelessWidget {
  const ParentRaporNotesCard({
    super.key,
    required this.notes,
    required this.teacher,
  });

  final String notes;
  final String teacher;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 64,
            decoration: BoxDecoration(
              color: ColorUtils.brandAzureDeep,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notes,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate900,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '— $teacher',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParentRaporDecisionBanner extends StatelessWidget {
  const ParentRaporDecisionBanner({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  @override
  Widget build(BuildContext context) {
    final raw = (reportCardData['promotion_decision'] ?? '').toString().trim();
    if (raw.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: ColorUtils.slate200, width: 0.75),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 20,
              color: ColorUtils.slate500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keputusan kenaikan kelas belum diumumkan oleh sekolah.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final palette = _palette(raw);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: palette.fg, width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(palette.icon, size: 18, color: palette.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KEPUTUSAN KENAIKAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.fg,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  raw,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.titleFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color border, Color fg, Color titleFg, IconData icon}) _palette(
    String decision,
  ) {
    final l = decision.toLowerCase();
    if (l.contains('tinggal') || l.contains('tidak naik')) {
      return (
        bg: const Color(0xFFFEE2E2),
        border: const Color(0xFFFCA5A5),
        fg: const Color(0xFFB91C1C),
        titleFg: const Color(0xFF7F1D1D),
        icon: Icons.cancel_outlined,
      );
    }
    if (l.contains('pertimbangan') || l.contains('belum')) {
      return (
        bg: const Color(0xFFFEF3C7),
        border: const Color(0xFFFCD34D),
        fg: const Color(0xFFB45309),
        titleFg: const Color(0xFF78350F),
        icon: Icons.help_outline_rounded,
      );
    }
    return (
      bg: const Color(0xFFDCFCE7),
      border: const Color(0xFF86EFAC),
      fg: const Color(0xFF15803D),
      titleFg: const Color(0xFF14532D),
      icon: Icons.check_rounded,
    );
  }
}

class ParentRaporGanjilDecisionNote extends StatelessWidget {
  const ParentRaporGanjilDecisionNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ColorUtils.brandAzureDeep,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keputusan kenaikan kelas',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.brandAzureDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Akan diumumkan oleh sekolah setelah Semester Genap. '
                  'Rapor Semester Ganjil hanya menampilkan capaian tengah tahun.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParentRaporExportNote extends StatelessWidget {
  const ParentRaporExportNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Text(
        'Rapor ini hanya tampilan ringkas. Untuk dokumen resmi sekolah, '
        'unduh PDF.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ColorUtils.slate500,
          height: 1.5,
        ),
      ),
    );
  }
}

// =====================================================================
// Bottom action bar
// =====================================================================

class ParentRaporBottomActionBar extends StatelessWidget {
  const ParentRaporBottomActionBar({
    super.key,
    required this.onShare,
    required this.onPrint,
  });

  final VoidCallback onShare;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: ColorUtils.slate700,
                ),
                label: Text(
                  'Bagikan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ColorUtils.slate200),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onPrint,
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'Cetak PDF',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.brandAzureDeep,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
