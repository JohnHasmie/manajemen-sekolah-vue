import 'package:manajemensekolah/core/constants/api_endpoints.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Dedicated service for all Finance/Billing (Tagihan) API operations.
/// Extracted from the monolithic ApiService to improve modularity.
class FinanceService {
  // Get Tagihan with pagination & filters
  static Future<Map<String, dynamic>> getBillsPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? studentId,
    String? paymentTypeId,
    String? classId,
  }) async {
    final Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (studentId != null && studentId.isNotEmpty) {
      queryParams['student_id'] = studentId;
    }
    if (paymentTypeId != null && paymentTypeId.isNotEmpty) {
      queryParams['payment_type_id'] = paymentTypeId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }

    final response = await dioClient.get(
      ApiEndpoints.bills,
      queryParameters: queryParams,
    );

    final result = response.data;

    if (result is Map<String, dynamic>) return result;

    // fallback
    return {
      'success': true,
      'data': result is List ? result : [],
      'pagination': {
        'total_items': result is List ? result.length : 0,
        'total_pages': 1,
        'current_page': page,
        'per_page': limit,
        'has_next_page': false,
        'has_prev_page': false,
      },
    };
  }

  static Future<void> markBillRead({
    String? studentId,
    List<String>? billIds,
  }) async {
    try {
      await dioClient.post(
        ApiEndpoints.billMarkRead,
        data: {
          if (studentId != null) 'student_id': studentId,
          if (billIds != null) 'bill_ids': billIds,
        },
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking bills read: $e');
    }
  }

  static Future<void> markSingleBillRead({required String billId}) async {
    try {
      await dioClient.post(
        ApiEndpoints.billMarkSingleRead,
        data: {'bill_id': billId},
      );
    } catch (e) {
      AppLogger.error('api', 'Error marking bill read: $e');
    }
  }

  static Future<int> getUnreadBillingCount() async {
    try {
      final response = await dioClient.get(ApiEndpoints.billUnreadCount);
      final result = response.data;
      return int.tryParse(result['count']?.toString() ?? '0') ?? 0;
    } catch (e) {
      AppLogger.error('api', 'Error getting unread billing count: $e');
      return 0;
    }
  }

  // Manual payment entry by admin (for offline/cash payments)
  static Future<dynamic> inputManualPayment(Map<String, dynamic> data) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.paymentManual,
        data: data,
      );
      await CacheInvalidationService.onFinanceChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('api', 'Error input pembayaran manual: $e');
      rethrow;
    }
  }

  // Generate Bills for a specific Payment Type
  static Future<dynamic> generateBills({
    String? paymentTypeId,
    required String month,
    required String academicYearId,
  }) async {
    try {
      final Map<String, dynamic> body = {
        'month': month,
        'academic_year_id': academicYearId,
      };
      if (paymentTypeId != null) {
        body['payment_type_id'] = paymentTypeId;
      }
      final response = await dioClient.post(
        ApiEndpoints.generateBill,
        data: body,
      );
      await CacheInvalidationService.onFinanceChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('api', 'Error generating bills: $e');
      rethrow;
    }
  }

  // Get Finance Dashboard Stats
  static Future<Map<String, dynamic>> getFinanceDashboardStats() async {
    try {
      final response = await dioClient.get(ApiEndpoints.financeDashboard);
      final result = response.data;
      if (result is Map<String, dynamic>) {
        return result;
      }
      return {};
    } catch (e) {
      AppLogger.error('api', 'Error getting finance stats: $e');
      return {};
    }
  }

  // Get Generated Months
  static Future<List<String>> getGeneratedMonths({
    required String paymentTypeId,
    required String academicYearId,
  }) async {
    try {
      final response = await dioClient.get(
        '${ApiEndpoints.financeGeneratedMonths}?payment_type_id=$paymentTypeId&academic_year_id=$academicYearId',
      );
      final result = response.data;
      if (result is List) {
        return List<String>.from(result);
      }
      return [];
    } catch (e) {
      AppLogger.error('api', 'Error getting generated months: $e');
      return [];
    }
  }

  // Delete Bills for a specific Payment Type
  static Future<dynamic> deleteBillsByType(
    String paymentTypeId, {
    String? month,
  }) async {
    try {
      String url = '/bills/type/$paymentTypeId';
      if (month != null) {
        url += '?month=$month';
      }
      final response = await dioClient.delete(url);
      await CacheInvalidationService.onFinanceChanged();
      return response.data;
    } catch (e) {
      AppLogger.error('api', 'Error deleting bills by type: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getFinanceBillStats({
    String? academicYearId,
    String? paymentTypeId,
    String? month,
    String? classId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (academicYearId != null && academicYearId.isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId;
    }
    if (paymentTypeId != null && paymentTypeId.isNotEmpty) {
      queryParams['payment_type_id'] = paymentTypeId;
    }
    if (month != null && month.isNotEmpty) queryParams['month'] = month;
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }

    try {
      final response = await dioClient.get(
        ApiEndpoints.financeBillStats,
        queryParameters: queryParams,
      );

      final result = response.data;
      return result['data'] ?? {};
    } catch (e) {
      AppLogger.error('api', 'Error fetching finance bill stats: $e');
      return {};
    }
  }

  static Future<List<dynamic>> getFinanceDashboardChart({
    String? academicYearId,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (academicYearId != null) params['academic_year_id'] = academicYearId;

      final response = await dioClient.get(
        ApiEndpoints.financeDashboardChart,
        queryParameters: params,
      );
      final result = response.data;

      if (result is List) return result;
      return [];
    } catch (e) {
      AppLogger.error('api', 'Error fetching finance dashboard chart: $e');
      return [];
    }
  }
}
