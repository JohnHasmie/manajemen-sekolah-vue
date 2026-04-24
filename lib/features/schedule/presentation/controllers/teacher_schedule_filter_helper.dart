// Filter and display helpers for TeacherScheduleController.
// Handles schedule filtering, sorting, and day name normalization.
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// Helper class for schedule filtering and display operations.
class TeacherScheduleFilterHelper {
  /// Normalises a day name to its canonical Indonesian form.
  /// Accepts English names and common variants.
  ///
  /// Pure function — like a PHP `normalise_day_name()` helper.
  static String normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) {
      return 'Selasa';
    }
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return name;
  }

  /// Extracts the list of day-ID strings from a schedule item.
  /// Handles both Array and serialised-string formats from the API.
  ///
  /// Like a PHP accessor on the Schedule model: `getDaysIdsAttribute()`.
  static List<String> extractDayIds(dynamic schedule) {
    final List<String> ids = [];
    final rawDaysIds = schedule['days_ids'];

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
        } catch (e) {
          // ignore: empty_catches
        }
      }
    }

    // Fallback to single day_id field
    if (ids.isEmpty) {
      final fallbackId = Schedule.fromJson(
        Map<String, dynamic>.from(schedule as Map),
      ).dayId;
      if (fallbackId != null && fallbackId.isNotEmpty) {
        ids.add(fallbackId);
      }
    }
    return ids;
  }

  /// Filters and sorts the raw schedule list according to search text, day,
  /// class filters, and "today first" priority ordering.
  ///
  /// Pure function — like a Laravel `ScheduleFilter` pipeline class.
  static List<dynamic> getFilteredSchedules({
    required List<dynamic> scheduleList,
    required String searchText,
    required List<String> selectedDayIds,
    required String? selectedClassId,
    required Map<String, String> dayIdMap,
  }) {
    final searchTerm = searchText.toLowerCase();
    final now = DateTime.now();

    // Standard day mappings for stable sorting
    const dayNamesISO = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const dayOrder = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const weekdayToIndo = {
      1: 'Senin',
      2: 'Selasa',
      3: 'Rabu',
      4: 'Kamis',
      5: 'Jumat',
      6: 'Sabtu',
      7: 'Minggu',
    };

    final currentDayISO = dayNamesISO[now.weekday - 1];
    final currentDayIndo = normalizeDayName(currentDayISO);

    // Resolve current-day ID from dynamic map
    String? currentDayId;
    dayIdMap.forEach((key, value) {
      if (normalizeDayName(key) == currentDayIndo) {
        currentDayId = value.toString();
      }
    });

    // Reverse-map the selected day IDs back to canonical Indonesian day names.
    // Needed because the backend's lesson_hour.day payload serialises day_id
    // as a UUID (not the weekday-number values in dayIdMap), so pure ID
    // comparison never matches. By also matching on the schedule's dayName
    // (which the API returns as English like "Monday" and we normalise), the
    // filter still works regardless of which ID format the payload carries.
    final selectedDayNames = selectedDayIds
        .map((id) {
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => const MapEntry('', ''),
          );
          return entry.key.isNotEmpty ? normalizeDayName(entry.key) : '';
        })
        .where((s) => s.isNotEmpty)
        .toSet();

    final filtered = scheduleList.where((schedule) {
      final model = Schedule.fromJson(
        Map<String, dynamic>.from(schedule as Map),
      );
      final subjectName = (model.subjectName ?? '').toLowerCase();
      final className = (model.className ?? '').toLowerCase();
      final teacherName = (model.teacherName ?? '').toLowerCase();
      final startTime = (model.startTime ?? '').toLowerCase();
      final endTime = (model.endTime ?? '').toLowerCase();
      final lessonHour = (model.lessonHour?.toString() ?? '');
      final daysIds = extractDayIds(schedule);

      final dayNamesStr = daysIds
          .map((id) {
            final entry = dayIdMap.entries.firstWhere(
              (e) => e.value.toString() == id,
              orElse: () => const MapEntry('', ''),
            );
            return entry.key.isNotEmpty
                ? entry.key
                : (weekdayToIndo[int.tryParse(id) ?? 0] ?? '');
          })
          .where((k) => k.isNotEmpty)
          .join(' ')
          .toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          teacherName.contains(searchTerm) ||
          dayNamesStr.contains(searchTerm) ||
          startTime.contains(searchTerm) ||
          endTime.contains(searchTerm) ||
          lessonHour.contains(searchTerm);

      bool dayMatchesById() {
        return selectedDayIds.any((selectedId) {
          return daysIds.any((dId) => dId.toString() == selectedId.toString());
        });
      }

      bool dayMatchesByName() {
        if (selectedDayNames.isEmpty) return false;
        final scheduleDayName = normalizeDayName(model.dayName ?? '');
        return scheduleDayName.isNotEmpty &&
            selectedDayNames.contains(scheduleDayName);
      }

      final matchesDay =
          selectedDayIds.isEmpty || dayMatchesById() || dayMatchesByName();

      final matchesClass =
          selectedClassId == null ||
          selectedClassId.isEmpty ||
          model.classId == selectedClassId;

      return matchesSearch && matchesDay && matchesClass;
    }).toList();

    // Sort: today first, then sequential weekday, then start time
    filtered.sort((a, b) {
      final dayIdA = extractDayIds(a);
      final dayIdB = extractDayIds(b);

      bool belongsToToday(dynamic item, List<String> ids) {
        // Tier 1: Direct day_name field via model
        final dayName =
            Schedule.fromJson(Map<String, dynamic>.from(item as Map)).dayName ??
            '';
        if (dayName.isNotEmpty && normalizeDayName(dayName) == currentDayIndo) {
          return true;
        }
        // Tier 2: ID match via dynamic map
        if (currentDayId != null && ids.any((id) => id == currentDayId)) {
          return true;
        }
        // Tier 3: Direct ISO weekday number match
        if (ids.any((id) => id == now.weekday.toString())) {
          return true;
        }
        // Tier 4: Map key normalized match
        return ids.any((id) {
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => const MapEntry('', ''),
          );
          return entry.key.isNotEmpty &&
              normalizeDayName(entry.key) == currentDayIndo;
        });
      }

      final isTodayA = belongsToToday(a, dayIdA);
      final isTodayB = belongsToToday(b, dayIdB);

      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;

      int getMinDayRank(List<String> ids) {
        if (ids.isEmpty) return 99;
        int minIdx = 99;
        for (final id in ids) {
          String name = '';
          final entry = dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => const MapEntry('', ''),
          );
          if (entry.key.isNotEmpty) {
            name = normalizeDayName(entry.key);
          } else {
            name = weekdayToIndo[int.tryParse(id) ?? 0] ?? '';
          }
          final int idx = dayOrder.indexOf(name);
          if (idx != -1 && idx < minIdx) minIdx = idx;
        }
        return minIdx;
      }

      final rankA = getMinDayRank(dayIdA);
      final rankB = getMinDayRank(dayIdB);
      if (rankA != rankB) return rankA.compareTo(rankB);

      if (dayIdA.length != dayIdB.length) {
        return dayIdA.length.compareTo(dayIdB.length);
      }

      final timeA =
          Schedule.fromJson(Map<String, dynamic>.from(a as Map)).startTime ??
          '00:00';
      final timeB =
          Schedule.fromJson(Map<String, dynamic>.from(b as Map)).startTime ??
          '00:00';
      return timeA.compareTo(timeB);
    });

    return filtered;
  }
}
