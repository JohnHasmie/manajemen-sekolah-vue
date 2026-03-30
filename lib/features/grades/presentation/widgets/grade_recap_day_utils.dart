// Day-name normalisation and day-ID extraction helpers for the grade recap
// screen's "today's schedule" priority logic.
// Extracted from _GradeRecapPageState as pure top-level functions so the
// main screen file stays lean.
// Like a Laravel helper file (`helpers/day_utils.php`) — stateless utilities.
import 'dart:convert';

/// Normalises an Indonesian or English day name to a canonical Indonesian form.
///
/// Examples:
///   `normalizeDayName('Monday')` → `'Senin'`
///   `normalizeDayName('senin')` → `'Senin'`
///
/// Like a Vue filter or a Laravel `Str::` helper — pure input→output.
String normalizeDayName(String name) {
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

/// Extracts a list of day IDs from a schedule map entry.
///
/// Handles three formats for `days_ids` / `day_id`:
///   - A `List` (already parsed JSON array)
///   - A JSON-encoded string (`"[1,2,3]"`)
///   - A comma-separated string (`"1,2,3"`)
///
/// Returns an empty list when the schedule is null or has no day fields.
/// Like a Laravel accessor — normalises inconsistent API shapes.
List<String> extractDayIds(dynamic schedule) {
  if (schedule == null) return [];
  final rawIds = schedule['days_ids'] ?? schedule['day_id'];
  if (rawIds == null) return [];

  if (rawIds is List) {
    return rawIds.map((e) => e.toString()).toList();
  }
  if (rawIds is String) {
    if (rawIds.contains('[')) {
      try {
        final parsed = json.decode(rawIds);
        if (parsed is List) return parsed.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return rawIds
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return [rawIds.toString()];
}
