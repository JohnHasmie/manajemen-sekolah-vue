// Card-view builder for the Materi overview hub — Frame A v2.
//
// Visual contract — derived from `_design/teacher_materi_redesign.html`
// Frame A:
//
//   ┌──────────────────────────────────────────────┐
//   │ ◯92%   7A                                  ›  │
//   │        IPA Terpadu                            │
//   │        8 bab · 24 sub-bab                     │
//   │   ┌────────┬────────┬────────┐                │
//   │   │  22    │   2    │  15    │                │
//   │   │TERCATAT│ BELUM  │  AI    │                │
//   │   └────────┴────────┴────────┘                │
//   │ ████████████████░░░ 92%                       │
//   └──────────────────────────────────────────────┘
//
// Components:
//   • 50dp conic-gradient progress ring with white inner circle
//     showing "<n>%". Color resolves to green ≥80%, cobalt 40-79%,
//     amber 1-39%, slate 0%.
//   • Cobalt class kicker (uppercase) + bold subject name + slate
//     "<chapters> bab · <sub-chapters> sub-bab" sub-line.
//   • 3-cell stats grid (Tercatat cobalt-tinted / Belum slate / AI
//     violet-tinted). Belum lights amber when > 0 to draw attention.
//   • 5dp gradient progress bar at the bottom (cobalt→azure for the
//     normal range; amber for low; slate for zero; green for full).
//
// In wali_kelas mode the teacher's name shows in a slim row between
// the title block and the stats grid (so wali kelas knows who's
// teaching that subject in their homeroom).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

mixin CardViewBuilderMixin {
  Color get primaryColor;
  LanguageProvider get lp;
  bool get isHomeroomView;
  void Function(String, String, String, String) get onOpenChapter;

  /// Resolves a (background, text) color pair for the percent value.
  /// Used both for the progress ring's filled arc and the inner-text.
  ({Color arc, Color text}) progressColors(double pct) {
    if (pct >= 80) {
      return (arc: ColorUtils.success600, text: ColorUtils.success600);
    }
    if (pct >= 40) {
      return (arc: ColorUtils.brandCobalt, text: ColorUtils.brandCobalt);
    }
    if (pct >= 1) {
      return (arc: ColorUtils.warning600, text: ColorUtils.warning600);
    }
    return (arc: ColorUtils.slate400, text: ColorUtils.slate500);
  }

  Widget buildCard(BuildContext context, dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final sn = g['subject_name']?.toString() ?? '-';
    final classId = g['class_id']?.toString() ?? '';
    final subjectId = g['subject_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onOpenChapter(classId, cn, subjectId, sn),
          child: cardBody(g, cn, sn),
        ),
      ),
    );
  }

  Widget cardBody(dynamic g, String cn, String sn) {
    final pct = (g['progress_pct'] is num)
        ? (g['progress_pct'] as num).toDouble()
        : 0.0;
    final totalCh = (g['total_chapters'] is num)
        ? (g['total_chapters'] as num).toInt()
        : 0;
    final totalSub = (g['total_sub_chapters'] is num)
        ? (g['total_sub_chapters'] as num).toInt()
        : 0;
    final checked = (g['checked'] is num) ? (g['checked'] as num).toInt() : 0;
    final generated = (g['generated'] is num)
        ? (g['generated'] as num).toInt()
        : 0;
    final pending = ((totalCh + totalSub) - checked).clamp(0, 1 << 31);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerRow(cn, sn, pct, totalCh, totalSub),
          if (isHomeroomView &&
              (g['teacher_name'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _teacherRow(g['teacher_name'].toString()),
          ],
          const SizedBox(height: 10),
          _statsRow(checked, pending, generated),
          const SizedBox(height: 10),
          _progressBar(pct),
        ],
      ),
    );
  }

  /// Class kicker + subject name + meta + progress ring on the left,
  /// chevron on the right.
  Widget _headerRow(
    String cn,
    String sn,
    double pct,
    int totalCh,
    int totalSub,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProgressRing(pct: pct, colors: progressColors(pct)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cn,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandCobalt,
                  letterSpacing: 0.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sn,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '$totalCh bab · $totalSub sub-bab',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: ColorUtils.slate400),
      ],
    );
  }

  Widget _teacherRow(String teacherName) {
    return Padding(
      padding: const EdgeInsets.only(left: 62),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 12, color: ColorUtils.slate500),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              teacherName,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate600,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(int checked, int pending, int generated) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            value: '$checked',
            label: 'TERCATAT',
            color: ColorUtils.brandCobalt,
            tinted: true,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '$pending',
            label: 'BELUM',
            color: pending > 0 ? ColorUtils.warning600 : ColorUtils.slate500,
            tinted: false,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '$generated',
            label: 'AI',
            color: const Color(0xFF7C3AED),
            tinted: true,
          ),
        ),
      ],
    );
  }

  /// Gradient progress bar — cobalt→azure for normal, amber for low,
  /// slate for zero, green for full.
  Widget _progressBar(double pct) {
    final color = progressColors(pct).arc;
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: ColorUtils.slate100),
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: pct >= 40 && pct < 80
                        ? [ColorUtils.brandCobalt, ColorUtils.brandAzure]
                        : [color, color],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double pct;
  final ({Color arc, Color text}) colors;

  const _ProgressRing({required this.pct, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring (slate-100) + colored arc.
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: ColorUtils.slate100,
              valueColor: AlwaysStoppedAnimation<Color>(colors.arc),
            ),
          ),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: colors.text,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool tinted;

  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
    required this.tinted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.06) : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tinted ? color.withValues(alpha: 0.18) : ColorUtils.slate100,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: tinted ? color : ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
