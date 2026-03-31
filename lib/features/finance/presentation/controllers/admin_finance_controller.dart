// Controller for AdminFinanceScreen (admin_finance_screen.dart).
//
// Like a Laravel Controller class extracted from a fat Blade/route closure,
// or a Vue Composition API `setup()` pulled into its own composable.
//
// Holds all data-fetching, data-manipulation and pure-helper logic so that
// admin_finance_screen.dart only concerns itself with widget rendering and
// `setState` calls.
//
// Usage in screen:
//   final ctrl = ref.read(adminFinanceControllerProvider);

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';

/// Riverpod provider for [AdminFinanceController].
/// Use `ref.read(adminFinanceControllerProvider)` from the screen.
///
/// Plain [Provider] (not AsyncNotifier) — the controller owns no state.
/// State stays in the screen's `setState` calls, matching the pattern used by
/// [GradeBookController] and other controllers in this codebase.
final adminFinanceControllerProvider = Provider<AdminFinanceController>((ref) {
  return AdminFinanceController(ref);
});

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result returned by [AdminFinanceController.loadPaymentTypes].
/// The screen applies each field via setState.
class LoadPaymentTypesResult {
  final List<dynamic> paymentTypeList;

  /// Non-null when the fetch failed. Screen shows the error snackbar.
  final String? error;

  const LoadPaymentTypesResult({required this.paymentTypeList, this.error});

  LoadPaymentTypesResult.failure(String message)
      : paymentTypeList = const [],
        error = message;
}

/// Result returned by [AdminFinanceController.loadBills].
class LoadBillsResult {
  final List<dynamic> bills;
  final bool hasMoreData;
  final String? error;

  const LoadBillsResult({
    required this.bills,
    required this.hasMoreData,
    this.error,
  });

  LoadBillsResult.failure(String message)
      : bills = const [],
        hasMoreData = false,
        error = message;
}

/// Result returned by [AdminFinanceController.loadPendingPayments].
class LoadPendingPaymentsResult {
  final List<dynamic> pendingPaymentList;
  final int totalPendingPayments;
  final bool hasMorePending;
  final String? error;

  const LoadPendingPaymentsResult({
    required this.pendingPaymentList,
    required this.totalPendingPayments,
    required this.hasMorePending,
    this.error,
  });

  LoadPendingPaymentsResult.failure(String message)
      : pendingPaymentList = const [],
        totalPendingPayments = 0,
        hasMorePending = false,
        error = message;
}

/// Result returned by [AdminFinanceController.loadDashboardData].
class LoadDashboardResult {
  final Map<String, dynamic> dashboardData;
  final String? error;

  const LoadDashboardResult({required this.dashboardData, this.error});

  LoadDashboardResult.failure(String message)
      : dashboardData = const {},
        error = message;
}

/// Result returned by [AdminFinanceController.loadClassData].
class LoadClassDataResult {
  final List<dynamic> classList;
  final List<dynamic> studentList;
  final Map<String, List<dynamic>> studentsByClass;

  /// Bills grouped by student_id, from [AdminFinanceController.loadBillsForStudents].
  final Map<String, List<dynamic>> billsByStudent;
  final String? error;

  const LoadClassDataResult({
    required this.classList,
    required this.studentList,
    required this.studentsByClass,
    required this.billsByStudent,
    this.error,
  });

  LoadClassDataResult.failure(String message)
      : classList = const [],
        studentList = const [],
        studentsByClass = const {},
        billsByStudent = const {},
        error = message;
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Plain Dart class holding all data/logic for [FinanceScreenState].
///
/// Analogy: think of this as the Laravel Controller that was previously inlined
/// inside the View (admin_finance_screen.dart). It receives `ref` — like
/// Laravel's service container — so it can read providers without ever calling
/// setState itself.
class AdminFinanceController {
  final Ref _ref;

  AdminFinanceController(this._ref);

  // ─── Pure helpers ──────────────────────────────────────────────────────────

  /// Returns the primary theme color for the admin role.
  /// Pure — no side effects, like a Vue computed property.
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  /// Returns the card gradient for admin finance UI elements.
  LinearGradient getCardGradient() {
    final color = getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [color, color.withValues(alpha: 0.85)],
    );
  }

  /// Formats a raw numeric amount into an Indonesian Rupiah string.
  /// Like a Vue filter: `{{ amount | currency }}`.
  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final double value = double.parse(amount.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(value);
    } catch (e) {
      return 'Rp 0';
    }
  }

  /// Converts a `YYYY-MM` string like `"2024-03"` into a human-readable
  /// Indonesian month name: `"Maret 2024"`.
  String formatMonth(String? monthStr) {
    if (monthStr == null || monthStr.isEmpty) return '';
    try {
      final parts = monthStr.split('-');
      if (parts.length != 2) return monthStr;

      final year = parts[0];
      final month = int.tryParse(parts[1]) ?? 1;

      const monthNames = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];

      return '${monthNames[month - 1]} $year';
    } catch (e) {
      return monthStr;
    }
  }

  /// Parses a JSON-encoded or Map goal/target object into a plain Dart Map.
  /// Returns an empty map on null or parse error.
  Map<String, dynamic> parseGoal(dynamic goalData) {
    if (goalData == null) return {};
    if (goalData is Map<String, dynamic>) return goalData;
    if (goalData is String) {
      try {
        return json.decode(goalData) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.error('finance', e);
        return {};
      }
    }
    return {};
  }

  /// Extracts the human-readable goal description from raw goal data.
  String getGoalDescription(dynamic goalData) {
    final parsed = parseGoal(goalData);
    return parsed['description'] ?? 'Tujuan pembayaran';
  }

  /// Returns the translated period label for a payment type period string.
  /// Like a Vue i18n filter: `{{ period | translatePeriod }}`.
  String getTranslatedPeriod(String? period) {
    if (period == null) return '-';

    final languageProvider = _ref.read(languageRiverpod);
    final lower = period.toLowerCase();

    if (lower == 'once' || lower == 'sekali') {
      return languageProvider.getTranslatedText({
        'en': 'One Time',
        'id': 'Sekali',
      });
    } else if (lower == 'bulanan' || lower == 'monthly') {
      return languageProvider.getTranslatedText({
        'en': 'Monthly',
        'id': 'Bulanan',
      });
    } else if (lower == 'tahunan' || lower == 'yearly') {
      return languageProvider.getTranslatedText({
        'en': 'Yearly',
        'id': 'Tahunan',
      });
    } else if (lower == 'semester') {
      return languageProvider.getTranslatedText({
        'en': 'Semester',
        'id': 'Semester',
      });
    }

    return period;
  }

  /// Filters [paymentTypeList] by [searchTerm], [statusFilter], and
  /// [periodFilter]. Pure function — no side effects.
  ///
  /// Like `computed: filteredPaymentTypes()` in a Vue component.
  List<dynamic> getFilteredPaymentTypes({
    required List<dynamic> paymentTypeList,
    required String searchTerm,
    String? statusFilter,
    String? periodFilter,
  }) {
    return paymentTypeList.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final description = item['description']?.toString().toLowerCase() ?? '';
      final lower = searchTerm.toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          name.contains(lower) ||
          description.contains(lower);

      final matchesStatus =
          statusFilter == null ||
          (statusFilter == 'aktif' && item['status'] == 'aktif') ||
          (statusFilter == 'non_aktif' && item['status'] == 'non-aktif');

      final matchesPeriod =
          periodFilter == null ||
          (periodFilter == 'bulanan' && item['periode'] == 'bulanan') ||
          (periodFilter == 'tahunan' && item['periode'] == 'tahunan');

      return matchesSearch && matchesStatus && matchesPeriod;
    }).toList();
  }

  // ─── Cache key ─────────────────────────────────────────────────────────────

  /// Builds the local-cache key for the finance data.
  /// Returns null when filters/search are active (skip caching in those cases).
  ///
  /// Like `Cache::tags(['finance'])->key("finance_data_{yearId}")` in Laravel.
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

  // ─── Data calculation helpers ─────────────────────────────────────────────

  /// Groups [bills] into batch records keyed by payment_type + YYYY-MM.
  ///
  /// Used as a fallback when the dashboard API returns empty generated_batches.
  /// Like a Laravel Collection `groupBy()` + `map()` chain.
  List<dynamic> calculateBatchesFromBills(List<dynamic> bills) {
    final Map<String, Map<String, dynamic>> batches = {};

    for (var t in bills) {
      final type = t['payment_type'] ?? {};
      final typeId = (t['payment_type_id'] ?? type['id'])?.toString();
      final dueDateStr = t['due_date']?.toString() ?? '';

      if (typeId == null || dueDateStr.isEmpty) continue;

      final month =
          dueDateStr.length >= 7 ? dueDateStr.substring(0, 7) : 'Unknown';
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

  // ─── API — fetch methods ───────────────────────────────────────────────────

  /// Fetches all payment types from the API and normalises status/period values
  /// to lowercase Indonesian keys (`aktif`, `bulanan`, etc.).
  ///
  /// Returns [LoadPaymentTypesResult]; check `.error` to detect failure.
  /// The screen shows error snackbars itself so no BuildContext is needed here.
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

          // Normalise status → Indonesian
          if (newItem['status'] == 'active') {
            newItem['status'] = 'aktif';
          } else if (newItem['status'] == 'inactive') {
            newItem['status'] = 'non-aktif';
          }

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

  /// Fetches a page of bills using [FinanceService.getBillsPaginated].
  ///
  /// [resetPage] true = first page (screen should clear existing list first).
  /// Returns [LoadBillsResult]; check `.error` to detect failure.
  Future<LoadBillsResult> loadBills({
    required int page,
    required int perPage,
    String? statusFilter,
  }) async {
    try {
      final res = await FinanceService.getBillsPaginated(
        page: page,
        limit: perPage,
        status: statusFilter,
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

  /// Fetches the paginated pending-payment list.
  ///
  /// [loadMore] false (default) = first page, [loadMore] true = next page.
  /// [currentPage] should be the page the screen is currently on.
  ///
  /// Returns [LoadPendingPaymentsResult].
  Future<LoadPendingPaymentsResult> loadPendingPayments({
    required int page,
    required int perPage,
    bool loadMore = false,
  }) async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      String url =
          '/payments?status=pending&limit=$perPage&page=$page';
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

      // Flatten nested student/bill/payment_type into UI-friendly keys
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
          ErrorUtils.getFriendlyMessage(e));
    }
  }

  /// Fetches the finance dashboard summary stats.
  ///
  /// Falls back to deriving generated_batches from the bills list when the
  /// API returns an empty batches array.
  ///
  /// Returns [LoadDashboardResult].
  Future<LoadDashboardResult> loadDashboardData() async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      String url = '/finance/dashboard';
      if (academicYearId != null) {
        url += '?academic_year_id=$academicYearId';
      }

      final response = await ApiService().get(url);
      final data =
          Map<String, dynamic>.from(response is Map ? response : {});

      // Fallback: compute batches client-side if API returns none
      final List<dynamic> batches = data['generated_batches'] ?? [];
      if (batches.isEmpty) {
        final res = await FinanceService.getBillsPaginated(limit: 500);
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

  /// Fetches class list, student list, groups students by class, and loads all
  /// bills grouped by student.
  ///
  /// Returns [LoadClassDataResult].
  Future<LoadClassDataResult> loadClassData() async {
    try {
      final academicYearProvider = _ref.read(academicYearRiverpod);
      final academicYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      // ── Classes ───────────────────────────────────────────────────────────
      String classUrl = '/classes?limit=1000';
      if (academicYearId != null) {
        classUrl += '&academic_year_id=$academicYearId';
      }

      final classResponse = await ApiService().get(classUrl);
      final List<dynamic> classList;
      if (classResponse is Map && classResponse.containsKey('data')) {
        classList =
            classResponse['data'] is List ? classResponse['data'] : [];
      } else {
        classList = classResponse is List ? classResponse : [];
      }

      // ── Students ──────────────────────────────────────────────────────────
      final studentResponse =
          await ApiService().get('/students?limit=1000');
      final List<dynamic> allStudents;
      if (studentResponse is Map && studentResponse.containsKey('data')) {
        allStudents =
            studentResponse['data'] is List ? studentResponse['data'] : [];
      } else {
        allStudents = studentResponse is List ? studentResponse : [];
      }

      // Group students by class_id
      final Map<String, List<dynamic>> studentsByClass = {};
      for (var student in allStudents) {
        String? classId = student['class_id']?.toString();
        if (classId == null && student['class'] != null) {
          classId = student['class']['id']?.toString();
        }
        if (classId != null) {
          studentsByClass.putIfAbsent(classId, () => []).add(student);
        }
      }

      // ── Bills grouped by student ──────────────────────────────────────────
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

  /// Fetches all bills and groups them by student_id.
  ///
  /// Used by [loadClassData] and the ClassReportTab.
  Future<Map<String, List<dynamic>>> loadBillsForStudents() async {
    try {
      final billsResponse = await ApiService().get('/bills?limit=10000');

      List<dynamic> allBills = [];
      if (billsResponse is Map<String, dynamic> &&
          billsResponse.containsKey('data')) {
        allBills =
            billsResponse['data'] is List ? billsResponse['data'] : [];
      } else if (billsResponse is List) {
        allBills = billsResponse;
      }

      // Group by student_id — like SQL `GROUP BY student_id`
      final Map<String, List<dynamic>> billsByStudent = {};
      for (var bill in allBills) {
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

  // ─── API — write methods ───────────────────────────────────────────────────

  /// Deletes a payment type by its ID.
  ///
  /// Returns `null` on success, or an error message string on failure.
  /// The caller (screen) shows the confirmation dialog and success/error
  /// snackbars itself — no BuildContext needed here.
  Future<String?> deletePaymentType(Map<String, dynamic> paymentType) async {
    try {
      await ApiService().delete('/payment-type/${paymentType['id']}');
      return null;
    } catch (e) {
      AppLogger.error('finance', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }

  /// Deletes all generated bills for a given payment_type + month batch.
  ///
  /// Returns `null` on success, or an error message string on failure.
  /// The caller shows the confirmation dialog and snackbars itself.
  Future<String?> deleteGeneratedBills({
    required String paymentTypeId,
    required String month,
  }) async {
    try {
      await FinanceService.deleteBillsByType(paymentTypeId, month: month);
      return null;
    } catch (e) {
      AppLogger.error('finance', e);
      return ErrorUtils.getFriendlyMessage(e);
    }
  }
}
