import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_helpers.dart';

/// Attendance detail bottom sheet — shown when attendance already filled.
class ScheduleCardAttendanceDetail extends StatelessWidget {
  final String subjectName;
  final String className;
  final Map<String, dynamic> schedule;
  final Map<String, dynamic>? attendance;
  final Color primary;
  final LanguageProvider languageProvider;
  final VoidCallback onEditTap;

  const ScheduleCardAttendanceDetail({
    super.key,
    required this.subjectName,
    required this.className,
    required this.schedule,
    required this.attendance,
    required this.primary,
    required this.languageProvider,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    final hadir = attendance?['hadir'] ?? 0;
    final sakit = attendance?['sakit'] ?? 0;
    final izin = attendance?['izin'] ?? 0;
    final alpha = attendance?['alpha'] ?? 0;
    final total = attendance?['total'] ?? 0;
    final model = Schedule.fromJson(schedule);
    final dayName = model.dayName ?? '';
    final jamKe = model.lessonHour?.toString() ?? '-';
    final timeStr =
        '${formatTimeStr(model.startTime)} – '
        '${formatTimeStr(model.endTime)}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildDateInfo(dayName, timeStr, jamKe),
          const SizedBox(height: 16),
          _buildStatCards(hadir, sakit),
          const SizedBox(height: 12),
          _buildBreakdownSection(sakit, izin, alpha, total),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildHeaderText()),
          _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Attendance Detail',
            'id': 'Detail Absensi',
          }),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subjectName,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return IconButton(
      icon: const Icon(Icons.edit_rounded, color: Colors.white),
      onPressed: onEditTap,
      tooltip: languageProvider.getTranslatedText({'en': 'Edit', 'id': 'Ubah'}),
    );
  }

  Widget _buildDateInfo(String dayName, String timeStr, String jamKe) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: ColorUtils.slate500,
          ),
          const SizedBox(width: 6),
          Text(
            '$dayName · $timeStr',
            style: TextStyle(fontSize: 13, color: ColorUtils.slate600),
          ),
          const SizedBox(width: 12),
          Text(
            'Jam ke-$jamKe',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate700,
            ),
          ),
          const Spacer(),
          Text(
            'Kelas: $className',
            style: TextStyle(fontSize: 13, color: ColorUtils.slate600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(int hadir, int sakit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _AttendanceStatCard(
            label: languageProvider.getTranslatedText({
              'en': 'Present',
              'id': 'Hadir',
            }),
            count: hadir,
            color: ColorUtils.success600,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(width: 8),
          _AttendanceStatCard(
            label: languageProvider.getTranslatedText({
              'en': 'Late',
              'id': 'Terlambat',
            }),
            count: 0,
            color: Colors.orange,
            icon: Icons.access_time_rounded,
          ),
          const SizedBox(width: 8),
          _AttendanceStatCard(
            label: languageProvider.getTranslatedText({
              'en': 'Absent',
              'id': 'Tidak Hadir',
            }),
            count: sakit,
            color: ColorUtils.error600,
            icon: Icons.cancel_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection(int sakit, int izin, int alpha, int total) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBreakdownItemSakit(sakit),
            _buildBreakdownItemIzin(izin),
            _buildBreakdownItemAlpha(alpha),
            _buildBreakdownItemTotal(total),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItemSakit(int sakit) {
    return _AttendanceBreakdownItem(
      label: languageProvider.getTranslatedText({'en': 'Sick', 'id': 'Sakit'}),
      count: sakit,
      color: Colors.orange,
    );
  }

  Widget _buildBreakdownItemIzin(int izin) {
    return _AttendanceBreakdownItem(
      label: languageProvider.getTranslatedText({'en': 'Permit', 'id': 'Izin'}),
      count: izin,
      color: ColorUtils.warning600,
    );
  }

  Widget _buildBreakdownItemAlpha(int alpha) {
    return _AttendanceBreakdownItem(
      label: 'Alpha',
      count: alpha,
      color: ColorUtils.error600,
    );
  }

  Widget _buildBreakdownItemTotal(int total) {
    return _AttendanceBreakdownItem(
      label: 'Total',
      count: total,
      color: ColorUtils.slate700,
    );
  }
}

class _AttendanceStatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _AttendanceStatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceBreakdownItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _AttendanceBreakdownItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: ColorUtils.slate500)),
      ],
    );
  }
}
