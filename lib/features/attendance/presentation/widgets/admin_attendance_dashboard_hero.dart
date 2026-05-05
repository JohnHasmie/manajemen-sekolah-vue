// Admin Kehadiran report dashboard hero — Mockup #11.
//
// Stacks the navy gradient hero (back button + title + DateRangeChipBar
// + AttendanceRingHero), the 2-card KPI strip, and the per-tingkat
// TrendSparkRow panel. Drops below the existing list/table content of
// AdminAttendanceReportScreen as a top-of-page summary.
//
// State: holds the active [AttendanceRange] locally and forwards it
// to `attendanceDashboardProvider` so switching chips re-fetches
// without rebuilding the screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_attendance_components.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_dashboard_service.dart';

class AdminAttendanceDashboardHero extends ConsumerStatefulWidget {
  /// Tap callback for a tingkat row — usually drills into the
  /// per-student detail screen (Mockup #12) filtered to that tingkat.
  final void Function(int tingkat)? onTingkatTap;

  /// Tap callback for the export bar at the bottom of the hero. When
  /// null the bar hides itself.
  final VoidCallback? onExportTap;

  const AdminAttendanceDashboardHero({
    super.key,
    this.onTingkatTap,
    this.onExportTap,
  });

  @override
  ConsumerState<AdminAttendanceDashboardHero> createState() =>
      _AdminAttendanceDashboardHeroState();
}

class _AdminAttendanceDashboardHeroState
    extends ConsumerState<AdminAttendanceDashboardHero> {
  AttendanceRange _range = AttendanceRange.today;

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final async = ref.watch(attendanceDashboardProvider(_range));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Navy hero ────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: ColorUtils.brandGradient('admin'),
            boxShadow: [
              BoxShadow(
                color: navy.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TitleRow(onBack: () => AppNavigator.pop(context)),
                const SizedBox(height: AppSpacing.sm),
                DateRangeChipBar(
                  active: _range,
                  onSelect: (r) => setState(() => _range = r),
                ),
                const SizedBox(height: AppSpacing.lg),
                async.when(
                  data: (d) => AttendanceRingHero(
                    breakdown: d.breakdown,
                    subtitle: d.rangeLabel.isEmpty
                        ? 'Hadir'
                        : 'Hadir ${d.rangeLabel.toLowerCase()}',
                  ),
                  loading: () => const _RingPlaceholder(),
                  error: (_, __) => const _RingPlaceholder(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
        // ── KPI strip (Rata kehadiran + Siswa tidak hadir) ───────
        //
        // Always render the 2-card strip — never collapse it to a
        // SizedBox.shrink. Earlier we hid it on `error` and on the
        // initial-load tick before the API resolved, which left a
        // tall blank gap between the navy hero and the TingkatPanel
        // (the user reported this as "no kpi cards"). Now the strip
        // is part of the page skeleton and the inner values fall
        // back to zeros when data isn't available.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: _KpiStrip(
            avgPct: async.maybeWhen(
              data: (d) => d.avgPct,
              orElse: () => 0,
            ),
            absentCount: async.maybeWhen(
              data: (d) => d.absentCount,
              orElse: () => 0,
            ),
            absentDelta: async.maybeWhen(
              data: (d) => d.absentDelta,
              orElse: () => 0,
            ),
            sparkline: async.maybeWhen(
              data: (d) => d.kpiSparkline,
              orElse: () => const <double>[],
            ),
            isLoading: async.isLoading && !async.hasValue,
          ),
        ),
        // ── Tingkat trend panel ──────────────────────────────────
        async.when(
          data: (d) => _TingkatPanel(
            trends: d.tingkats,
            onTap: widget.onTingkatTap,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        // ── Export bar ───────────────────────────────────────────
        if (widget.onExportTap != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: _ExportBar(onTap: widget.onExportTap!),
          ),
      ],
    );
  }
}

// =====================================================================
// Title row
// =====================================================================

class _TitleRow extends StatelessWidget {
  final VoidCallback onBack;
  const _TitleRow({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onBack,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Akademik · Kehadiran',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Laporan harian',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

// =====================================================================
// KPI strip
// =====================================================================

class _KpiStrip extends StatelessWidget {
  final double avgPct;
  final int absentCount;
  final int absentDelta;
  final List<double> sparkline;
  final bool isLoading;

  const _KpiStrip({
    required this.avgPct,
    required this.absentCount,
    required this.absentDelta,
    required this.sparkline,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _KpiCard(
            kicker: 'RATA KEHADIRAN',
            value: isLoading ? '—' : '${avgPct.toStringAsFixed(1)}%',
            valueColor: ColorUtils.slate900,
            sparkline: sparkline,
            sparklineColor: AttendancePalette.present,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KpiCard(
            kicker: 'SISWA TIDAK HADIR',
            value: isLoading ? '—' : absentCount.toString(),
            valueColor: AttendancePalette.alpha,
            footer: isLoading
                ? 'memuat…'
                : (absentDelta == 0
                    ? 'sama dengan kemarin'
                    : (absentDelta > 0
                        ? '↑ ${absentDelta.abs()} dari kemarin'
                        : '↓ ${absentDelta.abs()} dari kemarin')),
            footerColor:
                absentDelta > 0 ? AttendancePalette.alpha : ColorUtils.slate500,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String kicker;
  final String value;
  final Color valueColor;
  final List<double>? sparkline;
  final Color? sparklineColor;
  final String? footer;
  final Color? footerColor;

  const _KpiCard({
    required this.kicker,
    required this.value,
    required this.valueColor,
    this.sparkline,
    this.sparklineColor,
    this.footer,
    this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // Slightly stronger border + shadow than the original so the
        // cards read clearly on the slate50 background (the user
        // reported them as "missing" because the previous shadow
        // (alpha 0.04) and absent border made them blend in).
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kicker,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          if (sparkline != null && sparkline!.isNotEmpty)
            SizedBox(
              height: 16,
              child: CustomPaint(
                painter: _MiniSpark(
                  points: sparkline!,
                  color: sparklineColor ?? AttendancePalette.present,
                ),
              ),
            )
          else if (footer != null)
            Text(
              footer!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: footerColor ?? ColorUtils.slate500,
              ),
            )
          // Always reserve a third row of space so the two cards stay
          // the same height regardless of whether the data has a
          // sparkline or a footer string. Otherwise the cards visibly
          // shrink mid-frame when the AsyncValue resolves.
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MiniSpark extends CustomPainter {
  final List<double> points;
  final Color color;
  const _MiniSpark({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final maxV = points.reduce((a, b) => a > b ? a : b);
    final minV = points.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV) <= 0 ? 1 : (maxV - minV);

    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final v = points[i];
      final yFrac = 1 - ((v - minV) / span);
      final x = i * dx;
      final y = yFrac * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSpark old) =>
      old.points != points || old.color != color;
}

class _KpiStripSkeleton extends StatelessWidget {
  const _KpiStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        2,
        (_) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Tingkat panel
// =====================================================================

class _TingkatPanel extends StatelessWidget {
  final List<TingkatTrend> trends;
  final void Function(int tingkat)? onTap;

  const _TingkatPanel({required this.trends, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TREN PER TINGKAT · 7 HARI',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < trends.length; i++) ...[
                  TrendSparkRow(
                    label: 'Tingkat ${trends[i].tingkat}',
                    currentPct: trends[i].currentPct,
                    sparkPoints: trends[i].series,
                    deltaPct: trends[i].deltaPct,
                    alertCopy: trends[i].alertCopy,
                    onTap: onTap == null
                        ? null
                        : () => onTap!(trends[i].tingkat),
                  ),
                  if (i < trends.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: ColorUtils.slate100,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Misc
// =====================================================================

class _RingPlaceholder extends StatelessWidget {
  const _RingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 152,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(
                Colors.white.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );
  }
}

class _ExportBar extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 6),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.file_download_rounded, color: navy, size: 22),
              const SizedBox(width: 10),
              Text(
                'Ekspor laporan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PDF · Excel · CSV',
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Buat',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
