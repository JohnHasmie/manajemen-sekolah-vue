// Result types for [FinanceDataLoader] data loading operations.

/// Result returned by [FinanceDataLoader.loadPaymentTypes].
class LoadPaymentTypesResult {
  final List<dynamic> paymentTypeList;
  final String? error;

  const LoadPaymentTypesResult({required this.paymentTypeList, this.error});

  LoadPaymentTypesResult.failure(String message)
    : paymentTypeList = const [],
      error = message;
}

/// Result returned by [FinanceDataLoader.loadBills].
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

/// Result returned by [FinanceDataLoader.loadPendingPayments].
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

/// Result returned by [FinanceDataLoader.loadDashboardData].
class LoadDashboardResult {
  final Map<String, dynamic> dashboardData;
  final String? error;

  const LoadDashboardResult({required this.dashboardData, this.error});

  LoadDashboardResult.failure(String message)
    : dashboardData = const {},
      error = message;
}

/// Result returned by [FinanceDataLoader.loadClassData].
class LoadClassDataResult {
  final List<dynamic> classList;
  final List<dynamic> studentList;
  final Map<String, List<dynamic>> studentsByClass;
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

/// Result returned by `AdminFinanceController.setPaymentTypeStatus`.
///
/// Carries the side-effect count (how many Bill rows the server
/// generated as a consequence of flipping to active) so the UI can show
/// a more useful toast than just "diaktifkan". Also surfaces the actual
/// backend error message so the admin sees the real problem instead of
/// the generic "Gagal memproses permintaan" fallback.
class SetStatusResult {
  /// Null on success, friendly Indonesian error string on failure.
  final String? error;

  /// Number of Bill rows the backend created during this transition.
  /// Zero when (a) the call failed, (b) the admin set status=inactive,
  /// or (c) every student already had a bill for the chosen month.
  final int billsGenerated;

  /// The `YYYY-MM` the activation applied to, when the caller specified
  /// one. Null when the backend used today's month as the default.
  final String? monthApplied;

  const SetStatusResult({
    required this.error,
    required this.billsGenerated,
    required this.monthApplied,
  });

  bool get isSuccess => error == null;
}
