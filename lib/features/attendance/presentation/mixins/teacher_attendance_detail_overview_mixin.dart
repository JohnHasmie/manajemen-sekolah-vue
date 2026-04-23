import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';

/// Mixin for overview card building.
mixin TeacherAttendanceDetailOverviewMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  /// Build overview card with statistics
  Widget buildOverviewCard(
    LanguageProvider languageProvider,
    Map<String, int> stats,
    int totalStudents,
  ) {
    final presentCount = stats['hadir'] ?? 0;
    final lateCount = stats['terlambat'] ?? 0;
    final sickCount = stats['sakit'] ?? 0;
    final permitCount = stats['izin'] ?? 0;
    final absentCount = stats['alpha'] ?? 0;

    final attendanceRate = totalStudents > 0
        ? ((presentCount + lateCount) / totalStudents * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ColorUtils.corporateCard(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    height: 78,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(78, 78),
                          painter: AttendanceDonutPainter(
                            present: presentCount,
                            late: lateCount,
                            sick: sickCount,
                            permit: permitCount,
                            absent: absentCount,
                            total: totalStudents,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$attendanceRate%',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Rate',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate400,
                                height: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildVerticalDivider(),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Status Summary',
                            'id': 'Ringkasan Status',
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate500,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildLegendItem('Hadir', ColorUtils.success600),
                            const SizedBox(width: 8),
                            _buildLegendItem('Telat', Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildLegendItem('Skt/Izn', ColorUtils.warning600),
                            const SizedBox(width: 8),
                            _buildLegendItem('Alpha', ColorUtils.error600),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildVerticalDivider(),
                  Container(
                    width: 54,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$totalStudents',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: ColorUtils.slate800,
                          ),
                        ),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Students',
                            'id': 'Siswa',
                          }),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: ColorUtils.slate50.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactMetric(
                  'Hadir',
                  presentCount,
                  ColorUtils.success600,
                ),
                _buildSeparator(),
                _buildCompactMetric('Telat', lateCount, Colors.orange),
                _buildSeparator(),
                _buildCompactMetric(
                  'Izin',
                  permitCount + sickCount,
                  ColorUtils.warning600,
                ),
                _buildSeparator(),
                _buildCompactMetric('Alpha', absentCount, ColorUtils.error600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ColorUtils.slate100.withValues(alpha: 0),
            ColorUtils.slate200,
            ColorUtils.slate100.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Container(
      width: 1,
      height: 12,
      color: ColorUtils.slate200.withValues(alpha: 0.5),
    );
  }

  Widget _buildCompactMetric(String label, int count, Color color) {
    return Row(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate400,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }
}
