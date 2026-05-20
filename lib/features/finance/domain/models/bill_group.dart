// Aggregated Tagihan row — one (payment_type × class × academic_year)
// bucket from the admin Operasional Keuangan hub's grouped list.
//
// Backed by `GET /finance/bill-groups` (see
// FinanceRepository::getBillGroups for the server-side aggregation).
// The hub used to fetch every individual bill and group them in
// Dart; the model + endpoint pair lets us push that GROUP BY to
// Postgres so the hub payload only carries the rows it renders.
//
// The per-student bills inside the bucket aren't carried here — the
// detail screen calls /bills?payment_type_id=X&class_id=Y when the
// admin taps into the bucket. Lazy fan-out keeps cold-start traffic
// small even on schools with thousands of bills.
library;

class BillGroup {
  final String paymentTypeId;
  final String paymentTypeName;
  final String classId;
  final String className;

  /// Academic year name as stored on `academic_years.name` (typically
  /// "2024/2025"). May be null if the bill row was orphaned from its
  /// AY — render the title without a year suffix in that case.
  final String? yearLabel;

  final int totalCount;
  final int paidCount;
  final int unpaidCount;
  final int overdueCount;

  final double totalAmount;
  final double paidAmount;

  const BillGroup({
    required this.paymentTypeId,
    required this.paymentTypeName,
    required this.classId,
    required this.className,
    required this.yearLabel,
    required this.totalCount,
    required this.paidCount,
    required this.unpaidCount,
    required this.overdueCount,
    required this.totalAmount,
    required this.paidAmount,
  });

  factory BillGroup.fromJson(Map<String, dynamic> json) {
    double parseAmount(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int parseCount(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return BillGroup(
      paymentTypeId: (json['payment_type_id'] ?? '').toString(),
      paymentTypeName: (json['payment_type_name'] ?? '').toString(),
      classId: (json['class_id'] ?? '').toString(),
      className: (json['class_name'] ?? '').toString(),
      yearLabel: json['year_label']?.toString(),
      totalCount: parseCount(json['total_count']),
      paidCount: parseCount(json['paid_count']),
      unpaidCount: parseCount(json['unpaid_count']),
      overdueCount: parseCount(json['overdue_count']),
      totalAmount: parseAmount(json['total_amount']),
      paidAmount: parseAmount(json['paid_amount']),
    );
  }

  /// Human-readable card title — "Uang Pangkal · 7A (2024)".
  /// Falls back to "Tagihan" when the payment type name is missing.
  String get title {
    final base = paymentTypeName.trim().isEmpty
        ? 'Tagihan'
        : paymentTypeName.trim();
    final cls = className.trim();
    final year = (yearLabel ?? '').trim();
    final head = cls.isEmpty ? base : '$base · $cls';
    return year.isEmpty ? head : '$head ($year)';
  }
}