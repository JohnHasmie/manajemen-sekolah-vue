import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_progress_ring.dart';

/// Summary-stats hero rendered at the top of the Rekap Nilai overview.
///
/// Shows four at-a-glance metrics: number of classes, total students, overall
/// completion (as a circular ring), and the overall average score. Designed
/// to match the corporate look of the teacher-portal headers.
class GradeRecapStatsHero extends StatelessWidget {
  final Color primaryColor;
  final int classCount;
  final int studentCount;
  final double completionPct;
  final double? avgScore;
  final bool isHomeroomView;

  const GradeRecapStatsHero({
    super.key,
    required this.primaryColor,
    required this.classCount,
    required this.studentCount,
    required this.completionPct,
    required this.avgScore,
    required this.isHomeroomView,
  });

  Color _progressColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }

  String get _completionLabel {
    if (completionPct >= 100) return 'Selesai';
    if (completionPct >= 80) return 'Hampir';
    if (completionPct >= 40) return 'Sedang';
    if (completionPct > 0) return 'Mulai';
    return 'Belum';
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = _progressColor(completionPct);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor,
            Color.lerp(primaryColor, Colors.black, 0.15) ?? primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHomeroomView
                          ? Icons.shield_outlined
                          : Icons.school_outlined,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHomeroomView ? 'Wali Kelas' : 'Mengajar',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_graph_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GradeRecapProgressRing(
                value: completionPct / 100,
                size: 64,
                strokeWidth: 6,
                activeColor: Colors.white,
                trackColor: Colors.white.withValues(alpha: 0.22),
                label: '${completionPct.round()}%',
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _completionLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Progres Rekap',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rata-rata penyelesaian rekap nilai',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  value: '$classCount',
                  label: 'Kelas',
                  icon: Icons.class_outlined,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              Expanded(
                child: _StatCell(
                  value: '$studentCount',
                  label: 'Siswa',
                  icon: Icons.people_outline,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              Expanded(
                child: _StatCell(
                  value: avgScore != null
                      ? avgScore!.toStringAsFixed(0)
                      : '–',
                  label: 'Rata-rata',
                  icon: Icons.stars_outlined,
                  valueColor: avgScore != null
                      ? _scoreColorForHero(avgScore!)
                      : Colors.white,
                ),
              ),
            ],
          ),
          // Bar stays for a11y — parents reading the ring might prefer a
          // linear reference too, but we intentionally omit it here because
          // the ring and the big % already convey the same information.
          // Keeping the method in case we need a fallback later.
          if (completionPct < 100 && completionPct > 0) ...[
            const SizedBox(height: 4),
            _thinProgressReference(progressColor),
          ],
        ],
      ),
    );
  }

  Color _scoreColorForHero(double s) {
    // On the dark gradient background, the red/amber palette reads as muted,
    // so we lean on a warmer off-white for sub-optimal scores to keep
    // contrast high. Green stays — it reads well over the brand colour.
    if (s >= 80) return const Color(0xFF86EFAC);
    if (s >= 60) return const Color(0xFFFED7AA);
    return const Color(0xFFFECACA);
  }

  Widget _thinProgressReference(Color activeColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: completionPct / 100,
        minHeight: 2,
        backgroundColor: Colors.white.withValues(alpha: 0.18),
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? valueColor;

  const _StatCell({
    required this.value,
    required this.label,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.6)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor ?? Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
