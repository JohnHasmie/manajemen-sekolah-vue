// Part of the teacher attendance screen library.
// Contains pure helper functions (no widget state access) extracted to keep
// teacher_attendance_screen.dart under 1,500 lines.
//
// Like splitting a large Vue page's utility functions into a separate
// composable file — same logic, just moved for readability.
part of 'teacher_attendance_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// CACHE HELPER
// ──────────────────────────────────────────────────────────────────────────────

/// Load a single data source with cache-first pattern.
/// Returns cached data if available, otherwise fetches from API and saves to cache.
Future<List<dynamic>> _loadWithCache({
  required String cacheKey,
  required Duration ttl,
  required Future<List<dynamic>> Function() apiFetcher,
  bool useCache = true,
}) async {
  // Try cache first
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

  // Fetch from API
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
// DATE / TIME HELPERS
// ──────────────────────────────────────────────────────────────────────────────

// Get current academic year
String _getCurrentAcademicYear() {
  final now = DateTime.now();
  final currentYear = now.year;
  final currentMonth = now.month;
  if (currentMonth >= 7) {
    return '$currentYear/${currentYear + 1}';
  } else {
    return '${currentYear - 1}/$currentYear';
  }
}

// Get current term (semester)
String _getCurrentTerm() {
  final now = DateTime.now();
  final currentMonth = now.month;
  if (currentMonth >= 7) {
    return '1';
  } else {
    return '2';
  }
}

// Get current day ID (1=Senin, 2=Selasa, etc.)
String _getCurrentDayId() {
  final now = DateTime.now();
  final weekday = now.weekday; // 1=Monday, 7=Sunday
  return weekday.toString();
}

// Check if current time is within schedule time
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

// Helper function to parse date string as local date (not UTC)
DateTime _parseLocalDate(String dateString) {
  // Use AppDateUtils for consistent and correct parsing
  return AppDateUtils.parseApiDate(dateString) ?? DateTime.now();
}

bool _isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
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
// TOUR TARGETS
// ──────────────────────────────────────────────────────────────────────────────

List<TargetFocus> _createTourTargets(
  GlobalKey tabSwitcherKey,
  GlobalKey searchFilterKey,
) {
  final List<TargetFocus> targets = [];

  targets.add(
    TargetFocus(
      identify: "TabSwitcher",
      keyTarget: tabSwitcherKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.bottom,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Mode Absensi",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Pilih 'Hasil Absensi' untuk melihat rekapan daftar hadir sebelumnya, atau 'Tambah Absensi' untuk mulai memanggil daftar hadir siswa hari ini.",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  targets.add(
    TargetFocus(
      identify: "SearchFilter",
      keyTarget: searchFilterKey,
      alignSkip: Alignment.bottomRight,
      shape: ShapeLightFocus.RRect,
      radius: 12,
      contents: [
        TargetContent(
          align: ContentAlign.top,
          builder: (context, controller) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Pencarian & Filter",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    "Gunakan kotak pencarian ini untuk mencari data absensi, dan gunakan tombol filter di sebelah kanannya untuk mencari rekapan absensi berdasarkan hari, bulan, atau mata pelajaran tertentu.",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  return targets;
}

// ──────────────────────────────────────────────────────────────────────────────
// STYLING HELPERS
// ──────────────────────────────────────────────────────────────────────────────

// ========== HELPER FUNCTIONS FOR STYLING ==========
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
