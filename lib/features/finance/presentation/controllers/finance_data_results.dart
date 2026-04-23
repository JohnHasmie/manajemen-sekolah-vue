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
