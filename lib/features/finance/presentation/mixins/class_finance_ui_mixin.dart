import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_report_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';

/// Mixin for UI building methods in class finance report.
mixin ClassFinanceUIMixin on State<ClassFinanceReportScreen> {
  /// Builds a filter chip widget.
  Widget buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: getPrimaryColor()),
      ),
      backgroundColor: getPrimaryColor().withValues(alpha: 0.1),
      deleteIcon: Icon(Icons.close, size: 16, color: getPrimaryColor()),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: getPrimaryColor().withValues(alpha: 0.2)),
      ),
    );
  }

  /// Builds a row for detail dialog display.
  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: ColorUtils.slate600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows filter sheet modal.
  void showFilterSheet(
    List<MonthGroup> monthGroups,
    String selectedStatus,
    String? selectedMonthKey,
    String? selectedPaymentTypeId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClassFinanceReportFilterSheet(
        primaryColor: getPrimaryColor(),
        selectedStatus: selectedStatus,
        selectedMonthKey: selectedMonthKey,
        selectedPaymentTypeId: selectedPaymentTypeId,
        monthGroups: monthGroups,
        onStatusChanged: onStatusFilterChanged,
        onMonthChanged: onMonthFilterChanged,
        onPaymentTypeChanged: onPaymentTypeFilterChanged,
      ),
    );
  }

  /// Shows bill detail bottom sheet.
  void showDetailDialog(dynamic bill) {
    if (bill == null) return;

    AppBottomSheet.show<void>(
      context: context,
      title: 'Detail Tagihan',
      icon: Icons.receipt_long_outlined,
      primaryColor: getPrimaryColor(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: buildDetailRows(bill),
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Tutup',
        secondaryLabel: 'Batal',
        primaryColor: getPrimaryColor(),
        onPrimary: () => AppNavigator.pop(context),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }

  List<Widget> buildDetailRows(dynamic bill) {
    final status = (bill['status'] ?? '').toString();
    final isPaid =
        status == 'paid' || status == 'verified' || status == 'success';
    return [
      buildDetailRow('Status', isPaid ? 'Lunas' : 'Belum Lunas'),
      buildDetailRow(
        'Jumlah',
        formatRupiah(
          bill['amount'] ?? bill['bill_amount'] ?? bill['total_amount'],
        ),
      ),
      buildDetailRow('Tanggal Buat', formatDate(bill['created_at'])),
      buildDetailRow('Jatuh Tempo', formatDate(bill['due_date'])),
      buildDetailRow('Keterangan', bill['description'] ?? '-'),
    ];
  }

  String formatRupiah(dynamic value) {
    if (value == null) return 'Rp 0';
    return 'Rp $value';
  }

  String formatDate(dynamic date) {
    return date?.toString().split('T')[0] ?? '-';
  }

  /// Must be implemented by State to provide primary color.
  Color getPrimaryColor();

  /// Callback when status filter changes.
  void onStatusFilterChanged(String status);

  /// Callback when month filter changes.
  void onMonthFilterChanged(String? month);

  /// Callback when payment type filter changes.
  void onPaymentTypeFilterChanged(String? paymentTypeId);
}
