// Bottom-sheet for filtering the class finance report table.
//
// Extracted from `_showFilterSheet` in class_finance_report_screen.dart.
// Like a Vue component that owns temporary local state and emits updates
// back to the parent immediately on each selection change.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Bottom-sheet widget for filtering the class finance report.
class ClassFinanceReportFilterSheet extends StatefulWidget {
  final Color primaryColor;
  final String selectedStatus;
  final String? selectedMonthKey;
  final String? selectedPaymentTypeId;
  final List<MonthGroup> monthGroups;

  final void Function(String status) onStatusChanged;
  final void Function(String? monthKey) onMonthChanged;
  final void Function(String? typeId) onPaymentTypeChanged;

  const ClassFinanceReportFilterSheet({
    super.key,
    required this.primaryColor,
    required this.selectedStatus,
    required this.selectedMonthKey,
    required this.selectedPaymentTypeId,
    required this.monthGroups,
    required this.onStatusChanged,
    required this.onMonthChanged,
    required this.onPaymentTypeChanged,
  });

  @override
  State<ClassFinanceReportFilterSheet> createState() =>
      _ClassFinanceReportFilterSheetState();
}

class _ClassFinanceReportFilterSheetState
    extends State<ClassFinanceReportFilterSheet> {
  late String _selectedStatus;
  late String? _selectedMonthKey;
  late String? _selectedPaymentTypeId;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.selectedStatus;
    _selectedMonthKey = widget.selectedMonthKey;
    _selectedPaymentTypeId = widget.selectedPaymentTypeId;
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = 'Semua';
      _selectedMonthKey = null;
      _selectedPaymentTypeId = null;
    });
    widget.onStatusChanged('Semua');
    widget.onMonthChanged(null);
    widget.onPaymentTypeChanged(null);
  }

  Map<String, String> _buildUniqueTypes() {
    final allTypes = widget.monthGroups
        .expand((m) => m.paymentTypes.map((p) => {'id': p.id, 'name': p.name}))
        .toSet()
        .toList();

    final uniqueTypes = <String, String>{};
    for (final t in allTypes) {
      if (t['id'] != null && t['name'] != null) {
        uniqueTypes[t['id']!] = t['name']!;
      }
    }
    return uniqueTypes;
  }

  @override
  Widget build(BuildContext context) {
    final months = widget.monthGroups
        .map((m) => {'key': m.monthKey, 'name': m.monthName})
        .toList();
    final uniqueTypes = _buildUniqueTypes();

    return AppFilterBottomSheet(
      title: 'Filter Laporan',
      icon: Icons.tune_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: 'Status Pembayaran',
                icon: Icons.check_circle_outline_rounded,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: const [
                  FilterOption(value: 'Semua', label: 'Semua'),
                  FilterOption(value: 'Lunas', label: 'Lunas'),
                  FilterOption(value: 'Belum Dibayar', label: 'Belum Dibayar'),
                  FilterOption(
                    value: 'Belum Diverifikasi',
                    label: 'Belum Diverifikasi',
                  ),
                ],
                selectedValue: _selectedStatus,
                onSelected: (value) {
                  if (value != null) {
                    setState(() => _selectedStatus = value);
                    widget.onStatusChanged(value);
                  }
                },
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: 'Bulan',
                icon: Icons.calendar_month_rounded,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String?>(
                options: [
                  const FilterOption(value: null, label: 'Semua Bulan'),
                  ...months.map(
                    (m) => FilterOption(value: m['key'], label: m['name']!),
                  ),
                ],
                selectedValue: _selectedMonthKey,
                onSelected: (val) {
                  setState(() => _selectedMonthKey = val);
                  widget.onMonthChanged(val);
                },
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: 'Jenis Pembayaran',
                icon: Icons.payment_rounded,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String?>(
                options: [
                  const FilterOption(value: null, label: 'Semua Jenis'),
                  ...uniqueTypes.entries.map(
                    (e) => FilterOption(value: e.key, label: e.value),
                  ),
                ],
                selectedValue: _selectedPaymentTypeId,
                onSelected: (val) {
                  setState(() => _selectedPaymentTypeId = val);
                  widget.onPaymentTypeChanged(val);
                },
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
        ],
      ),
      onApply: () => AppNavigator.pop(context),
      onReset: _resetFilters,
    );
  }
}
