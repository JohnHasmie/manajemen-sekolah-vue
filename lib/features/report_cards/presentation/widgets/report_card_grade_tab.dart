// Tab 2 (Nilai Akademik) of the Isi Raport form — Frame A + B of
// `_design/teacher_raport_isi_pengetahuan_ketrampilan_redesign.html`.
//
// The paper raport requires TWO scores per mata pelajaran:
//   • Pengetahuan (KI 3) — cobalt accent
//   • Keterampilan (KI 4) — violet accent
//
// Both columns already exist on the backend (`raport_subjects` table:
// knowledge_score / knowledge_predicate / knowledge_description +
// skill_score / skill_predicate / skill_description, all six in the
// store/update payload). The old grade tab silently dropped the skill
// half — this rewrite renders it.
//
// List card (Frame A):
//   • subject icon (palette-hashed) + name / KKM · teacher meta
//   • two side-by-side score cells underneath:
//       Pengetahuan (KI 3) | Keterampilan (KI 4)
//     each showing value, status tint, and auto-predikat pill.
//   • KKM counter on the section header reports mapel with BOTH
//     scores filled (so "5 / 8 KKM" means 5 mapel are fully entered,
//     not just 5 mapel that have one score above KKM).
//
// Edit sheet (Frame B):
//   • Two stacked `_NilaiSection` cards — cobalt KI 3, violet KI 4.
//   • Each section: numeric score + predikat chip-row (auto-selected
//     from score, manual tap overrides) + deskripsi textarea.
//   • AppBottomSheet + BottomSheetFooter for shared chrome.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

class ReportCardGradeTab extends StatefulWidget {
  final List<Map<String, dynamic>> subjects;
  final void Function(int index, String field, String value) onSubjectChanged;
  final VoidCallback onMarkUnsaved;

  const ReportCardGradeTab({
    super.key,
    required this.subjects,
    required this.onSubjectChanged,
    required this.onMarkUnsaved,
  });

  @override
  State<ReportCardGradeTab> createState() => _ReportCardGradeTabState();
}

class _ReportCardGradeTabState extends State<ReportCardGradeTab> {
  static const _kkmDefault = 75;

  /// A mapel "passes" only when BOTH Pengetahuan and Keterampilan
  /// scores are filled AND both ≥ KKM. Anything else (one filled, one
  /// empty, one below KKM) leaves the mapel outside the pass count.
  int _passCount() {
    var n = 0;
    for (final s in widget.subjects) {
      final k = double.tryParse(s['knowledge_score']?.toString() ?? '');
      final sk = double.tryParse(s['skill_score']?.toString() ?? '');
      if (k != null && sk != null && k >= _kkmDefault && sk >= _kkmDefault) {
        n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final pass = _passCount();
    final total = widget.subjects.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        _SectionHead(pass: pass, total: total),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.subjects.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NilaiRow(
              subject: widget.subjects[i],
              kkm: _kkmDefault,
              onTap: () => _openEditSheet(i, widget.subjects[i]),
            ),
          ),
      ],
    );
  }

  /// Open the per-mapel tap-to-edit sheet. The sheet owns its own
  /// `score / predikat / deskripsi` controllers for BOTH sides and
  /// calls back into [widget.onSubjectChanged] once per field on Save.
  void _openEditSheet(int index, Map<String, dynamic> subject) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RaportNilaiEditSheet(
        subject: subject,
        kkm: _kkmDefault,
        onSave: (knowledge, skill) {
          // Pengetahuan trio
          widget.onSubjectChanged(index, 'knowledge_score', knowledge.score);
          widget.onSubjectChanged(
            index,
            'knowledge_predicate',
            knowledge.predikat,
          );
          widget.onSubjectChanged(
            index,
            'knowledge_description',
            knowledge.deskripsi,
          );
          // Keterampilan trio — same field shape, just `skill_*` keys.
          widget.onSubjectChanged(index, 'skill_score', skill.score);
          widget.onSubjectChanged(index, 'skill_predicate', skill.predikat);
          widget.onSubjectChanged(index, 'skill_description', skill.deskripsi);
          widget.onMarkUnsaved();
          setState(() {}); // refresh pass-count + row preview chips
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Section head — "DAFTAR MAPEL · N MAPEL" + KKM pass-count pill on the
// right. The pill turns success-green once every mapel is filled.
// ──────────────────────────────────────────────────────────────────────

class _SectionHead extends StatelessWidget {
  final int pass;
  final int total;
  const _SectionHead({required this.pass, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Text(
            'DAFTAR MAPEL · $total MAPEL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: pass >= total
                    ? ColorUtils.success600.withValues(alpha: 0.10)
                    : ColorUtils.warning600.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pass >= total ? '$total / $total KKM ✓' : '$pass / $total KKM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: pass >= total
                      ? ColorUtils.success600
                      : ColorUtils.warning700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Mapel row card with two side-by-side score cells.
// ──────────────────────────────────────────────────────────────────────

class _NilaiRow extends StatelessWidget {
  final Map<String, dynamic> subject;
  final int kkm;
  final VoidCallback onTap;

  const _NilaiRow({
    required this.subject,
    required this.kkm,
    required this.onTap,
  });

  /// Hash-stable color palette for the subject icon. The third tuple
  /// element is the icon shown in the badge — kept distinct per index
  /// so two different mapel never look identical.
  static const _palette = <(Color, Color, IconData)>[
    (Color(0xFFE0E7FF), Color(0xFF4F46E5), Icons.menu_book_rounded),
    (Color(0xFFDCFCE7), Color(0xFF15803D), Icons.public_rounded),
    (Color(0xFFFEF3C7), Color(0xFFB45309), Icons.calculate_rounded),
    (Color(0xFFEDE9FE), Color(0xFF7C3AED), Icons.translate_rounded),
    (Color(0xFFFFE4E6), Color(0xFFE11D48), Icons.directions_run_rounded),
    (Color(0xFFCCFBF1), Color(0xFF0D9488), Icons.science_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final name = subject['subject_name']?.toString() ?? 'Mapel';
    final teacher = (subject['teacher_name'] ?? subject['teacher'] ?? '')
        .toString();
    final palette = _palette[name.hashCode.abs() % _palette.length];

    final kScore = double.tryParse(
      subject['knowledge_score']?.toString() ?? '',
    );
    final sScore = double.tryParse(subject['skill_score']?.toString() ?? '');
    final kFilled = kScore != null && kScore > 0;
    final sFilled = sScore != null && sScore > 0;
    final bothFilled = kFilled && sFilled;
    final bothPass = bothFilled && kScore >= kkm && sScore >= kkm;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bothPass
                  ? ColorUtils.success600.withValues(alpha: 0.30)
                  : ColorUtils.slate200,
              width: bothPass ? 1.2 : 1,
            ),
            gradient: bothPass
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      ColorUtils.success600.withValues(alpha: 0.03),
                      Colors.white,
                    ],
                    stops: const [0.0, 0.4],
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.$1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(palette.$3, size: 18, color: palette.$2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
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
                        const SizedBox(height: 1),
                        Text(
                          teacher.isNotEmpty
                              ? 'KKM $kkm · $teacher'
                              : 'KKM $kkm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: ColorUtils.slate300,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ScoreCell(
                      label: 'Pengetahuan',
                      ki: 'KI 3',
                      score: kScore,
                      kkm: kkm,
                      predikat:
                          subject['knowledge_predicate']?.toString().trim() ??
                          '',
                      accent: ColorUtils.brandCobalt,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ScoreCell(
                      label: 'Keterampilan',
                      ki: 'KI 4',
                      score: sScore,
                      kkm: kkm,
                      predikat:
                          subject['skill_predicate']?.toString().trim() ?? '',
                      accent: const Color(0xFF7C3AED), // violet600
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Score cell — half of the dual-score row. Shows label / KI tag, the
// numeric value (or '—' when empty), and an auto-predikat pill on the
// right when filled.
// ──────────────────────────────────────────────────────────────────────

class _ScoreCell extends StatelessWidget {
  final String label;
  final String ki;
  final double? score;
  final int kkm;
  final String predikat;
  final Color accent;

  const _ScoreCell({
    required this.label,
    required this.ki,
    required this.score,
    required this.kkm,
    required this.predikat,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final filled = score != null && score! > 0;
    final effectivePredikat = filled
        ? (predikat.isNotEmpty
              ? predikat.toUpperCase()
              : predikatFromScore(score, kkm: kkm))
        : '';
    final tone = _toneFor(score, kkm);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? Colors.white : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: filled ? accent.withValues(alpha: 0.30) : ColorUtils.slate200,
          width: filled ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      ki,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate400,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  filled ? _formatScore(score) : '—',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: filled ? tone : ColorUtils.slate300,
                    letterSpacing: -0.3,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          if (effectivePredikat.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                effectivePredikat,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _toneFor(double? v, int kkm) {
    if (v == null || v == 0) return ColorUtils.slate400;
    if (v >= 90) return ColorUtils.success600;
    if (v >= kkm) return ColorUtils.brandCobalt;
    if (v >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }
}

// ──────────────────────────────────────────────────────────────────────
// Helpers — shared by row + sheet.
// ──────────────────────────────────────────────────────────────────────

String _formatScore(dynamic v) {
  if (v == null) return '';
  final d = double.tryParse(v.toString());
  if (d == null || d == 0) return '';
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toStringAsFixed(1);
}

/// Maps a numeric score to the canonical Indonesian raport predikat:
///   ≥ 90 → A
///   ≥ KKM (75 by default) → B
///   ≥ 60 → C
///   anything below → D
/// Returns empty string for null / 0 scores so the caller can render
/// "—" or an empty chip slot.
String predikatFromScore(num? score, {int kkm = 75}) {
  if (score == null || score == 0) return '';
  if (score >= 90) return 'A';
  if (score >= kkm) return 'B';
  if (score >= 60) return 'C';
  return 'D';
}

// ──────────────────────────────────────────────────────────────────────
// Per-side input bundle used by the edit sheet.
// ──────────────────────────────────────────────────────────────────────

class _KIInput {
  final String score;
  final String predikat;
  final String deskripsi;
  const _KIInput({
    required this.score,
    required this.predikat,
    required this.deskripsi,
  });
}

// ──────────────────────────────────────────────────────────────────────
// Tap-to-edit sheet — two stacked sections, Pengetahuan + Keterampilan.
// ──────────────────────────────────────────────────────────────────────

class _RaportNilaiEditSheet extends StatefulWidget {
  final Map<String, dynamic> subject;
  final int kkm;
  final void Function(_KIInput knowledge, _KIInput skill) onSave;

  const _RaportNilaiEditSheet({
    required this.subject,
    required this.kkm,
    required this.onSave,
  });

  @override
  State<_RaportNilaiEditSheet> createState() => _RaportNilaiEditSheetState();
}

class _RaportNilaiEditSheetState extends State<_RaportNilaiEditSheet> {
  // Pengetahuan (KI 3)
  late final TextEditingController _kScoreCtrl;
  late final TextEditingController _kPredCtrl;
  late final TextEditingController _kDescCtrl;
  bool _kPredManual = false;

  // Keterampilan (KI 4)
  late final TextEditingController _sScoreCtrl;
  late final TextEditingController _sPredCtrl;
  late final TextEditingController _sDescCtrl;
  bool _sPredManual = false;

  static const _predikatOptions = <String>['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _kScoreCtrl = TextEditingController(
      text: _formatScore(widget.subject['knowledge_score']),
    );
    _kPredCtrl = TextEditingController(
      text: widget.subject['knowledge_predicate']?.toString() ?? '',
    );
    _kDescCtrl = TextEditingController(
      text: widget.subject['knowledge_description']?.toString() ?? '',
    );

    _sScoreCtrl = TextEditingController(
      text: _formatScore(widget.subject['skill_score']),
    );
    _sPredCtrl = TextEditingController(
      text: widget.subject['skill_predicate']?.toString() ?? '',
    );
    _sDescCtrl = TextEditingController(
      text: widget.subject['skill_description']?.toString() ?? '',
    );

    // Mark predikat as manual if it disagrees with what the score
    // would suggest on open — protects an admin's prior override.
    _kPredManual = _isManual(_kPredCtrl.text, _kScoreCtrl.text);
    _sPredManual = _isManual(_sPredCtrl.text, _sScoreCtrl.text);

    _kScoreCtrl.addListener(() => _onScoreChanged(side: _Side.knowledge));
    _sScoreCtrl.addListener(() => _onScoreChanged(side: _Side.skill));
  }

  @override
  void dispose() {
    _kScoreCtrl.dispose();
    _kPredCtrl.dispose();
    _kDescCtrl.dispose();
    _sScoreCtrl.dispose();
    _sPredCtrl.dispose();
    _sDescCtrl.dispose();
    super.dispose();
  }

  bool _isManual(String pred, String scoreText) {
    final p = pred.trim().toUpperCase();
    if (p.isEmpty) return false;
    final score = double.tryParse(scoreText);
    if (score == null) return p.isNotEmpty;
    return p != predikatFromScore(score, kkm: widget.kkm);
  }

  void _onScoreChanged({required _Side side}) {
    // Auto-fill predikat from score unless the teacher tapped a chip
    // explicitly (in which case `_*PredManual` is true and we leave
    // their choice alone).
    final scoreText = side == _Side.knowledge
        ? _kScoreCtrl.text
        : _sScoreCtrl.text;
    final manual = side == _Side.knowledge ? _kPredManual : _sPredManual;
    if (manual) {
      setState(() {});
      return;
    }
    final score = double.tryParse(scoreText);
    final suggested = predikatFromScore(score, kkm: widget.kkm);
    if (side == _Side.knowledge) {
      _kPredCtrl.text = suggested;
    } else {
      _sPredCtrl.text = suggested;
    }
    setState(() {});
  }

  void _onPredikatTap({required _Side side, required String value}) {
    if (side == _Side.knowledge) {
      _kPredCtrl.text = value;
      // Mark manual ONLY when the choice deviates from the auto-suggest.
      final score = double.tryParse(_kScoreCtrl.text);
      _kPredManual = predikatFromScore(score, kkm: widget.kkm) != value;
    } else {
      _sPredCtrl.text = value;
      final score = double.tryParse(_sScoreCtrl.text);
      _sPredManual = predikatFromScore(score, kkm: widget.kkm) != value;
    }
    setState(() {});
  }

  void _save() {
    widget.onSave(
      _KIInput(
        score: _kScoreCtrl.text.trim(),
        predikat: _kPredCtrl.text.trim(),
        deskripsi: _kDescCtrl.text.trim(),
      ),
      _KIInput(
        score: _sScoreCtrl.text.trim(),
        predikat: _sPredCtrl.text.trim(),
        deskripsi: _sDescCtrl.text.trim(),
      ),
    );
    AppNavigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final subjectName = widget.subject['subject_name']?.toString() ?? 'Mapel';
    final teacher =
        (widget.subject['teacher_name'] ?? widget.subject['teacher'] ?? '')
            .toString();

    return AppBottomSheet(
      title: subjectName,
      subtitle: teacher.isNotEmpty
          ? 'KKM ${widget.kkm} · $teacher'
          : 'KKM ${widget.kkm}',
      icon: Icons.menu_book_rounded,
      primaryColor: cobalt,
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _NilaiSection(
            title: kRepCarKnowledge.tr,
            ki: 'KI 3',
            accent: cobalt,
            icon: Icons.menu_book_rounded,
            scoreCtrl: _kScoreCtrl,
            predikatCtrl: _kPredCtrl,
            descCtrl: _kDescCtrl,
            isManual: _kPredManual,
            kkm: widget.kkm,
            predikatOptions: _predikatOptions,
            onPredikatTap: (v) =>
                _onPredikatTap(side: _Side.knowledge, value: v),
            descPlaceholder:
                'Mis. Menunjukkan pemahaman yang baik terhadap konsep…',
          ),
          const SizedBox(height: AppSpacing.md),
          _NilaiSection(
            title: kRepCarSkills.tr,
            ki: 'KI 4',
            accent: const Color(0xFF7C3AED), // violet600
            icon: Icons.build_outlined,
            scoreCtrl: _sScoreCtrl,
            predikatCtrl: _sPredCtrl,
            descCtrl: _sDescCtrl,
            isManual: _sPredManual,
            kkm: widget.kkm,
            predikatOptions: _predikatOptions,
            onPredikatTap: (v) => _onPredikatTap(side: _Side.skill, value: v),
            descPlaceholder:
                'Mis. Mampu menerapkan keterampilan pada konteks nyata…',
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Simpan',
        primaryColor: cobalt,
        onPrimary: _save,
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

enum _Side { knowledge, skill }

// ──────────────────────────────────────────────────────────────────────
// One KI section card inside the edit sheet — same shape regardless of
// whether it's Pengetahuan (cobalt) or Keterampilan (violet). Built as
// a stateless widget so the parent state owns the controllers.
// ──────────────────────────────────────────────────────────────────────

class _NilaiSection extends StatelessWidget {
  final String title;
  final String ki;
  final Color accent;
  final IconData icon;
  final TextEditingController scoreCtrl;
  final TextEditingController predikatCtrl;
  final TextEditingController descCtrl;
  final bool isManual;
  final int kkm;
  final List<String> predikatOptions;
  final ValueChanged<String> onPredikatTap;
  final String descPlaceholder;

  const _NilaiSection({
    required this.title,
    required this.ki,
    required this.accent,
    required this.icon,
    required this.scoreCtrl,
    required this.predikatCtrl,
    required this.descCtrl,
    required this.isManual,
    required this.kkm,
    required this.predikatOptions,
    required this.onPredikatTap,
    required this.descPlaceholder,
  });

  @override
  Widget build(BuildContext context) {
    final score = double.tryParse(scoreCtrl.text);
    final scoreFilled = score != null && score > 0;
    final passKkm = scoreFilled && score >= kkm;

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Head: icon + label + KI tag ──
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ki,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Score field with KKM badge ──
          _capsLabel('Nilai (0–100)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: scoreCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,3}(\.\d{0,1})?$'),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.2,
                  ),
                  decoration: _inputDecoration(accent, hint: '0–100'),
                ),
              ),
              if (scoreFilled) ...[
                const SizedBox(width: 8),
                _KkmBadge(passKkm: passKkm),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // ── Predikat chips ──
          _capsLabel('Predikat'),
          const SizedBox(height: 6),
          Row(
            children: predikatOptions.map((opt) {
              final selected = predikatCtrl.text.trim().toUpperCase() == opt;
              final disabled = !scoreFilled;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: opt == predikatOptions.last ? 0 : 6,
                  ),
                  child: _PredikatChip(
                    label: opt,
                    selected: selected,
                    disabled: disabled,
                    accent: accent,
                    onTap: () => onPredikatTap(opt),
                  ),
                ),
              );
            }).toList(),
          ),
          if (isManual && scoreFilled) ...[
            const SizedBox(height: 4),
            Text(
              'Predikat diubah manual',
              style: TextStyle(
                fontSize: 10.5,
                color: ColorUtils.slate500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // ── Deskripsi textarea ──
          _capsLabel('Deskripsi'),
          const SizedBox(height: 6),
          TextField(
            controller: descCtrl,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: 14,
              color: ColorUtils.slate900,
              height: 1.4,
            ),
            decoration: _inputDecoration(accent, hint: descPlaceholder),
          ),
        ],
      ),
    );
  }

  Widget _capsLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate600,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(Color accent, {required String hint}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(
        color: ColorUtils.slate400,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ColorUtils.slate200, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ColorUtils.slate200, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 1.8),
      ),
    );
  }
}

class _KkmBadge extends StatelessWidget {
  final bool passKkm;
  const _KkmBadge({required this.passKkm});

  @override
  Widget build(BuildContext context) {
    final color = passKkm ? ColorUtils.success600 : ColorUtils.warning600;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        passKkm ? '≥ KKM' : '< KKM',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PredikatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final Color accent;
  final VoidCallback onTap;

  const _PredikatChip({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? accent
        : (disabled ? ColorUtils.slate100 : Colors.white);
    final fg = selected
        ? Colors.white
        : (disabled ? ColorUtils.slate400 : ColorUtils.slate700);
    final border = selected
        ? accent
        : (disabled ? ColorUtils.slate200 : ColorUtils.slate300);
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: fg,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
