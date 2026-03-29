// Value objects for the class finance report table.
// Like Laravel Eloquent models but read-only — purely for structuring
// column/month data passed down from ClassFinanceReportScreen to ClassFinanceTable.

/// Groups payment-type columns under a single calendar month.
///
/// In Laravel terms, this is like a Collection groupBy('month') result —
/// one [MonthGroup] per month, each holding its active [paymentTypes].
class MonthGroup {
  final String monthKey; // e.g. '2024-07'
  final String monthName; // e.g. 'Juli'
  final List<PaymentTypeColumn> paymentTypes;

  MonthGroup({
    required this.monthKey,
    required this.monthName,
    required this.paymentTypes,
  });
}

/// A single payment-type column within a [MonthGroup].
///
/// Like a pivot table entry — links a payment type id/name to a month.
class PaymentTypeColumn {
  final String id;
  final String name;

  PaymentTypeColumn({required this.id, required this.name});
}
