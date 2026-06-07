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
//
// During the Phase-2 readability split the grid's sub-widgets and helper
// types were moved into sibling `part` files (chrome, day column, session
// blocks, and density/render models); this file keeps the public
// [AdminScheduleWeekGridView] layout orchestrator + the
// [AdminScheduleWeekGridSkeleton] placeholder.
library;

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule_kpi_summary.dart';

part 'admin_schedule_week_grid_chrome.dart';
part 'admin_schedule_day_column.dart';
part 'admin_schedule_week_grid_blocks.dart';
part 'admin_schedule_week_grid_models.dart';

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

  /// IDs currently selected in bulk-select mode (TR.F).
  ///
  /// When non-empty the grid switches into "select" mode: blocks
  /// render a cobalt check-corner overlay when their id is in the
  /// set, tapping a block toggles its membership instead of opening
  /// the detail sheet, and drag-and-drop is suppressed so the admin
  /// can sweep selections without accidental drops. The screen
  /// passes the same `_selectedIds` set the BulkActionBar reads.
  final Set<String> selectedIds;
  bool get isBulkMode => selectedIds.isNotEmpty;

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
    this.selectedIds = const <String>{},
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
        .map(Map<String, dynamic>.from)
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
                            selectedIds: selectedIds,
                            isBulkMode: isBulkMode,
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
                          selectedIds: selectedIds,
                          isBulkMode: isBulkMode,
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
