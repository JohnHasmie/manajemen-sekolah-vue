// A single schedule entry card shown in the card-list view.
// Extracted from TeachingScheduleScreen._buildScheduleCard().
//
// Like a Vue `<ScheduleCard :schedule="..." :teacher="..." />` component.
// All data flows in via constructor params; navigation callbacks are passed
// from the parent state so this widget stays StatelessWidget.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_info_tag.dart';

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

  /// Returns the day IDs stored in a schedule record, handling both List and
  /// comma-separated-string formats from different API versions.
  List<String> _extractDayIds(dynamic s) {
    final List<String> ids = [];
    final rawDaysIds = s['days_ids'];

    if (rawDaysIds != null) {
      if (rawDaysIds is List) {
        ids.addAll(rawDaysIds.map((id) => id.toString()));
      } else if (rawDaysIds is String) {
        try {
          final clean = rawDaysIds
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
          if (clean.isNotEmpty) {
            ids.addAll(
              clean
                  .split(',')
                  .map((id) => id.trim())
                  .where((id) => id.isNotEmpty),
            );
          }
        } catch (_) {}
      }
    }

    if (ids.isEmpty) {
      final fallbackId = s['day_id'] ?? s['hari_id'];
      if (fallbackId != null) ids.add(fallbackId.toString());
    }
    return ids;
  }

  /// Normalises a raw day name (English or Indonesian, any case) to its
  /// canonical Bahasa Indonesia capitalised form, e.g. "monday" → "Senin".
  String _normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return name;
  }

  Color _getDayColor(String day) =>
      dayColorMap[day] ?? const Color(0xFF6B7280);

  Color _getPrimaryColor() => ColorUtils.getRoleColor('guru');

  @override
  Widget build(BuildContext context) {
    final daysIds = _extractDayIds(schedule);

    // Build a comma-separated display string of day names from IDs.
    String dayNames = daysIds
        .map((id) {
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('Unknown', ''),
          );
          return entry.key;
        })
        .where((n) => n != 'Unknown' && n.isNotEmpty)
        .join(', ');

    if (dayNames.isEmpty) {
      final rawDayName =
          (schedule['hari_nama'] ?? schedule['day_name'] ?? '').toString();
      if (rawDayName.isNotEmpty) dayNames = _normalizeDayName(rawDayName);
    }

    final day = dayNames.isNotEmpty ? dayNames : 'Unknown';

    // Determine the color accent for this card based on the first day.
    final firstDayName = daysIds.isNotEmpty
        ? dayIdMap.entries
              .firstWhere(
                (e) => e.value.toString() == daysIds.first.toString(),
                orElse: () => MapEntry('Senin', ''),
              )
              .key
        : 'Senin';
    final dayColor = _getDayColor(firstDayName);
    final primary = _getPrimaryColor();

    return Container(
      key: index == 0 ? firstScheduleKey : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Tap the card → open Attendance screen for this schedule.
          onTap: () {
            AppNavigator.push(
              context,
              AttendancePage(
                teacher: {'id': teacherId, 'nama': teacherNama},
                initialDate: DateTime.now(),
                initialSubjectId:
                    (schedule['subject_id'] ??
                            schedule['mata_pelajaran_id'] ??
                            schedule['mata_pelajaran']?['id'])
                        ?.toString(),
                initialSubjectName:
                    (schedule['subject_name'] ??
                            schedule['mata_pelajaran_nama'] ??
                            schedule['mata_pelajaran']?['name'])
                        ?.toString(),
                initialclassId:
                    (schedule['class_id'] ??
                            schedule['kelas_id'] ??
                            schedule['class']?['id'])
                        ?.toString(),
                initialClassName:
                    (schedule['class_name'] ??
                            schedule['kelas_nama'] ??
                            schedule['class']?['name'])
                        ?.toString(),
              ),
            );
          },
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row: icon + subject name + day badge ──────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Colored icon container
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: dayColor.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(
                          color: dayColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: dayColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Subject name + academic year
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule['mata_pelajaran_nama'] ??
                                languageProvider.getTranslatedText({
                                  'en': 'Subject',
                                  'id': 'Mata Pelajaran',
                                }),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            schedule['tahun_ajaran_nama'] ?? selectedAcademicYear,
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Day badge (e.g. "Senin")
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: dayColor.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                        border: Border.all(
                          color: dayColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          color: dayColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),
                Divider(height: 1, color: ColorUtils.slate100),
                const SizedBox(height: 10),

                // ── Info tags: time, class, session, semester ─────────────
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ScheduleInfoTag(
                      icon: Icons.access_time_rounded,
                      label:
                          '${_formatTime(schedule["jam_mulai"])} – ${_formatTime(schedule["jam_selesai"])}',
                      color: primary,
                    ),
                    ScheduleInfoTag(
                      icon: Icons.class_rounded,
                      label: schedule['kelas_nama'] ?? '-',
                      color: primary,
                    ),
                    ScheduleInfoTag(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'Jam ke-${schedule["jam_ke"] ?? "-"}',
                      color: dayColor,
                    ),
                    if (schedule['semester_nama'] != null)
                      ScheduleInfoTag(
                        icon: Icons.calendar_month_rounded,
                        label: schedule['semester_nama'],
                        color: ColorUtils.slate500,
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Action buttons: Material | Activity ───────────────────
                Row(
                  key: index == 0 ? actionButtonsKey : null,
                  children: [
                    // Materials button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          AppNavigator.push(
                            context,
                            TeacherMaterialScreen(
                              teacher: {'id': teacherId, 'nama': teacherNama},
                              initialSubjectId:
                                  (schedule['subject_id'] ??
                                          schedule['mata_pelajaran_id'])
                                      ?.toString(),
                              initialSubjectName:
                                  (schedule['subject_name'] ??
                                          schedule['mata_pelajaran_nama'])
                                      ?.toString(),
                              initialClassId:
                                  (schedule['class_id'] ?? schedule['kelas_id'])
                                      ?.toString(),
                              initialClassName:
                                  (schedule['class_name'] ??
                                          schedule['kelas_nama'])
                                      ?.toString(),
                            ),
                          );
                        },
                        icon: Icon(Icons.library_books_rounded, size: 15),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Material',
                            'id': 'Materi',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(
                            color: primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Class Activity button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Compute the next calendar date this schedule occurs.
                          final now = DateTime.now();
                          final scheduleDay = dayIdMap.entries
                              .firstWhere(
                                (entry) =>
                                    entry.value.toString() ==
                                    (schedule['day_id'] ?? schedule['hari_id'])
                                        ?.toString(),
                                orElse: () => MapEntry('Senin', '1'),
                              )
                              .key;
                          final scheduleDayIndex = dayOptions.indexOf(
                            scheduleDay,
                          );
                          final todayIndex = now.weekday;
                          int daysUntilSchedule =
                              scheduleDayIndex - todayIndex;
                          if (daysUntilSchedule < 0) daysUntilSchedule += 7;
                          final scheduleDate = now.add(
                            Duration(days: daysUntilSchedule),
                          );
                          AppNavigator.push(
                            context,
                            ClassActivityScreen(
                              initialDate: scheduleDate,
                              initialSubjectId:
                                  (schedule['subject_id'] ??
                                          schedule['mata_pelajaran_id'])
                                      ?.toString(),
                              initialSubjectName:
                                  (schedule['subject_name'] ??
                                          schedule['mata_pelajaran_nama'])
                                      ?.toString(),
                              initialClassId:
                                  (schedule['class_id'] ?? schedule['kelas_id'])
                                      ?.toString(),
                              initialClassName:
                                  (schedule['class_name'] ??
                                          schedule['kelas_nama'])
                                      ?.toString(),
                              autoShowActivityDialog: true,
                            ),
                          );
                        },
                        icon: Icon(Icons.assignment_rounded, size: 15),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Activity',
                            'id': 'Aktivitas',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
