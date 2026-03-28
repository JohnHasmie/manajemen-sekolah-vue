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
}
