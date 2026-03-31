// Dialog body for manually recording a student payment.
//
// Extracted from `_showManualPaymentForm` in class_finance_report_screen.dart.
// Like a Vue component `<ManualPaymentDialog :bill="bill" @save="onSave" />`
// that owns its own file picker state and emits save/cancel events.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_dialog_text_field.dart';

/// Dialog widget for manually recording a payment for a given [bill].
///
/// Owns the [selectedFile], payment-method, amount, and date form state.
/// Calls [onSave] with the collected values when the admin confirms.
/// Calls [onPickFile] when the file-picker button is tapped (the parent
/// handles the platform file-picker call and updates [selectedFile] via setState).
class ClassFinanceManualPaymentDialog extends StatelessWidget {
  final dynamic bill;
  final Color primaryColor;
  final File? selectedFile;

  /// Format a currency amount as "Rp X" — provided by the parent so we don't
  /// duplicate the NumberFormat logic here.
  final String Function(dynamic) formatCurrency;

  /// Called when the admin taps "Pilih File"; receives a [StateSetter] so the
  /// callback can call setDialogState to update [selectedFile] inside the dialog.
  final Future<void> Function(StateSetter setDialogState) onPickFile;

  /// Returns the human-readable file-type label for a given file path.
  final String Function(String filePath) getFileTypeText;

  /// Called when the admin confirms the form.
  final void Function({
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  }) onSave;

  final TextEditingController paymentMethodController;
  final TextEditingController amountController;
  final TextEditingController paymentDateController;

  const ClassFinanceManualPaymentDialog({
    super.key,
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
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        child: Icon(
                          Icons.payment_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.uploadPaymentProof.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            AppSpacing.v2,
                            Text(
                              'Catat pembayaran manual siswa',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoItem(
                        AppLocalizations.paymentTypes.tr,
                        bill['payment_type']?['name'] ??
                            bill['jenis_pembayaran_nama'] ??
                            '-',
                      ),
                      _buildInfoItem(
                        AppLocalizations.billAmount.tr,
                        formatCurrency(bill['amount'] ?? bill['bill_amount']),
                      ),

                      const SizedBox(height: AppSpacing.lg),
                      Divider(),
                      const SizedBox(height: AppSpacing.lg),

                      DropdownButtonFormField<String>(
                        initialValue: 'Tunai',
                        decoration: InputDecoration(
                          labelText: 'Metode Pembayaran',
                          prefixIcon: Icon(
                            Icons.payment,
                            color: primaryColor,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: ColorUtils.slate200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: ColorUtils.slate200,
                            ),
                          ),
                          filled: true,
                          fillColor: ColorUtils.slate50,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Transfer Bank',
                            child: Text(AppLocalizations.bankTransfer.tr),
                          ),
                          DropdownMenuItem(
                            value: 'Tunai',
                            child: Text('Tunai'),
                          ),
                          DropdownMenuItem(
                            value: 'Kartu Kredit/Debit',
                            child: Text(AppLocalizations.creditCard.tr),
                          ),
                          DropdownMenuItem(
                            value: 'Lainnya',
                            child: Text('Lainnya'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            paymentMethodController.text = value;
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FinanceDialogTextField(
                        controller: amountController,
                        label: 'Jumlah Bayar',
                        icon: Icons.attach_money,
                        primaryColor: primaryColor,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FinanceDialogTextField(
                        controller: paymentDateController,
                        label: 'Tanggal Bayar',
                        icon: Icons.calendar_today,
                        primaryColor: primaryColor,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            paymentDateController.text = date
                                .toString()
                                .split(' ')[0];
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // File picker section — uses setDialogState to refresh
                      // the selected-file display inside this StatefulBuilder.
                      _FilePickerSection(
                        selectedFile: selectedFile,
                        primaryColor: primaryColor,
                        getFileTypeText: getFileTypeText,
                        onPickFile: () => onPickFile(setDialogState),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: ColorUtils.slate100),
                    ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: BorderSide(color: ColorUtils.slate300),
                          ),
                          child: Text(
                            AppLocalizations.cancel.tr,
                            style: TextStyle(color: ColorUtils.slate600),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (paymentMethodController.text.isEmpty ||
                                amountController.text.isEmpty) {
                              return;
                            }
                            AppNavigator.pop(context);
                            onSave(
                              paymentMethod: paymentMethodController.text,
                              amount:
                                  double.parse(amountController.text),
                              date: paymentDateController.text,
                              file: selectedFile,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            AppLocalizations.save.tr,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

/// File picker display section used inside [ClassFinanceManualPaymentDialog].
///
/// Keeps the selected-file display isolated so it can be rebuilt by
/// the outer [StatefulBuilder] without rebuilding the whole form.
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
  Widget build(BuildContext context) {
    return Container(
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
          ),
          if (selectedFile != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              getFileTypeText(selectedFile!.path),
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.slate600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            onPressed: onPickFile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
            ),
            child: Text(
              'Pilih File',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
