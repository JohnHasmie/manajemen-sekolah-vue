// 3-cell KPI overlap card for the rekap nilai detail screen —
// Tuntas · Belum · Rata-rata.
//
// Extracted verbatim from `teacher_grade_recap_screen.dart` so the
// screen stays a thin orchestrator. The card computes its three figures
// from `tableData` + the live `scoreControllers` so it stays in sync
// with the matrix the teacher is editing (including unsaved edits).
//
// While `isLoading` is true the screen swaps in [GradeRecapKpiSkeleton]
// instead of this widget — the skeleton mirrors this card's shape so
// the slot stays anchored and there's no flash of "0 / 0 / —".
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class GradeRecapKpiCard extends StatelessWidget {
  final List<Map<String, dynamic>> tableData;
  final Map<String, TextEditingController> scoreControllers;
  final LanguageProvider lp;

  const GradeRecapKpiCard({
    super.key,
    required this.tableData,
    required this.scoreControllers,
    required this.lp,
  });

  @override
  Widget build(BuildContext context) {
    // Definitions:
    //   • Tuntas — student's avg across non-null bab_scores >= KKM (75).
    //   • Belum  — student has no entries OR their avg is < KKM.
    //   • Rata-rata — class average computed as MEAN OF MEANS: each
    //                 student's per-row avg, then averaged across the
    //                 class. This matches the backend's overview card
    //                 (`AVG(per_row_avg)` in `Api\GradeRecapController`)
    //                 so the figure here lines up with the figure on
    //                 the Rekap Nilai overview. Also the conventional
    //                 definition for "rata-rata kelas" — every student
    //                 weighs equally regardless of how many bab they
    //                 have completed.
    //
    // Reads scores from the `bab_scores` list on each row (already
    // populated when the table loads) AND the live score controllers
    // (which carry edits the teacher hasn't saved yet) so the KPI
    // reflects what's actually on screen — not just what's persisted.
    // Per-student key shape is "$scId|bab|$idx".
    const kkm = 75.0;
    int tuntas = 0;
    int belum = 0;
    double sumOfRowAvgs = 0;
    int rowsWithScores = 0;
    for (final row in tableData) {
      final scId = (row['student_class_id'] ?? row['id'] ?? '').toString();
      final scores = <double>[];

      // 1. Live edits in score controllers.
      for (final entry in scoreControllers.entries) {
        if (!entry.key.startsWith('$scId|bab|')) continue;
        final v = entry.value.text.trim();
        if (v.isEmpty) continue;
        final parsed = double.tryParse(v.replaceAll(',', '.'));
        if (parsed != null) scores.add(parsed);
      }

      // 2. Fallback to row['bab_scores'] when controllers haven't
      //    been built yet (first frame after a reload).
      if (scores.isEmpty && row['bab_scores'] is List) {
        for (final v in (row['bab_scores'] as List)) {
          if (v is num) scores.add(v.toDouble());
        }
      }

      if (scores.isEmpty) {
        belum++;
        continue;
      }
      final avgRow = scores.reduce((a, b) => a + b) / scores.length;
      if (avgRow >= kkm) {
        tuntas++;
      } else {
        belum++;
      }
      sumOfRowAvgs += avgRow;
      rowsWithScores++;
    }
    final avg = rowsWithScores > 0 ? (sumOfRowAvgs / rowsWithScores) : null;

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
              label: lp.getTranslatedText({'en': 'Done', 'id': 'Tuntas'}),
              value: '$tuntas',
              color: ColorUtils.success600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Pending', 'id': 'Belum'}),
              value: '$belum',
              color: ColorUtils.warning600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Avg', 'id': 'Rata-rata'}),
              value: avg == null ? '—' : avg.toStringAsFixed(0),
              color: ColorUtils.info600,
            ),
          ],
        ),
      ),
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
}
