// Bottom sheet that lets the admin pick which month to resume a
// monthly Jenis on when they re-activate it.
//
// Flow:
//   1. Admin taps "Aktifkan" on a Bulanan Jenis that was Nonaktif.
//   2. This sheet opens with a year navigator (◀ 2026 ▶) and a 3×4
//      grid of month chips (Jan–Des). Current month is preselected.
//   3. Admin taps a month, then Lanjutkan.
//   4. Returned `YYYY-MM` is sent as `month` field in the PATCH
//      /payment-types/{id}/status body so the backend generates bills
//      for that specific month.
//
// For non-Bulanan periodes the row-action skips this sheet entirely —
// the backend's `GenerateBillsForTypeAction` derives the period from
// the Jenis's `start_date` for semester/yearly/sekali types.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Opens the month-picker sheet. Returns the chosen month as
/// `YYYY-MM` or null when the admin cancels.
Future<String?> showActivateMonthPickerSheet({
  required BuildContext context,
  required Color primaryColor,
  required String jenisName,
  DateTime? initialMonth,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActivateMonthPickerSheet(
      primaryColor: primaryColor,
      jenisName: jenisName,
      initialMonth: initialMonth ?? DateTime.now(),
    ),
  );
}

class _ActivateMonthPickerSheet extends StatefulWidget {
  final Color primaryColor;
  final String jenisName;
  final DateTime initialMonth;

  const _ActivateMonthPickerSheet({
    required this.primaryColor,
    required this.jenisName,
    required this.initialMonth,
  });

  @override
  State<_ActivateMonthPickerSheet> createState() =>
      _ActivateMonthPickerSheetState();
}

class _ActivateMonthPickerSheetState extends State<_ActivateMonthPickerSheet> {
  // Indonesian month names — Jan–Des, 3-letter abbreviations matching
  // the rest of the admin Keuangan screens.
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
    _month = widget.initialMonth.month;
  }

  /// `YYYY-MM` formatter matching the backend's regex
  /// `^\d{4}-(0[1-9]|1[0-2])$`.
  String _formatYearMonth() {
    final y = _year.toString().padLeft(4, '0');
    final m = _month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Disables future months > 12 months out — keeps the admin from
  /// generating bills 5 years ahead by accident. The backend will
  /// accept them, but it's almost certainly a typo.
  bool _isMonthEnabled(int year, int month) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year + 1, now.month);
    final candidate = DateTime(year, month);
    return !candidate.isAfter(cutoff);
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    return AppBottomSheet(
      title: kFinSelectActiveMonth.tr,
      subtitle:
          'Tagihan akan dibuat untuk bulan yang dipilih pada '
          '"${widget.jenisName}".',
      icon: Icons.event_available_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.7,
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _YearNavigator(
            year: _year,
            primaryColor: navy,
            onPrev: () => setState(() => _year--),
            onNext: () => setState(() => _year++),
          ),
          const SizedBox(height: 16),
          _MonthGrid(
            year: _year,
            selectedYear: _year,
            selectedMonth: _month,
            primaryColor: navy,
            months: _months,
            isEnabled: _isMonthEnabled,
            onPicked: (m) => setState(() => _month = m),
          ),
          const SizedBox(height: 16),
          _SelectedSummary(
            year: _year,
            month: _month,
            months: _months,
            primaryColor: navy,
          ),
          const SizedBox(height: 16),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Lanjutkan',
        primaryColor: navy,
        secondaryLabel: 'Batal',
        onPrimary: () => Navigator.of(context).pop(_formatYearMonth()),
        onSecondary: () => Navigator.of(context).pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Internals
// ─────────────────────────────────────────────────────────────────────

class _YearNavigator extends StatelessWidget {
  final int year;
  final Color primaryColor;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _YearNavigator({
    required this.year,
    required this.primaryColor,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          _ChevronButton(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
            primaryColor: primaryColor,
          ),
          Expanded(
            child: Center(
              child: Text(
                'Tahun $year',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
            ),
          ),
          _ChevronButton(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color primaryColor;

  const _ChevronButton({
    required this.icon,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final int year;
  final int selectedYear;
  final int selectedMonth;
  final Color primaryColor;
  final List<String> months;
  final bool Function(int year, int month) isEnabled;
  final ValueChanged<int> onPicked;

  const _MonthGrid({
    required this.year,
    required this.selectedYear,
    required this.selectedMonth,
    required this.primaryColor,
    required this.months,
    required this.isEnabled,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    // 4 rows × 3 cols grid. Built manually rather than GridView so the
    // sheet keeps its natural height (no nested-scrollable confusion).
    final rows = <Widget>[];
    for (var r = 0; r < 4; r++) {
      final cells = <Widget>[];
      for (var c = 0; c < 3; c++) {
        final monthNum = r * 3 + c + 1;
        final selected = (year == selectedYear) && (monthNum == selectedMonth);
        final enabled = isEnabled(year, monthNum);
        cells.add(
          Expanded(
            child: _MonthCell(
              label: months[monthNum - 1],
              selected: selected,
              enabled: enabled,
              primaryColor: primaryColor,
              onTap: enabled ? () => onPicked(monthNum) : null,
            ),
          ),
        );
        if (c < 2) cells.add(const SizedBox(width: 8));
      }
      rows.add(Row(children: cells));
      if (r < 3) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final Color primaryColor;
  final VoidCallback? onTap;

  const _MonthCell({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? primaryColor.withValues(alpha: 0.12)
        : (enabled ? Colors.white : ColorUtils.slate50);
    final border = selected ? primaryColor : ColorUtils.slate200;
    final textColor = !enabled
        ? ColorUtils.slate400
        : (selected ? primaryColor : ColorUtils.slate700);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedSummary extends StatelessWidget {
  final int year;
  final int month;
  final List<String> months;
  final Color primaryColor;

  const _SelectedSummary({
    required this.year,
    required this.month,
    required this.months,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final monthName = _fullMonthName(month);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 18, color: primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Akan dibuat untuk $monthName $year',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fullMonthName(int month) {
    const names = [
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
    return names[(month - 1).clamp(0, 11)];
  }
}
