// Per-siswa card view for the class finance report.
//
// Toggleable alternative to the [ClassFinanceTable] matrix — same
// data, vertical cards instead of a horizontally-scrolling grid.
// Each card shows the student's avatar, NIS, lunas ratio, and a
// row of small icon pills for each (jenis × month) bucket that the
// matrix would render as a cell.
//
// Friendlier on narrow phones than the matrix, which forces
// horizontal scroll past 2-3 columns. Wired from
// [ClassFinanceReportScreen] via the [ViewToggleButton] above the
// body — Matrix is still default, this view is opt-in.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class ClassFinanceStudentCards extends StatelessWidget {
  final List<dynamic> students;
  final Map<String, List<dynamic>> billsByStudent;
  final List<MonthGroup> monthGroups;
  final String searchQuery;
  final String? selectedPaymentTypeId;
  final String? selectedMonthKey;
  final String selectedStatus;
  final void Function(dynamic bill) onBillTap;

  const ClassFinanceStudentCards({
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

  /// Returns the (label, color, icon) for the bill's current state.
  /// Mirrors [BillStatusCell]'s vocab so the per-siswa view matches
  /// the matrix at a glance.
  _CellTone _tone(dynamic bill) {
    if (bill == null) return _CellTone.dash;
    if (_isPaid(bill)) return _CellTone.lunas;
    if (_isOverdue(bill)) return _CellTone.tempo;
    if (_hasPendingPayment(bill)) return _CellTone.pending;
    return _CellTone.belum;
  }

  List<dynamic> _filterStudents() {
    return students.where((s) {
      if (searchQuery.isNotEmpty &&
          !s['name'].toString().toLowerCase().contains(searchQuery)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Effective (month × jenis) buckets the cards should iterate over.
  /// Mirrors the matrix's column logic — selecting a jenis collapses
  /// to that jenis's months; selecting a month collapses to that
  /// single month.
  List<_BucketKey> _buckets() {
    final out = <_BucketKey>[];
    for (final m in monthGroups) {
      if (selectedMonthKey != null && m.monthKey != selectedMonthKey) {
        continue;
      }
      for (final p in m.paymentTypes) {
        if (selectedPaymentTypeId != null && p.id != selectedPaymentTypeId) {
          continue;
        }
        out.add(
          _BucketKey(
            monthKey: m.monthKey,
            monthName: m.monthName,
            paymentTypeId: p.id,
            paymentTypeName: p.name,
          ),
        );
      }
    }
    return out;
  }

  dynamic _findBill(String studentId, _BucketKey b) {
    final bills = billsByStudent[studentId] ?? const [];
    for (final bill in bills) {
      if (bill['payment_type_id']?.toString() != b.paymentTypeId) continue;
      final due = bill['due_date'];
      if (due == null) continue;
      final d = DateTime.tryParse(due.toString());
      if (d == null) continue;
      final k = "${d.year}-${d.month.toString().padLeft(2, '0')}";
      if (k == b.monthKey) return bill;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterStudents();
    final buckets = _buckets();

    if (filtered.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final raw = filtered[i] as Map<String, dynamic>;
        final s = Student.fromJson(raw);
        return _StudentCard(
          student: s,
          buckets: buckets,
          findBill: (b) => _findBill(s.id, b),
          tone: _tone,
          onBillTap: onBillTap,
        );
      },
    );
  }
}

class _BucketKey {
  final String monthKey;
  final String monthName;
  final String paymentTypeId;
  final String paymentTypeName;
  const _BucketKey({
    required this.monthKey,
    required this.monthName,
    required this.paymentTypeId,
    required this.paymentTypeName,
  });
}

enum _CellTone { lunas, belum, tempo, pending, dash }

/// One jenis's row of buckets inside a student card. Built by
/// [_StudentCard._groupByJenis] so the card body can render each
/// jenis as its own subsection (header pill + month strip).
class _JenisRow {
  final String jenisName;
  final List<_BucketKey> items = [];
  _JenisRow({required this.jenisName});
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final List<_BucketKey> buckets;
  final dynamic Function(_BucketKey b) findBill;
  final _CellTone Function(dynamic bill) tone;
  final void Function(dynamic bill) onBillTap;

  const _StudentCard({
    required this.student,
    required this.buckets,
    required this.findBill,
    required this.tone,
    required this.onBillTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Walk the bucket list and split it into one [_JenisRow] per
  /// payment-type. Preserves the bucket order so the month columns
  /// inside each jenis section stay chronological. Used by the card
  /// body to render a small "SPP" / "Uang Pangkal" label above each
  /// row of month pills.
  List<_JenisRow> _groupByJenis(List<_BucketKey> buckets) {
    final byJenis = <String, _JenisRow>{};
    final order = <String>[];
    for (final b in buckets) {
      final row = byJenis.putIfAbsent(b.paymentTypeId, () {
        order.add(b.paymentTypeId);
        return _JenisRow(jenisName: b.paymentTypeName);
      });
      row.items.add(b);
    }
    return [for (final id in order) byJenis[id]!];
  }

  @override
  Widget build(BuildContext context) {
    final paid = buckets.where((b) {
      final bill = findBill(b);
      return bill != null && tone(bill) == _CellTone.lunas;
    }).length;
    final total = buckets.where((b) => findBill(b) != null).length;
    final ratioColor = paid == 0
        ? ColorUtils.error600
        : (paid == total ? ColorUtils.success600 : ColorUtils.warning600);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _initials(student.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name.isNotEmpty ? student.name : '-',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (student.studentNumber.isNotEmpty)
                      Text(
                        student.studentNumber,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$paid/${buckets.isEmpty ? 0 : buckets.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ratioColor,
                    ),
                  ),
                  Text(
                    'LUNAS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (buckets.isEmpty)
            const SizedBox.shrink()
          else ...[
            const SizedBox(height: 10),
            // Group buckets by jenis. When the user has a single jenis
            // selected we still render the label above its month row —
            // makes it obvious *which* jenis the pills are for, and
            // avoids the prior all-mixed wrap where the same month
            // (e.g. Mei) appeared 3-4 times back-to-back with no
            // indication that the duplicates belonged to different
            // payment types.
            for (final group in _groupByJenis(buckets)) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      group.jenisName,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Container(height: 1, color: ColorUtils.slate100),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in group.items)
                    _BucketPill(
                      label: b.monthName.length > 3
                          ? b.monthName.substring(0, 3)
                          : b.monthName,
                      tone: tone(findBill(b)),
                      onTap: () {
                        final bill = findBill(b);
                        if (bill != null) onBillTap(bill);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _BucketPill extends StatelessWidget {
  final String label;
  final _CellTone tone;
  final VoidCallback onTap;

  const _BucketPill({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (tone) {
      _CellTone.lunas => (
        ColorUtils.success600.withValues(alpha: 0.12),
        ColorUtils.success600,
        Icons.check_rounded,
      ),
      _CellTone.belum => (
        ColorUtils.error600.withValues(alpha: 0.10),
        ColorUtils.error600,
        Icons.close_rounded,
      ),
      _CellTone.tempo => (
        ColorUtils.warning600.withValues(alpha: 0.14),
        ColorUtils.warning600,
        Icons.priority_high_rounded,
      ),
      _CellTone.pending => (
        ColorUtils.corporateBlue600.withValues(alpha: 0.12),
        ColorUtils.corporateBlue600,
        Icons.hourglass_top_rounded,
      ),
      _CellTone.dash => (
        ColorUtils.slate100,
        ColorUtils.slate400,
        Icons.remove_rounded,
      ),
    };
    final disabled = tone == _CellTone.dash;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: fg.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
