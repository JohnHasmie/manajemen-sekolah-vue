// Controller for AdminFinanceScreen (admin_finance_screen.dart).
//
// Like a Laravel Controller class extracted from a fat Blade/route closure,
// or a Vue Composition API `setup()` pulled into its own composable.
//
// Holds orchestration logic, delegating data-fetching to [FinanceDataLoader]
// and formatting to [PaymentTypesFormatter]. Preserves all public methods
// from the original controller.
//
// Usage in screen:
//   final ctrl = ref.read(adminFinanceControllerProvider);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/finance/data/finance_service.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/'
    'finance_data_loader.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/'
    'finance_data_results.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/'
    'payment_types_formatter.dart';

// Re-export result types from results for backward compatibility
export 'package:manajemensekolah/features/finance/presentation/controllers/'
    'finance_data_results.dart'
    show
        LoadPaymentTypesResult,
        LoadBillsResult,
        LoadPendingPaymentsResult,
        LoadDashboardResult,
        LoadClassDataResult;

/// Riverpod provider for [AdminFinanceController].
/// Use `ref.read(adminFinanceControllerProvider)` from the screen.
final adminFinanceControllerProvider = Provider<AdminFinanceController>((ref) {
  return AdminFinanceController(ref);
});

/// Main controller orchestrating finance data and presentation logic.
///
/// Delegates:
/// - **Data loading**: [FinanceDataLoader]
/// - **Formatting**: [PaymentTypesFormatter]
/// - **Write operations**: Direct via API services
///
/// Public API remains unchanged from original 701-line controller.
class AdminFinanceController {
  final Ref _ref;
  late final FinanceDataLoader _loader;
  late final PaymentTypesFormatter _formatter;

  AdminFinanceController(this._ref) {
    _loader = FinanceDataLoader(_ref);
    _formatter = PaymentTypesFormatter(_ref);
  }

  // ─── Formatting (delegated) ─────────────────────────────────────────────

  /// Returns the primary theme color for the admin role.
  Color getPrimaryColor() {
    return _formatter.getPrimaryColor();
  }

  /// Returns the card gradient for admin finance UI elements.
  LinearGradient getCardGradient() {
    return _formatter.getCardGradient();
  }

  /// Formats a raw numeric amount into an Indonesian Rupiah string.
  String formatCurrency(dynamic amount) {
    return _formatter.formatCurrency(amount);
  }

  /// Converts a `YYYY-MM` string into a human-readable Indonesian month.
  String formatMonth(String? monthStr) {
    return _formatter.formatMonth(monthStr);
  }

  /// Parses a JSON-encoded or Map goal/target object into a plain Dart Map.
  Map<String, dynamic> parseGoal(dynamic goalData) {
    return _formatter.parseGoal(goalData);
  }

  /// Extracts the human-readable goal description from raw goal data.
  String getGoalDescription(dynamic goalData) {
    return _formatter.getGoalDescription(goalData);
  }

  /// Returns the translated period label for a payment type period string.
  String getTranslatedPeriod(String? period) {
    return _formatter.getTranslatedPeriod(period);
  }

  /// Filters [paymentTypeList] by [searchTerm], [statusFilter], and
  /// [periodFilter]. Pure function — no side effects.
  List<dynamic> getFilteredPaymentTypes({
    required List<dynamic> paymentTypeList,
    required String searchTerm,
    String? statusFilter,
    String? periodFilter,
  }) {
    return _formatter.getFilteredPaymentTypes(
      paymentTypeList: paymentTypeList,
      searchTerm: searchTerm,
      statusFilter: statusFilter,
      periodFilter: periodFilter,
    );
  }

  // ─── Cache key (delegated) ──────────────────────────────────────────────

  /// Builds the local-cache key for the finance data.
  /// Returns null when filters/search are active (skip caching).
  String? buildFinanceCacheKey({
    String? selectedStatusFilter,
    String? selectedPeriodFilter,
    String searchText = '',
  }) {
    return _loader.buildFinanceCacheKey(
      selectedStatusFilter: selectedStatusFilter,
      selectedPeriodFilter: selectedPeriodFilter,
      searchText: searchText,
    );
  }

  // ─── Data calculation (delegated) ────────────────────────────────────────

  /// Groups [bills] into batch records keyed by payment_type + YYYY-MM.
  List<dynamic> calculateBatchesFromBills(List<dynamic> bills) {
    return _loader.calculateBatchesFromBills(bills);
  }

  // ─── Data loading (delegated) ────────────────────────────────────────────

  /// Fetches all payment types from the API and normalises values.
  Future<LoadPaymentTypesResult> loadPaymentTypes() async {
    return _loader.loadPaymentTypes();
  }

  /// Fetches a page of bills using [FinanceService.getBillsPaginated].
  Future<LoadBillsResult> loadBills({
    required int page,
    required int perPage,
    String? statusFilter,
  }) async {
    return _loader.loadBills(
      page: page,
      perPage: perPage,
      statusFilter: statusFilter,
    );
  }

  /// Fetches the paginated pending-payment list.
  Future<LoadPendingPaymentsResult> loadPendingPayments({
    required int page,
    required int perPage,
    bool loadMore = false,
  }) async {
    return _loader.loadPendingPayments(
      page: page,
      perPage: perPage,
      loadMore: loadMore,
    );
  }

  /// Fetches the finance dashboard summary stats.
  Future<LoadDashboardResult> loadDashboardData() async {
    return _loader.loadDashboardData();
  }

  /// Fetches class list, student list, groups students by class, loads bills.
  Future<LoadClassDataResult> loadClassData() async {
    return _loader.loadClassData();
  }

  /// Fetches all bills and groups them by student_id.
  Future<Map<String, List<dynamic>>> loadBillsForStudents() async {
    return _loader.loadBillsForStudents();
  }

  // ─── Write operations ───────────────────────────────────────────────────

  /// Deletes a payment type by its ID.
  /// Returns `null` on success, or an error message string on failure.
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
  /// Returns `null` on success, or an error message string on failure.
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
