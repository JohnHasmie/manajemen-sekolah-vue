// Week-grid calendar view for the admin Jadwal hub (Frame A of the
// redesign). Renders schedules as color-coded session blocks on a
// Mon-Sab × time grid — like Google Calendar's week view but compact
// enough for a phone screen.
//
// Architecture notes:
// * **Slot mapping.** Schedules don't have raw start/end timestamps —
//   they reference `lesson_hour_days_id` which joins to `lesson_hours`
//   (start_time, end_time, hour_number, day_id). The schedule
//   transformer pre-flattens those onto each row as `day_id`,
//   `start_time`, `end_time`, and `lesson_hour`. We use start_time
//   and end_time to position blocks.
//
// * **Time axis.** Computed from the loaded `lesson_hour_list`:
//   earliest start_time across the school's slots becomes minute-0,
//   latest end_time becomes the total grid height. This keeps the
//   widget school-agnostic — a morning-only school renders a shorter
//   grid; a full-day school renders 9-10 hours.
//
// * **Color coding.** Subject blocks get a deterministic color from
//   a small brand-tinted palette using `subject_id.hashCode % N`. Same
//   subject = same color across the week. Conflict rows always render
//   in red regardless of subject.
//
// * **Now-line.** When the current weekday is one of the visible days,
//   a thin red line + dot marks the current minute on that column.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule_kpi_summary.dart';

/// Renders a week × time-slot calendar of [scheduleList].
///
/// Each schedule appears as a color-coded block positioned by its
/// `start_time` / `end_time` on the column for its `day_id`. Tapping a
/// block invokes [onScheduleTap].
class AdminScheduleWeekGridView extends StatelessWidget {
  /// Filtered list of schedules to render. Each item must be a
  /// `Map<String, dynamic>` with at least `id`, `day_id`, `start_time`,
  /// `end_time`, `subject_id`, `subject_name`, `class_name`. The
  /// schedule transformer in the model layer normalizes these from the
  /// raw API response.
  final List<dynamic> scheduleList;

  /// All school days (Sen-Sab) — drives the column headers. Each item
  /// must be a Map with `id`, `name`, and `order_number`.
  final List<dynamic> dayList;

  /// All school lesson_hours — used to compute the earliest/latest time
  /// bounds for the grid's y-axis. Each item must be a Map with
  /// `start_time` and `end_time`.
  final List<dynamic> lessonHourList;

  /// Optional callback when the admin taps a session block.
  final void Function(Map<String, dynamic> schedule)? onScheduleTap;

  /// Optional callback when the admin long-presses a block — used by
  /// Frame E (drag-to-reschedule) to lift the block. Hooked up in TR.E.
  final void Function(Map<String, dynamic> schedule)? onScheduleLongPress;

  /// Drag-and-drop reschedule callback (Frame E.1).
  ///
  /// Fires when an admin long-press-drags a session block onto a
  /// different day column and lifts off. The widget pre-computes the
  /// new target slot by:
  ///   1. Reading the drop column's `day_id`.
  ///   2. Translating the drop's y-coordinate to a minutes-from-midnight
  ///      value via the same `pxPerMinute` scale used for rendering.
  ///   3. Finding the lesson_hour on that day_id whose start_time is
  ///      nearest to the dropped minute (±30-min tolerance).
  ///
  /// Callers wire this to [ApiScheduleService.rescheduleSession]; the
  /// widget itself doesn't touch the network so it can be unit-tested
  /// without a service mock.
  ///
  /// When [onReschedule] is null, drag handles are still attached but
  /// drops are no-ops — useful for read-only viewers.
  final Future<void> Function({
    required Map<String, dynamic> schedule,
    required String newLessonHourDaysId,
    required String newDayId,
    required String newStartTime,
  })?
  onReschedule;

  /// Optional currently-selected day_id to subtly highlight that column.
  final String? highlightDayId;

  /// Day_id the grid is "zoomed in" on. When set, the grid renders a
  /// single full-width day column with a day-tab strip above it for
  /// navigation (tap a tab or swipe horizontally to move to another
  /// day). When null, the standard 6-day week grid renders.
  ///
  /// The screen defaults this to today's day_id so the admin lands on
  /// a readable single-day view by default and only zooms out to the
  /// week when they need cross-day context.
  final String? focusedDayId;

  /// Fires when the user changes the focused day (swipe / tab tap / the
  /// zoom-out chevron). Pass `null` to leave focused mode and return
  /// to the full 6-day week view.
  final ValueChanged<String?>? onFocusedDayChanged;

  /// Density-mode callback — tap on a 6+ session cluster card.
  ///
  /// Fires with the full list of sessions sharing the cluster's slot
  /// (same `day_id` + `start_time`). Wired to a "slot expansion" sheet
  /// in the screen so admins can browse, search, and edit each of the
  /// 21 sessions in a high-conflict slot. When null, the cluster card
  /// stays a visual aggregate with no expansion.
  final void Function(List<Map<String, dynamic>> sessions)? onSlotClusterTap;

  /// Density-mode callback — long-press on a 6+ session cluster card.
  ///
  /// Used by the screen to enter bulk-select mode with every session
  /// in the cluster pre-selected. Fast path for "move every 10:00 to
  /// Tuesday" without touching each row.
  final void Function(List<Map<String, dynamic>> sessions)?
  onSlotClusterLongPress;

  /// Vertical scale — pixels per minute. 0.7 makes a 45-minute slot
  /// render ~31dp tall (enough for the subject title + a meta line)
  /// and gives bentrok clusters extra room when blocks split into
  /// half-width lanes.
  final double pxPerMinute;

  /// Time-column width. Narrow enough to leave 6 day columns readable
  /// on a 360dp phone.
  final double timeColumnWidth;

  const AdminScheduleWeekGridView({
    super.key,
    required this.scheduleList,
    required this.dayList,
    required this.lessonHourList,
    this.onScheduleTap,
    this.onScheduleLongPress,
    this.onReschedule,
    this.onSlotClusterTap,
    this.onSlotClusterLongPress,
    this.highlightDayId,
    this.focusedDayId,
    this.onFocusedDayChanged,
    this.pxPerMinute = 0.7,
    this.timeColumnWidth = 32,
  });

  // ── Time axis helpers ─────────────────────────────────────────────

  /// Parses "HH:MM" or "HH:MM:SS" into total minutes from midnight.
  /// Returns null when the input is empty / malformed.
  static int? _parseMinutes(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Formats a minutes-from-midnight value back to "HH:MM".
  static String _formatMinutes(int totalMinutes) {
    final h = (totalMinutes ~/ 60).clamp(0, 23);
    final m = (totalMinutes % 60).clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Returns (earliest, latest) minutes-from-midnight across all
  /// lesson_hour slots, with a small padding on each side. Falls back
  /// to 07:00–15:00 when the lesson_hour list is empty.
  (int, int) _computeBounds() {
    int? earliest;
    int? latest;
    for (final lh in lessonHourList) {
      if (lh is! Map) continue;
      final s = _parseMinutes(lh['start_time']);
      final e = _parseMinutes(lh['end_time']);
      if (s != null) {
        earliest = earliest == null ? s : (s < earliest ? s : earliest);
      }
      if (e != null) {
        latest = latest == null ? e : (e > latest ? e : latest);
      }
    }
    // Sensible default if the school hasn't seeded lesson_hours.
    earliest ??= 7 * 60;
    latest ??= 15 * 60;
    // Round earliest down to the nearest hour, latest up. Gives clean
    // 07, 08, 09… labels in the time column.
    earliest = (earliest ~/ 60) * 60;
    latest = ((latest + 59) ~/ 60) * 60;
    return (earliest, latest);
  }

  // ── Subject color palette ─────────────────────────────────────────

  /// Brand-tinted palette for session blocks. Order is stable so the
  /// same subject_id always picks the same swatch across page-loads.
  /// Cobalt + azure lead because they pair with the admin navy chrome;
  /// the other slots cover the rest of the spectrum without clashing.
  static const List<_BlockPalette> _palettes = [
    _BlockPalette(
      border: Color(0xFF1B6FB8),
      bg: Color(0x1F1B6FB8),
      fg: Color(0xFF1B6FB8),
    ), // cobalt
    _BlockPalette(
      border: Color(0xFF21AFE6),
      bg: Color(0x1F21AFE6),
      fg: Color(0xFF1885B2),
    ), // azure
    _BlockPalette(
      border: Color(0xFF16A34A),
      bg: Color(0x1F16A34A),
      fg: Color(0xFF15803D),
    ), // green
    _BlockPalette(
      border: Color(0xFFF59E0B),
      bg: Color(0x1FF59E0B),
      fg: Color(0xFFB45309),
    ), // amber
    _BlockPalette(
      border: Color(0xFF7C3AED),
      bg: Color(0x1F7C3AED),
      fg: Color(0xFF7C3AED),
    ), // violet
    _BlockPalette(
      border: Color(0xFFE11D48),
      bg: Color(0x1FE11D48),
      fg: Color(0xFFE11D48),
    ), // rose
    _BlockPalette(
      border: Color(0xFF0D9488),
      bg: Color(0x1F0D9488),
      fg: Color(0xFF0D9488),
    ), // teal
    _BlockPalette(
      border: Color(0xFFEA580C),
      bg: Color(0x1FEA580C),
      fg: Color(0xFFEA580C),
    ), // orange
  ];

  static const _BlockPalette _conflictPalette = _BlockPalette(
    border: Color(0xFFDC2626),
    bg: Color(0x1FDC2626),
    fg: Color(0xFFB91C1C),
  );

  _BlockPalette _paletteFor(Map<String, dynamic> schedule) {
    if (schedule.hasScheduleConflict) {
      return _conflictPalette;
    }
    final key = (schedule['subject_id'] ?? schedule['mata_pelajaran_id'] ?? '')
        .toString();
    if (key.isEmpty) return _palettes[0];
    final idx = key.hashCode.abs() % _palettes.length;
    return _palettes[idx];
  }

  // ── Day axis helpers ──────────────────────────────────────────────

  /// Returns the visible days sorted by `order_number`, with Minggu
  /// (Sunday — order_number 7 or 0) filtered out since school weeks
  /// run Senin → Sabtu.
  List<Map<String, dynamic>> _visibleDays() {
    final mapped = dayList
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
    mapped.removeWhere((d) {
      final order = d['order_number'];
      // Filter Sunday: backends typically use 7 for Sun; also accept 0.
      if (order is num) return order == 7 || order == 0;
      final name = (d['name'] ?? '').toString().toLowerCase();
      return name == 'sunday' || name == 'minggu';
    });
    mapped.sort((a, b) {
      final ao = (a['order_number'] as num?)?.toInt() ?? 99;
      final bo = (b['order_number'] as num?)?.toInt() ?? 99;
      return ao.compareTo(bo);
    });
    return mapped;
  }

  /// Returns the current weekday's day_id if today is Senin–Sabtu, else
  /// null. Used to render the now-line + today-column tint.
  String? _todayDayId(List<Map<String, dynamic>> days) {
    final now = DateTime.now();
    // DateTime.weekday: 1 = Monday, 7 = Sunday. Server's order_number
    // also runs 1..7 with Monday=1.
    for (final d in days) {
      final order = (d['order_number'] as num?)?.toInt();
      if (order == now.weekday) return d['id']?.toString();
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final (startMin, endMin) = _computeBounds();
    final totalMinutes = (endMin - startMin).clamp(60, 24 * 60);
    // Focused mode gets a taller vertical scale so each session card
    // has room for the subject + class/teacher meta line on the wider
    // single-day column. Week mode keeps the compact scale so all 6
    // days fit on a 360dp phone.
    final isFocused = focusedDayId != null;
    final effectivePx = isFocused ? pxPerMinute * 1.3 : pxPerMinute;
    final gridHeight = totalMinutes * effectivePx;
    final days = _visibleDays();
    final todayId = _todayDayId(days);

    // Group schedules by day_id once for O(1) column lookups.
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final s in scheduleList) {
      if (s is! Map) continue;
      final m = Map<String, dynamic>.from(s);
      final dayId = m['day_id']?.toString();
      if (dayId == null) continue;
      byDay.putIfAbsent(dayId, () => []).add(m);
    }

    // Group lesson_hours by day_id so drop-target snapping doesn't
    // re-scan the full list on every drop. Each entry holds the
    // available slots on that day with their start-time in minutes
    // pre-parsed for fast nearest-neighbour matching.
    final hoursByDay = <String, List<_SlotEntry>>{};
    for (final lh in lessonHourList) {
      if (lh is! Map) continue;
      final dayId = lh['day_id']?.toString();
      final id = lh['id']?.toString();
      final startMin = _parseMinutes(lh['start_time']);
      if (dayId == null || id == null || startMin == null) continue;
      final endMin = _parseMinutes(lh['end_time']);
      // Default to a 45-minute lesson length when end_time is missing
      // — the ghost rectangle still needs a sensible height.
      final duration = (endMin != null && endMin > startMin)
          ? endMin - startMin
          : 45;
      hoursByDay
          .putIfAbsent(dayId, () => [])
          .add(
            _SlotEntry(
              lessonHourId: id,
              startMinutes: startMin,
              startTime: lh['start_time']?.toString() ?? '',
              durationMinutes: duration,
            ),
          );
    }

    // Now-line offset (only when today is visible). Uses the effective
    // scale so the dot lands in the right spot whether we're in the
    // compact week grid or the zoomed focused-day view.
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final showNowLine =
        todayId != null && nowMinutes >= startMin && nowMinutes <= endMin;
    final nowTopOffset = (nowMinutes - startMin) * effectivePx;

    // Focused-mode branch: render a single full-width day column with
    // a pill-tab strip above for swipe / tap navigation between days.
    // Falls back to the standard 6-column week view when focusedDayId
    // is null (admin tapped the zoom-out chevron).
    if (focusedDayId != null) {
      final focusedDay = days.firstWhere(
        (d) => d['id']?.toString() == focusedDayId,
        orElse: () => days.isNotEmpty ? days.first : <String, dynamic>{},
      );
      final focusedId = focusedDay['id']?.toString() ?? '';
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            _FocusedDayHeaderStrip(
              days: days,
              focusedDayId: focusedId,
              todayDayId: todayId,
              onPicked: (id) => onFocusedDayChanged?.call(id),
              onZoomOut: () => onFocusedDayChanged?.call(null),
            ),
            SizedBox(
              height: gridHeight + 4,
              child: GestureDetector(
                // Horizontal swipe → previous / next day. Velocity gate
                // ignores incidental drags (long-press on a block sets
                // up LongPressDraggable, which owns touches once it
                // activates).
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v.abs() < 250) return;
                  final idx = days.indexWhere(
                    (d) => d['id']?.toString() == focusedId,
                  );
                  if (idx < 0) return;
                  if (v < 0 && idx < days.length - 1) {
                    onFocusedDayChanged?.call(days[idx + 1]['id']?.toString());
                  } else if (v > 0 && idx > 0) {
                    onFocusedDayChanged?.call(days[idx - 1]['id']?.toString());
                  }
                },
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TimeColumn(
                          startMinutes: startMin,
                          endMinutes: endMin,
                          pxPerMinute: effectivePx,
                          width: timeColumnWidth,
                        ),
                        Expanded(
                          child: _DayColumn(
                            dayId: focusedId,
                            isToday: focusedId == todayId,
                            isHighlighted: focusedId == highlightDayId,
                            startMinutes: startMin,
                            endMinutes: endMin,
                            pxPerMinute: effectivePx,
                            isFocused: true,
                            schedules: byDay[focusedId] ?? const [],
                            slotsOnThisDay: hoursByDay[focusedId] ?? const [],
                            paletteFor: _paletteFor,
                            onTap: onScheduleTap,
                            onLongPress: onScheduleLongPress,
                            onReschedule: onReschedule,
                            onSlotClusterTap: onSlotClusterTap,
                            onSlotClusterLongPress: onSlotClusterLongPress,
                          ),
                        ),
                      ],
                    ),
                    if (showNowLine && focusedId == todayId)
                      Positioned(
                        left: timeColumnWidth,
                        right: 0,
                        top: nowTopOffset.clamp(0.0, gridHeight),
                        child: const _NowLine(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── Day header row ────────────────────────────────────
          _DayHeaderRow(
            days: days,
            todayDayId: todayId,
            timeColumnWidth: timeColumnWidth,
            onDayTap: onFocusedDayChanged == null
                ? null
                : (id) => onFocusedDayChanged!(id),
          ),
          // ── Time-aligned body grid ────────────────────────────
          SizedBox(
            height: gridHeight + 4,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Time column (left rail).
                    _TimeColumn(
                      startMinutes: startMin,
                      endMinutes: endMin,
                      pxPerMinute: pxPerMinute,
                      width: timeColumnWidth,
                    ),
                    // Day columns.
                    for (final d in days)
                      Expanded(
                        child: _DayColumn(
                          dayId: d['id']?.toString() ?? '',
                          isToday: d['id']?.toString() == todayId,
                          isHighlighted: d['id']?.toString() == highlightDayId,
                          startMinutes: startMin,
                          endMinutes: endMin,
                          pxPerMinute: pxPerMinute,
                          isFocused: false,
                          schedules: byDay[d['id']?.toString()] ?? const [],
                          slotsOnThisDay:
                              hoursByDay[d['id']?.toString()] ?? const [],
                          paletteFor: _paletteFor,
                          onTap: onScheduleTap,
                          onLongPress: onScheduleLongPress,
                          onReschedule: onReschedule,
                          onSlotClusterTap: onSlotClusterTap,
                          onSlotClusterLongPress: onSlotClusterLongPress,
                        ),
                      ),
                  ],
                ),
                // ── Now-line — drawn last so it sits over blocks ──
                if (showNowLine)
                  Positioned(
                    left: timeColumnWidth,
                    right: 0,
                    top: nowTopOffset.clamp(0.0, gridHeight),
                    child: const _NowLine(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Day header row
// ─────────────────────────────────────────────────────────────────────

class _DayHeaderRow extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final String? todayDayId;
  final double timeColumnWidth;
  final ValueChanged<String?>? onDayTap;

  const _DayHeaderRow({
    required this.days,
    required this.todayDayId,
    required this.timeColumnWidth,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: timeColumnWidth,
            child: Container(
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                border: Border(right: BorderSide(color: ColorUtils.slate200)),
              ),
              height: 32,
            ),
          ),
          for (final d in days)
            Expanded(
              child: _DayHeaderCell(
                day: d,
                isToday: d['id']?.toString() == todayDayId,
                onTap: onDayTap == null
                    ? null
                    : () => onDayTap!(d['id']?.toString()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeaderCell extends StatelessWidget {
  final Map<String, dynamic> day;
  final bool isToday;
  final VoidCallback? onTap;

  const _DayHeaderCell({required this.day, required this.isToday, this.onTap});

  String _abbreviation(String name) {
    // Indonesian day names — first 3 letters uppercase.
    if (name.length <= 3) return name.toUpperCase();
    return name.substring(0, 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = (day['name'] ?? '').toString();
    final cell = Container(
      height: 32,
      decoration: BoxDecoration(
        color: isToday ? ColorUtils.brandDarkBlue : Colors.transparent,
        border: Border(right: BorderSide(color: ColorUtils.slate100)),
      ),
      alignment: Alignment.center,
      child: Text(
        _abbreviation(name),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isToday ? Colors.white : ColorUtils.slate600,
          letterSpacing: 0.4,
        ),
      ),
    );
    if (onTap == null) return cell;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: cell,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Time column (left rail)
// ─────────────────────────────────────────────────────────────────────

class _TimeColumn extends StatelessWidget {
  final int startMinutes;
  final int endMinutes;
  final double pxPerMinute;
  final double width;

  const _TimeColumn({
    required this.startMinutes,
    required this.endMinutes,
    required this.pxPerMinute,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final hourCount = ((endMinutes - startMinutes) ~/ 60).clamp(1, 24);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(right: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < hourCount; i++)
            SizedBox(
              height: 60 * pxPerMinute,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate100),
                  ),
                ),
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 3, top: 2),
                child: Text(
                  ((startMinutes ~/ 60) + i).toString().padLeft(2, '0'),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Day column — schedule blocks positioned absolutely by start_time
// ─────────────────────────────────────────────────────────────────────

class _DayColumn extends StatefulWidget {
  final String dayId;
  final bool isToday;
  final bool isHighlighted;
  final int startMinutes;
  final int endMinutes;
  final double pxPerMinute;

  /// True when this column is rendering inside the single-day "focused"
  /// view (one day fills the full screen width). The extra horizontal
  /// real-estate lets each lane stay readable even when 4-6 sessions
  /// share a slot, so [_DayColumnState._computeSlotGroups] keeps lanes
  /// mode active up to 6 sessions instead of collapsing to a cluster
  /// card at 4 like it does in the cramped week grid.
  final bool isFocused;
  final List<Map<String, dynamic>> schedules;
  final List<_SlotEntry> slotsOnThisDay;
  final _BlockPalette Function(Map<String, dynamic>) paletteFor;
  final void Function(Map<String, dynamic>)? onTap;
  final void Function(Map<String, dynamic>)? onLongPress;
  final Future<void> Function({
    required Map<String, dynamic> schedule,
    required String newLessonHourDaysId,
    required String newDayId,
    required String newStartTime,
  })?
  onReschedule;
  final void Function(List<Map<String, dynamic>> sessions)? onSlotClusterTap;
  final void Function(List<Map<String, dynamic>> sessions)?
  onSlotClusterLongPress;

  const _DayColumn({
    required this.dayId,
    required this.isToday,
    required this.isHighlighted,
    required this.startMinutes,
    required this.endMinutes,
    required this.pxPerMinute,
    required this.isFocused,
    required this.schedules,
    required this.slotsOnThisDay,
    required this.paletteFor,
    required this.onTap,
    required this.onLongPress,
    required this.onReschedule,
    required this.onSlotClusterTap,
    required this.onSlotClusterLongPress,
  });

  @override
  State<_DayColumn> createState() => _DayColumnState();
}

class _DayColumnState extends State<_DayColumn> {
  /// The slot the user's finger is currently over (within ±30-min
  /// tolerance) while dragging. Null when nothing is dragged here, or
  /// when the finger is over a stretch of the column with no nearby
  /// lesson_hour — in that case the ghost is hidden as a visual cue
  /// that the drop will no-op.
  _SlotEntry? _hoveredSlot;

  /// Returns the slot on this day whose start_time is closest to
  /// [droppedMinutes], within a generous ±30-minute tolerance so the
  /// admin's drop doesn't need to be pixel-perfect. Returns null when
  /// the day has no slots or no slot is within tolerance.
  _SlotEntry? _nearestSlot(int droppedMinutes) {
    if (widget.slotsOnThisDay.isEmpty) return null;
    _SlotEntry? best;
    int bestDiff = 1 << 30;
    for (final slot in widget.slotsOnThisDay) {
      final diff = (slot.startMinutes - droppedMinutes).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = slot;
      }
    }
    if (best == null) return null;
    if (bestDiff > 30) return null;
    return best;
  }

  /// Translates a local y-coordinate inside the column into the nearest
  /// slot entry. Used by both [onMove] (for the ghost preview) and
  /// [onAcceptWithDetails] (for the actual drop resolution) so both
  /// paths agree on what slot the admin meant.
  _SlotEntry? _slotAtLocalY(double localY) {
    final droppedMinutes =
        widget.startMinutes + (localY / widget.pxPerMinute).round();
    return _nearestSlot(droppedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final hourCount = ((widget.endMinutes - widget.startMinutes) ~/ 60).clamp(
      1,
      24,
    );
    final dropEnabled =
        widget.onReschedule != null && widget.slotsOnThisDay.isNotEmpty;
    // Local aliases for fields read directly inside `build()`. Anything
    // referenced from `_buildBlock` reads through `widget.` instead
    // since `_buildBlock` is a separate method on the State.
    final startMinutes = widget.startMinutes;
    final pxPerMinute = widget.pxPerMinute;
    final schedules = widget.schedules;
    final onReschedule = widget.onReschedule;
    final dayId = widget.dayId;
    final isToday = widget.isToday;
    final isHighlighted = widget.isHighlighted;

    // Pre-compute slot groups so each cluster of sessions sharing a
    // start_time picks the right density bucket — `lanes` (≤3),
    // `stack` (4–5), or `cluster` (6+). This keeps the column readable
    // even when 21 classes are scheduled at the same lesson_hour.
    final groups = _computeSlotGroups(schedules);

    // Drag-hover state: figure out if the currently-hovered slot maps
    // to a high-density group, so we can hand the hover treatment to
    // the block itself (and suppress the generic ghost rectangle).
    final hoveredStartMin = _hoveredSlot?.startMinutes;
    _RenderMode? hoveredGroupMode;
    for (final g in groups) {
      if (g.startMinutes == hoveredStartMin) {
        hoveredGroupMode = g.renderMode;
        break;
      }
    }
    final hoveredIsHighDensity =
        hoveredGroupMode == _RenderMode.stack ||
        hoveredGroupMode == _RenderMode.cluster;

    final columnBody = LayoutBuilder(
      builder: (ctx, constraints) {
        final colWidth = constraints.maxWidth;
        return Stack(
          children: [
            // Hour-grid lines.
            Column(
              children: [
                for (var i = 0; i < hourCount; i++)
                  SizedBox(
                    height: 60 * pxPerMinute,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate100),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Session blocks — dispatch per group's render mode. The
            // group whose slot is currently being hovered gets a
            // `isHovered: true` flag so its renderer can light up.
            for (final group in groups)
              ..._renderGroup(
                group,
                hourCount,
                colWidth,
                isHovered: hoveredStartMin == group.startMinutes,
              ),
          ],
        );
      },
    );

    final styled = Container(
      decoration: BoxDecoration(
        color: isToday
            ? ColorUtils.brandDarkBlue.withValues(alpha: 0.03)
            : (isHighlighted
                  ? ColorUtils.brandCobalt.withValues(alpha: 0.04)
                  : Colors.white),
        border: Border(right: BorderSide(color: ColorUtils.slate100)),
      ),
      child: columnBody,
    );

    // Wire the DragTarget only when reschedule is supported. Without
    // [onReschedule] the column stays inert so drag drops on a
    // read-only viewer cleanly bounce back to the source.
    if (!dropEnabled) return styled;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        // Live preview — translate the global drop position to local y
        // inside this column and resolve the slot the admin's finger
        // currently hovers. Clears _hoveredSlot when no slot is within
        // tolerance (so the user sees no ghost in dead zones).
        final ro = context.findRenderObject() as RenderBox?;
        if (ro == null || !ro.hasSize) return;
        final localY = ro.globalToLocal(details.offset).dy;
        final hovered = _slotAtLocalY(localY);
        if (hovered?.lessonHourId != _hoveredSlot?.lessonHourId) {
          setState(() => _hoveredSlot = hovered);
        }
      },
      onLeave: (_) {
        if (_hoveredSlot != null) {
          setState(() => _hoveredSlot = null);
        }
      },
      onAcceptWithDetails: (details) async {
        final ro = context.findRenderObject() as RenderBox?;
        if (ro == null || !ro.hasSize) return;
        final localY = ro.globalToLocal(details.offset).dy;
        final slot = _slotAtLocalY(localY);
        // Clear the ghost immediately so it doesn't linger after drop.
        if (_hoveredSlot != null) {
          setState(() => _hoveredSlot = null);
        }
        if (slot == null) return;
        // No-op when the drop lands on the source slot.
        final currentLessonHourId = (details.data['lesson_hour_days_id'] ?? '')
            .toString();
        if (currentLessonHourId == slot.lessonHourId) return;
        await onReschedule!.call(
          schedule: details.data,
          newLessonHourDaysId: slot.lessonHourId,
          newDayId: dayId,
          newStartTime: slot.startTime,
        );
      },
      builder: (ctx, candidate, rejected) {
        final dragging = candidate.isNotEmpty;
        if (!dragging || _hoveredSlot == null) return styled;
        // High-density slots (stack / cluster) provide their own
        // hover feedback baked into the block — see
        // `_buildStackBlock` / `_buildClusterCard` `isHovered`. Skip
        // the generic ghost so we don't double-up the cobalt overlay
        // on top of an already-highlighted card.
        if (hoveredIsHighDensity) return styled;
        // Per-slot ghost: cobalt outlined rectangle at the resolved
        // target slot's position. Width spans the column minus the
        // standard 2px inset; height is derived from the slot's own
        // duration so the preview matches what will actually land.
        //
        // We deliberately *don't* tint the whole column — that visual
        // implied any drop point would succeed; we want the admin to
        // see where exactly the snap is going.
        final ghostTop =
            (_hoveredSlot!.startMinutes - startMinutes) * pxPerMinute;
        final ghostHeight = (_hoveredSlot!.durationMinutes * pxPerMinute).clamp(
          20.0,
          double.infinity,
        );
        return Stack(
          children: [
            styled,
            Positioned(
              top: ghostTop,
              left: 2,
              right: 2,
              height: ghostHeight,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorUtils.brandCobalt.withValues(alpha: 0.12),
                    border: Border.all(color: ColorUtils.brandCobalt, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _hoveredSlot!.startTime,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.brandCobalt,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Groups a day's schedules into per-slot buckets so each group can
  /// pick the right density mode (lanes / stack / cluster) for the
  /// number of sessions sharing the same start_time.
  ///
  /// School schedules in this app snap to fixed `lesson_hours`, so all
  /// sessions at the same hour share `start_time` exactly — bucketing
  /// by `start_time` cleanly separates each lesson_hour's row into its
  /// own group. The density bucket is then chosen by count:
  ///   * 1–3 sessions → [_RenderMode.lanes] (existing side-by-side path)
  ///   * 4–5 sessions → [_RenderMode.stack] (compact stacked mini-cards)
  ///   * 6+  sessions → [_RenderMode.cluster] (aggregator card)
  ///
  /// Within each group sessions are sorted by class_name for stable
  /// visual ordering. Returned list is sorted by start_time so earlier
  /// slots paint first inside the Stack.
  List<_SlotGroup> _computeSlotGroups(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const [];
    final byStart = <int, List<Map<String, dynamic>>>{};
    for (final s in items) {
      final startMin = AdminScheduleWeekGridView._parseMinutes(s['start_time']);
      if (startMin == null) continue;
      byStart.putIfAbsent(startMin, () => []).add(s);
    }

    final groups = <_SlotGroup>[];
    for (final entry in byStart.entries) {
      final start = entry.key;
      final sessions = entry.value;
      sessions.sort((a, b) {
        final ca = (a['class_name'] ?? a['kelas_nama'] ?? '').toString();
        final cb = (b['class_name'] ?? b['kelas_nama'] ?? '').toString();
        return ca.compareTo(cb);
      });

      // Use the max end_time across the group for the rendered height.
      // In practice every session in the group shares the same end_time
      // (they all reference the same lesson_hour), but the max guards
      // against staggered durations.
      var maxEnd = start;
      var anyConflict = false;
      for (final s in sessions) {
        final endMin = AdminScheduleWeekGridView._parseMinutes(s['end_time']);
        if (endMin != null && endMin > maxEnd) maxEnd = endMin;
        if (s.hasScheduleConflict) anyConflict = true;
      }
      final dur = (maxEnd - start).clamp(20, 240);

      // Two density buckets: lanes vs cluster. The stack bucket
      // previously sat between them (4–5) but rendered text unreadably
      // small on a 50px-wide column, so we collapse it into cluster
      // mode — the cluster card's count badge + tap-to-expand is more
      // useful than half-readable mini-cards.
      //
      // The lane-mode threshold is wider in focused mode (≤6) because
      // the single-day view spans the full screen width — 6 lanes
      // across ~340dp leaves each card ~52dp wide, which is still
      // legible. In the cramped week grid each day column is only
      // ~50dp wide, so we collapse to cluster mode at 4+ sessions.
      final laneThreshold = widget.isFocused ? 6 : 3;
      final mode = sessions.length <= laneThreshold
          ? _RenderMode.lanes
          : _RenderMode.cluster;

      groups.add(
        _SlotGroup(
          startMinutes: start,
          durationMinutes: dur,
          sessions: sessions,
          hasConflict: anyConflict,
          renderMode: mode,
        ),
      );
    }

    groups.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return groups;
  }

  /// Dispatches each group to the renderer that fits its density mode.
  ///
  /// [isHovered] is true when a drag is currently positioned over this
  /// group's slot — used by stack / cluster renderers to light up
  /// their borders + tint as a drop-zone affordance. Lanes mode uses
  /// the generic ghost overlay from the DragTarget builder instead.
  List<Widget> _renderGroup(
    _SlotGroup group,
    int hourCount,
    double colWidth, {
    bool isHovered = false,
  }) {
    switch (group.renderMode) {
      case _RenderMode.lanes:
        final widgets = <Widget>[];
        for (var i = 0; i < group.sessions.length; i++) {
          widgets.addAll(
            _buildBlock(
              group.sessions[i],
              hourCount,
              i,
              group.sessions.length,
              colWidth,
            ),
          );
        }
        return widgets;
      case _RenderMode.stack:
        return [_buildStackBlock(group, hourCount, isHovered: isHovered)];
      case _RenderMode.cluster:
        return [_buildClusterCard(group, hourCount, isHovered: isHovered)];
    }
  }

  List<Widget> _buildBlock(
    Map<String, dynamic> s,
    int hourCount,
    int lane,
    int totalLanes,
    double colWidth,
  ) {
    final startMin = AdminScheduleWeekGridView._parseMinutes(s['start_time']);
    final endMin = AdminScheduleWeekGridView._parseMinutes(s['end_time']);
    if (startMin == null || endMin == null || endMin <= startMin) {
      return const [];
    }
    final top = (startMin - widget.startMinutes) * widget.pxPerMinute;
    final height = (endMin - startMin) * widget.pxPerMinute;
    if (top < 0 || top > hourCount * 60 * widget.pxPerMinute) {
      return const [];
    }

    // Lane geometry: split the column width into [totalLanes] columns
    // when 2-3 sessions share the start_time, full width when there's
    // only one.
    const sideInset = 2.0;
    const laneGap = 1.0;
    final availableWidth = (colWidth - 2 * sideInset).clamp(0.0, 9999.0);
    final laneWidth = totalLanes <= 1
        ? availableWidth
        : (availableWidth - laneGap * (totalLanes - 1)) / totalLanes;
    final leftPos = sideInset + lane * (laneWidth + laneGap);
    final palette = widget.paletteFor(s);
    final subjectName = (s['subject_name'] ?? s['mata_pelajaran_nama'] ?? '—')
        .toString();
    final className = (s['class_name'] ?? s['kelas_nama'] ?? '').toString();
    final teacherName = (s['teacher_name'] ?? s['guru_nama'] ?? '').toString();
    final isConflict = s.hasScheduleConflict;

    // Inner card content — reused for the in-grid block AND the
    // LongPressDraggable feedback overlay so the drag preview matches
    // the original visual exactly (just rotated + shadowed).
    final cardContent = Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(5),
        border: Border(left: BorderSide(color: palette.border, width: 3)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isConflict) ...[
                Icon(Icons.warning_amber_rounded, size: 9, color: palette.fg),
                const SizedBox(width: 2),
              ],
              Expanded(
                child: Text(
                  subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: palette.fg,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          if (height > 26 && (className.isNotEmpty || teacherName.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                [
                  className,
                  if (teacherName.isNotEmpty) teacherName,
                ].where((e) => e.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: palette.fg.withValues(alpha: 0.85),
                  height: 1.1,
                ),
              ),
            ),
        ],
      ),
    );

    final blockHeight = height.clamp(18.0, double.infinity);
    final blockGesture = GestureDetector(
      onTap: widget.onTap == null ? null : () => widget.onTap!(s),
      onLongPress: widget.onLongPress == null
          ? null
          : () => widget.onLongPress!(s),
      child: cardContent,
    );

    // Drag is disabled when the column has no reschedule callback
    // (read-only) — in that case render the block as before so tap
    // still opens the detail sheet.
    final Widget interactive = widget.onReschedule == null
        ? blockGesture
        : LongPressDraggable<Map<String, dynamic>>(
            // Press-and-hold for ~500ms before the block starts to
            // float — matches Flutter's default LongPressDraggable
            // timing so it doesn't fire on accidental scrolls.
            data: s,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: _DragFeedbackCard(
              palette: palette,
              subjectName: subjectName,
              className: className,
              teacherName: teacherName,
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: DottedOutline(child: cardContent),
            ),
            child: blockGesture,
          );

    return [
      Positioned(
        top: top,
        left: leftPos,
        width: laneWidth,
        height: blockHeight,
        child: interactive,
      ),
    ];
  }

  /// Stack mode renderer — 4–5 sessions at the same slot are too many
  /// for side-by-side lanes (each would shrink below ~24px) so we
  /// stack them vertically as compact mini-cards inside one positioned
  /// container that fills the slot's time range.
  ///
  /// Each mini-card carries the class + subject abbreviated to fit a
  /// 12dp row, and stays tappable so the admin can open the detail
  /// sheet. Drag is intentionally disabled in this mode — the cards
  /// are too short to grip cleanly; the detail sheet's "Pindah Slot"
  /// action covers the move-out flow.
  Widget _buildStackBlock(
    _SlotGroup group,
    int hourCount, {
    bool isHovered = false,
  }) {
    final top = (group.startMinutes - widget.startMinutes) * widget.pxPerMinute;
    final height = group.durationMinutes * widget.pxPerMinute;

    // Show up to 4 mini-cards; if more, the last row is a "+ N lagi"
    // hint so the count is still visible without overflowing the slot.
    const maxVisible = 4;
    final visible = group.sessions.take(maxVisible).toList();
    final overflow = group.sessions.length - visible.length;

    // Hover styling: cobalt-tinted background + thicker cobalt border
    // so the user sees this slot will receive the dropped session.
    final borderColor = isHovered
        ? ColorUtils.brandCobalt
        : (group.hasConflict
              ? ColorUtils.error600.withValues(alpha: 0.30)
              : ColorUtils.slate200);
    final bgColor = isHovered
        ? ColorUtils.brandCobalt.withValues(alpha: 0.08)
        : (group.hasConflict
              ? ColorUtils.error600.withValues(alpha: 0.04)
              : Colors.white);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height.clamp(36.0, double.infinity),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: borderColor, width: isHovered ? 2 : 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            for (final s in visible)
              Expanded(
                child: _StackMiniCard(
                  schedule: s,
                  palette: widget.paletteFor(s),
                  onTap: widget.onTap == null ? null : () => widget.onTap!(s),
                ),
              ),
            if (overflow > 0)
              Expanded(child: _StackOverflowPill(count: overflow)),
          ],
        ),
      ),
    );
  }

  /// Cluster mode renderer — 6+ sessions at one slot collapse to a
  /// single aggregator card. The card shows the count badge ("21 sesi"),
  /// a short preview of the subjects/classes mix, and a "▾ ketuk untuk
  /// lihat" hint. Tap opens an expansion sheet (wired in TR.I.5);
  /// long-press seeds bulk-select with all cluster session ids.
  Widget _buildClusterCard(
    _SlotGroup group,
    int hourCount, {
    bool isHovered = false,
  }) {
    final top = (group.startMinutes - widget.startMinutes) * widget.pxPerMinute;
    final height = group.durationMinutes * widget.pxPerMinute;

    // Aggregate stats — top-3 distinct subjects to preview.
    final subjects = <String>{};
    final classes = <String>{};
    for (final s in group.sessions) {
      final sub = (s['subject_name'] ?? s['mata_pelajaran_nama'] ?? '')
          .toString();
      if (sub.isNotEmpty) subjects.add(sub);
      final cls = (s['class_name'] ?? s['kelas_nama'] ?? '').toString();
      if (cls.isNotEmpty) classes.add(cls);
    }
    final topSubjects = subjects.take(3).join(' · ');
    final tally = '${subjects.length} mapel · ${classes.length} kelas';

    // Hover styling: thicker border + brighter gradient so a dragged
    // session lands on visible feedback. We override the conflict-red
    // border with cobalt while hovering so the user sees the drop is
    // accepted (not that there's a new conflict to fix).
    final borderColor = isHovered
        ? ColorUtils.brandCobalt
        : (group.hasConflict ? ColorUtils.error600 : ColorUtils.brandCobalt);
    final borderWidth = isHovered ? 2.5 : 1.5;
    final gradientColors = isHovered
        ? [
            ColorUtils.brandCobalt.withValues(alpha: 0.28),
            ColorUtils.brandCobalt.withValues(alpha: 0.14),
          ]
        : (group.hasConflict
              ? [
                  ColorUtils.error600.withValues(alpha: 0.16),
                  ColorUtils.brandCobalt.withValues(alpha: 0.10),
                ]
              : [
                  ColorUtils.brandCobalt.withValues(alpha: 0.14),
                  ColorUtils.brandCobalt.withValues(alpha: 0.06),
                ]);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: height.clamp(40.0, double.infinity),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSlotClusterTap == null
            ? null
            : () => widget.onSlotClusterTap!(group.sessions),
        onLongPress: widget.onSlotClusterLongPress == null
            ? null
            : () => widget.onSlotClusterLongPress!(group.sessions),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          // Progressive disclosure: at very short heights (≤30dp inner
          // space) the card shows just the count badge; with a bit more
          // room the subject preview + hint stack in. LayoutBuilder is
          // the right tool here — `height` (slot duration) doesn't
          // account for padding / border chrome, so a `height > 36`
          // threshold would still overflow on 45-min slots in
          // compact-week mode (45 * 0.7 = 31.5px raw, ~22px inside the
          // chrome). Cluster content is purely informational and
          // tappable — clipping it instead of letting RenderFlex throw
          // is the right trade-off.
          child: ClipRect(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final inner = c.maxHeight;
                // Tier thresholds — measured against actual inner
                // height (padding + border already subtracted out).
                //   ≥48 → badge + 2-line preview + hint
                //   ≥34 → badge + 1-line preview
                //   <34 → badge only
                final showPreview = inner >= 34;
                final showTally = inner >= 48;
                final showHint = inner >= 48;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Count badge — red on conflict, navy otherwise.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: group.hasConflict
                              ? ColorUtils.error600
                              : ColorUtils.brandDarkBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${group.sessions.length} sesi',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (showPreview)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topSubjects,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: ColorUtils.brandCobalt,
                                  height: 1.1,
                                ),
                              ),
                              if (showTally)
                                Text(
                                  tally,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate700,
                                    height: 1.1,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (showHint)
                      Text(
                        isHovered ? '↓ Lepas di sini' : '▾ ketuk',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: isHovered
                              ? ColorUtils.brandCobalt
                              : ColorUtils.slate500,
                          height: 1.1,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Density mode picked per slot group by [_DayColumnState._computeSlotGroups].
///
/// * [lanes]   — 1–3 sessions: side-by-side lanes (existing path).
/// * [stack]   — 4–5 sessions: compact vertical mini-cards.
/// * [cluster] — 6+ sessions: aggregator card with count + preview.
enum _RenderMode { lanes, stack, cluster }

/// A bucket of sessions that share the same `start_time` on a single
/// day — the unit the density renderer dispatches on.
class _SlotGroup {
  /// Start time in minutes-from-midnight (shared across all sessions).
  final int startMinutes;

  /// Slot duration in minutes (max end_time - start across the group).
  final int durationMinutes;

  /// Sessions in this slot, sorted by `class_name` for stable display.
  final List<Map<String, dynamic>> sessions;

  /// True when any session in the group is bentrok (drives red chrome).
  final bool hasConflict;

  /// Density bucket chosen by the session count — lanes / stack / cluster.
  final _RenderMode renderMode;

  const _SlotGroup({
    required this.startMinutes,
    required this.durationMinutes,
    required this.sessions,
    required this.hasConflict,
    required this.renderMode,
  });
}

/// One row inside a stack-mode block. Renders a compact mini-card with
/// the subject + class abbreviated to fit a ~12dp row.
class _StackMiniCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final _BlockPalette palette;
  final VoidCallback? onTap;

  const _StackMiniCard({
    required this.schedule,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subject =
        (schedule['subject_name'] ?? schedule['mata_pelajaran_nama'] ?? '—')
            .toString();
    final className = (schedule['class_name'] ?? schedule['kelas_nama'] ?? '')
        .toString();
    final isConflict = schedule.hasScheduleConflict;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(3),
          border: Border(left: BorderSide(color: palette.border, width: 2)),
        ),
        child: Row(
          children: [
            if (isConflict) ...[
              Icon(Icons.warning_amber_rounded, size: 8, color: palette.fg),
              const SizedBox(width: 2),
            ],
            Expanded(
              child: Text(
                className.isEmpty ? subject : '$className · $subject',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: palette.fg,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "+ N lagi" pill rendered as the last row of a stack-mode block when
/// there are more sessions than visible mini-card slots.
class _StackOverflowPill extends StatelessWidget {
  final int count;

  const _StackOverflowPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        '+ $count lagi',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: ColorUtils.slate600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Tilted card the user's finger carries while dragging a session.
/// Wider + shadowed than the in-grid block so it reads as "lifted".
class _DragFeedbackCard extends StatelessWidget {
  final _BlockPalette palette;
  final String subjectName;
  final String className;
  final String teacherName;

  const _DragFeedbackCard({
    required this.palette,
    required this.subjectName,
    required this.className,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.04, // ~-2.3° tilt
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 140,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.border, width: 2),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: palette.fg,
                  height: 1.1,
                ),
              ),
              if (className.isNotEmpty || teacherName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      className,
                      if (teacherName.isNotEmpty) teacherName,
                    ].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                '↓ lepas di slot lain',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thin dashed-style outline shown where the block USED to sit while
/// it's being dragged. Flutter doesn't have native dashed borders, so
/// we use a translucent cobalt outline as a near-equivalent.
class DottedOutline extends StatelessWidget {
  final Widget child;

  const DottedOutline({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: ColorUtils.brandCobalt.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Now line — red horizontal line + dot
// ─────────────────────────────────────────────────────────────────────

class _NowLine extends StatelessWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 1,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(height: 1, color: ColorUtils.error600),
            Positioned(
              left: -3,
              top: -3,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: ColorUtils.error600,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Block palette
// ─────────────────────────────────────────────────────────────────────

class _BlockPalette {
  final Color border;
  final Color bg;
  final Color fg;
  const _BlockPalette({
    required this.border,
    required this.bg,
    required this.fg,
  });
}

/// Compact descriptor for a single lesson_hour slot, used by the
/// drag-and-drop target to snap a dropped block to the nearest matching
/// time on the destination day.
class _SlotEntry {
  /// `lesson_hours.id` — the foreign key the reschedule endpoint expects
  /// as the new `lesson_hour_days_id`.
  final String lessonHourId;

  /// Cached minutes-from-midnight of the slot's start_time for fast
  /// nearest-neighbour matching during drag drops.
  final int startMinutes;

  /// Raw start_time string ("HH:MM[:SS]"). Surfaced back to the caller's
  /// reschedule callback so success snacks can quote the new time
  /// without re-querying the row.
  final String startTime;

  /// Slot length in minutes (end - start). Defaults to 45 when the slot
  /// has no end_time. Used by the drag-and-drop ghost rectangle so its
  /// preview height matches the actual slot duration.
  final int durationMinutes;

  const _SlotEntry({
    required this.lessonHourId,
    required this.startMinutes,
    required this.startTime,
    required this.durationMinutes,
  });
}

// ─────────────────────────────────────────────────────────────────────
// Focused-day header strip
// ─────────────────────────────────────────────────────────────────────

/// Header used in the grid's focused-day mode — pill tabs for each
/// weekday (active = filled navy, others = outlined slate) plus a
/// zoom-out chevron on the right that returns to the full week view.
///
/// Today gets a small accent dot next to its label so the admin can
/// always see which day "is today" while browsing other days.
class _FocusedDayHeaderStrip extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final String focusedDayId;
  final String? todayDayId;
  final ValueChanged<String> onPicked;
  final VoidCallback onZoomOut;

  const _FocusedDayHeaderStrip({
    required this.days,
    required this.focusedDayId,
    required this.todayDayId,
    required this.onPicked,
    required this.onZoomOut,
  });

  String _abbr(String name) {
    if (name.isEmpty) return '—';
    return name.substring(0, name.length.clamp(0, 3)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < days.length; i++) ...[
                    _DayPill(
                      label: _abbr((days[i]['name'] ?? '').toString()),
                      active: days[i]['id']?.toString() == focusedDayId,
                      isToday: days[i]['id']?.toString() == todayDayId,
                      onTap: () => onPicked(days[i]['id']?.toString() ?? ''),
                    ),
                    if (i < days.length - 1) const SizedBox(width: 4),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Zoom-out: returns to the full 6-day week view.
          Tooltip(
            message: 'Lihat semua hari',
            child: GestureDetector(
              onTap: onZoomOut,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: ColorUtils.slate200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 16,
                  color: ColorUtils.brandDarkBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  final String label;
  final bool active;
  final bool isToday;
  final VoidCallback onTap;

  const _DayPill({
    required this.label,
    required this.active,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? ColorUtils.brandDarkBlue : Colors.white,
          border: Border.all(
            color: active ? ColorUtils.brandDarkBlue : ColorUtils.slate200,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : ColorUtils.slate700,
                letterSpacing: 0.3,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? Colors.white : ColorUtils.error600,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact placeholder for screens that show the grid in a constrained
/// space (e.g. the schedule card on the admin dashboard). Exposed here
/// so callers don't accidentally inline a one-off "Coming soon" tile.
class AdminScheduleWeekGridSkeleton extends StatelessWidget {
  const AdminScheduleWeekGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
