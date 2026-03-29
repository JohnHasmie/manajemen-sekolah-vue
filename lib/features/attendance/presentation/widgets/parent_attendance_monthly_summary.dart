// Extracted from parent_attendance_screen.dart (_buildMonthlySummary).
// Like a Vue `<MonthlySummaryCard>` component -- shows the attendance
// percentage bar and per-status counts for the selected period.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/parent_attendance_stat_item.dart';

/// Summary card showing overall attendance percentage and per-status counts.
///
/// Parameters (like Vue props):
/// - [monthlySummary]   -- map of status key → count (hadir, terlambat, etc.)
/// - [hasActiveFilter]  -- true when a month/semester/search filter is active
/// - [primaryColor]     -- role-based accent color (wali = green/teal)
/// - [languageProvider] -- used for translating "Yearly Recap" / "Filtered Recap"
/// - [summaryKey]       -- GlobalKey for the tutorial coach mark target
/// - [getStatusColor]   -- callback to resolve a status key to its Color
class ParentAttendanceMonthlySummary extends StatelessWidget {
  final Map<String, int> monthlySummary;
  final bool hasActiveFilter;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final GlobalKey summaryKey;
  final Color Function(String status) getStatusColor;

  const ParentAttendanceMonthlySummary({
    super.key,
    required this.monthlySummary,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.languageProvider,
    required this.summaryKey,
    required this.getStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays = monthlySummary.values.reduce((a, b) => a + b);
    final attendancePercentage = totalDays > 0
        ? (((monthlySummary['hadir']! + monthlySummary['terlambat']!) /
                    totalDays *
                    100)
                .round())
        : 0;

    return Container(
      key: summaryKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        children: [
          // Header with recap label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasActiveFilter
                    ? languageProvider.getTranslatedText({
                        'en': 'Filtered Recap',
                        'id': 'Rekap Terfilter',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Yearly Recap',
                        'id': 'Rekap Tahunan',
                      }),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Attendance percentage badge
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$attendancePercentage%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppLocalizations.attendanceRate.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Per-status stat items row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ParentAttendanceStatItem(
                label: AppLocalizations.present.tr,
                count: monthlySummary['hadir']!,
                color: getStatusColor('hadir'),
              ),
              ParentAttendanceStatItem(
                label: AppLocalizations.late.tr,
                count: monthlySummary['terlambat']!,
                color: getStatusColor('terlambat'),
              ),
              ParentAttendanceStatItem(
                label: AppLocalizations.permission.tr,
                count: monthlySummary['izin']!,
                color: getStatusColor('izin'),
              ),
              ParentAttendanceStatItem(
                label: AppLocalizations.sick.tr,
                count: monthlySummary['sakit']!,
                color: getStatusColor('sakit'),
              ),
              ParentAttendanceStatItem(
                label: AppLocalizations.alpha.tr,
                count: monthlySummary['alpha']!,
                color: getStatusColor('alpha'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
