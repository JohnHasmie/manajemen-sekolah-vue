// Single-purpose month picker for the Keuangan header period pill.
//
// The header used to show a static "May 2026 ▾" label sourced from the
// money-flow API and ignored taps. Now the pill opens this sheet so the
// admin can scope the page to a specific month or "Semua bulan".
//
// Returns a [MonthFilterResult] when Apply / a pill is tapped, or
// `null` if the sheet is dismissed without a change. The result wraps
// a nullable `String?` so we can distinguish "all months" (null inside
// a non-null result) from "dismissed" (null result).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

class MonthFilterResult {
  /// `YYYY-MM` to keep, or `null` for "all months".
  final String? month;
  const MonthFilterResult(this.month);
}

const _monthLong = [
  '',
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

String monthFilterLabelFor(String? key) {
  if (key == null) return 'Semua bulan';
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final m = int.tryParse(parts[1]) ?? 0;
  if (m < 1 || m > 12) return key;
  return '${_monthLong[m]} ${parts[0]}';
}

/// Opens the month picker sheet and returns the chosen result, or
/// `null` if the user dismissed it.
Future<MonthFilterResult?> showMonthFilterSheet(
  BuildContext context, {
  required Color primaryColor,
  required String? initialMonth,
}) {
  return showModalBottomSheet<MonthFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MonthFilterSheet(
      primaryColor: primaryColor,
      initialMonth: initialMonth,
    ),
  );
}

class MonthFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final String? initialMonth;

  const MonthFilterSheet({
    super.key,
    required this.primaryColor,
    required this.initialMonth,
  });

  @override
  State<MonthFilterSheet> createState() => _MonthFilterSheetState();
}

class _MonthFilterSheetState extends State<MonthFilterSheet> {
  String? _month;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  /// Last 12 months (newest first) plus the next 2 ahead, in case the
  /// admin wants to scope to upcoming due dates.
  List<String> _buildMonthKeys() {
    final now = DateTime.now();
    return List.generate(14, (i) {
      // i=0 is +1 month ahead, i=1 is current month, i>=2 backwards
      final dt = DateTime(now.year, now.month - (i - 1));
      final mm = dt.month.toString().padLeft(2, '0');
      return '${dt.year}-$mm';
    });
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;
    final months = _buildMonthKeys();

    return AppBottomSheet(
      title: 'Pilih bulan',
      subtitle: 'Saring data Keuangan ke bulan tertentu.',
      icon: Icons.calendar_month_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.82,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          _SectionHeader(
            label: 'BULAN',
            icon: Icons.calendar_today_rounded,
            trailing: _month == null ? 'SEMUA' : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PillToggle(
                label: 'Semua bulan',
                selected: _month == null,
                primaryColor: navy,
                onTap: () => setState(() => _month = null),
              ),
              for (final m in months)
                _PillToggle(
                  label: monthFilterLabelFor(m),
                  selected: _month == m,
                  primaryColor: navy,
                  onTap: () => setState(() => _month = m),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Terapkan',
        primaryColor: navy,
        secondaryLabel: 'Batal',
        onPrimary: () => AppNavigator.pop(context, MonthFilterResult(_month)),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? trailing;
  const _SectionHeader({
    required this.label,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: ColorUtils.slate500),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ColorUtils.slate500,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(
            '· $trailing',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ColorUtils.slate300,
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: ColorUtils.slate100)),
      ],
    );
  }
}

class _PillToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color primaryColor;
  final VoidCallback onTap;
  const _PillToggle({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? primaryColor.withValues(alpha: 0.10)
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? primaryColor : ColorUtils.slate200,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 13, color: primaryColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? primaryColor : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
