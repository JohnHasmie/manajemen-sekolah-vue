// Year + month picker for the Keuangan header period pill.
//
// Two-section layout: TAHUN (year chips from backend) and BULAN (month 1-12).
// Fetches available years via GET /api/finance/available-years on init.
// When both are selected, filters to that month. Either can be null for "all".
//
// Returns a [MonthFilterResult] when Apply / a pill is tapped, or
// `null` if the sheet is dismissed without a change.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

class MonthFilterResult {
  /// Year (e.g. 2026), null = all years
  final int? year;

  /// Month (1-12), null = all months
  final int? month;
  const MonthFilterResult({this.year, this.month});
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

String monthFilterLabelFor({int? year, int? month}) {
  if (year == null && month == null) return 'Semua periode';
  if (year != null && month == null) return '$year';
  if (year == null && month != null) {
    if (month < 1 || month > 12) return 'Semua bulan';
    return _monthLong[month];
  }
  // Both set
  if (month == null || year == null) return 'Semua periode';
  if (month < 1 || month > 12) return '$year';
  return '${_monthLong[month]} $year';
}

/// Opens the year + month picker sheet and returns the chosen result, or
/// `null` if the user dismissed it. Fetches available years from the backend.
Future<MonthFilterResult?> showMonthFilterSheet(
  BuildContext context, {
  required Color primaryColor,
  int? initialYear,
  int? initialMonth,
}) {
  return showModalBottomSheet<MonthFilterResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MonthFilterSheet(
      primaryColor: primaryColor,
      initialYear: initialYear,
      initialMonth: initialMonth,
    ),
  );
}

class MonthFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final int? initialYear;
  final int? initialMonth;

  const MonthFilterSheet({
    super.key,
    required this.primaryColor,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<MonthFilterSheet> createState() => _MonthFilterSheetState();
}

class _MonthFilterSheetState extends State<MonthFilterSheet> {
  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
    _selectedMonth = widget.initialMonth;
    _fetchAvailableYears();
  }

  Future<void> _fetchAvailableYears() async {
    try {
      final api = ApiService();
      final response = await api.get('/finance/available-years');
      if (mounted && response['data'] is List) {
        setState(() {
          _availableYears = List<int>.from(response['data'] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final navy = widget.primaryColor;

    return AppBottomSheet(
      title: 'Pilih periode',
      subtitle: 'Saring data Keuangan berdasarkan tahun dan bulan.',
      icon: Icons.calendar_month_rounded,
      primaryColor: navy,
      maxHeightFactor: 0.82,
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      content: _isLoading
          ? const Center(
              child: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                _SectionHeader(
                  label: 'TAHUN',
                  icon: Icons.calendar_today_rounded,
                  trailing: _selectedYear == null ? 'SEMUA' : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillToggle(
                      label: 'Semua tahun',
                      selected: _selectedYear == null,
                      primaryColor: navy,
                      onTap: () => setState(() => _selectedYear = null),
                    ),
                    for (final y in _availableYears)
                      _PillToggle(
                        label: '$y',
                        selected: _selectedYear == y,
                        primaryColor: navy,
                        onTap: () => setState(() => _selectedYear = y),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionHeader(
                  label: 'BULAN',
                  icon: Icons.calendar_today_rounded,
                  trailing: _selectedMonth == null ? 'SEMUA' : null,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillToggle(
                      label: 'Semua bulan',
                      selected: _selectedMonth == null,
                      primaryColor: navy,
                      onTap: () => setState(() => _selectedMonth = null),
                    ),
                    for (int m = 1; m <= 12; m++)
                      _PillToggle(
                        label: _monthLong[m],
                        selected: _selectedMonth == m,
                        primaryColor: navy,
                        onTap: () => setState(() => _selectedMonth = m),
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
        onPrimary: () => AppNavigator.pop(
          context,
          MonthFilterResult(year: _selectedYear, month: _selectedMonth),
        ),
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
