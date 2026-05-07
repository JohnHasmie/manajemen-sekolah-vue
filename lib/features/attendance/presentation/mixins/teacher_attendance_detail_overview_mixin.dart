import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';

/// KPI overlay for the attendance detail screen — Frame B/F mockup.
///
/// Replaces the legacy donut + legend card with a clean 4-cell strip
/// (`HADIR · SAKIT · IZIN · ALPA`) that overlaps the bottom of the
/// gradient header. The values are bold and brand-coloured; labels are
/// uppercase slate. Matches the mockup's `.kpi-card .kpi-row`.
mixin TeacherAttendanceDetailOverviewMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  /// Build the KPI overlap card.
  ///
  /// Note: legacy callers pass `totalStudents` so the signature is kept
  /// compatible — the count is no longer rendered (the count belongs on
  /// the section head row instead).
  Widget buildOverviewCard(
    LanguageProvider lp,
    Map<String, int> stats,
    int totalStudents,
  ) {
    final hadir = stats['hadir'] ?? 0;
    final terlambat = stats['terlambat'] ?? 0;
    // Mockup folds Telat into Sakit visually (only 4 cells), but the
    // app distinguishes Telat. We surface both: Hadir + Telat counted
    // together would mask late arrivals, so keep Sakit as Sakit and
    // surface Telat next to it via colour.
    final sakit = stats['sakit'] ?? 0;
    final izin = stats['izin'] ?? 0;
    final alpha = stats['alpha'] ?? 0;

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
            _kpiCell('Hadir', hadir, ColorUtils.success600),
            _divider(),
            _kpiCell('Telat', terlambat, ColorUtils.violet700),
            _divider(),
            _kpiCell('Sakit', sakit, ColorUtils.warning600),
            _divider(),
            _kpiCell('Izin', izin, ColorUtils.info600),
            _divider(),
            _kpiCell('Alpa', alpha, ColorUtils.error600),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell(String label, int value, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
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

  Widget _divider() {
    return Container(width: 1, height: 28, color: ColorUtils.slate100);
  }
}
