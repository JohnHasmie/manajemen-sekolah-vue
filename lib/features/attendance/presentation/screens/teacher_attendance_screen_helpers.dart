// Part of the teacher attendance screen library.
// Contains pure helper functions (no widget state access).
part of 'teacher_attendance_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// CACHE HELPER
// ──────────────────────────────────────────────────────────────────────────────

Future<List<dynamic>> _loadWithCache({
  required String cacheKey,
  required Duration ttl,
  required Future<List<dynamic>> Function() apiFetcher,
  bool useCache = true,
}) async {
  if (useCache) {
    try {
      final cached = await LocalCacheService.load(cacheKey, ttl: ttl);
      if (cached != null) {
        AppLogger.debug('attendance', 'Cache hit: $cacheKey');
        return List<dynamic>.from(cached);
      }
    } catch (e) {
      AppLogger.error('attendance', 'Cache load error ($cacheKey): $e');
    }
  }
  final data = await apiFetcher();
  if (data.isNotEmpty) {
    LocalCacheService.save(cacheKey, data);
  }
  return data;
}

// ──────────────────────────────────────────────────────────────────────────────
// API HELPER
// ──────────────────────────────────────────────────────────────────────────────

Future<List<dynamic>> _getSubjectByTeacher(
  String teacherId, {
  String? classId,
}) async {
  try {
    final result = await getIt<ApiTeacherService>().getSubjectByTeacher(
      teacherId,
      classId: classId,
    );
    return result;
  } catch (e) {
    AppLogger.error('attendance', 'Error getting mata pelajaran by guru: $e');
    return [];
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// TIME HELPERS
// ──────────────────────────────────────────────────────────────────────────────

bool _isWithinScheduleTime(String jamMulai, String jamSelesai) {
  if (jamMulai.isEmpty || jamSelesai.isEmpty) return false;
  try {
    final now = TimeOfDay.now();
    final startParts = jamMulai.split(':');
    final endParts = jamSelesai.split(':');

    final start = TimeOfDay(
      hour: int.parse(startParts[0]),
      minute: int.parse(startParts[1].split('.')[0]),
    );
    final end = TimeOfDay(
      hour: int.parse(endParts[0]),
      minute: int.parse(endParts[1].split('.')[0]),
    );

    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  } catch (e) {
    AppLogger.error('attendance', 'Error parsing time: $e');
    return false;
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STATUS HELPERS
// ──────────────────────────────────────────────────────────────────────────────

String _mapStatusToBackend(String status) {
  switch (status.toLowerCase()) {
    case 'hadir':
      return 'present';
    case 'terlambat':
      return 'late';
    case 'izin':
      return 'excused';
    case 'sakit':
      return 'sick';
    case 'alpha':
    case 'absent':
      return 'absent';
    default:
      return 'present';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STYLING HELPERS
// ──────────────────────────────────────────────────────────────────────────────

Color _getPrimaryColor() {
  return ColorUtils.getRoleColor('guru');
}

LinearGradient _getCardGradient() {
  final primaryColor = _getPrimaryColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
  );
}
