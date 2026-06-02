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
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';

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
    // Backend rename: `raport_subjects` → `report_card_subjects`.
    final subjects =
        (reportCardData['reportCardSubjects'] ??
                reportCardData['report_card_subjects'] ??
                reportCardData['raportSubjects'] ??
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
// Subject card with knowledge (KI 3) / skill (KI 4) dual cells + KKM verdict
// =====================================================================
//
// Layout — matches _design/parent_raport_pengetahuan_ketrampilan_redesign.html
// (Frame 1) 100%. Two score cells side-by-side, each with its own KI tag,
// auto-predikat pill (A/B/C/D), value 22pt, and gradient-tinted background.
// The whole card frame shifts tone based on tuntas / partial / fail.
// =====================================================================

// Brand tokens used across both score cells. Hoisted so they're shared with
// the optional Deskripsi sheet at the bottom of this file.
const Color _kKi3 = Color(0xFF1B6FB8); // brandCobalt — Pengetahuan
const Color _kKi4 = Color(0xFF7C3AED); // violet600 — Keterampilan
const Color _kFailBg = Color(0xFFFEE2E2);
const Color _kFailFg = Color(0xFFB91C1C);
const Color _kFailBorder = Color(0x3FDC2626);
const Color _kPassBg = Color(0xFFDCFCE7);
const Color _kPassFg = Color(0xFF15803D);
const Color _kPassBorder = Color(0x3F16A34A);
const Color _kPartialBg = Color(0xFFFEF3C7);
const Color _kPartialFg = Color(0xFFB45309);
const Color _kPartialBorder = Color(0x3FD97706);

// Predikat → pill colors. Letter band derived from score using ≥90/≥80/≥70/<70.
({Color bg, Color fg}) _kPredikatPill(String letter) {
  switch (letter) {
    case 'A':
      return (bg: const Color(0xFF16A34A), fg: Colors.white);
    case 'B':
      return (bg: _kKi3, fg: Colors.white);
    case 'C':
      return (bg: const Color(0xFFD97706), fg: Colors.white);
    case 'D':
    case 'E':
      return (bg: const Color(0xFFDC2626), fg: Colors.white);
    default:
      return (bg: ColorUtils.slate200, fg: ColorUtils.slate500);
  }
}

String _kBandLetter(double v) {
  if (v >= 90) return 'A';
  if (v >= 80) return 'B';
  if (v >= 70) return 'C';
  if (v >= 60) return 'D';
  return 'E';
}

({Color bg, Color fg}) _kLetterBadge(String letter) {
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

class ParentRaporSubjectCard extends StatelessWidget {
  const ParentRaporSubjectCard({super.key, required this.subject, this.onTap});

  final Map subject;

  /// Optional tap handler — when set, the whole card becomes tappable and
  /// will typically open [showParentRaporDeskripsiSheet] in the parent
  /// detail screen. Left null on screens that don't want the affordance.
  final VoidCallback? onTap;

  static double? _toDouble(dynamic v) {
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

    final knowledge = _toDouble(subject['knowledge_score']);
    final skill = _toDouble(subject['skill_score']);
    final kkm = _toDouble(subject['kkm']) ?? 75;

    // Predikat — prefer backend-stored letter if present, else compute from
    // the score itself so empty rows still render gracefully.
    final knowledgePredikat = _predikat(
      subject['knowledge_predicate'],
      knowledge,
    );
    final skillPredikat = _predikat(subject['skill_predicate'], skill);

    final knowledgeFailing = knowledge != null && knowledge < kkm;
    final skillFailing = skill != null && skill < kkm;
    final allFailing = knowledgeFailing && skillFailing;
    final partialFailing = !allFailing && (knowledgeFailing || skillFailing);

    // Letter badge averages whatever we have (or falls back to dash).
    final avg = _avgOf(knowledge, skill);
    final letter = avg == null ? '–' : _kBandLetter(avg);
    final letterPalette = letter == '–'
        ? (bg: ColorUtils.slate100, fg: ColorUtils.slate400)
        : _kLetterBadge(letter);

    // Card frame tone shifts: tuntas → green-tinted, partial/fail → red-tinted.
    final hasAnyScore = knowledge != null || skill != null;
    final Color cardBorder;
    final Gradient? cardGradient;
    if (!hasAnyScore) {
      cardBorder = ColorUtils.slate200;
      cardGradient = null;
    } else if (allFailing || partialFailing) {
      cardBorder = const Color(0x47DC2626);
      cardGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFDC2626).withValues(alpha: 0.03), Colors.white],
        stops: const [0.0, 0.6],
      );
    } else {
      cardBorder = const Color(0x4016A34A);
      cardGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF16A34A).withValues(alpha: 0.03), Colors.white],
        stops: const [0.0, 0.65],
      );
    }

    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardGradient == null ? Colors.white : null,
        gradient: cardGradient,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: cardBorder, width: 0.75),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: letter badge + name + meta ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: letterPalette.bg,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: letterPalette.fg,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _metaLine(teacher, knowledgePredikat, skillPredikat),
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
          // ── Score split: KI 3 (cobalt) | KI 4 (violet) ───────────────
          Row(
            children: [
              Expanded(
                child: _ParentRaporScoreCell(
                  ki: 'KI 3',
                  label: 'Pengetahuan',
                  accent: _kKi3,
                  score: knowledge,
                  predikat: knowledgePredikat,
                  failing: knowledgeFailing,
                  kkm: kkm,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ParentRaporScoreCell(
                  ki: 'KI 4',
                  label: 'Keterampilan',
                  accent: _kKi4,
                  score: skill,
                  predikat: skillPredikat,
                  failing: skillFailing,
                  kkm: kkm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Verdict bar: pass / partial / fail / empty ──────────────
          _ParentRaporVerdictBar(
            kkm: kkm,
            knowledgeFailing: knowledgeFailing,
            skillFailing: skillFailing,
            allFailing: allFailing,
            partialFailing: partialFailing,
            hasAnyScore: hasAnyScore,
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: card,
      ),
    );
  }

  String _predikat(dynamic raw, double? score) {
    final stored = (raw ?? '').toString().trim();
    if (stored.isNotEmpty && stored != '–') return stored;
    if (score == null) return '';
    return _kBandLetter(score);
  }

  String _metaLine(String teacher, String kPred, String sPred) {
    // "Pak Andi · Sangat Baik" style. If both predikats present and equal,
    // collapse to one; otherwise show whichever exists.
    final parts = <String>[];
    if (teacher.isNotEmpty) parts.add(teacher);
    final friendly = _friendlyPredikat(kPred, sPred);
    if (friendly.isNotEmpty) parts.add(friendly);
    return parts.join(' · ');
  }

  String _friendlyPredikat(String k, String s) {
    String label(String letter) {
      switch (letter) {
        case 'A':
          return 'Sangat Baik';
        case 'B':
          return 'Baik';
        case 'C':
          return 'Cukup';
        case 'D':
        case 'E':
          return 'Perlu dukungan';
        default:
          return letter; // pass through stored Indonesian phrase
      }
    }

    final kk = k.trim();
    final ss = s.trim();
    if (kk.isEmpty && ss.isEmpty) return '';
    if (kk == ss) return label(kk);
    if (kk.isNotEmpty && ss.isNotEmpty) {
      return '${label(kk)} / ${label(ss)}';
    }
    return label(kk.isEmpty ? ss : kk);
  }

  double? _avgOf(double? a, double? b) {
    if (a != null && b != null) return (a + b) / 2;
    return a ?? b;
  }
}

class _ParentRaporScoreCell extends StatelessWidget {
  const _ParentRaporScoreCell({
    required this.ki,
    required this.label,
    required this.accent,
    required this.score,
    required this.predikat,
    required this.failing,
    required this.kkm,
  });

  final String ki;
  final String label;
  final Color accent;
  final double? score;
  final String predikat;
  final bool failing;
  final double kkm;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = failing ? const Color(0xFFDC2626) : accent;
    final valueColor = score == null
        ? ColorUtils.slate300
        : (failing ? _kFailFg : ColorUtils.slate900);
    final pillLetter =
        predikat.isNotEmpty &&
            const ['A', 'B', 'C', 'D', 'E'].contains(predikat.toUpperCase())
        ? predikat.toUpperCase()
        : (score == null ? '' : _kBandLetter(score!));
    final pill = pillLetter.isEmpty
        ? null
        : (failing ? _kPredikatPill('D') : _kPredikatPill(pillLetter));

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [effectiveAccent.withValues(alpha: 0.06), Colors.white],
          stops: const [0.0, 0.6],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: effectiveAccent.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KI tag + predikat pill row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: effectiveAccent,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  ki,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (pill != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: pill.bg,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    pillLetter,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: pill.fg,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate600,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          // Score row: value + "/ 100"
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                score == null ? '–' : score!.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 4),
                Text(
                  '/ 100',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate400,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ParentRaporVerdictBar extends StatelessWidget {
  const _ParentRaporVerdictBar({
    required this.kkm,
    required this.knowledgeFailing,
    required this.skillFailing,
    required this.allFailing,
    required this.partialFailing,
    required this.hasAnyScore,
  });

  final double kkm;
  final bool knowledgeFailing;
  final bool skillFailing;
  final bool allFailing;
  final bool partialFailing;
  final bool hasAnyScore;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String text;
    if (!hasAnyScore) {
      bg = ColorUtils.slate50;
      fg = ColorUtils.slate500;
      border = ColorUtils.slate100;
      icon = Icons.schedule_rounded;
      text = 'Menunggu input guru mapel';
    } else if (allFailing) {
      bg = _kFailBg;
      fg = _kFailFg;
      border = _kFailBorder;
      icon = Icons.error_outline_rounded;
      text = 'KKM ${kkm.toStringAsFixed(0)} · Belum tuntas pada kedua aspek';
    } else if (partialFailing) {
      bg = _kPartialBg;
      fg = _kPartialFg;
      border = _kPartialBorder;
      icon = Icons.info_outline_rounded;
      text =
          'KKM ${kkm.toStringAsFixed(0)} · Belum tuntas pada '
          '${knowledgeFailing ? 'pengetahuan' : 'keterampilan'}';
    } else {
      bg = _kPassBg;
      fg = _kPassFg;
      border = _kPassBorder;
      icon = Icons.check_circle_outline_rounded;
      text = 'KKM ${kkm.toStringAsFixed(0)} · Tuntas';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: border, width: 0.75),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
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
          decoration: const BoxDecoration(
            color: Color(0xFFFEF3C7),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.emoji_events_rounded,
            size: 16,
            color: Color(0xFFB45309),
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    ach['type'].toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
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
    // Backend canonical: `promoted` / `not_promoted` / `graduated` /
    // `not_graduated` (was `Naik Kelas` / `Tidak Naik` / `Lulus`).
    // Map back to the Indonesian display strings the banner expects.
    final rawDecision = (reportCardData['promotion_decision'] ?? '')
        .toString()
        .trim();
    final raw = switch (rawDecision.toLowerCase()) {
      'promoted' => 'Naik Kelas',
      'not_promoted' => 'Tinggal di Kelas',
      'graduated' => 'Lulus',
      'not_graduated' => 'Tidak Lulus',
      _ => rawDecision,
    };
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

/// Sticky bottom bar with print/share affordances for the rapor detail
/// screen. Layout adapts to role:
///
/// * **wali / guru** — [Bagikan] [Cetak PDF]. Cetak calls `onPrintRaport`
///   (or `onPrintCertificate` for wali; controlled by the caller via
///   `defaultVariant`).
/// * **admin** — [Cetak Raport] [Cetak E-Raport]. Both formats are
///   exposed side-by-side; admin doesn't share via the bottom bar.
///
/// When [isPublished] is false (rapor still a draft), both Cetak buttons
/// render disabled with a `'Belum tersedia (draft)'` hint and don't fire
/// their handlers.
class ParentRaporBottomActionBar extends StatelessWidget {
  const ParentRaporBottomActionBar({
    super.key,
    required this.role,
    required this.isPublished,
    this.onShare,
    this.onPrintRaport,
    this.onPrintCertificate,
  });

  /// One of `'wali' | 'guru' | 'admin'`. Drives layout + accent color.
  final String role;

  /// True when the rapor has been published. Disables both Cetak CTAs
  /// when false because the backend export endpoint will 404.
  final bool isPublished;

  /// Share callback — only used in the wali/guru layout.
  final VoidCallback? onShare;

  /// Print using the official `raport.pdf` Blade template (full doc).
  /// Used by the "Cetak PDF" CTA on guru, by "Cetak Raport" on admin.
  final VoidCallback? onPrintRaport;

  /// Print using the `raport.certificate` Blade template (modern style).
  /// Used by the "Cetak PDF" CTA on wali, by "Cetak E-Raport" on admin.
  final VoidCallback? onPrintCertificate;

  bool get _isAdmin => role == 'admin' || role == 'administrator';

  Color get _accent => ColorUtils.getRoleColor(role);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPublished) ...[
            _DraftHintRow(accent: _accent),
            const SizedBox(height: 8),
          ],
          _isAdmin ? _buildAdminRow() : _buildDefaultRow(),
        ],
      ),
    );
  }

  // ── wali / guru variant ─────────────────────────────────────────────
  Widget _buildDefaultRow() {
    final printHandler = role == 'wali' ? onPrintCertificate : onPrintRaport;
    return Row(
      children: [
        Expanded(
          child: _ghostButton(
            label: 'Bagikan',
            icon: Icons.ios_share_rounded,
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _primaryButton(
            label: 'Cetak PDF',
            icon: Icons.picture_as_pdf_outlined,
            onTap: isPublished ? printHandler : null,
          ),
        ),
      ],
    );
  }

  // ── admin variant ───────────────────────────────────────────────────
  Widget _buildAdminRow() {
    return Row(
      children: [
        Expanded(
          child: _outlinedAccentButton(
            label: 'Cetak Raport',
            icon: Icons.description_outlined,
            onTap: isPublished ? onPrintRaport : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _primaryButton(
            label: 'Cetak E-Raport',
            icon: Icons.picture_as_pdf_outlined,
            onTap: isPublished ? onPrintCertificate : null,
          ),
        ),
      ],
    );
  }

  Widget _ghostButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: ColorUtils.slate700),
        label: Text(
          label,
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
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _accent : ColorUtils.slate200,
          disabledBackgroundColor: ColorUtils.slate200,
          disabledForegroundColor: ColorUtils.slate500,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _outlinedAccentButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final fg = enabled ? _accent : ColorUtils.slate400;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: fg),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: enabled
                ? _accent.withValues(alpha: 0.45)
                : ColorUtils.slate200,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _DraftHintRow extends StatelessWidget {
  const _DraftHintRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: const Color(0xFFFDE68A), width: 0.75),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: const Color(0xFFB45309),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Rapor masih draft — cetak PDF belum tersedia',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Deskripsi Capaian sheet (Frame 2 of the parent rapor redesign)
// =====================================================================
//
// Surfaces knowledge_description + skill_description for one mata pelajaran.
// Backend already populates both fields (wali kelas redesign TA.22–26); this
// is the parent-facing read-only view that mirrors the wali kelas KI 3/KI 4
// section. Triggered by tapping a [ParentRaporSubjectCard].

/// Opens the per-mapel deskripsi capaian sheet. Returns when dismissed.
Future<void> showParentRaporDeskripsiSheet(
  BuildContext context, {
  required Map subject,
}) {
  return AppBottomSheet.show<void>(
    context: context,
    title: _readSubjectName(subject),
    subtitle: 'Deskripsi capaian belajar',
    icon: Icons.menu_book_rounded,
    primaryColor: ColorUtils.brandCobalt,
    contentPadding: EdgeInsets.zero,
    content: _ParentRaporDeskripsiBody(subject: subject),
  );
}

String _readSubjectName(Map subject) {
  if (subject['subject'] is Map) {
    return ((subject['subject'] as Map)['name'] ?? 'Mata Pelajaran').toString();
  }
  return 'Mata Pelajaran';
}

class _ParentRaporDeskripsiBody extends StatelessWidget {
  const _ParentRaporDeskripsiBody({required this.subject});

  final Map subject;

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _predikat(dynamic raw, double? score) {
    final stored = (raw ?? '').toString().trim();
    if (stored.isNotEmpty && stored != '–') return stored;
    if (score == null) return '';
    return _kBandLetter(score);
  }

  @override
  Widget build(BuildContext context) {
    final teacher =
        (subject['teacher_name'] ??
                (subject['subject'] is Map
                    ? (subject['subject'] as Map)['teacher_name']
                    : null) ??
                '')
            .toString();
    final knowledge = _toDouble(subject['knowledge_score']);
    final skill = _toDouble(subject['skill_score']);
    final kkm = _toDouble(subject['kkm']) ?? 75;

    final knowledgeDesc = (subject['knowledge_description'] ?? '')
        .toString()
        .trim();
    final skillDesc = (subject['skill_description'] ?? '').toString().trim();

    final knowledgePred = _predikat(subject['knowledge_predicate'], knowledge);
    final skillPred = _predikat(subject['skill_predicate'], skill);

    final knowledgeFailing = knowledge != null && knowledge < kkm;
    final skillFailing = skill != null && skill < kkm;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (teacher.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: ColorUtils.slate500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Guru mapel: $teacher',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          // KI 3 block
          _ParentRaporDeskripsiBlock(
            ki: 'KI 3',
            label: 'Pengetahuan',
            accent: _kKi3,
            score: knowledge,
            predikat: knowledgePred,
            description: knowledgeDesc,
            failing: knowledgeFailing,
          ),
          const SizedBox(height: 12),
          // KI 4 block
          _ParentRaporDeskripsiBlock(
            ki: 'KI 4',
            label: 'Keterampilan',
            accent: _kKi4,
            score: skill,
            predikat: skillPred,
            description: skillDesc,
            failing: skillFailing,
          ),
          if (knowledgeDesc.isEmpty && skillDesc.isEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ColorUtils.brandAzure.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: ColorUtils.brandAzure.withValues(alpha: 0.20),
                  width: 0.75,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: ColorUtils.brandAzureDeep,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wali kelas belum menulis deskripsi capaian untuk '
                      'mata pelajaran ini. Hubungi wali kelas via menu '
                      'Pesan jika dibutuhkan.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.brandAzureDeep,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: ColorUtils.slate100,
                foregroundColor: ColorUtils.slate700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              onPressed: () => AppNavigator.pop(context),
              child: const Text(
                'Tutup',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentRaporDeskripsiBlock extends StatelessWidget {
  const _ParentRaporDeskripsiBlock({
    required this.ki,
    required this.label,
    required this.accent,
    required this.score,
    required this.predikat,
    required this.description,
    required this.failing,
  });

  final String ki;
  final String label;
  final Color accent;
  final double? score;
  final String predikat;
  final String description;
  final bool failing;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = failing ? const Color(0xFFDC2626) : accent;
    final hasScore = score != null;
    final pillLetter =
        predikat.isNotEmpty &&
            const ['A', 'B', 'C', 'D', 'E'].contains(predikat.toUpperCase())
        ? predikat.toUpperCase()
        : (hasScore ? _kBandLetter(score!) : '');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [effectiveAccent.withValues(alpha: 0.05), Colors.white],
          stops: const [0.0, 0.7],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: effectiveAccent.withValues(alpha: 0.18),
          width: 0.75,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: effectiveAccent,
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                ),
                child: Text(
                  ki,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label · ${hasScore ? score!.toStringAsFixed(0) : '–'} / 100',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pillLetter.isNotEmpty)
                Text(
                  'Predikat $pillLetter',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: failing ? _kFailFg : effectiveAccent,
                    letterSpacing: 0.2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description.isEmpty
                ? '— Belum ada deskripsi capaian dari wali kelas.'
                : description,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: description.isEmpty
                  ? ColorUtils.slate400
                  : ColorUtils.slate700,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
