// Per-kelas Laporan Keuangan matrix — C1 mockup, single-jenis design.
//
// Built from scratch to match `_design/admin_keuangan_redesign.html`
// Frame C1 exactly:
//   • Header band — navy bg, white labels:  "Siswa | Jul | Ags | …"
//   • Sticky student column on the left  (name + NIS in 2 lines)
//   • Right side scrolls horizontally when there are more months than
//     fit the viewport (typical for SPP × 6 months)
//   • Each cell is an icon pill (✓ lunas, ✕ belum, ! tempo, ⏳ pending,
//     – belum berlaku) tinted by status; tapping fires `onBillTap`
//
// Assumes a SINGLE jenis is active upstream — the C1 design has no
// jenis sub-headers because the [ClassFinanceJenisTabs] strip in the
// host screen narrows the view to one jenis at a time. When the
// screen passes `monthsForJenis` containing more than one jenis's
// worth of columns we still render them in order, but the matrix
// doesn't add a secondary header — that's the per-siswa card view's
// job.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class ClassFinanceMatrix extends StatelessWidget {
  final List<dynamic> students;
  final Map<String, List<dynamic>> billsByStudent;
  final List<MonthGroup> monthGroups;
  final String searchQuery;
  final String? selectedPaymentTypeId;
  final String? selectedMonthKey;
  final String selectedStatus;
  final Color primaryColor;
  final void Function(dynamic bill) onBillTap;

  const ClassFinanceMatrix({
    super.key,
    required this.students,
    required this.billsByStudent,
    required this.monthGroups,
    required this.searchQuery,
    required this.selectedPaymentTypeId,
    required this.selectedMonthKey,
    required this.selectedStatus,
    required this.primaryColor,
    required this.onBillTap,
  });

  // ── Layout constants ──────────────────────────────────────────────
  static const double _leftWidth = 116.0;
  static const double _cellWidth = 76.0;
  static const double _headerHeight = 38.0;
  static const double _rowHeight = 52.0;

  bool _isPaid(dynamic bill) {
    final s = (bill['status'] ?? 'pending').toString();
    return s == 'paid' || s == 'verified' || s == 'success';
  }

  bool _isOverdue(dynamic bill) {
    if (_isPaid(bill)) return false;
    final due = bill['due_date'];
    if (due == null) return false;
    final d = DateTime.tryParse(due.toString());
    if (d == null) return false;
    return d.isBefore(DateTime.now());
  }

  bool _hasPendingPayment(dynamic bill) {
    final payments = bill['payments'];
    if (payments is! List) return false;
    for (final p in payments) {
      if (p is Map && (p['status'] ?? '').toString() == 'pending') return true;
    }
    return false;
  }

  _CellTone _tone(dynamic bill) {
    if (bill == null) return _CellTone.dash;
    if (_isPaid(bill)) return _CellTone.lunas;
    if (_isOverdue(bill)) return _CellTone.tempo;
    if (_hasPendingPayment(bill)) return _CellTone.pending;
    return _CellTone.belum;
  }

  /// Effective month list — narrows by the active jenis tab + the
  /// (optional) bulan filter from the consolidated sheet.
  List<_MonthCol> _columns() {
    final out = <_MonthCol>[];
    for (final m in monthGroups) {
      if (selectedMonthKey != null && m.monthKey != selectedMonthKey) {
        continue;
      }
      for (final p in m.paymentTypes) {
        if (selectedPaymentTypeId != null && p.id != selectedPaymentTypeId) {
          continue;
        }
        out.add(
          _MonthCol(
            monthKey: m.monthKey,
            monthName: m.monthName,
            jenisId: p.id,
            jenisName: p.name,
          ),
        );
      }
    }
    return out;
  }

  bool _statusMatches(dynamic bill) {
    if (selectedStatus == 'Semua') return true;
    if (selectedStatus == 'Lunas') return _isPaid(bill);
    if (selectedStatus == 'Belum Dibayar') {
      return !_isPaid(bill) && !_hasPendingPayment(bill);
    }
    if (selectedStatus == 'Belum Diverifikasi') {
      return !_isPaid(bill) && _hasPendingPayment(bill);
    }
    return true;
  }

  List<dynamic> _filterStudents(List<_MonthCol> cols) {
    return students.where((s) {
      if (searchQuery.isNotEmpty &&
          !s['name'].toString().toLowerCase().contains(searchQuery)) {
        return false;
      }
      if (selectedStatus != 'Semua') {
        final id = s['id'].toString();
        final bills = billsByStudent[id] ?? const [];
        for (final c in cols) {
          final bill = _findBill(bills, c);
          if (bill != null && _statusMatches(bill)) return true;
        }
        return false;
      }
      return true;
    }).toList();
  }

  dynamic _findBill(List<dynamic> bills, _MonthCol c) {
    for (final bill in bills) {
      if (bill['payment_type_id']?.toString() != c.jenisId) continue;
      final due = bill['due_date'];
      if (due == null) continue;
      final d = DateTime.tryParse(due.toString());
      if (d == null) continue;
      final k = "${d.year}-${d.month.toString().padLeft(2, '0')}";
      if (k == c.monthKey) return bill;
    }
    return null;
  }

  String _shortMonth(String full) {
    if (full.length <= 3) return full;
    return full.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final cols = _columns();
    final rows = _filterStudents(cols);
    final scrollCtrl = ScrollController();

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Tidak ada siswa cocok dengan pencarian.',
            style: TextStyle(
              fontSize: 12.5,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Wrap the matrix in a vertical SingleChildScrollView so it can
    // exceed the parent's bounded height (the screen hosts us inside
    // an Expanded). Without this, a class with > ~10 students would
    // overflow the viewport and Flutter's debug layer prints the
    // "BOTTOM OVERFLOWED BY N PIXELS" warning. The student column
    // and the month columns share the same Column-of-rows layout, so
    // a single outer vertical scroll keeps both in sync without
    // needing two synchronised scroll controllers.
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            // ── Sticky student column ─────────────────────────────────
            SizedBox(
              width: _leftWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StudentColHeader(primaryColor: primaryColor),
                  for (var i = 0; i < rows.length; i++)
                    _StudentColCell(
                      student: Student.fromJson(
                        rows[i] as Map<String, dynamic>,
                      ),
                      zebra: i.isOdd,
                    ),
                ],
              ),
            ),
            // ── Scrollable month columns ──────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row — navy band with month names.
                    Container(
                      height: _headerHeight,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate300),
                        ),
                      ),
                      child: Row(
                        children: [
                          for (final c in cols)
                            SizedBox(
                              width: _cellWidth,
                              child: Center(
                                child: Text(
                                  _shortMonth(c.monthName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Cell rows.
                    for (var i = 0; i < rows.length; i++)
                      Container(
                        height: _rowHeight,
                        decoration: BoxDecoration(
                          color: i.isOdd ? ColorUtils.slate50 : Colors.white,
                          border: Border(
                            bottom: BorderSide(color: ColorUtils.slate100),
                          ),
                        ),
                        child: Row(
                          children: [
                            for (final c in cols)
                              _MatrixCell(
                                bill: _findBill(
                                  billsByStudent[(rows[i]
                                              as Map<String, dynamic>)['id']
                                          .toString()] ??
                                      const [],
                                  c,
                                ),
                                toneFor: _tone,
                                onTap: onBillTap,
                                width: _cellWidth,
                                height: _rowHeight,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Internals ───────────────────────────────────────────────────────

class _MonthCol {
  final String monthKey;
  final String monthName;
  final String jenisId;
  final String jenisName;
  const _MonthCol({
    required this.monthKey,
    required this.monthName,
    required this.jenisId,
    required this.jenisName,
  });
}

enum _CellTone { lunas, belum, tempo, pending, dash }

class _StudentColHeader extends StatelessWidget {
  final Color primaryColor;
  const _StudentColHeader({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ClassFinanceMatrix._headerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: primaryColor,
        border: Border(
          right: BorderSide(color: ColorUtils.slate300),
          bottom: BorderSide(color: ColorUtils.slate300),
        ),
      ),
      child: const Text(
        'Siswa',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StudentColCell extends StatelessWidget {
  final Student student;
  final bool zebra;
  const _StudentColCell({required this.student, required this.zebra});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ClassFinanceMatrix._rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: zebra ? ColorUtils.slate50 : Colors.white,
        border: Border(
          right: BorderSide(color: ColorUtils.slate200),
          bottom: BorderSide(color: ColorUtils.slate100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            student.name.isNotEmpty ? student.name : '-',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (student.studentNumber.isNotEmpty)
            Text(
              student.studentNumber,
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  final dynamic bill;
  final _CellTone Function(dynamic bill) toneFor;
  final void Function(dynamic bill) onTap;
  final double width;
  final double height;

  const _MatrixCell({
    required this.bill,
    required this.toneFor,
    required this.onTap,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(bill);
    final (bg, fg, icon, label) = switch (tone) {
      _CellTone.lunas => (
        ColorUtils.success600.withValues(alpha: 0.12),
        ColorUtils.success600,
        Icons.check_rounded,
        '✓',
      ),
      _CellTone.belum => (
        ColorUtils.error600.withValues(alpha: 0.10),
        ColorUtils.error600,
        Icons.close_rounded,
        '✕',
      ),
      _CellTone.tempo => (
        ColorUtils.warning600.withValues(alpha: 0.14),
        ColorUtils.warning600,
        Icons.priority_high_rounded,
        '!',
      ),
      _CellTone.pending => (
        ColorUtils.corporateBlue600.withValues(alpha: 0.12),
        ColorUtils.corporateBlue600,
        Icons.hourglass_top_rounded,
        '⏳',
      ),
      _CellTone.dash => (
        ColorUtils.slate100,
        ColorUtils.slate400,
        Icons.remove_rounded,
        '–',
      ),
    };
    // Suppress unused-element warning for `label` — kept available
    // for future text-only modes (a11y, low-icon density on small
    // screens) without changing the public widget API.
    // ignore: unused_local_variable
    final _ = label;
    final disabled = tone == _CellTone.dash;

    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled || bill == null ? null : () => onTap(bill),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fg.withValues(alpha: 0.30)),
              ),
              child: Icon(icon, size: 14, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
