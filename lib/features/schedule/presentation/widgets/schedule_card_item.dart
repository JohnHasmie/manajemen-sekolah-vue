// A single schedule entry card shown in the card-list view.
// Extracted from TeachingScheduleScreen._buildScheduleCard().
//
// Like a Vue `<ScheduleCard :schedule="..." :teacher="..." />` component.
// All data flows in via constructor params; navigation callbacks are passed
// from the parent state so this widget stays StatelessWidget.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_info_tag.dart';

/// Formats a raw time string like "07.30.00" or "07:30:00" → "07:30".
String _formatTimeStr(String? time) {
  if (time == null || time.isEmpty) return '--:--';
  final cleanedTime = time.replaceAll('.', ':');
  final timeParts = cleanedTime.split(':');
  if (timeParts.length >= 2) {
    final hour = timeParts[0].padLeft(2, '0');
    final minute = timeParts[1].padLeft(2, '0');
    return '$hour:$minute';
  }
  return time.length >= 5 ? time.substring(0, 5) : time;
}

const _kDayNames = <String, Map<String, String>>{
  'Senin': {'en': 'Monday', 'id': 'Senin'},
  'Selasa': {'en': 'Tuesday', 'id': 'Selasa'},
  'Rabu': {'en': 'Wednesday', 'id': 'Rabu'},
  'Kamis': {'en': 'Thursday', 'id': 'Kamis'},
  'Jumat': {'en': 'Friday', 'id': 'Jumat'},
  'Sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
  'Minggu': {'en': 'Sunday', 'id': 'Minggu'},
};

/// A card displaying one schedule entry with subject, day badge, time/class
/// info tags, and quick-action buttons for Materials and Class Activity.
///
/// In Laravel terms: like a Blade `@component('schedule-card', ['schedule' => $s])`.
class ScheduleCardItem extends StatelessWidget {
  const ScheduleCardItem({
    super.key,
    required this.schedule,
    required this.languageProvider,
    required this.index,
    required this.dayIdMap,
    required this.dayColorMap,
    required this.dayOptions,
    required this.selectedAcademicYear,
    required this.teacherId,
    required this.teacherNama,
    this.firstScheduleKey,
    this.actionButtonsKey,
    this.isPast = false,
    this.dailySummary,
  });

  /// The raw schedule map from the API (e.g. `{ 'mata_pelajaran_nama': '...' }`).
  final Map<String, dynamic> schedule;

  /// Used for translating UI strings to the user's locale.
  final LanguageProvider languageProvider;

  /// Zero-based position in the list — used to attach GlobalKeys for the
  /// onboarding tour to the first card's elements.
  final int index;

  /// Maps day names (Bahasa) to their numeric IDs, e.g. `{'Senin': '1', ...}`.
  final Map<String, String> dayIdMap;

  /// Maps day names to their brand colors, e.g. `{'Senin': Color(...), ...}`.
  final Map<String, Color> dayColorMap;

  /// Ordered list of day names used to compute "next occurrence" dates.
  final List<String> dayOptions;

  /// Currently selected academic year string, e.g. `"2024/2025"`.
  final String selectedAcademicYear;

  /// The logged-in teacher's ID (passed to navigation destinations).
  final String teacherId;

  /// The logged-in teacher's display name.
  final String teacherNama;

  /// Attached to the card container of the first item for the onboarding tour.
  final GlobalKey? firstScheduleKey;

  /// Attached to the action-buttons row of the first item for the onboarding tour.
  final GlobalKey? actionButtonsKey;

  /// Whether this schedule hour has already passed (dimmed styling).
  final bool isPast;

  /// Daily summary data keyed by "{class_id}__{subject_id}" for button fill states.
  final Map<String, dynamic>? dailySummary;

  // ---------------------------------------------------------------------------
  // Pure helper methods (no state read — safe to be static / top-level)
  // ---------------------------------------------------------------------------

  /// Formats a raw time string like "07.30.00" or "07:30:00" → "07:30".
  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    final cleanedTime = time.replaceAll('.', ':');
    final timeParts = cleanedTime.split(':');
    if (timeParts.length >= 2) {
      final hour = timeParts[0].padLeft(2, '0');
      final minute = timeParts[1].padLeft(2, '0');
      return '$hour:$minute';
    }
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  // ---------------------------------------------------------------------------
  // Summary lookup helpers
  // ---------------------------------------------------------------------------

  /// Looks up this card's summary from the daily summary map.
  /// Only returns data for today's schedule — attendance/activity are date-specific,
  /// so showing "filled" on other days would be misleading.
  Map<String, dynamic>? _getSummary() {
    if (dailySummary == null) return null;
    // Only show summary for today's schedules
    if (!_isScheduleToday()) return null;
    final summaries = dailySummary!['summaries'];
    if (summaries == null || summaries is! Map) return null;
    final classId = (schedule['class_id'] ?? schedule['kelas_id'])?.toString();
    final subjectId = (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();
    if (classId == null || subjectId == null) return null;
    final key = '${classId}__$subjectId';
    final s = summaries[key];
    return s is Map<String, dynamic> ? s : null;
  }

  /// Whether this schedule's day matches today's weekday.
  bool _isScheduleToday() {
    final dayId = (schedule['day_id'] ?? schedule['hari_id'])?.toString();
    if (dayId == null) return false;
    final entry = dayIdMap.entries.firstWhere(
      (e) => e.value.toString() == dayId,
      orElse: () => const MapEntry('', ''),
    );
    if (entry.key.isEmpty) return false;
    const dayWeekdays = {'Senin': 1, 'Selasa': 2, 'Rabu': 3, 'Kamis': 4, 'Jumat': 5, 'Sabtu': 6, 'Minggu': 7};
    final name = entry.key;
    final normalized = _kDayNames.keys.firstWhere(
      (k) => name.toLowerCase().contains(k.toLowerCase()),
      orElse: () => '',
    );
    return dayWeekdays[normalized] == DateTime.now().weekday;
  }

  bool _hasAttendance(Map<String, dynamic>? summary) =>
      summary != null && summary['attendance']?['filled'] == true;

  bool _hasActivity(Map<String, dynamic>? summary) =>
      summary != null && summary['class_activity']?['filled'] == true;

  bool _hasMaterial(Map<String, dynamic>? summary) =>
      summary != null && (summary['material_progress']?['checked'] ?? 0) > 0;

  /// Computes the next calendar date this schedule occurs.
  DateTime _computeScheduleDate() {
    final now = DateTime.now();
    final scheduleDay = dayIdMap.entries
        .firstWhere(
          (entry) => entry.value.toString() == (schedule['day_id'] ?? schedule['hari_id'])?.toString(),
          orElse: () => const MapEntry('Senin', '1'),
        )
        .key;
    final scheduleDayIndex = dayOptions.indexOf(scheduleDay);
    final todayIndex = now.weekday;
    int daysUntil = scheduleDayIndex - todayIndex;
    if (daysUntil < 0) daysUntil += 7;
    return now.add(Duration(days: daysUntil));
  }

  // ---------------------------------------------------------------------------
  // Extracted getters for schedule fields (used by buttons and summary)
  // ---------------------------------------------------------------------------

  String? get _subjectId => (schedule['subject_id'] ?? schedule['mata_pelajaran_id'])?.toString();
  String? get _subjectName => (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'])?.toString();
  String? get _classId => (schedule['class_id'] ?? schedule['kelas_id'])?.toString();
  String? get _className => (schedule['class_name'] ?? schedule['kelas_nama'])?.toString();

  @override
  Widget build(BuildContext context) {
    // Use role-based theme color, not per-day colors
    final primary = _getPrimaryColor();
    final accentColor = isPast ? ColorUtils.slate400 : primary;
    final textColor = isPast ? ColorUtils.slate500 : ColorUtils.slate900;
    final subTextColor = isPast ? ColorUtils.slate400 : ColorUtils.slate500;

    // Summary-based fill states for buttons
    final summary = _getSummary();
    final attendanceFilled = _hasAttendance(summary);
    final activityFilled = _hasActivity(summary);
    final materialFilled = _hasMaterial(summary);
    final allFilled = attendanceFilled && activityFilled && materialFilled;

    // When all 3 are filled, card gets theme background
    final cardBg = allFilled ? primary.withValues(alpha: 0.08) : Colors.white;
    final cardBorder = allFilled
        ? primary.withValues(alpha: 0.3)
        : isPast ? ColorUtils.slate200 : ColorUtils.slate200;

    return Container(
      key: index == 0 ? firstScheduleKey : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSummarySheet(context, summary),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Opacity(
            opacity: isPast ? 0.7 : 1.0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: cardBorder),
                boxShadow: isPast ? [] : ColorUtils.corporateShadow(elevation: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row: icon + subject name (no day badge) ──────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                        ),
                        child: Icon(Icons.menu_book_rounded, color: accentColor, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule['mata_pelajaran_nama'] ?? languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'}),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Kelas: ${schedule['kelas_nama'] ?? '-'}',
                              style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // ── Info tags: time, jam ke, semester ──────────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ScheduleInfoTag(
                        icon: Icons.access_time_rounded,
                        label: '${_formatTime(schedule["jam_mulai"])} – ${_formatTime(schedule["jam_selesai"])}',
                        color: accentColor,
                      ),
                      ScheduleInfoTag(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Jam ke-${schedule["jam_ke"] ?? "-"}',
                        color: accentColor,
                      ),
                      if (schedule['semester_nama'] != null)
                        ScheduleInfoTag(
                          icon: Icons.calendar_month_rounded,
                          label: schedule['semester_nama'],
                          color: subTextColor,
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── 3 Action buttons: Presensi | Materi | Kegiatan Kelas ─
                  Row(
                    key: index == 0 ? actionButtonsKey : null,
                    children: [
                      // Presensi button
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.fact_check_rounded,
                          label: languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Presensi'}),
                          isFilled: attendanceFilled,
                          primary: primary,
                          onPressed: () {
                            _openAttendance(context, attendanceFilled);
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Materi button
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.library_books_rounded,
                          label: languageProvider.getTranslatedText({'en': 'Material', 'id': 'Materi'}),
                          isFilled: materialFilled,
                          primary: primary,
                          onPressed: () => _openMaterial(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Kegiatan Kelas button
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.assignment_rounded,
                          label: languageProvider.getTranslatedText({'en': 'Class Activity', 'id': 'Kegiatan Kelas'}),
                          isFilled: activityFilled,
                          primary: primary,
                          onPressed: () => _openClassActivity(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation methods — open as full-screen dialog
  // ---------------------------------------------------------------------------

  void _openAttendance(BuildContext context, bool hasData) {
    if (hasData) {
      // Show attendance detail as a bottom sheet dialog
      final summary = _getSummary();
      final att = summary?['attendance'];
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AttendanceDetailSheet(
          subjectName: _subjectName ?? '-',
          className: _className ?? '-',
          schedule: schedule,
          attendance: att,
          primary: _getPrimaryColor(),
          languageProvider: languageProvider,
          onEditTap: () {
            Navigator.pop(context);
            _showAttendanceDialog(context, 1); // go to input tab
          },
        ),
      );
    } else {
      // No data yet — open input mode as dialog
      _showAttendanceDialog(context, 1);
    }
  }

  void _showAttendanceDialog(BuildContext context, int tabIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => AttendancePage(
        teacher: {'id': teacherId, 'nama': teacherNama},
        initialDate: _computeScheduleDate(),
        initialSubjectId: _subjectId,
        initialSubjectName: _subjectName,
        initialclassId: _classId,
        initialClassName: _className,
        initialLessonHourNumber: int.tryParse(schedule['jam_ke']?.toString() ?? ''),
        initialTabIndex: tabIndex,
        embedded: true,
      ),
    );
  }

  void _openMaterial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: TeacherMaterialScreen(
            teacher: {'id': teacherId, 'nama': teacherNama},
            initialSubjectId: _subjectId,
            initialSubjectName: _subjectName,
            initialClassId: _classId,
            initialClassName: _className,
            embedded: true,
          ),
        ),
      ),
    );
  }

  void _openClassActivity(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: ClassActivityScreen(
            initialDate: _computeScheduleDate(),
            initialSubjectId: _subjectId,
            initialSubjectName: _subjectName,
            initialClassId: _classId,
            initialClassName: _className,
            autoShowActivityDialog: false,
            embedded: true,
          ),
        ),
      ),
    );
  }

  void _showSummarySheet(BuildContext context, Map<String, dynamic>? summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleQuickSummary(
        schedule: schedule,
        summary: summary,
        languageProvider: languageProvider,
        primary: _getPrimaryColor(),
        onAttendanceTap: () {
          Navigator.pop(context);
          _openAttendance(context, _hasAttendance(summary));
        },
        onMaterialTap: () {
          Navigator.pop(context);
          _openMaterial(context);
        },
        onActivityTap: () {
          Navigator.pop(context);
          _openClassActivity(context);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable action button with filled/outline states
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isFilled;
  final Color primary;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isFilled,
    required this.primary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isFilled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          elevation: 0,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 2),
          ],
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: primary.withValues(alpha: 0.4), width: 1),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primary), textAlign: TextAlign.center, maxLines: 2),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick summary bottom sheet shown on card tap
// ---------------------------------------------------------------------------

class _ScheduleQuickSummary extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Map<String, dynamic>? summary;
  final LanguageProvider languageProvider;
  final Color primary;
  final VoidCallback onAttendanceTap;
  final VoidCallback onMaterialTap;
  final VoidCallback onActivityTap;

  const _ScheduleQuickSummary({
    required this.schedule,
    required this.summary,
    required this.languageProvider,
    required this.primary,
    required this.onAttendanceTap,
    required this.onMaterialTap,
    required this.onActivityTap,
  });

  String _buildDayTimeLabel() {
    final dayName = (schedule['hari_nama'] ?? schedule['day_name'] ?? '').toString();
    final normalizedDay = _kDayNames.keys.firstWhere(
      (k) => dayName.toLowerCase().contains(k.toLowerCase()),
      orElse: () => dayName,
    );
    final dayTranslation = _kDayNames[normalizedDay];
    final dayLabel = dayTranslation != null
        ? languageProvider.getTranslatedText(dayTranslation)
        : normalizedDay;
    final startTime = _formatTimeStr(schedule['jam_mulai']?.toString());
    final endTime = _formatTimeStr(schedule['jam_selesai']?.toString());
    return '$dayLabel, $startTime – $endTime';
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = schedule['mata_pelajaran_nama'] ?? '-';
    final className = schedule['kelas_nama'] ?? '-';

    final att = summary?['attendance'];
    final act = summary?['class_activity'];
    final mat = summary?['material_progress'];

    final hadir = att?['hadir'] ?? 0;
    final sakit = att?['sakit'] ?? 0;
    final izin = att?['izin'] ?? 0;
    final alpha = att?['alpha'] ?? 0;
    final attFilled = att?['filled'] == true;
    final actCount = act?['count'] ?? 0;
    final matChecked = mat?['checked'] ?? 0;
    final matTotal = mat?['total'] ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            '$subjectName — $className',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            languageProvider.getTranslatedText({'en': 'Schedule Summary', 'id': 'Ringkasan Jadwal Ini'}),
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
          ),
          const SizedBox(height: 2),
          Text(
            _buildDayTimeLabel(),
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // Attendance row
          _SummaryRow(
            icon: Icons.fact_check_rounded,
            color: attFilled ? ColorUtils.success600 : ColorUtils.slate400,
            title: languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Presensi'}),
            subtitle: attFilled
                ? '${languageProvider.getTranslatedText({'en': 'Present', 'id': 'Hadir'})}: $hadir  ${languageProvider.getTranslatedText({'en': 'Sick', 'id': 'Sakit'})}: $sakit  ${languageProvider.getTranslatedText({'en': 'Permit', 'id': 'Izin'})}: $izin  Alpha: $alpha'
                : languageProvider.getTranslatedText({'en': 'Not yet filled', 'id': 'Belum diisi'}),
            onTap: onAttendanceTap,
          ),

          const Divider(height: 1),

          // Class Activity row
          _SummaryRow(
            icon: Icons.assignment_rounded,
            color: actCount > 0 ? ColorUtils.warning600 : ColorUtils.slate400,
            title: languageProvider.getTranslatedText({'en': 'Class Activity', 'id': 'Kegiatan Kelas'}),
            subtitle: actCount > 0
                ? '$actCount ${languageProvider.getTranslatedText({'en': 'activities', 'id': 'kegiatan'})}'
                : languageProvider.getTranslatedText({'en': 'No activities today', 'id': 'Belum ada kegiatan'}),
            onTap: onActivityTap,
          ),

          const Divider(height: 1),

          // Material Progress row
          _SummaryRow(
            icon: Icons.library_books_rounded,
            color: matChecked > 0 ? ColorUtils.corporateBlue600 : ColorUtils.slate400,
            title: languageProvider.getTranslatedText({'en': 'Material Progress', 'id': 'Progress Materi'}),
            subtitle: matTotal > 0
                ? '$matChecked / $matTotal ${languageProvider.getTranslatedText({'en': 'chapters', 'id': 'bab'})}'
                : languageProvider.getTranslatedText({'en': 'No material data', 'id': 'Belum ada data materi'}),
            onTap: onMaterialTap,
          ),
        ],
      ),
    );
  }
}

/// Attendance detail bottom sheet — shown when attendance already filled.
/// Like the "Detail Absensi" screen in the screenshot but as a dialog.
class _AttendanceDetailSheet extends StatelessWidget {
  final String subjectName;
  final String className;
  final Map<String, dynamic> schedule;
  final Map<String, dynamic>? attendance;
  final Color primary;
  final LanguageProvider languageProvider;
  final VoidCallback onEditTap;

  const _AttendanceDetailSheet({
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
    final dayName = (schedule['hari_nama'] ?? schedule['day_name'] ?? '').toString();
    final jamKe = schedule['jam_ke']?.toString() ?? '-';
    final timeStr = '${_formatTimeStr(schedule['jam_mulai']?.toString())} – ${_formatTimeStr(schedule['jam_selesai']?.toString())}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({'en': 'Attendance Detail', 'id': 'Detail Absensi'}),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subjectName,
                        style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: onEditTap,
                  tooltip: languageProvider.getTranslatedText({'en': 'Edit', 'id': 'Ubah'}),
                ),
              ],
            ),
          ),

          // Date + Jam info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: ColorUtils.slate500),
                const SizedBox(width: 6),
                Text(
                  '$dayName · $timeStr',
                  style: TextStyle(fontSize: 13, color: ColorUtils.slate600),
                ),
                const SizedBox(width: 12),
                Text(
                  'Jam ke-$jamKe',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate700),
                ),
                const Spacer(),
                Text(
                  'Kelas: $className',
                  style: TextStyle(fontSize: 13, color: ColorUtils.slate600),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Stats cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _StatCard(label: languageProvider.getTranslatedText({'en': 'Present', 'id': 'Hadir'}), count: hadir, color: ColorUtils.success600, icon: Icons.check_circle_rounded),
                const SizedBox(width: 8),
                _StatCard(label: languageProvider.getTranslatedText({'en': 'Late', 'id': 'Terlambat'}), count: 0, color: Colors.orange, icon: Icons.access_time_rounded),
                const SizedBox(width: 8),
                _StatCard(label: languageProvider.getTranslatedText({'en': 'Absent', 'id': 'Tidak Hadir'}), count: sakit + izin + alpha, color: ColorUtils.error600, icon: Icons.cancel_rounded),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Breakdown
          Padding(
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
                  _BreakdownItem(label: languageProvider.getTranslatedText({'en': 'Sick', 'id': 'Sakit'}), count: sakit, color: Colors.orange),
                  _BreakdownItem(label: languageProvider.getTranslatedText({'en': 'Permit', 'id': 'Izin'}), count: izin, color: ColorUtils.warning600),
                  _BreakdownItem(label: 'Alpha', count: alpha, color: ColorUtils.error600),
                  _BreakdownItem(label: 'Total', count: total, color: ColorUtils.slate700),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({required this.label, required this.count, required this.color, required this.icon});

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
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _BreakdownItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: ColorUtils.slate500)),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SummaryRow({
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
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColorUtils.slate800)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: ColorUtils.slate500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: ColorUtils.slate400, size: 20),
          ],
        ),
      ),
    );
  }
}
