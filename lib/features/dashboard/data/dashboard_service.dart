import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Dedicated service for Dashboard API operations.
/// Extracted from the monolithic ApiService to improve modularity.
class DashboardService {
  /// Fetches dashboard statistics (student count, teacher count, etc.) by role.
  /// Like a Laravel dashboard controller that aggregates stats per user role.
  static Future<Map<String, dynamic>> getDashboardStats({
    required String role,
    String? academicYearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'role': role};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }

      final response = await dioClient.get(
        ApiEndpoints.dashboardStats,
        queryParameters: queryParams,
      );

      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        return Map<String, dynamic>.from(result['data'] ?? {});
      }
      return {};
    } catch (e) {
      AppLogger.error('api', 'Error fetching dashboard stats: $e');
      return {};
    }
  }

  /// Latest academic-feed items for the parent Akademik hub
  /// "Aktivitas terbaru" preview strip.
  ///
  /// Backend route: `GET /dashboard/parent-academic-recent`
  /// (Laravel `DashboardController@parentAcademicRecent`).
  ///
  /// Returns up to [limit] items aggregated across announcements,
  /// grades, class activities, and report-card publishes — newest
  /// first. Each item is a small bag of presentational fields the
  /// hub renders as-is:
  ///   - `type`: one of 'announcement' / 'grade' / 'class_activity'
  ///     / 'report_card' — drives the icon + chip color
  ///   - `title`: headline copy
  ///   - `source`: small caption above the title
  ///   - `time_ago`: humanised relative time
  ///   - `badge`: optional pill copy (e.g. 'A · 96', 'Penting')
  ///   - `extra`: optional inline supporting text
  ///
  /// Returns an empty list on any error so the UI can hide the
  /// section gracefully instead of breaking.
  /// Full Perlu Perhatian feed for the "Lihat Semua" inbox screen.
  /// Returns rows + per-category unread counts.
  ///
  /// Categories: all / tagihan / nilai / pengumuman / kehadiran /
  /// aktivitas / raport. The `category` parameter narrows server-side
  /// — passing `'all'` fetches everything.
  static Future<({List<Map<String, dynamic>> items, Map<String, int> counts})>
  getParentInbox({String category = 'all', int limit = 50}) async {
    try {
      final response = await dioClient.get(
        ApiEndpoints.parentInbox,
        queryParameters: {'category': category, 'limit': limit},
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        final items = raw is List
            ? raw
                  .whereType<Map>()
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e),
                  )
                  .toList(growable: false)
            : <Map<String, dynamic>>[];
        final counts = <String, int>{};
        final c = result['counts'];
        if (c is Map) {
          c.forEach((k, v) {
            counts[k.toString()] = (v is int)
                ? v
                : int.tryParse(v.toString()) ?? 0;
          });
        }
        return (items: items, counts: counts);
      }
      return (
        items: const <Map<String, dynamic>>[],
        counts: const <String, int>{},
      );
    } catch (e) {
      AppLogger.error('api', 'Error fetching parent inbox: $e');
      return (
        items: const <Map<String, dynamic>>[],
        counts: const <String, int>{},
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getParentAcademicRecent({
    String? academicYearId,
    int limit = 5,
  }) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        ApiEndpoints.parentAcademicRecent,
        queryParameters: queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        }
      }
      return const [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching parent academic recent: $e');
      return const [];
    }
  }
}
