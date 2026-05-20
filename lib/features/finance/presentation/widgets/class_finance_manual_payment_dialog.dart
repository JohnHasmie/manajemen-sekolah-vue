// Bottom sheet for manually recording a student payment.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/bill_info_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/payment_form_mixin.dart';

/// Shows a bottom sheet for manually recording a payment.
void showManualPaymentSheet({
  required BuildContext context,
  required dynamic bill,
  required Color primaryColor,
  required File? selectedFile,
  required String Function(dynamic) formatCurrency,
  required Future<void> Function(void Function(void Function())) onPickFile,
  required String Function(String) getFileTypeText,
  required void Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  })
  onSave,
  required TextEditingController paymentMethodController,
  required TextEditingController amountController,
  required TextEditingController paymentDateController,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ManualPaymentSheetContent(
      bill: bill,
      primaryColor: primaryColor,
      selectedFile: selectedFile,
      formatCurrency: formatCurrency,
      onPickFile: onPickFile,
      getFileTypeText: getFileTypeText,
      onSave: onSave,
      paymentMethodController: paymentMethodController,
      amountController: amountController,
      paymentDateController: paymentDateController,
    ),
  );
}

/// Internal stateful content widget for the manual payment sheet.
class _ManualPaymentSheetContent extends StatefulWidget {
  final dynamic bill;
  final Color primaryColor;
  final File? selectedFile;
  final String Function(dynamic) formatCurrency;
  final Future<void> Function(void Function(void Function())) onPickFile;
  final String Function(String) getFileTypeText;
  final void Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  })
  onSave;
  final TextEditingController paymentMethodController;
  final TextEditingController amountController;
  final TextEditingController paymentDateController;

  const _ManualPaymentSheetContent({
    required this.bill,
    required this.primaryColor,
    required this.selectedFile,
    required this.formatCurrency,
    required this.onPickFile,
    required this.getFileTypeText,
    required this.onSave,
    required this.paymentMethodController,
    required this.amountController,
    required this.paymentDateController,
  });

  @override
  State<_ManualPaymentSheetContent> createState() =>
      _ManualPaymentSheetContentState();
}

class _ManualPaymentSheetContentState
    extends State<_ManualPaymentSheetContent>
    with BillInfoMixin, PaymentFormMixin {
  late File? _currentFile;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.selectedFile;
  }

  @override
  dynamic get bill => widget.bill;
  @override
  Color get primaryColor => widget.primaryColor;
  @override
  File? get selectedFile => _currentFile;
  @override
  String Function(dynamic) get formatCurrency => widget.formatCurrency;
  @override
  TextEditingController get paymentMethodController =>
      widget.paymentMethodController;
  @override
  TextEditingController get amountController => widget.amountController;
  @override
  TextEditingController get paymentDateController =>
      widget.paymentDateController;

  Future<void> _handlePickFile() async {
    // Close the sheet first to allow file picker to show
    Navigator.pop(context);
    
    // Pick the file
    await widget.onPickFile((fn) {
      // This callback updates the parent's selectedFile
      fn();
    });
    
    // Reopen the sheet with updated file
    if (mounted) {
      showManualPaymentSheet(
        context: context,
        bill: widget.bill,
        primaryColor: widget.primaryColor,
        selectedFile: widget.selectedFile,
        formatCurrency: widget.formatCurrency,
        onPickFile: widget.onPickFile,
        getFileTypeText: widget.getFileTypeText,
        onSave: widget.onSave,
        paymentMethodController: widget.paymentMethodController,
        amountController: widget.amountController,
        paymentDateController: widget.paymentDateController,
      );
    }
  }

  void _handleSave() {
    final paymentMethod = paymentMethodController.text.trim();
    final amountText = amountController.text.trim();
    final date = paymentDateController.text.trim();

    if (paymentMethod.isEmpty || amountText.isEmpty || date.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) return;

    widget.onSave(
      paymentMethod: paymentMethod,
      amount: amount,
      date: date,
      file: _currentFile,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Unggah Bukti Pembayaran',
      subtitle: 'Catat pembayaran manual siswa',
      icon: Icons.receipt_long_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.85,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildBillInfo(),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          buildPaymentMethod(),
          const SizedBox(height: AppSpacing.md),
          buildAmount(),
          const SizedBox(height: AppSpacing.md),
          buildDate(),
          const SizedBox(height: AppSpacing.md),
          _FilePickerSection(
            selectedFile: _currentFile,
            primaryColor: widget.primaryColor,
            getFileTypeText: widget.getFileTypeText,
            onPickFile: _handlePickFile,
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: 'Simpan',
        secondaryLabel: 'Batal',
        primaryColor: widget.primaryColor,
        onPrimary: _handleSave,
        onSecondary: () => Navigator.pop(context),
      ),
    );
  }
}

/// File picker section widget.
class _FilePickerSection extends StatelessWidget {
  final File? selectedFile;
  final Color primaryColor;
  final String Function(String) getFileTypeText;
  final VoidCallback onPickFile;

  const _FilePickerSection({
    required this.selectedFile,
    required this.primaryColor,
    required this.getFileTypeText,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: selectedFile != null
                ? ColorUtils.success600
                : ColorUtils.slate200,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.upload_file,
              color: selectedFile != null
                  ? ColorUtils.success600
                  : ColorUtils.slate400,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              selectedFile != null
                  ? 'File terpilih: ${selectedFile!.path.split('/').last}'
                  : 'Pilih bukti pembayaran',
              style: TextStyle(
                color: selectedFile != null
                    ? ColorUtils.success600
                    : ColorUtils.slate400,
              ),
              textAlign: TextAlign.center,
            ),
            if (selectedFile != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                getFileTypeText(selectedFile!.path),
                style: TextStyle(fontSize: 10, color: ColorUtils.slate600),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            ElevatedButton(
              onPressed: onPickFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
              child: const Text(
                'Pilih File',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
