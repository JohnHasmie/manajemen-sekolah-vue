// Tab 2 (Nilai Akademik) of the report card detail form — Frame B
// of `_design/teacher_raport_isi_redesign.html`.
//
// Each row carries:
//   • 36dp icon badge color-coded per subject hash
//   • Mapel name + `KKM <n> · <teacher>` meta
//   • Score chip + predikat chip (read-only previews of the current
//     value)
// Section head reports `<n> mapel` + KKM-pass count chip.
//
// The row is tap-to-edit (SS2-HH): tapping anywhere opens a full
// editor sheet with score + predikat + deskripsi fields. The previous
// inline-score-only input lost the teacher's "keterangan" workflow —
// they had nowhere to record predikat/deskripsi for the mapel. The
// sheet matches the Sikap-tab pattern so the Isi Raport experience
// feels consistent across tabs.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
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

  int _passCount() {
    var n = 0;
    for (final s in widget.subjects) {
      final d = double.tryParse(s['knowledge_score']?.toString() ?? '');
      if (d != null && d >= _kkmDefault) n++;
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
        _buildSectionHead(pass, total),
        const SizedBox(height: 8),
        for (var i = 0; i < widget.subjects.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NilaiRow(
              index: i,
              subject: widget.subjects[i],
              kkm: _kkmDefault,
              onTap: () => _openEditSheet(i, widget.subjects[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHead(int pass, int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: pass >= total
                    ? ColorUtils.success600.withValues(alpha: 0.10)
                    : ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                pass >= total ? '$total KKM ✓' : '$pass / $total KKM',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: pass >= total
                      ? ColorUtils.success600
                      : ColorUtils.slate600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Open the per-mapel tap-to-edit sheet. The sheet owns its own
  /// `score / predikat / deskripsi` controllers and calls back into
  /// [widget.onSubjectChanged] once per field on Save.
  void _openEditSheet(int index, Map<String, dynamic> subject) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RaportNilaiEditSheet(
        subject: subject,
        kkm: _kkmDefault,
        onSave: (score, predikat, deskripsi) {
          widget.onSubjectChanged(index, 'knowledge_score', score);
          widget.onSubjectChanged(index, 'knowledge_predicate', predikat);
          widget.onSubjectChanged(index, 'knowledge_description', deskripsi);
          widget.onMarkUnsaved();
          setState(() {}); // refresh pass-count + row preview chips
        },
      ),
    );
  }
}

class _NilaiRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> subject;
  final int kkm;
  final VoidCallback onTap;

  const _NilaiRow({
    required this.index,
    required this.subject,
    required this.kkm,
    required this.onTap,
  });

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

    final scoreStr = _formatScore(subject['knowledge_score']);
    final predikatStr = subject['knowledge_predicate']?.toString().trim() ?? '';
    final deskripsiStr =
        subject['knowledge_description']?.toString().trim() ?? '';
    final scoreDouble = double.tryParse(scoreStr);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.$1,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(palette.$3, size: 16, color: palette.$2),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          teacher.isNotEmpty
                              ? 'KKM $kkm · $teacher'
                              : 'KKM $kkm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ScoreBadge(
                    scoreText: scoreStr,
                    kkm: kkm,
                    score: scoreDouble,
                  ),
                ],
              ),
              if (predikatStr.isNotEmpty || deskripsiStr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 46), // align with avatar+gap
                    if (predikatStr.isNotEmpty)
                      _PredikatChip(
                        label: predikatStr,
                        score: scoreDouble,
                        kkm: kkm,
                      ),
                    if (predikatStr.isNotEmpty && deskripsiStr.isNotEmpty)
                      const SizedBox(width: 6),
                    if (deskripsiStr.isNotEmpty)
                      Expanded(
                        child: Text(
                          deskripsiStr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate600,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatScore(dynamic v) {
  if (v == null) return '';
  final d = double.tryParse(v.toString());
  if (d == null || d == 0) return '';
  if (d == d.roundToDouble()) return d.toInt().toString();
  return d.toStringAsFixed(1);
}

/// Read-only score chip on the list row. Color band matches the input
/// in the edit sheet — green ≥80, amber ≥KKM, red <KKM, slate empty.
class _ScoreBadge extends StatelessWidget {
  final String scoreText;
  final int kkm;
  final double? score;

  const _ScoreBadge({
    required this.scoreText,
    required this.kkm,
    required this.score,
  });

  (Color, Color, Color) _tint() {
    final v = score;
    if (v == null || v == 0) {
      return (Colors.white, ColorUtils.slate200, ColorUtils.slate900);
    }
    if (v >= 80) {
      return (
        ColorUtils.success600.withValues(alpha: 0.08),
        ColorUtils.success600.withValues(alpha: 0.30),
        ColorUtils.success600,
      );
    }
    if (v >= kkm) {
      return (
        ColorUtils.warning600.withValues(alpha: 0.08),
        ColorUtils.warning600.withValues(alpha: 0.30),
        ColorUtils.warning600,
      );
    }
    return (
      ColorUtils.error600.withValues(alpha: 0.08),
      ColorUtils.error600.withValues(alpha: 0.30),
      ColorUtils.error600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = _tint();
    final hasScore = scoreText.isNotEmpty;
    return Container(
      width: 72,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Text(
        hasScore ? scoreText : '–',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: hasScore ? fg : ColorUtils.slate400,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Predikat preview chip on the list row. Tint matches the score band
/// when present, otherwise slate.
class _PredikatChip extends StatelessWidget {
  final String label;
  final double? score;
  final int kkm;

  const _PredikatChip({
    required this.label,
    required this.score,
    required this.kkm,
  });

  Color _tint() {
    final v = score;
    if (v == null || v == 0) return ColorUtils.slate500;
    if (v >= 80) return ColorUtils.success600;
    if (v >= kkm) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  @override
  Widget build(BuildContext context) {
    final c = _tint();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Tap-to-edit sheet — score + predikat + deskripsi.
// ──────────────────────────────────────────────────────────────────────

class _RaportNilaiEditSheet extends StatefulWidget {
  final Map<String, dynamic> subject;
  final int kkm;
  final void Function(String score, String predikat, String deskripsi) onSave;

  const _RaportNilaiEditSheet({
    required this.subject,
    required this.kkm,
    required this.onSave,
  });

  @override
  State<_RaportNilaiEditSheet> createState() => _RaportNilaiEditSheetState();
}

class _RaportNilaiEditSheetState extends State<_RaportNilaiEditSheet> {
  late final TextEditingController _scoreCtrl;
  late final TextEditingController _predikatCtrl;
  late final TextEditingController _deskripsiCtrl;

  /// Predikat options that the teacher can tap; selection auto-fills the
  /// predikat text field. The chip set matches the Indonesian raport
  /// convention (A/B/C/D) and is independent from the free-form text
  /// input so teachers can override with custom phrasing.
  static const _predikatOptions = <String>['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _scoreCtrl = TextEditingController(
      text: _formatScore(widget.subject['knowledge_score']),
    );
    _predikatCtrl = TextEditingController(
      text: widget.subject['knowledge_predicate']?.toString() ?? '',
    );
    _deskripsiCtrl = TextEditingController(
      text: widget.subject['knowledge_description']?.toString() ?? '',
    );
    // Auto-suggest predikat when score changes and the predikat field is
    // empty — keeps the predikat in sync without overwriting a teacher's
    // manual entry.
    _scoreCtrl.addListener(_onScoreChanged);
  }

  @override
  void dispose() {
    _scoreCtrl.removeListener(_onScoreChanged);
    _scoreCtrl.dispose();
    _predikatCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  void _onScoreChanged() {
    if (_predikatCtrl.text.trim().isNotEmpty) return;
    final v = double.tryParse(_scoreCtrl.text);
    if (v == null) return;
    final suggested = _suggestPredikat(v);
    if (suggested.isNotEmpty) {
      _predikatCtrl.text = suggested;
    }
    setState(() {});
  }

  String _suggestPredikat(double v) {
    if (v >= 90) return 'A';
    if (v >= 80) return 'B';
    if (v >= widget.kkm) return 'C';
    return 'D';
  }

  void _save() {
    widget.onSave(
      _scoreCtrl.text.trim(),
      _predikatCtrl.text.trim(),
      _deskripsiCtrl.text.trim(),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final subjectName = widget.subject['subject_name']?.toString() ?? 'Mapel';
    final teacher =
        (widget.subject['teacher_name'] ?? widget.subject['teacher'] ?? '')
            .toString();

    return AppBottomSheet(
      title: 'Edit Nilai',
      subtitle: teacher.isNotEmpty ? '$subjectName · $teacher' : subjectName,
      icon: Icons.edit_note_rounded,
      primaryColor: cobalt,
      content: _buildBody(cobalt),
      footer: BottomSheetFooter(
        primaryLabel: 'Simpan',
        primaryColor: cobalt,
        onPrimary: _save,
        onSecondary: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBody(Color cobalt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _fieldLabel('Nilai (0–100)'),
        const SizedBox(height: 6),
        _scoreField(cobalt),
        const SizedBox(height: AppSpacing.lg),
        _fieldLabel('Predikat'),
        const SizedBox(height: 6),
        _predikatChips(cobalt),
        const SizedBox(height: 8),
        _predikatField(cobalt),
        const SizedBox(height: AppSpacing.lg),
        _fieldLabel('Deskripsi'),
        const SizedBox(height: 6),
        _deskripsiField(cobalt),
        const SizedBox(height: 4),
        Text(
          'Tulis ringkasan capaian belajar siswa pada mapel ini.',
          style: TextStyle(
            fontSize: 11,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
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

  Widget _scoreField(Color cobalt) {
    return TextField(
      controller: _scoreCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,1})?$')),
      ],
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate900,
      ),
      decoration: _inputDecoration(cobalt, hint: 'Mis. 85'),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _predikatChips(Color cobalt) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _predikatOptions.map((opt) {
        final isActive = _predikatCtrl.text.trim().toUpperCase() == opt;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            _predikatCtrl.text = opt;
            setState(() {});
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? cobalt.withValues(alpha: 0.12)
                  : ColorUtils.slate50,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive ? cobalt : ColorUtils.slate200,
                width: 1.2,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isActive ? cobalt : ColorUtils.slate700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _predikatField(Color cobalt) {
    return TextField(
      controller: _predikatCtrl,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ColorUtils.slate900,
      ),
      decoration: _inputDecoration(cobalt, hint: 'Mis. A, Sangat Baik, dst.'),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _deskripsiField(Color cobalt) {
    return TextField(
      controller: _deskripsiCtrl,
      minLines: 3,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 14, color: ColorUtils.slate900, height: 1.4),
      decoration: _inputDecoration(
        cobalt,
        hint: 'Mis. Surya menguasai operasi bilangan bulat dan…',
      ),
    );
  }

  InputDecoration _inputDecoration(Color cobalt, {required String hint}) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: TextStyle(
        color: ColorUtils.slate400,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        borderSide: BorderSide(color: cobalt, width: 1.8),
      ),
    );
  }
}
