// Dialog body for manually recording a student payment.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/bill_info_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/payment_dialog_footer_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/payment_form_mixin.dart';

/// Dialog for manually recording a payment.
class ClassFinanceManualPaymentDialog extends StatefulWidget {
  final dynamic bill;
  final Color primaryColor;
  final File? selectedFile;
  final String Function(dynamic) formatCurrency;
  final Future<void> Function(StateSetter) onPickFile;
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

  const ClassFinanceManualPaymentDialog({
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
    super.key,
  });

  @override
  State<ClassFinanceManualPaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<ClassFinanceManualPaymentDialog>
    with BillInfoMixin, PaymentFormMixin, PaymentDialogFooterMixin {
  @override
  dynamic get bill => widget.bill;
  @override
  Color get primaryColor => widget.primaryColor;
  @override
  File? get selectedFile => widget.selectedFile;
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
  @override
  void Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  })
  get onSave => widget.onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHeader(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: _buildFormContent(),
            ),
            buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() => Column(
    mainAxisSize: MainAxisSize.min,
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
      FilePickerSection(
        selectedFile: widget.selectedFile,
        primaryColor: widget.primaryColor,
        getFileTypeText: widget.getFileTypeText,
        onPickFile: () => widget.onPickFile(setState),
      ),
    ],
  );
}

/// File picker section widget.
class FilePickerSection extends StatelessWidget {
  final File? selectedFile;
  final Color primaryColor;
  final String Function(String) getFileTypeText;
  final VoidCallback onPickFile;

  const FilePickerSection({
    super.key,
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
              ? 'File terpilih: '
                    '${selectedFile!.path.split('/').last}'
              : 'Pilih bukti pembayaran',
          style: TextStyle(
            color: selectedFile != null
                ? ColorUtils.success600
                : ColorUtils.slate400,
          ),
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
