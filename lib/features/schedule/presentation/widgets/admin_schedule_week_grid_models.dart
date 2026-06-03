// Density/render data types for the admin week-grid view.
//
// Extracted verbatim from `admin_schedule_week_grid_view.dart` during the
// Phase-2 readability split. These are library-private helper types, so
// they live in a `part` file (sharing the grid library's private scope)
// rather than being promoted to public API.
part of 'admin_schedule_week_grid_view.dart';

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
