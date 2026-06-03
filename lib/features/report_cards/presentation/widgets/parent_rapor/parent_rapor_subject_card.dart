// =====================================================================
// Subject card with knowledge (KI 3) / skill (KI 4) dual cells + KKM verdict
// =====================================================================
//
// Layout — matches _design/parent_raport_pengetahuan_ketrampilan_redesign.html
// (Frame 1) 100%. Two score cells side-by-side, each with its own KI tag,
// auto-predikat pill (A/B/C/D), value 22pt, and gradient-tinted background.
// The whole card frame shifts tone based on tuntas / partial / fail.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_tokens.dart';

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
    final letter = avg == null ? '–' : parentRaporBandLetter(avg);
    final letterPalette = letter == '–'
        ? (bg: ColorUtils.slate100, fg: ColorUtils.slate400)
        : parentRaporLetterBadge(letter);

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
                  accent: kParentRaporKi3,
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
                  accent: kParentRaporKi4,
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
    return parentRaporBandLetter(score);
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
        : (failing ? kParentRaporFailFg : ColorUtils.slate900);
    final pillLetter =
        predikat.isNotEmpty &&
            const ['A', 'B', 'C', 'D', 'E'].contains(predikat.toUpperCase())
        ? predikat.toUpperCase()
        : (score == null ? '' : parentRaporBandLetter(score!));
    final pill = pillLetter.isEmpty
        ? null
        : (failing
              ? parentRaporPredikatPill('D')
              : parentRaporPredikatPill(pillLetter));

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
      bg = kParentRaporFailBg;
      fg = kParentRaporFailFg;
      border = kParentRaporFailBorder;
      icon = Icons.error_outline_rounded;
      text = 'KKM ${kkm.toStringAsFixed(0)} · Belum tuntas pada kedua aspek';
    } else if (partialFailing) {
      bg = kParentRaporPartialBg;
      fg = kParentRaporPartialFg;
      border = kParentRaporPartialBorder;
      icon = Icons.info_outline_rounded;
      text =
          'KKM ${kkm.toStringAsFixed(0)} · Belum tuntas pada '
          '${knowledgeFailing ? 'pengetahuan' : 'keterampilan'}';
    } else {
      bg = kParentRaporPassBg;
      fg = kParentRaporPassFg;
      border = kParentRaporPassBorder;
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
