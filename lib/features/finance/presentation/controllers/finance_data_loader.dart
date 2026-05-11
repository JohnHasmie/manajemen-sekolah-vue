// Facade for all finance data loading and manipulation.
// Extracted from [AdminFinanceController] to separate I/O from logic.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/finance_data_results.dart';

// ─── Data loader facade ──────────────────────────────────────────────────────

/// Facade for all finance data loading operations.
/// Delegates to [ApiService] and [FinanceService]; handles result mapping.
class FinanceDataLoader {
  final Ref _ref;

  FinanceDataLoader(this._ref);

  // ─── Cache key ──────────────────────────────────────────────────────────

  /// Builds the local-cache key for finance data.
  /// Returns null when filters/search are active (skip caching).
  String? buildFinanceCacheKey({
    String? selectedStatusFilter,
    String? selectedPeriodFilter,
    String searchText = '',
  }) {
    if (selectedStatusFilter != null ||
        selectedPeriodFilter != null ||
        searchText.isNotEmpty) {
      return null;
    }
    final academicYearProvider = _ref.read(academicYearRiverpod);
    final yearId =
        academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'all';
    return 'finance_data_$yearId';
  }

  // ─── Data calculation ───────────────────────────────────────────────────

  /// Groups [bills] into batch records keyed by payment_type + YYYY-MM.
  /// Used as a fallback when dashboard API returns empty generated_batches.
  List<dynamic> calculateBatchesFromBills(List<dynamic> bills) {
    final Map<String, Map<String, dynamic>> batches = {};

    for (final t in bills) {
      final type = t['payment_type'] ?? {};
      final typeId = (t['payment_type_id'] ?? type['id'])?.toString();
      final dueDateStr = t['due_date']?.toString() ?? '';

      if (typeId == null || dueDateStr.isEmpty) continue;

      final month = dueDateStr.length >= 7
          ? dueDateStr.substring(0, 7)
          : 'Unknown';
      final key = '${typeId}_$month';

      if (!batches.containsKey(key)) {
        batches[key] = {
          'payment_type_id': typeId,
          'name': type['name'] ?? 'No Name',
          'amount': type['amount'] ?? t['amount'] ?? 0,
          'month': month,
          'count': 0,
        };
      }
      batches[key]!['count']++;
    }

    final result = batches.values.toList();
    result.sort((a, b) => (b['month'] ?? '').compareTo(a['month'] ?? ''));
    return result;
  }

  // ─── Payment types ──────────────────────────────────────────────────────

  /// Fetches all payment types and normalises status/period values.
  Future<LoadPaymentTypesResult> loadPaymentTypes() async {
    try {
      final response = await ApiService().get('/payment-types');
      final List<dynamic> rawData;
      if (response is Map && response.containsKey('data')) {
        rawData = response['data'] is List ? response['data'] : [];
      } else {
        rawData = response is List ? response : [];
      }

      final normalised = rawData.map((item) {
        if (item is Map<String, dynamic>) {
          final newItem = Map<String, dynamic>.from(item);

          // Keep status as backend values ('active' / 'inactive').
          // UI widgets handle display translation to 'Aktif' / 'Nonaktif'.

          // Normalise period → lowercase Indonesian
          final period = newItem['periode']?.toString().toUpperCase();
          if (period == 'MONTHLY') {
            newItem['periode'] = 'bulanan';
          } else if (period == 'YEARLY') {
            newItem['periode'] = 'tahunan';
          } else if (period == 'SEMESTER') {
            newItem['periode'] = 'semester';
          } else if (period == 'ONCE') {
            newItem['periode'] = 'sekali bayar';
          } else if (newItem['periode'] != null) {
            newItem['periode'] = newItem['periode'].toString().toLowerCase();
          }

          return newItem;
        }
        return item;
      }).toList();

      return LoadPaymentTypesResult(paymentTypeList: normalised);
    } catch (e) {
      AppLogger.error('finance', e);
      return LoadPaymentTypesResult.failure(ErrorUtils.getFriendlyMessage(e));
    }
  }

  // ─── Bills ──────────────────────────────────────────────────────────────

  /// Fetches a page of bills using [FinanceService.getBillsPaginated].
  Future<LoadBillsResult> loadBills({
    required int page,
    required int perPage,
    String? statusFilter,
  }) async {
    try {
      final ayId = _ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final res = await FinanceService.getBillsPaginated(
        page: page,
        limit: perPage,
        status: statusFilter,
        academicYearId: ayId,
      );

      final List<dynamic> pageData;
      final Map<String, dynamic> pagination;

      if (res['success'] == true || res.containsKey('data')) {
        pageData = (res['data'] as List?) ?? [];
        pagination = (res['pagination'] as Map?)?.cast<String, dynamic>() ?? {};
      } else {
        pageData = [];
        pagination = {};
      }

      final hasMoreData =
          pagination['has_next_page'] ?? (pageData.length == perPage);

      return LoadBillsResult(bills: pageData, hasMoreData: hasMoreData as bool);
    } catch (e) {
      AppLogger.error('finance', e);
      return LoadBillsResult.failure(ErrorUtils.getFriendlyMessage(e));
    }
  }

  /// Fetches all bills and groups them by student_id.
  /// Used by [loadClassData] and the ClassFinanceReport drill screen
  /// (reachable via the navy-tinted ClassReportDrillCard pinned at
  /// the bottom of the Tagihan tab — Mockup #13).
  Future<Map<String, List<dynamic>>> loadBillsForStudents() async {
    try {
      final billsResponse = await ApiService().get('/bills?limit=10000');

      List<dynamic> allBills = [];
      if (billsResponse is Map<String, dynamic> &&
          billsResponse.containsKey('data')) {
        allBills = billsResponse['data'] is List ? billsResponse['data'] : [];
      } else if (billsResponse is List) {
        allBills = billsResponse;
      }

      final Map<String, List<dynamic>> billsByStudent = {};
      for (final bill in allBills) {
        final studentId = bill['student_id']?.toString();
        if (studentId != null) {
          billsByStudent.putIfAbsent(studentId, () => []).add(bill);
        }
      }

      return billsByStudent;
    } catch (e) {
      AppLogger.error('finance', e);
      return {};
    }
  }

  // ─── Pending payments ───────────────────────────────────────────────────

  /// Fetches paginated pending-payment list with flattened nested data.
  Future<LoadPendingPaymentsResult> loadPendingPayments({
    required int page,
    required int perPage,
    bool loadMore = false,
  }) async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      String url = '/payments?status=pending&limit=$perPage&page=$page';
      if (academicYearId != null) {
        url += '&academic_year_id=$academicYearId';
      }

      final response = await ApiService().get(url);

      final List<dynamic> rawList;
      int totalPending = 0;

      if (response is Map && response.containsKey('data')) {
        rawList = response['data'] is List ? response['data'] : [];
        if (response.containsKey('total')) {
          totalPending = int.tryParse(response['total'].toString()) ?? 0;
        } else if (response.containsKey('meta') && response['meta'] is Map) {
          totalPending =
              int.tryParse(response['meta']['total'].toString()) ?? 0;
        }
      } else {
        rawList = response is List ? response : [];
        totalPending = rawList.length;
      }

      final hasMorePending = rawList.length >= perPage;

      // Flatten nested student/bill/payment_type data
      final mappedList = rawList.map((item) {
        if (item is Map<String, dynamic>) {
          final newItem = Map<String, dynamic>.from(item);
          final bill = newItem['bill'] ?? {};
          final student = bill['student'] ?? {};
          final paymentType = bill['payment_type'] ?? {};

          newItem['siswa_nama'] ??= student['name'];
          newItem['jenis_pembayaran_nama'] ??= paymentType['name'];

          if (newItem['kelas_nama'] == null) {
            if (student['classes'] is List &&
                (student['classes'] as List).isNotEmpty) {
              newItem['kelas_nama'] = student['classes'][0]['name'];
            } else if (student['class_name'] != null) {
              newItem['kelas_nama'] = student['class_name'];
            } else if (student['class'] != null) {
              newItem['kelas_nama'] = student['class']['name'];
            }
          }

          return newItem;
        }
        return item;
      }).toList();

      return LoadPendingPaymentsResult(
        pendingPaymentList: mappedList,
        totalPendingPayments: totalPending,
        hasMorePending: hasMorePending,
      );
    } catch (e) {
      AppLogger.error('finance', e);
      return LoadPendingPaymentsResult.failure(
        ErrorUtils.getFriendlyMessage(e),
      );
    }
  }

  // ─── Dashboard ──────────────────────────────────────────────────────────

  /// Fetches dashboard summary stats with fallback batch calculation.
  Future<LoadDashboardResult> loadDashboardData() async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      String url = '/finance/dashboard';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await ApiService().get(url);
      final data = Map<String, dynamic>.from(response is Map ? response : {});

      // Fallback: compute batches client-side if API returns none
      final List<dynamic> batches = data['generated_batches'] ?? [];
      if (batches.isEmpty) {
        final ayId2 = _ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString();
        final res = await FinanceService.getBillsPaginated(
          limit: 500,
          academicYearId: ayId2,
        );
        final List<dynamic>? billsData = res['data'] is List
            ? res['data']
            : (res is List ? res : null);

        if (billsData != null) {
          data['generated_batches'] = calculateBatchesFromBills(billsData);
        }
      }

      return LoadDashboardResult(dashboardData: data);
    } catch (e) {
      AppLogger.error('finance', e);
      return LoadDashboardResult.failure(ErrorUtils.getFriendlyMessage(e));
    }
  }

  // ─── Class data ──────────────────────────────────────────────────────────

  /// Fetches classes, students, groups students by class, loads bills.
  Future<LoadClassDataResult> loadClassData() async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      // Fetch classes
      String classUrl = '/classes?limit=1000';
      if (academicYearId != null) {
        classUrl += '&academic_year_id=$academicYearId';
      }

      final classResponse = await ApiService().get(classUrl);
      final List<dynamic> classList;
      if (classResponse is Map && classResponse.containsKey('data')) {
        classList = classResponse['data'] is List ? classResponse['data'] : [];
      } else {
        classList = classResponse is List ? classResponse : [];
      }

      // Fetch students
      final studentResponse = await ApiService().get('/students?limit=1000');
      final List<dynamic> allStudents;
      if (studentResponse is Map && studentResponse.containsKey('data')) {
        allStudents = studentResponse['data'] is List
            ? studentResponse['data']
            : [];
      } else {
        allStudents = studentResponse is List ? studentResponse : [];
      }

      // Group students by class_id
      final Map<String, List<dynamic>> studentsByClass = {};
      for (final student in allStudents) {
        String? classId = student['class_id']?.toString();
        if (classId == null && student['class'] != null) {
          classId = student['class']['id']?.toString();
        }
        if (classId != null) {
          studentsByClass.putIfAbsent(classId, () => []).add(student);
        }
      }

      // Fetch bills grouped by student
      final Map<String, List<dynamic>> billsByStudent =
          await loadBillsForStudents();

      return LoadClassDataResult(
        classList: classList,
        studentList: allStudents,
        studentsByClass: studentsByClass,
        billsByStudent: billsByStudent,
      );
    } catch (e) {
      AppLogger.error('finance', e);
      return LoadClassDataResult.failure(ErrorUtils.getFriendlyMessage(e));
    }
  }
}
