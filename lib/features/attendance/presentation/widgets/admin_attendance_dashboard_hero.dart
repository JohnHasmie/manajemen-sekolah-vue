// Admin Kehadiran dashboard hero — Mockup #11, refactored.
//
// Stacks the shared BrandPageHeader + BrandKpiStrip overlap idiom
// every other admin screen uses, then drops a per-tingkat trend
// panel and an export bar below as body cards. The previous bespoke
// gradient + ring + 2-card KPI hybrid has been retired:
//   • Ring chart removed — its information is now surfaced by the
//     "Rata kehadiran" KPI column.
//   • 2-card KPI strip → 3-column `BrandKpiStrip` (Hadir / Tidak Hadir
//     / Rata kehadiran), overlapping the gradient like the parent
//     Tagihan / Nilai cards.
//
// State: holds the active [AttendanceRange] locally and forwards it
// to `attendanceDashboardProvider` so switching chips re-fetches
// without rebuilding the screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_attendance_components.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_dashboard_service.dart';

class AdminAttendanceDashboardHero extends ConsumerStatefulWidget {
  /// Tap callback for a tingkat row — usually drills into the
  /// per-student detail screen (Mockup #12) filtered to that tingkat.
  final void Function(int tingkat)? onTingkatTap;

  /// Tap callback for the export bar at the bottom of the body. When
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
    final async = ref.watch(attendanceDashboardProvider(_range));
    final data = async.maybeWhen(data: (d) => d, orElse: () => null);

    return BrandPageLayout(
      role: 'admin',
      onRefresh: () async {
        ref.invalidate(attendanceDashboardProvider(_range));
      },
      header: BrandPageHeader(
        role: 'admin',
        subtitle: kAttAcademicAttendance.tr,
        title: kAttDailyReport.tr,
        isRealtimeFresh: !async.isLoading && !async.hasError,
        // Reserve gradient overlap below the chip strip so the KPI
        // strip's top tucks into navy instead of covering the chips.
        kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
        bottomSlot: DateRangeChipBar(
          active: _range,
          onSelect: (r) => setState(() => _range = r),
          padding: EdgeInsets.zero,
        ),
      ),
      kpiCard: BrandKpiStrip(
        columns: [
          BrandKpiColumn(
            label: kPresent.tr,
            value: '${data?.breakdown.present ?? 0}',
            valueColor: const Color(0xFF15803D),
            sub: data == null
                ? null
                : '${data.breakdown.presentPct.toStringAsFixed(0)}${kAttPercentPresent.tr}',
          ),
          BrandKpiColumn(
            label: kAttAbsent.tr,
            value: '${data?.absentCount ?? 0}',
            valueColor: const Color(0xFFDC2626),
            sub: data == null
                ? null
                : (data.absentDelta == 0
                      ? kAttSameAsYesterday.tr
                      : data.absentDelta > 0
                      ? kAttIncreaseFromYesterday.tr.replaceFirst('↑', '↑ ${data.absentDelta.abs()}')
                      : kAttDecreaseFromYesterday.tr.replaceFirst('↓', '↓ ${data.absentDelta.abs()}')),
          ),
          BrandKpiColumn(
            label: kAttAverageAttendance.tr,
            value: data == null ? '0%' : '${data.avgPct.toStringAsFixed(1)}%',
            valueColor: ColorUtils.slate900,
            sub: data == null || data.rangeLabel.isEmpty
                ? null
                : data.rangeLabel.toLowerCase(),
          ),
        ],
      ),
      bodyChildren: [
        const SizedBox(height: AppSpacing.md),
        // Per-tingkat trend panel — only when we have data. Loading +
        // error fall back to a thin placeholder so the body never
        // collapses to 0dp height.
        async.when(
          data: (d) =>
              _TingkatPanel(trends: d.tingkats, onTap: widget.onTingkatTap),
          loading: () => const SizedBox(height: 80),
          error: (_, __) => const SizedBox(height: 8),
        ),
        if (widget.onExportTap != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: _ExportBar(onTap: widget.onExportTap!),
          ),
      ],
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
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kAttTrendByGrade7Days.tr,
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
                    label: '${kAttGrade.tr} ${trends[i].tingkat}',
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
// Export bar
// =====================================================================

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
                kAttExportReport.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PDF · Excel · CSV',
                style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: navy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  kAttCreate.tr,
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
