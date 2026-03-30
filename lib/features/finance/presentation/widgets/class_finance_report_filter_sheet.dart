// Bottom-sheet for filtering the class finance report table.
//
// Extracted from `_showFilterSheet` in class_finance_report_screen.dart.
// Like a Vue component `<ClassFinanceFilterSheet v-bind="filters" @update="..." />`
// that owns temporary local state and emits updates back to the parent immediately
// on each selection change (mirrors the original inline StatefulBuilder behaviour).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Bottom-sheet widget for filtering the class finance report.
///
/// Receives the current filter values ([selectedStatus], [selectedMonthKey],
/// [selectedPaymentTypeId]) and the data needed to populate dropdowns
/// ([monthGroups]).  Each change immediately calls back ([onStatusChanged],
/// [onMonthChanged], [onPaymentTypeChanged]) so the parent table re-renders
/// in real time — matching the original `setState` calls inside the sheet.
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
  // Mirror the original StatefulBuilder local state so the sheet's own UI
  // re-renders while also notifying the parent screen via the callbacks.
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

  LinearGradient get _cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.primaryColor,
          widget.primaryColor.withValues(alpha: 0.7),
        ],
      );

  @override
  Widget build(BuildContext context) {
    // Unique payment types across all month groups — like a Vue computed that
    // flattens and deduplicates `monthGroups.flatMap(m => m.paymentTypes)`.
    final allTypes = widget.monthGroups
        .expand(
          (m) => m.paymentTypes.map((p) => {'id': p.id, 'name': p.name}),
        )
        .toSet()
        .toList();
    final uniqueTypes = <String, String>{};
    for (var t in allTypes) {
      if (t['id'] != null && t['name'] != null) {
        uniqueTypes[t['id']!] = t['name']!;
      }
    }

    final months = widget.monthGroups
        .map((m) => {'key': m.monthKey, 'name': m.monthName})
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorUtils.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 14, 12, 18),
            decoration: BoxDecoration(
              gradient: _cardGradient,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Filter Laporan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = 'Semua';
                      _selectedMonthKey = null;
                      _selectedPaymentTypeId = null;
                    });
                    widget.onStatusChanged('Semua');
                    widget.onMonthChanged(null);
                    widget.onPaymentTypeChanged(null);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  _buildSectionHeader(
                    'Status Pembayaran',
                    Icons.circle_outlined,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Semua',
                      'Lunas',
                      'Belum Dibayar',
                      'Belum Diverifikasi',
                    ].map((statusOpt) {
                      final isSelected = _selectedStatus == statusOpt;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedStatus = statusOpt);
                          widget.onStatusChanged(statusOpt);
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.primaryColor.withValues(alpha: 0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? widget.primaryColor
                                  : ColorUtils.slate200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            statusOpt,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? widget.primaryColor
                                  : ColorUtils.slate600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: AppSpacing.xxl),
                  // Month Filter
                  _buildSectionHeader('Bulan', Icons.calendar_month_rounded),
                  _buildStyledDropdown<String?>(
                    value: _selectedMonthKey,
                    hint: 'Semua Bulan',
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(AppLocalizations.allMonths.tr),
                      ),
                      ...months.map(
                        (m) => DropdownMenuItem(
                          value: m['key'],
                          child: Text(m['name']!),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedMonthKey = val);
                      widget.onMonthChanged(val);
                    },
                  ),

                  SizedBox(height: AppSpacing.xxl),
                  // Payment Type Filter
                  _buildSectionHeader(
                    'Jenis Pembayaran',
                    Icons.receipt_long_rounded,
                  ),
                  _buildStyledDropdown<String?>(
                    value: _selectedPaymentTypeId,
                    hint: 'Semua Jenis',
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(AppLocalizations.allTypes.tr),
                      ),
                      ...uniqueTypes.entries.map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedPaymentTypeId = val);
                      widget.onPaymentTypeChanged(val);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.cancel.tr,
                      style: TextStyle(color: ColorUtils.slate600),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Terapkan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 15, color: widget.primaryColor),
          ),
          AppSpacing.h10,
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(
            hint,
            style: TextStyle(color: ColorUtils.slate400, fontSize: 14),
          ),
          value: value,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: ColorUtils.slate500,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
