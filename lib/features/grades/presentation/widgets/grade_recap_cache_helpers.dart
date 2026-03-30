// Generic cache-first loader helpers for the grade recap screen.
// Extracted from _GradeRecapPageState as pure top-level functions — they
// have no dependency on widget state, so they belong in a helper file.
// Like a Laravel Repository pattern — each function abstracts one data-fetch.
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Generic cache-first data loader.
///
/// Checks [cacheKey] first (within [ttl]); on a miss calls [apiFetcher] and
/// persists the result.  Returns the cached or freshly-fetched list.
///
/// Like a Laravel `Cache::remember()` wrapper — one line to get
/// "cache or fetch" behaviour everywhere.
Future<List<dynamic>> loadWithCache({
  required String cacheKey,
  required Duration ttl,
  required Future<List<dynamic>> Function() apiFetcher,
  bool useCache = true,
}) async {
  if (useCache) {
    try {
      final cached = await LocalCacheService.load(cacheKey, ttl: ttl);
      if (cached != null) {
        AppLogger.debug('grades', 'Cache hit: $cacheKey');
        return List<dynamic>.from(cached);
      }
    } catch (_) {}
  }
  final data = await apiFetcher();
  if (data.isNotEmpty) LocalCacheService.save(cacheKey, data);
  return data;
}

/// Cache-first loader specifically for the grades API endpoint.
///
/// Handles the `/grades/teacher` response shape (either a `{data:[...]}` map
/// or a bare list).  Falls back to the API when the cache is empty or stale.
///
/// In Laravel terms: wraps `GradeController@index` with a local cache layer.
Future<List<dynamic>> loadGradesWithCache({
  required String cacheKey,
  required Duration ttl,
  required String classId,
  required String subjectId,
  required String academicYearId,
  bool useCache = true,
}) async {
  if (useCache) {
    try {
      final cached = await LocalCacheService.load(cacheKey, ttl: ttl);
      if (cached != null) {
        AppLogger.debug('grades', 'Cache hit: $cacheKey');
        return List<dynamic>.from(cached);
      }
    } catch (_) {}
  }
  final rawGradesResponse = await ApiService().get(
    '/grades/teacher?class_id=$classId&subject_id=$subjectId&academic_year_id=$academicYearId&limit=1000',
  );
  List<dynamic> rawGrades = [];
  if (rawGradesResponse != null) {
    if (rawGradesResponse is Map && rawGradesResponse['data'] != null) {
      rawGrades = rawGradesResponse['data'];
    } else if (rawGradesResponse is List) {
      rawGrades = rawGradesResponse;
    }
  }
  if (rawGrades.isNotEmpty) LocalCacheService.save(cacheKey, rawGrades);
  return rawGrades;
}
