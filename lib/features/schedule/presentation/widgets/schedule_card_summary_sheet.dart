import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_helpers.dart';

/// Quick summary bottom sheet shown on card tap.
class ScheduleCardSummarySheet extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic>? summary;
  final LanguageProvider languageProvider;
  final Color primary;
  final VoidCallback onAttendanceTap;
  final VoidCallback onMaterialTap;
  final VoidCallback onActivityTap;

  const ScheduleCardSummarySheet({
    super.key,
    required this.schedule,
    required this.summary,
    required this.languageProvider,
    required this.primary,
    required this.onAttendanceTap,
    required this.onMaterialTap,
    required this.onActivityTap,
  });

  String _buildDayTimeLabel() {
    final model = Schedule.fromJson(schedule);
    final dayName = model.dayName ?? '';
    final normalizedDay = kDayNames.keys.firstWhere(
      (k) => dayName.toLowerCase().contains(k.toLowerCase()),
      orElse: () => dayName,
    );
    final dayTranslation = kDayNames[normalizedDay];
    final dayLabel = dayTranslation != null
        ? languageProvider.getTranslatedText(dayTranslation)
        : normalizedDay;
    final startTime = formatTimeStr(model.startTime);
    final endTime = formatTimeStr(model.endTime);
    return '$dayLabel, $startTime – $endTime';
  }

  @override
  Widget build(BuildContext context) {
    final model = Schedule.fromJson(schedule);
    final subjectName = (model.subjectName ?? '').isEmpty ? '-' : model.subjectName!;
    final className = (model.className ?? '').isEmpty ? '-' : model.className!;
    final summaryData = _extractSummaryData();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDragHandle(),
          const SizedBox(height: 16),
          _buildTitleSection(subjectName, className),
          const SizedBox(height: 16),
          _buildAttendanceRow(
            summaryData.hadir,
            summaryData.sakit,
            summaryData.izin,
            summaryData.alpha,
            summaryData.attFilled,
          ),
          const Divider(height: 1),
          _buildActivityRow(summaryData.actCount),
          const Divider(height: 1),
          _buildMaterialRow(summaryData.matChecked, summaryData.matTotal),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  ({
    int hadir,
    int sakit,
    int izin,
    int alpha,
    bool attFilled,
    int actCount,
    int matChecked,
    int matTotal,
  })
  _extractSummaryData() {
    final att = summary?['attendance'];
    final act = summary?['class_activity'];
    final mat = summary?['material_progress'];

    return (
      hadir: att?['hadir'] ?? 0,
      sakit: att?['sakit'] ?? 0,
      izin: att?['izin'] ?? 0,
      alpha: att?['alpha'] ?? 0,
      attFilled: att?['filled'] == true,
      actCount: act?['count'] ?? 0,
      matChecked: mat?['checked'] ?? 0,
      matTotal: mat?['total'] ?? 0,
    );
  }

  Widget _buildDragHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: ColorUtils.slate300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildTitleSection(String subjectName, String className) {
    return Column(
      children: [
        Text(
          '$subjectName — $className',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          _buildDayTimeLabel(),
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceRow(
    int hadir,
    int sakit,
    int izin,
    int alpha,
    bool attFilled,
  ) {
    final presentLabel = languageProvider.getTranslatedText({
      'en': 'Present',
      'id': 'Hadir',
    });
    final sickLabel = languageProvider.getTranslatedText({
      'en': 'Sick',
      'id': 'Sakit',
    });
    final permitLabel = languageProvider.getTranslatedText({
      'en': 'Permit',
      'id': 'Izin',
    });
    final notFilledLabel = languageProvider.getTranslatedText({
      'en': 'Not yet filled',
      'id': 'Belum diisi',
    });

    return _ScheduleSummaryRow(
      icon: Icons.fact_check_rounded,
      color: attFilled ? ColorUtils.success600 : ColorUtils.slate400,
      title: languageProvider.getTranslatedText({
        'en': 'Attendance',
        'id': 'Presensi',
      }),
      subtitle: attFilled
          ? '$presentLabel: $hadir  '
                '$sickLabel: $sakit  '
                '$permitLabel: $izin  '
                'Alpha: $alpha'
          : notFilledLabel,
      onTap: onAttendanceTap,
    );
  }

  Widget _buildActivityRow(int actCount) {
    final activitiesLabel = languageProvider.getTranslatedText({
      'en': 'activities',
      'id': 'kegiatan',
    });
    final noActivitiesLabel = languageProvider.getTranslatedText({
      'en': 'No activities today',
      'id': 'Belum ada kegiatan',
    });

    return _ScheduleSummaryRow(
      icon: Icons.assignment_rounded,
      color: actCount > 0 ? ColorUtils.warning600 : ColorUtils.slate400,
      title: languageProvider.getTranslatedText({
        'en': 'Class Activity',
        'id': 'Kegiatan Kelas',
      }),
      subtitle: actCount > 0 ? '$actCount $activitiesLabel' : noActivitiesLabel,
      onTap: onActivityTap,
    );
  }

  Widget _buildMaterialRow(int matChecked, int matTotal) {
    final chaptersLabel = languageProvider.getTranslatedText({
      'en': 'chapters',
      'id': 'bab',
    });
    final noMaterialLabel = languageProvider.getTranslatedText({
      'en': 'No material data',
      'id': 'Belum ada data materi',
    });

    return _ScheduleSummaryRow(
      icon: Icons.library_books_rounded,
      color: matChecked > 0 ? ColorUtils.corporateBlue600 : ColorUtils.slate400,
      title: languageProvider.getTranslatedText({
        'en': 'Material Progress',
        'id': 'Progress Materi',
      }),
      subtitle: matTotal > 0
          ? '$matChecked / $matTotal $chaptersLabel'
          : noMaterialLabel,
      onTap: onMaterialTap,
    );
  }
}

class _ScheduleSummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ScheduleSummaryRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            _buildIconBox(),
            const SizedBox(width: 14),
            Expanded(child: _buildTextColumn()),
            Icon(
              Icons.chevron_right_rounded,
              color: ColorUtils.slate400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBox() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildTextColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
        ),
      ],
    );
  }
}
