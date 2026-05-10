// Tab 2 (Nilai Akademik) of the report card detail form — Frame B
// of `_design/teacher_raport_isi_redesign.html`.
//
// Each row carries:
//   • 36dp icon badge color-coded per subject hash
//   • Mapel name + `KKM <n> · <teacher>` meta
//   • 72dp score input — color-coded (green ≥80, amber ≥60, red <60,
//     slate when empty)
// Section head reports `<n> mapel` + KKM-pass count chip.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

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

  // Per-row controllers so the input keeps the cursor across rebuilds.
  final Map<int, TextEditingController> _scoreCtrls = {};

  @override
  void didUpdateWidget(covariant ReportCardGradeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controllers with new widget data when subjects list changes.
    for (var i = 0; i < widget.subjects.length; i++) {
      final stored = _scoreCtrls[i];
      final next = _formatScore(widget.subjects[i]['knowledge_score']);
      if (stored == null) {
        _scoreCtrls[i] = TextEditingController(text: next);
      } else if (stored.text != next) {
        stored.text = next;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _scoreCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(int index) {
    return _scoreCtrls.putIfAbsent(index, () {
      return TextEditingController(
        text: _formatScore(widget.subjects[index]['knowledge_score']),
      );
    });
  }

  String _formatScore(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null || d == 0) return '';
    if (d == d.roundToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(1);
  }

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
              controller: _ctrlFor(i),
              onScoreChanged: (v) {
                widget.onSubjectChanged(i, 'knowledge_score', v);
                widget.onMarkUnsaved();
                setState(() {}); // refresh pass-count
              },
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
}

class _NilaiRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> subject;
  final int kkm;
  final TextEditingController controller;
  final ValueChanged<String> onScoreChanged;

  const _NilaiRow({
    required this.index,
    required this.subject,
    required this.kkm,
    required this.controller,
    required this.onScoreChanged,
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
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
                  teacher.isNotEmpty ? 'KKM $kkm · $teacher' : 'KKM $kkm',
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
          _ScoreField(
            controller: controller,
            kkm: kkm,
            onChanged: onScoreChanged,
          ),
        ],
      ),
    );
  }
}

class _ScoreField extends StatelessWidget {
  final TextEditingController controller;
  final int kkm;
  final ValueChanged<String> onChanged;

  const _ScoreField({
    required this.controller,
    required this.kkm,
    required this.onChanged,
  });

  (Color, Color, Color) _tint() {
    final v = double.tryParse(controller.text);
    if (v == null || v == 0) {
      return (Colors.white, ColorUtils.slate200, ColorUtils.slate900);
    }
    if (v >= 80) {
      return (
        ColorUtils.success600.withValues(alpha: 0.06),
        ColorUtils.success600.withValues(alpha: 0.30),
        ColorUtils.success600,
      );
    }
    if (v >= kkm) {
      return (
        ColorUtils.warning600.withValues(alpha: 0.06),
        ColorUtils.warning600.withValues(alpha: 0.30),
        ColorUtils.warning600,
      );
    }
    return (
      ColorUtils.error600.withValues(alpha: 0.06),
      ColorUtils.error600.withValues(alpha: 0.30),
      ColorUtils.error600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (bg, border, fg) = _tint();
    return SizedBox(
      width: 72,
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: -0.2,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: bg,
          hintText: '–',
          hintStyle: TextStyle(
            color: ColorUtils.slate400,
            fontWeight: FontWeight.w700,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: fg, width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
