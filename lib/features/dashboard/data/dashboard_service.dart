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
                  .map<Map<String, dynamic>>(Map<String, dynamic>.from)
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

  /// Full Perlu Perhatian feed for the teacher's "Lihat semua"
  /// inbox screen (GG.7). Calls the uncapped variant of the
  /// priority inbox composer — same five aggregators as the
  /// dashboard card but no top-5 cap.
  ///
  /// Returns the raw row list. Parsing into `PriorityInboxItem`
  /// happens at the call site so the model stays single-source
  /// (used by both this surface and the dashboard transformer).
  ///
  /// Returns an empty list on any error — matches the backend's
  /// graceful-degrade strategy (it also returns `data: []` on
  /// aggregator failure).
  static Future<List<Map<String, dynamic>>> getTeacherPriorityInbox({
    String? academicYearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        ApiEndpoints.teacherPriorityInbox,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map<Map<String, dynamic>>(Map<String, dynamic>.from)
              .toList(growable: false);
        }
      }
      return const [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching teacher priority inbox: $e');
      return const [];
    }
  }

  /// Capped (top-N) admin Perlu Perhatian list. Backs the
  /// admin_dashboard_body inbox card. Same shape as the teacher
  /// endpoint — list of inbox-item maps that the call site parses
  /// into `PriorityInboxItem` via `PriorityInboxItem.parseList`.
  ///
  /// Backend response also carries `total` (full unfiltered count)
  /// when items exist; we surface both as a tuple-ish return so the
  /// card can render "Perlu Perhatian · 5/12" when the list is
  /// capped. Returns `(items: [], total: 0)` on any error.
  static Future<({List<Map<String, dynamic>> items, int total})>
  getAdminPriorityInbox({String? academicYearId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        ApiEndpoints.adminPriorityInbox,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        final total = result['total'];
        if (raw is List) {
          final items = raw
              .whereType<Map>()
              .map<Map<String, dynamic>>(Map<String, dynamic>.from)
              .toList(growable: false);
          return (items: items, total: total is int ? total : items.length);
        }
      }
      return (items: const <Map<String, dynamic>>[], total: 0);
    } catch (e) {
      AppLogger.error('api', 'Error fetching admin priority inbox: $e');
      return (items: const <Map<String, dynamic>>[], total: 0);
    }
  }

  /// Full Perlu Perhatian feed for the admin's "Lihat semua" inbox
  /// screen. Uncapped variant of the admin composer.
  static Future<List<Map<String, dynamic>>> getAdminPriorityInboxAll({
    String? academicYearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        ApiEndpoints.adminPriorityInboxAll,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map<Map<String, dynamic>>(Map<String, dynamic>.from)
              .toList(growable: false);
        }
      }
      return const [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching admin priority inbox all: $e');
      return const [];
    }
  }

  /// Capped (top-N) parent Perlu Perhatian list — fans out across
  /// every child the parent is wali of unless [studentId] narrows
  /// the scope. Same return shape as the admin variant so the
  /// dashboard card stays one rendering path.
  ///
  /// Returns `(items: [], total: 0)` on any error.
  static Future<({List<Map<String, dynamic>> items, int total})>
  getParentPriorityInbox({String? studentId, String? academicYearId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (studentId != null && studentId.isNotEmpty) {
        queryParams['student_id'] = studentId;
      }
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        ApiEndpoints.parentPriorityInbox,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        final total = result['total'];
        if (raw is List) {
          final items = raw
              .whereType<Map>()
              .map<Map<String, dynamic>>(Map<String, dynamic>.from)
              .toList(growable: false);
          return (items: items, total: total is int ? total : items.length);
        }
      }
      return (items: const <Map<String, dynamic>>[], total: 0);
    } catch (e) {
      AppLogger.error('api', 'Error fetching parent priority inbox: $e');
      return (items: const <Map<String, dynamic>>[], total: 0);
    }
  }

  /// Uncapped variant of the parent priority inbox — backs the
  /// parent "Lihat semua" inbox screen.
  static Future<List<Map<String, dynamic>>> getParentPriorityInboxAll({
    String? studentId,
    String? academicYearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (studentId != null && studentId.isNotEmpty) {
        queryParams['student_id'] = studentId;
      }
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await dioClient.get(
        ApiEndpoints.parentPriorityInboxAll,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      final result = response.data;
      if (result is Map<String, dynamic> && result['success'] == true) {
        final raw = result['data'];
        if (raw is List) {
          return raw
              .whereType<Map>()
              .map<Map<String, dynamic>>(Map<String, dynamic>.from)
              .toList(growable: false);
        }
      }
      return const [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching parent priority inbox all: $e');
      return const [];
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
              .map<Map<String, dynamic>>(Map<String, dynamic>.from)
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
