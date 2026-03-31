// Schedule detail dialog extracted from
// TeachingScheduleManagementScreenState._showScheduleDetail().
//
// Like a Laravel Livewire modal component — receives the schedule map and
// callbacks for edit/close, and renders the full detail view. No state,
// no providers; all data is passed in via constructor params.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_detail_item.dart';

/// Shows a modal dialog with all fields of one schedule entry.
///
/// Call via `showDialog(builder: (_) => ScheduleDetailDialog(...))`.
/// In Laravel terms: like `@include('schedule.modals.detail', ['schedule' => $s])`.
class ScheduleDetailDialog extends StatelessWidget {
  const ScheduleDetailDialog({
    super.key,
    required this.schedule,
    required this.primaryColor,
    required this.languageProvider,
    required this.isReadOnly,
    required this.formatTime,
    required this.formatScheduleDays,
    required this.getGradeLevel,
    required this.onEdit,
  });

  /// The raw schedule map from the API.
  final Map<String, dynamic> schedule;

  /// Role-specific accent colour (admin blue).
  final Color primaryColor;

  /// Used for translating UI strings.
  final LanguageProvider languageProvider;

  /// When true, the Edit button is hidden (academic year is locked).
  final bool isReadOnly;

  /// Pure helper — formats `jam_mulai`/`jam_selesai` into "HH:MM - HH:MM".
  final String Function(Map<String, dynamic> schedule) formatTime;

  /// Pure helper — resolves day IDs to translated day name strings.
  final String Function(
    Map<String, dynamic> schedule, [
    LanguageProvider? provider,
  ]) formatScheduleDays;

  /// Pure helper — returns the grade-level label for a class ID.
  final String Function(String classId) getGradeLevel;

  /// Called when the user taps Edit — parent state opens the edit form.
  final void Function(Map<String, dynamic> schedule) onEdit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Pattern #10 Gradient Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Schedule Details',
                          'id': 'Detail Jadwal',
                        }),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        schedule['mata_pelajaran_nama'] ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Detail rows ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                ScheduleDetailItem(
                  icon: Icons.subject_outlined,
                  title: languageProvider.getTranslatedText({
                    'en': 'Subject',
                    'id': 'Mata Pelajaran',
                  }),
                  value: schedule['mata_pelajaran_nama'] ?? '-',
                  primaryColor: primaryColor,
                ),
                ScheduleDetailItem(
                  icon: Icons.person_outline,
                  title: languageProvider.getTranslatedText({
                    'en': 'Teacher',
                    'id': 'Guru',
                  }),
                  value: schedule['guru_nama'] ?? '-',
                  primaryColor: primaryColor,
                ),
                ScheduleDetailItem(
                  icon: Icons.school_outlined,
                  title: languageProvider.getTranslatedText({
                    'en': 'Class',
                    'id': 'Kelas',
                  }),
                  value: schedule['kelas_nama'] ?? '-',
                  primaryColor: primaryColor,
                ),
                ScheduleDetailItem(
                  icon: Icons.today_outlined,
                  title: languageProvider.getTranslatedText({
                    'en': 'Day',
                    'id': 'Hari',
                  }),
                  value: formatScheduleDays(schedule, languageProvider),
                  primaryColor: primaryColor,
                ),
                ScheduleDetailItem(
                  icon: Icons.access_time_outlined,
                  title: languageProvider.getTranslatedText({
                    'en': 'Time',
                    'id': 'Waktu',
                  }),
                  value: formatTime(schedule),
                  primaryColor: primaryColor,
                ),
                ScheduleDetailItem(
                  icon: Icons.grade_outlined,
                  title: languageProvider.getTranslatedText({
                    'en': 'Grade Level',
                    'id': 'Tingkat Kelas',
                  }),
                  value: getGradeLevel(schedule['class_id'] ?? ''),
                  primaryColor: primaryColor,
                  isLast: true,
                ),
              ],
            ),
          ),

          // ── Footer ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: ColorUtils.slate100, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Close',
                        'id': 'Tutup',
                      }),
                      style: TextStyle(color: ColorUtils.slate600),
                    ),
                  ),
                ),
                if (!isReadOnly) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppNavigator.pop(context);
                        onEdit(schedule);
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Edit',
                          'id': 'Edit',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
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
