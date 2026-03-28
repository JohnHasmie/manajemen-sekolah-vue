// Attendance overview card for the dashboard showing today's attendance summary.
//
// Like a Vue `<AttendanceSummaryCard>` dashboard widget. Displays present/absent/
// sick/permitted counts with a colored distribution bar. Similar to a Laravel
// dashboard stat card showing today's attendance breakdown.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A compact dashboard card showing today's attendance summary with a distribution bar.
///
/// Like a Vue `<AttendanceOverviewCard>` with props:
/// - [hadir] / [izin] / [sakit] / [alpha] - attendance counts by status
/// - [total] - total expected attendance
/// - [onTap] - navigate to full attendance screen
///
/// Shows a horizontal stacked bar (like a CSS flexbox progress bar) with
/// color-coded segments for each attendance status, plus a legend.
class AttendanceOverviewCard extends StatelessWidget {
  final int hadir;
  final int izin;
  final int sakit;
  final int alpha;
  final int total;
  final VoidCallback? onTap;

  const AttendanceOverviewCard({
    super.key,
    required this.hadir,
    required this.izin,
    required this.sakit,
    required this.alpha,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = total > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200, width: 1),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.success600.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: ColorUtils.success600.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorUtils.success600.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.how_to_reg_outlined,
                      size: 18,
                      color: ColorUtils.success600,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasData ? '$hadir/$total' : '-',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                            height: 1.1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Absensi Hari Ini',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate600,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Spacer(),
              if (hasData) ...[
                // Mini bar showing attendance distribution
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        if (hadir > 0)
                          Flexible(
                            flex: hadir,
                            child: Container(color: ColorUtils.success600),
                          ),
                        if (izin > 0)
                          Flexible(
                            flex: izin,
                            child: Container(color: ColorUtils.info600),
                          ),
                        if (sakit > 0)
                          Flexible(
                            flex: sakit,
                            child: Container(color: ColorUtils.warning600),
                          ),
                        if (alpha > 0)
                          Flexible(
                            flex: alpha,
                            child: Container(color: ColorUtils.error600),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6),
                // Legend
                Row(
                  children: [
                    _buildLegend(ColorUtils.success600, 'H:$hadir'),
                    SizedBox(width: 6),
                    _buildLegend(ColorUtils.info600, 'I:$izin'),
                    SizedBox(width: 6),
                    _buildLegend(ColorUtils.warning600, 'S:$sakit'),
                    SizedBox(width: 6),
                    _buildLegend(ColorUtils.error600, 'A:$alpha'),
                  ],
                ),
              ] else
                Text(
                  'Belum ada data absensi',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single legend item (colored dot + label) for the attendance bar.
  Widget _buildLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }
}
