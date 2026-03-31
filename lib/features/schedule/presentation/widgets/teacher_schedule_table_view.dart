// Excel-like weekly timetable widget for the teacher schedule screen.
// Extracted from TeachingScheduleScreenState._buildTableView() and
// _buildTimeForSession() — purely presentational, all data flows in via params.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Renders the teacher's weekly schedule as a scrollable grid table.
///
/// Like a Vue `<TeacherScheduleTable :schedules="..." :day-id-map="..." />`
/// component — it only reads data, never calls setState on its own.
/// The parent screen owns filter + load state and passes resolved values here.
///
/// Columns: session number | time slot | one column per available day×class.
/// Rows: one per unique "jam ke-" (session number) in [schedules].
class TeacherScheduleTableView extends StatelessWidget {
  const TeacherScheduleTableView({
    super.key,
    required this.schedules,
    required this.dayIdMap,
    required this.dayColorMap,
    required this.primaryColor,
  });

  /// Filtered schedule list from the parent screen (already search/filter applied).
  final List<dynamic> schedules;

  /// Maps localized day name → day ID string, e.g. `{'Senin': '1', ...}`.
  /// Used to resolve raw `day_id` / `days_ids` values back to readable names.
  final Map<String, String> dayIdMap;

  /// Maps localized day name → brand color for that day column.
  final Map<String, Color> dayColorMap;

  /// Role-specific accent color (teacher = indigo). Used for header and title.
  final Color primaryColor;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the display color for [day], falling back to slate-grey.
  Color _getDayColor(String day) => dayColorMap[day] ?? const Color(0xFF6B7280);

  /// Formats a raw time string (e.g. "07.30.00" or "07:30:00") to "HH:MM".
  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    final cleaned = time.replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  /// Finds the schedule entry whose `jam_ke` matches [session] and returns a
  /// widget showing its start / end time, or placeholder dashes when absent.
  Widget _buildTimeForSession(int session) {
    // Like `array_first($schedules, fn($s) => $s['jam_ke'] == $session)` in PHP.
    final match = schedules.firstWhere(
      (s) => (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session,
      orElse: () => <String, dynamic>{},
    );

    if ((match as Map).isNotEmpty) {
      final start = _formatTime(match['jam_mulai'] as String?);
      final end = _formatTime(match['jam_selesai'] as String?);
      return Text(
        '$start\n$end',
        style: const TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      '--:--\n--:--',
      style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
      textAlign: TextAlign.center,
    );
  }

  /// Finds the schedule entry for a specific [session] × [day] × [className]
  /// cell, returning `null` when the cell is empty.
  Map<String, dynamic>? _getScheduleForCell(
    int session,
    String day,
    String className,
  ) {
    try {
      final result = schedules.firstWhere(
        (s) =>
            (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session &&
            s['hari_nama']?.toString() == day &&
            s['kelas_nama']?.toString() == className,
        orElse: () => <String, dynamic>{},
      );
      final map = result as Map<String, dynamic>;
      return map.isNotEmpty ? map : null;
    } catch (_) {
      return null;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Step 1: group schedules by day → class → [entries] ──────────────────
    // Like a Laravel Collection `groupBy('hari_id')` chained with `groupBy('kelas_nama')`.
    final Map<String, Map<String, List<dynamic>>> scheduleMap = {};

    for (final schedule in schedules) {
      // A schedule may span multiple days (`days_ids` list) or a single day
      // (`day_id` / `hari_id` scalar).
      final daysIds = <dynamic>[];
      if (schedule['days_ids'] != null) {
        if (schedule['days_ids'] is List) {
          daysIds.addAll(schedule['days_ids'] as List);
        } else if (schedule['days_ids'] is String) {
          try {
            final parsed = (schedule['days_ids'] as String)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',');
            daysIds.addAll(parsed);
          } catch (_) {}
        }
      }
      if (daysIds.isEmpty) {
        if (schedule['day_id'] != null) {
          daysIds.add(schedule['day_id']);
        } else if (schedule['hari_id'] != null) {
          daysIds.add(schedule['hari_id']);
        }
      }

      for (final rawDayId in daysIds) {
        // Resolve numeric/string ID → localized day name.
        final entry = dayIdMap.entries.firstWhere(
          (e) => e.value.toString() == rawDayId.toString(),
          orElse: () => const MapEntry('Unknown', ''),
        );
        final day = entry.key;
        if (day == 'Unknown') continue;

        final classItem = schedule['kelas_nama']?.toString() ?? 'Unknown';
        scheduleMap.putIfAbsent(day, () => {});
        scheduleMap[day]!.putIfAbsent(classItem, () => []);
        scheduleMap[day]![classItem]!.add(schedule);
      }
    }

    // ── Step 2: derive column/row axis lists ─────────────────────────────────
    final classes =
        scheduleMap.values.expand((d) => d.keys).toSet().toList()..sort();

    // Keep canonical day order rather than insertion order.
    const orderedDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final availableDays = orderedDays.where(scheduleMap.containsKey).toList();

    final allSessions = schedules
        .map((s) => int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0)
        .toSet()
        .toList()
      ..sort();

    // ── Step 3: render ───────────────────────────────────────────────────────
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'JADWAL PELAJARAN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Table container — like an HTML `<table>` with explicit borders.
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: ColorUtils.slate300),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Column(
                  children: [
                    // ── Header row 1: day names ────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate300),
                        ),
                      ),
                      child: Row(
                        children: [
                          // "Jam Ke-" header cell
                          _headerCell(
                            width: 80,
                            height: 60,
                            child: const Text(
                              'Jam Ke-',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // "Waktu" header cell
                          _headerCell(
                            width: 100,
                            height: 60,
                            child: const Text(
                              'Waktu',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          // One merged day-column per available day
                          ...availableDays.expand((day) => [
                            Container(
                              width: 200 * classes.length.toDouble(),
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: availableDays.last == day
                                        ? Colors.transparent
                                        : ColorUtils.slate300,
                                  ),
                                ),
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _getDayColor(day),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),

                    // ── Header row 2: class names ──────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.05),
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate300),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells under "Jam Ke-" and "Waktu"
                          _headerCell(width: 80, height: 40),
                          _headerCell(width: 100, height: 40),
                          // Class name sub-headers for each day
                          ...availableDays.expand((day) {
                            return classes.asMap().entries.map((classEntry) {
                              final isLastInDay =
                                  classEntry.key == classes.length - 1;
                              final isLastDay = availableDays.last == day;
                              return Container(
                                width: 200,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: (isLastInDay && !isLastDay)
                                          ? ColorUtils.slate300
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  classEntry.value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              );
                            });
                          }),
                        ],
                      ),
                    ),

                    // ── Data rows: one per session number ──────────────────
                    ...allSessions.map((session) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: session == allSessions.last
                                  ? Colors.transparent
                                  : ColorUtils.slate300,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Session number cell
                            _headerCell(
                              width: 80,
                              height: 60,
                              child: Text(
                                session.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Time range cell
                            _headerCell(
                              width: 100,
                              height: 60,
                              child: _buildTimeForSession(session),
                            ),
                            // Data cells for each day × class
                            ...availableDays.expand((day) {
                              return classes.map((classItem) {
                                final cell = _getScheduleForCell(
                                  session,
                                  day,
                                  classItem,
                                );
                                return Container(
                                  width: 200,
                                  height: 60,
                                  padding: const EdgeInsets.all(AppSpacing.xs),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: classes.last == classItem &&
                                                availableDays.last != day
                                            ? ColorUtils.slate300
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: cell != null
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _getDayColor(day)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                const BorderRadius.all(Radius.circular(4)),
                                            border: Border.all(
                                              color: _getDayColor(day)
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                cell['mata_pelajaran_nama'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getDayColor(day),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (cell['guru_nama'] != null)
                                                Text(
                                                  cell['guru_nama']!,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: ColorUtils.slate500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                );
                              });
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // ── Legend ───────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: ColorUtils.slate300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keterangan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 16,
                      children: availableDays.map((day) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getDayColor(day),
                                borderRadius: const BorderRadius.all(Radius.circular(2)),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(day, style: const TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shared cell container used by both header rows and the session/time column.
  /// Has a right border to separate columns, like `border-right: 1px solid`
  /// in CSS table cells.
  Widget _headerCell({
    required double width,
    required double height,
    Widget? child,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ColorUtils.slate300)),
      ),
      child: child,
    );
  }
}
