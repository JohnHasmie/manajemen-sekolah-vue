// Card-view builder for the Materi overview hub — Frame A3 / Option B
// (rebuilt from scratch in M3.3 to match
// `_design/teacher_materi_card_v3_redesign.html` 100%).
//
// Visual contract — Option B "bar-led" layout:
//
//   ┌──────────────────────────────────────────────┐
//   │ 7A                                  44%  ›   │
//   │ B. Arab                                       │
//   │ 8 bab · 24 sub-bab                            │
//   │                                               │
//   │ ████████░░░░░░░░░░░░░░░░░░                    │
//   │                                               │
//   │ ● 14 tercatat   ●  18 belum                   │
//   └──────────────────────────────────────────────┘
//
// What changed vs the old ring-led card (M3.x predecessor):
//   • Ring removed — percent moves to a bold inline number on the
//     right of the header row.
//   • The 3-cell stat tile grid (Tercatat / Belum / AI) is gone. The
//     AI count was retired per user feedback; the remaining two stats
//     fold into a single inline dot-legend below the bar.
//   • The bottom progress bar stays as the sole progress visual
//     (the ring duplicated it and added clutter).
//
// Color buckets resolve once per card and tint the percent + bar:
//   ≥ 80%  → success-600 (near complete)
//   40-79% → brand-cobalt (on track)
//   1-39%  → warning-600 (below target)
//   0%     → slate-500   (not started)
//
// In wali_kelas mode the teacher's name shows in a slim row between
// the title block and the progress bar.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

mixin CardViewBuilderMixin {
  Color get primaryColor;
  LanguageProvider get lp;
  bool get isHomeroomView;
  void Function(String, String, String, String) get onOpenChapter;

  /// Resolves the headline color for the percent + bar based on bucket.
  Color _bucketColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.brandCobalt;
    if (pct >= 1) return ColorUtils.warning600;
    return ColorUtils.slate500;
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
    final pending = ((totalCh + totalSub) - checked).clamp(0, 1 << 31);
    final bucket = _bucketColor(pct);

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
          _headerRow(cn, sn, pct, totalCh, totalSub, bucket),
          if (isHomeroomView &&
              (g['teacher_name'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            _teacherRow(g['teacher_name'].toString()),
          ],
          const SizedBox(height: 12),
          _progressBar(pct, bucket),
          const SizedBox(height: 10),
          _legendRow(checked, pending),
        ],
      ),
    );
  }

  /// Title block on the left (kicker + name + meta), bold % on the
  /// right, chevron all the way right.
  Widget _headerRow(
    String cn,
    String sn,
    double pct,
    int totalCh,
    int totalSub,
    Color bucket,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        const SizedBox(width: 8),
        _PercentLabel(pct: pct, color: bucket),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 18, color: ColorUtils.slate400),
      ],
    );
  }

  Widget _teacherRow(String teacherName) {
    return Row(
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
    );
  }

  /// Slim 6dp bar tinted to the bucket color. For mid-range (cobalt)
  /// progress we apply the cobalt→azure gradient to match the brand
  /// language; all other buckets use a flat fill so amber and green
  /// read as semantic signals (below-target / near-complete).
  Widget _progressBar(double pct, Color bucket) {
    final isCobaltRange = pct >= 40 && pct < 80;
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: ColorUtils.slate100),
            FractionallySizedBox(
              widthFactor: (pct / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isCobaltRange
                      ? LinearGradient(
                          colors: [
                            ColorUtils.brandCobalt,
                            ColorUtils.brandAzure,
                          ],
                        )
                      : LinearGradient(colors: [bucket, bucket]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline dot-legend: ● cobalt "N tercatat" · ● amber "N belum".
  /// The Belum dot mutes to slate when zero so the card doesn't shout
  /// at the user when everything is recorded.
  Widget _legendRow(int checked, int pending) {
    final belumColor = pending > 0
        ? ColorUtils.warning700
        : ColorUtils.slate500;
    return Row(
      children: [
        _LegendSeg(
          dotColor: ColorUtils.brandCobalt,
          textColor: ColorUtils.brandCobalt,
          label: '$checked tercatat',
        ),
        const SizedBox(width: 10),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: ColorUtils.slate300,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        _LegendSeg(
          dotColor: pending > 0 ? ColorUtils.warning600 : ColorUtils.slate400,
          textColor: belumColor,
          label: '$pending belum',
        ),
      ],
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _PercentLabel extends StatelessWidget {
  final double pct;
  final Color color;

  const _PercentLabel({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          pct.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
        Text(
          '%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color.withValues(alpha: 0.7),
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _LegendSeg extends StatelessWidget {
  final Color dotColor;
  final Color textColor;
  final String label;

  const _LegendSeg({
    required this.dotColor,
    required this.textColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
