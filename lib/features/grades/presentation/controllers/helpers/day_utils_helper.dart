import 'dart:convert';

/// Helper for day name normalization and extraction.
class DayUtilsHelper {
  /// Normalizes day names to standard Indonesian format.
  static String normalizeDayName([String? name]) {
    name ??= _getSystemDayName();
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) {
      return 'Senin';
    }
    if (name.contains('selasa') || name.contains('tuesday')) {
      return 'Selasa';
    }
    if (name.contains('rabu') || name.contains('wednesday')) {
      return 'Rabu';
    }
    if (name.contains('kamis') || name.contains('thursday')) {
      return 'Kamis';
    }
    if (name.contains('jumat') || name.contains('friday')) {
      return 'Jumat';
    }
    if (name.contains('sabtu') || name.contains('saturday')) {
      return 'Sabtu';
    }
    if (name.contains('minggu') || name.contains('sunday')) {
      return 'Minggu';
    }
    return name;
  }

  /// Gets the current system day name in English.
  static String _getSystemDayName() {
    final now = DateTime.now();
    final names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[now.weekday - 1];
  }

  /// Extracts day IDs from a schedule object.
  static List<String> extractDayIds(dynamic schedule) {
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
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
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
}
