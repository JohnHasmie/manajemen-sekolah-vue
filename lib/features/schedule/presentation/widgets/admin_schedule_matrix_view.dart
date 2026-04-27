// Admin Jadwal Mengajar — matrix (timetable) view.
//
// Rows = lesson-hour time-slots, columns = days of the week. Each cell
// surfaces the schedules that land on that (time-slot, day) pair, which
// usually means one per class but can stack when multiple classes share
// the same slot on the same day.
//
// Composed from the shared [FrozenColumnTable] scaffold so the matrix
// gets horizontal scrolling, sticky time-slot column, and visual parity
// with the other spreadsheet surfaces (grade recap, finance report,
// raport overview). Filter state (day / class / lesson-hour) is owned by
// the parent screen; we just reflect whatever list we're handed.
//
// Tapping a cell's schedule chip dispatches [onScheduleTap] so the
// parent can open [ScheduleDetailDialog] — the same flow the card list
// uses.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/frozen_column_table.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Matrix (timetable) view of admin-managed schedules.
///
/// Render contract: the widget expects to be placed inside an [Expanded]
/// or other height-bounded parent. The internal [SingleChildScrollView]
/// handles vertical overflow when the time-slot list is taller than the
/// available space; the horizontal day axis scrolls inside
/// [FrozenColumnTable] on its own axis.
class AdminScheduleMatrixView extends StatelessWidget {
  /// Filtered schedules — already narrowed by the parent's active filters.
  final List<dynamic> scheduleList;

  /// All days returned by the API. The matrix renders one column per
  /// entry unless [selectedDayId] restricts it.
  final List<dynamic> dayList;

  /// All lesson hours returned by the API. Each entry becomes one row
  /// unless [selectedLessonHour] restricts it.
  final List<dynamic> lessonHourList;

  /// When non-null, only the day with this id renders as a column.
  final String? selectedDayId;

  /// When non-null (an `hour_number` string like "1"), only that hour's
  /// row renders.
  final String? selectedLessonHour;

  /// Admin accent — used for header tint and chip borders.
  final Color primaryColor;

  /// Language provider for header labels and empty states.
  final LanguageProvider languageProvider;

  /// Fires when the user taps a schedule chip. Dispatches the raw
  /// schedule map (not the parsed model) because downstream callers like
  /// `_showScheduleDetail` expect the wire format.
  final void Function(Map<String, dynamic> schedule) onScheduleTap;

  const AdminScheduleMatrixView({
    super.key,
    required this.scheduleList,
    required this.dayList,
    required this.lessonHourList,
    required this.primaryColor,
    required this.languageProvider,
    required this.onScheduleTap,
    this.selectedDayId,
    this.selectedLessonHour,
  });

  // ── Derived axes ───────────────────────────────────────────────────

  /// Day columns: name + id, sorted by the API's natural order. Filters
  /// via [selectedDayId] when set.
  List<_DayAxis> _buildDayAxes() {
    final filtered = selectedDayId == null
        ? dayList
        : dayList.where((d) => d['id'].toString() == selectedDayId).toList();
    return filtered
        .map<_DayAxis>((d) {
          final id = d['id']?.toString() ?? '';
          final name = (d['name'] ?? d['nama'] ?? '').toString();
          return _DayAxis(id: id, label: _translateDay(name));
        })
        .where((d) => d.id.isNotEmpty)
        .toList();
  }

  /// Row axes (lesson-hour time-slots), sorted by start time.
  ///
  /// The API may return [lessonHourList] entries duplicated across days /
  /// semesters / academic-year scopes (one row per (day, hour) join), but
  /// the matrix only wants one *unique* time-slot row per
  /// (hourNumber, startTime, endTime). Without deduping, every "Jam 1
  /// 07:00–07:45" row repeats N times in the left column with the same
  /// schedules drawn next to each — the bug captured in
  /// `_baseline/admin/06_schedule_matrix.png`. Dedupe before sorting.
  List<_TimeSlotAxis> _buildTimeSlotAxes() {
    final filtered = selectedLessonHour == null
        ? lessonHourList
        : lessonHourList.where((jp) {
            final h = (jp['hour_number'] ?? jp['jam_ke'])?.toString();
            return h == selectedLessonHour;
          }).toList();

    final seen = <String>{};
    final axes = <_TimeSlotAxis>[];
    for (final jp in filtered) {
      final hour = (jp['hour_number'] ?? jp['jam_ke'] ?? '').toString();
      final start = _trimTime(
        (jp['start_time'] ?? jp['jam_mulai'] ?? '').toString(),
      );
      final end = _trimTime(
        (jp['end_time'] ?? jp['jam_selesai'] ?? '').toString(),
      );
      if (start.isEmpty) continue;
      final dedupeKey = '$hour|$start|$end';
      if (!seen.add(dedupeKey)) continue;
      axes.add(
        _TimeSlotAxis(hourNumber: hour, startTime: start, endTime: end),
      );
    }
    axes.sort((a, b) => a.startTime.compareTo(b.startTime));
    return axes;
  }

  /// Bucket schedules by (timeSlotKey, dayId) for O(1) cell lookup.
  /// TimeSlotKey = "HH:mm-HH:mm" matching the lesson-hour axis format.
  Map<String, List<Map<String, dynamic>>> _bucketSchedules() {
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final raw in scheduleList) {
      if (raw is! Map) continue;
      final schedule = Map<String, dynamic>.from(raw);
      final model = Schedule.fromJson(schedule);
      final slotKey =
          '${_trimTime(model.startTime ?? '')}-${_trimTime(model.endTime ?? '')}';
      if (slotKey == '-') continue;

      for (final dayId in _extractDayIds(schedule, model)) {
        final key = '$slotKey|$dayId';
        (buckets[key] ??= []).add(schedule);
      }
    }
    return buckets;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final days = _buildDayAxes();
    final timeSlots = _buildTimeSlotAxes();
    final buckets = _bucketSchedules();

    final timeColumn = FrozenTableColumn(
      width: 92,
      header: _HeaderCell(
        label: languageProvider.getTranslatedText(const {
          'en': 'Time',
          'id': 'Waktu',
        }),
        icon: Icons.access_time_rounded,
      ),
      cellBuilder: (rowIndex) {
        final slot = timeSlots[rowIndex];
        return _TimeSlotCell(
          hourNumber: slot.hourNumber,
          startTime: slot.startTime,
          endTime: slot.endTime,
          accentColor: primaryColor,
        );
      },
    );

    final dayColumns = days.map<FrozenTableColumn>((day) {
      return FrozenTableColumn(
        width: 164,
        header: _HeaderCell(label: day.label),
        cellBuilder: (rowIndex) {
          final slot = timeSlots[rowIndex];
          final key = '${slot.startTime}-${slot.endTime}|${day.id}';
          final schedules = buckets[key] ?? const [];
          return _ScheduleCell(
            schedules: schedules,
            accentColor: primaryColor,
            onTap: onScheduleTap,
          );
        },
      );
    }).toList();

    // Empty time-slot axis → show a friendly empty card rather than a
    // zero-row FrozenColumnTable (which would render only the header strip).
    if (timeSlots.isEmpty || dayColumns.isEmpty) {
      return _EmptyMatrixCard(
        languageProvider: languageProvider,
        accentColor: primaryColor,
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      clipBehavior: Clip.antiAlias,
      // Vertical scroll wrapper — FrozenColumnTable renders fixed-height
      // rows (no built-in Y scroll), so callers own scrolling. Mirrors the
      // pattern used by `teacher_grade_recap_screen.dart` wrapping
      // `GradeRecapTableView`.
      child: SingleChildScrollView(
        child: FrozenColumnTable(
          rowCount: timeSlots.length,
          leftColumns: [timeColumn],
          rightColumns: dayColumns,
          headerHeight: 48,
          rowHeight: 110,
          headerBackgroundColor: primaryColor,
          primaryColor: primaryColor,
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _trimTime(String raw) {
    if (raw.isEmpty) return '';
    return raw.length > 5 ? raw.substring(0, 5) : raw;
  }

  /// Mirrors the translation used by the card view so the matrix labels
  /// agree with filter chips.
  String _translateDay(String name) {
    if (name.isEmpty) return '';
    const idToEn = {
      'Senin': 'Monday',
      'Selasa': 'Tuesday',
      'Rabu': 'Wednesday',
      'Kamis': 'Thursday',
      'Jumat': 'Friday',
      'Sabtu': 'Saturday',
      'Minggu': 'Sunday',
    };
    const enToId = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };
    if (languageProvider.currentLanguage == 'en') {
      return idToEn[name] ?? name;
    }
    return enToId[name] ?? name;
  }

  List<String> _extractDayIds(Map<String, dynamic> schedule, Schedule model) {
    final raw = schedule['days_ids'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      final cleaned = raw.replaceAll('[', '').replaceAll(']', '');
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final fallback = model.dayId ?? '';
    return fallback.isEmpty ? const [] : [fallback];
  }
}

// ── Internal value objects ───────────────────────────────────────────

class _DayAxis {
  final String id;
  final String label;
  const _DayAxis({required this.id, required this.label});
}

class _TimeSlotAxis {
  final String hourNumber;
  final String startTime;
  final String endTime;
  const _TimeSlotAxis({
    required this.hourNumber,
    required this.startTime,
    required this.endTime,
  });
}

// ── Cell widgets ─────────────────────────────────────────────────────

/// Matrix header cell — white text on accent background.
class _HeaderCell extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _HeaderCell({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 14),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left-frozen cell: hour number + start/end time stack.
class _TimeSlotCell extends StatelessWidget {
  final String hourNumber;
  final String startTime;
  final String endTime;
  final Color accentColor;

  const _TimeSlotCell({
    required this.hourNumber,
    required this.startTime,
    required this.endTime,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hourNumber.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Text(
                'Jam $hourNumber',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            startTime,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          Text(
            endTime,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-scrollable cell: stacks one chip per schedule that lands on
/// this (time-slot, day) pair. Scrolls internally when overflowing.
class _ScheduleCell extends StatelessWidget {
  final List<Map<String, dynamic>> schedules;
  final Color accentColor;
  final void Function(Map<String, dynamic> schedule) onTap;

  const _ScheduleCell({
    required this.schedules,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return Container(
        alignment: Alignment.center,
        child: Text(
          '—',
          style: TextStyle(
            color: ColorUtils.slate300,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: schedules.length,
        physics: const ClampingScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          final schedule = schedules[i];
          final model = Schedule.fromJson(schedule);
          final subject = (model.subjectName ?? '').isEmpty
              ? '—'
              : model.subjectName!;
          final className = model.className ?? '';
          return _ScheduleChip(
            subject: subject,
            className: className,
            accentColor: accentColor,
            onTap: () => onTap(schedule),
          );
        },
      ),
    );
  }
}

/// Shown when either axis (time-slots, days) is empty — e.g. the filter
/// narrowed everything away or the reference data hasn't loaded yet.
class _EmptyMatrixCard extends StatelessWidget {
  final LanguageProvider languageProvider;
  final Color accentColor;

  const _EmptyMatrixCard({
    required this.languageProvider,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.table_chart_outlined,
            size: 36,
            color: accentColor.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 10),
          Text(
            languageProvider.getTranslatedText(const {
              'en': 'Matrix unavailable',
              'id': 'Matriks belum tersedia',
            }),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            languageProvider.getTranslatedText(const {
              'en':
                  'Adjust the filter or wait for lesson hours and days to load.',
              'id':
                  'Sesuaikan filter atau tunggu jam pelajaran & hari termuat.',
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  final String subject;
  final String className;
  final Color accentColor;
  final VoidCallback onTap;

  const _ScheduleChip({
    required this.subject,
    required this.className,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(color: accentColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              if (className.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
