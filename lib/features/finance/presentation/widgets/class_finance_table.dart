// Scrollable finance report table for a single class.
// Displays a frozen student-name column on the left and horizontally-scrollable
// month/payment-type columns on the right — like a pivot table in Laravel reports.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/bill_status_cell.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// A pure display widget that renders the class finance pivot table.
///
/// All data is passed in as constructor params (like Vue props) — no internal
/// state. Callbacks replace direct setState calls so the parent screen stays
/// the single source of truth.
///
/// Constructor params:
/// - [students]         – list of student maps (id, name, student_number)
/// - [billsByStudent]   – map of student_id -> their bill list
/// - [monthGroups]      – column structure produced by _buildMonthGroups()
/// - [searchQuery]      – already-lowercased search string
/// - [selectedPaymentTypeId] – active payment-type filter (null = all)
/// - [selectedMonthKey] – active month filter (null = all)
/// - [selectedStatus]   – 'Semua' | 'Lunas' | 'Belum Dibayar' | 'Belum Diverifikasi'
/// - [onBillTap]        – called when a bill cell is tapped (parent opens options sheet)
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

  // ---------------------------------------------------------------------------
  // Status helper — mirrors _checkStatusMatch() in the parent screen.
  // Like a Laravel scope: filters bills by their payment status.
  // ---------------------------------------------------------------------------
  bool _checkStatusMatch(dynamic bill, String filter) {
    if (filter == 'Semua') return true;
    final String status = bill['status'] ?? 'pending';
    final bool isPaid = status == 'verified';

    if (filter == 'Lunas') return isPaid;

    if (!isPaid) {
      bool hasPendingPayment = false;
      if (bill['payments'] != null) {
        for (var p in bill['payments']) {
          if (p['status'] == 'pending') hasPendingPayment = true;
        }
      }
      if (filter == 'Belum Dibayar') return !hasPendingPayment;
      if (filter == 'Belum Diverifikasi') return hasPendingPayment;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------------
    // 1. Filter students by search query and status.
    //    Like Laravel's ->filter() chained on a Collection.
    // ------------------------------------------------------------------
    final List<dynamic> filteredStudents = students.where((s) {
      if (searchQuery.isNotEmpty &&
          !s['name'].toString().toLowerCase().contains(searchQuery)) {
        return false;
      }

      if (selectedStatus != 'Semua') {
        bool match = false;
        final String studentId = s['id'].toString();
        final bills = billsByStudent[studentId] ?? [];
        for (var bill in bills) {
          if (_checkStatusMatch(bill, selectedStatus)) {
            match = true;
            break;
          }
        }
        return match;
      }
      return true;
    }).toList();

    // ------------------------------------------------------------------
    // 2. Filter month groups / payment-type columns.
    // ------------------------------------------------------------------
    final List<MonthGroup> filteredGroups = monthGroups
        .where((m) {
          if (selectedMonthKey != null && m.monthKey != selectedMonthKey) {
            return false;
          }
          return true;
        })
        .map((m) {
          if (selectedPaymentTypeId == null) return m;
          final filteredTypes = m.paymentTypes
              .where((p) => p.id == selectedPaymentTypeId)
              .toList();
          return MonthGroup(
            monthKey: m.monthKey,
            monthName: m.monthName,
            paymentTypes: filteredTypes,
          );
        })
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        double totalWidth = constraints.maxWidth;
        if (totalWidth.isInfinite) {
          totalWidth = MediaQuery.of(context).size.width;
        }

        double scrollableWidth = totalWidth - 150 - 5;
        if (scrollableWidth < 0) scrollableWidth = 0;

        // ------------------------------------------------------------------
        // 3. Fixed left column — student names (frozen, does not scroll).
        //    Like a sticky first column in an HTML table.
        // ------------------------------------------------------------------
        final List<Widget> fixedColumnWidgets = [];

        // Header cell "Nama Siswa"
        fixedColumnWidgets.add(
          Container(
            width: 150,
            height: 60,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: ColorUtils.slate300),
                bottom: BorderSide(color: ColorUtils.slate300),
              ),
              color: ColorUtils.slate100,
            ),
            child: Text(
              'Nama Siswa',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate700,
              ),
            ),
          ),
        );

        // Data rows — one per student
        for (var i = 0; i < filteredStudents.length; i++) {
          final student = filteredStudents[i];
          fixedColumnWidgets.add(
            Container(
              width: 150,
              height: 50,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: ColorUtils.slate300),
                  bottom: BorderSide(color: ColorUtils.slate200),
                ),
                color: i % 2 == 0 ? Colors.white : ColorUtils.slate50,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'] ?? '-',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (student['student_number'] != null)
                    Text(
                      student['student_number'],
                      style: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        // ------------------------------------------------------------------
        // 4. Build scrollable header rows (month + payment-type labels).
        // ------------------------------------------------------------------
        final List<Widget> monthHeaderWidgets = [];
        final List<Widget> typeHeaderWidgets = [];

        for (var group in filteredGroups) {
          final int colCount =
              group.paymentTypes.isNotEmpty ? group.paymentTypes.length : 1;
          final double groupWidth = colCount * 100.0;

          // Month header spans all its payment-type sub-columns
          monthHeaderWidgets.add(
            Container(
              width: groupWidth,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: ColorUtils.slate300),
                  bottom: BorderSide(color: ColorUtils.slate300),
                ),
                color: ColorUtils.corporateBlue600,
              ),
              child: Text(
                group.monthName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          );

          // Payment-type sub-headers (or placeholder when month has no types)
          if (group.paymentTypes.isEmpty) {
            typeHeaderWidgets.add(
              Container(
                width: 100,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: ColorUtils.slate300),
                    bottom: BorderSide(color: ColorUtils.slate300),
                  ),
                  color: ColorUtils.slate100,
                ),
                child: Text(
                  '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate400,
                  ),
                ),
              ),
            );
          } else {
            for (var type in group.paymentTypes) {
              typeHeaderWidgets.add(
                Container(
                  width: 100,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: ColorUtils.slate300),
                      bottom: BorderSide(color: ColorUtils.slate300),
                    ),
                    color: ColorUtils.slate100,
                  ),
                  child: Text(
                    type.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ColorUtils.slate600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }
          }
        }

        final Widget headerRow = Column(
          children: [
            Row(children: monthHeaderWidgets),
            Row(children: typeHeaderWidgets),
          ],
        );

        // ------------------------------------------------------------------
        // 5. Build data rows — one row per student, one cell per type/month.
        //    Like a nested foreach over $students and $monthGroups in Blade.
        // ------------------------------------------------------------------
        final List<Widget> dataRows = [];
        for (var i = 0; i < filteredStudents.length; i++) {
          final student = filteredStudents[i];
          final String studentId = student['id'].toString();
          final studentBills = billsByStudent[studentId] ?? [];

          final List<Widget> rowCells = [];

          for (var group in filteredGroups) {
            if (group.paymentTypes.isEmpty) {
              // Empty placeholder cell for months with no active payment types
              rowCells.add(
                Container(
                  width: 100,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: ColorUtils.slate200),
                      bottom: BorderSide(color: ColorUtils.slate200),
                    ),
                    color: i % 2 == 0 ? Colors.white : ColorUtils.slate50,
                  ),
                  child: const SizedBox(),
                ),
              );
            } else {
              for (var type in group.paymentTypes) {
                // Find bill matching this student + month + payment type
                final bill = studentBills.firstWhere((b) {
                  if (b['payment_type_id'].toString() != type.id) return false;
                  if (b['due_date'] == null) return false;
                  try {
                    final DateTime d = DateTime.parse(b['due_date']);
                    final String k =
                        "${d.year}-${d.month.toString().padLeft(2, '0')}";
                    return k == group.monthKey;
                  } catch (_) {
                    return false;
                  }
                }, orElse: () => null);

                rowCells.add(
                  Container(
                    width: 100,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: ColorUtils.slate200),
                        bottom: BorderSide(color: ColorUtils.slate200),
                      ),
                      color: i % 2 == 0 ? Colors.white : ColorUtils.slate50,
                    ),
                    child: BillStatusCell(
                      bill: bill,
                      onTap: () => onBillTap(bill),
                    ),
                  ),
                );
              }
            }
          }
          dataRows.add(Row(children: rowCells));
        }

        // ------------------------------------------------------------------
        // 6. Combine frozen column + horizontally-scrollable area.
        //    Like CSS position:sticky on the first table column.
        // ------------------------------------------------------------------
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Frozen student-name column with a subtle right shadow
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.05),
                    offset: Offset(4, 0),
                    blurRadius: 5,
                    spreadRadius: 0,
                  ),
                ],
              ),
              width: 150,
              child: Column(children: fixedColumnWidgets),
            ),

            // Horizontally-scrollable bill data columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerRow,
                    Column(children: dataRows),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
