// Scrollable finance report table for a single class.
//
// Frozen student-name column on the left; horizontally scrollable payment-
// type columns on the right, grouped into a secondary header of calendar
// months (like a pivot table).
//
// Layout is delegated to the shared `FrozenColumnTable` scaffold in
// `lib/core/widgets/frozen_column_table.dart`. This widget is responsible
// for:
//   • Filtering students/groups by search, month, status, and payment type
//   • Mapping month-groups → the secondary header row
//   • Building per-cell bill lookups and delegating render to BillStatusCell
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/frozen_column_table.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/bill_status_cell.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class ClassFinanceTable extends StatelessWidget {
  final List<dynamic> students;
  final Map<String, List<dynamic>> billsByStudent;
  final List<MonthGroup> monthGroups;
  final String searchQuery;
  final String? selectedPaymentTypeId;
  final String? selectedMonthKey;
  final String selectedStatus;
  final void Function(dynamic bill) onBillTap;

  const ClassFinanceTable({
    super.key,
    required this.students,
    required this.billsByStudent,
    required this.monthGroups,
    required this.searchQuery,
    required this.selectedPaymentTypeId,
    required this.selectedMonthKey,
    required this.selectedStatus,
    required this.onBillTap,
  });

  // ── Layout constants ──────────────────────────────────────────────────────
  static const double _leftWidth = 150.0;
  static const double _cellWidth = 100.0;
  static const double _monthHeaderHeight = 30.0;
  static const double _typeHeaderHeight = 30.0;
  static const double _rowHeight = 50.0;

  // ── Filtering ────────────────────────────────────────────────────────────

  /// Mirrors Laravel scope patterns for bill-status matching.
  ///
  /// Backend vocabulary for "fully paid" diverges across surfaces:
  /// `CreatePaymentAction` writes `'paid'`, older admin flows write
  /// `'verified'`, some legacy seeds use `'success'`. We accept all
  /// three here to match [BillStatusCell]'s display logic.
  bool _statusMatches(dynamic bill, String filter) {
    if (filter == 'Semua') return true;
    final String status = bill['status'] ?? 'pending';
    final bool isPaid =
        status == 'paid' || status == 'verified' || status == 'success';

    if (filter == 'Lunas') return isPaid;

    if (!isPaid) {
      bool hasPending = false;
      if (bill['payments'] != null) {
        for (final p in bill['payments']) {
          if (p['status'] == 'pending') hasPending = true;
        }
      }
      if (filter == 'Belum Dibayar') return !hasPending;
      if (filter == 'Belum Diverifikasi') return hasPending;
    }
    return false;
  }

  List<dynamic> _filterStudents() {
    return students.where((s) {
      if (searchQuery.isNotEmpty &&
          !s['name'].toString().toLowerCase().contains(searchQuery)) {
        return false;
      }
      if (selectedStatus != 'Semua') {
        final studentId = s['id'].toString();
        final bills = billsByStudent[studentId] ?? [];
        for (final bill in bills) {
          if (_statusMatches(bill, selectedStatus)) return true;
        }
        return false;
      }
      return true;
    }).toList();
  }

  List<MonthGroup> _filterGroups() {
    return monthGroups
        .where(
          (m) => selectedMonthKey == null || m.monthKey == selectedMonthKey,
        )
        .map((m) {
          if (selectedPaymentTypeId == null) return m;
          final filtered = m.paymentTypes
              .where((p) => p.id == selectedPaymentTypeId)
              .toList();
          return MonthGroup(
            monthKey: m.monthKey,
            monthName: m.monthName,
            paymentTypes: filtered,
          );
        })
        .toList();
  }

  /// Number of right-side columns occupied by [group] — one per payment
  /// type, or a single placeholder if the month has none.
  int _columnsFor(MonthGroup group) =>
      group.paymentTypes.isEmpty ? 1 : group.paymentTypes.length;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filterStudents();
    final groups = _filterGroups();

    return FrozenColumnTable(
      rowCount: filtered.length,
      leftColumns: [
        FrozenTableColumn(
          width: _leftWidth,
          header: _buildLeftHeader(),
          cellBuilder: (i) => _buildLeftCell(filtered[i], i),
        ),
      ],
      leftSecondaryHeader: _buildLeftSecondaryHeader(),
      rightColumns: _buildRightColumns(groups, filtered),
      rightSecondaryHeader: _buildRightSecondaryHeader(groups),
      headerHeight: _typeHeaderHeight,
      secondaryHeaderHeight: _monthHeaderHeight,
      rowHeight: _rowHeight,
      rowDecorationBuilder: _rowDecoration,
      showLeftColumnShadow: true,
    );
  }

  // ── Left column ──────────────────────────────────────────────────────────

  /// Spacer above "Nama Siswa", visually aligned with the month-group
  /// banner row on the right. Matches the blue banner's background so the
  /// header reads as a single 2-row block.
  Widget _buildLeftSecondaryHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.corporateBlue600,
        border: Border(
          right: BorderSide(color: ColorUtils.slate300),
          bottom: BorderSide(color: ColorUtils.slate300),
        ),
      ),
    );
  }

  Widget _buildLeftHeader() {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        border: Border(
          right: BorderSide(color: ColorUtils.slate300),
          bottom: BorderSide(color: ColorUtils.slate300),
        ),
      ),
      child: Text(
        'Nama Siswa',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: ColorUtils.slate700,
        ),
      ),
    );
  }

  Widget _buildLeftCell(dynamic student, int index) {
    final model = Student.fromJson(student as Map<String, dynamic>);
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ColorUtils.slate300)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            model.name.isNotEmpty ? model.name : '-',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          if (model.studentNumber.isNotEmpty)
            Text(
              model.studentNumber,
              style: TextStyle(color: ColorUtils.slate400, fontSize: 11),
            ),
        ],
      ),
    );
  }

  // ── Right columns ────────────────────────────────────────────────────────

  List<FrozenTableColumn> _buildRightColumns(
    List<MonthGroup> groups,
    List<dynamic> filteredStudents,
  ) {
    final cols = <FrozenTableColumn>[];
    for (final group in groups) {
      if (group.paymentTypes.isEmpty) {
        cols.add(
          FrozenTableColumn(
            width: _cellWidth,
            header: _buildTypeHeader('-', faded: true),
            cellBuilder: (i) => _buildCell(null),
          ),
        );
      } else {
        for (final type in group.paymentTypes) {
          cols.add(
            FrozenTableColumn(
              width: _cellWidth,
              header: _buildTypeHeader(type.name),
              cellBuilder: (i) =>
                  _buildCell(_findBill(filteredStudents[i], group, type)),
            ),
          );
        }
      }
    }
    return cols;
  }

  /// Secondary (month-group) header: one banner per month, each spanning
  /// the total width of its payment-type columns below.
  Widget _buildRightSecondaryHeader(List<MonthGroup> groups) {
    return Row(
      children: [
        for (final group in groups)
          Container(
            width: _columnsFor(group) * _cellWidth,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600,
              border: Border(
                right: BorderSide(color: ColorUtils.slate300),
                bottom: BorderSide(color: ColorUtils.slate300),
              ),
            ),
            child: Text(
              group.monthName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTypeHeader(String label, {bool faded = false}) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        border: Border(
          right: BorderSide(color: ColorUtils.slate300),
          bottom: BorderSide(color: ColorUtils.slate300),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: faded ? ColorUtils.slate400 : ColorUtils.slate600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Cell ─────────────────────────────────────────────────────────────────

  Widget _buildCell(dynamic bill) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ColorUtils.slate200)),
      ),
      child: bill == null
          ? const SizedBox()
          : BillStatusCell(bill: bill, onTap: () => onBillTap(bill)),
    );
  }

  /// Find a bill for the given student × month × payment type, or null.
  dynamic _findBill(dynamic student, MonthGroup group, PaymentTypeColumn type) {
    final studentId = Student.fromJson(student as Map<String, dynamic>).id;
    final studentBills = billsByStudent[studentId] ?? const [];
    for (final b in studentBills) {
      if (b['payment_type_id'].toString() != type.id) continue;
      if (b['due_date'] == null) continue;
      try {
        final d = DateTime.parse(b['due_date']);
        final k = "${d.year}-${d.month.toString().padLeft(2, '0')}";
        if (k == group.monthKey) return b;
      } catch (_) {
        // skip malformed dates
      }
    }
    return null;
  }

  // ── Row decoration ───────────────────────────────────────────────────────

  BoxDecoration _rowDecoration(int rowIndex) {
    return BoxDecoration(
      color: rowIndex.isEven ? Colors.white : ColorUtils.slate50,
      border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
    );
  }
}
