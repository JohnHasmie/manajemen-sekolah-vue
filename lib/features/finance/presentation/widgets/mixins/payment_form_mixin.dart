import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_dialog_text_field.dart';

/// Mixin providing payment form field builders.
mixin PaymentFormMixin {
  /// Abstract: BuildContext for date picker.
  BuildContext get context;

  /// Abstract: Primary color for styling.
  Color get primaryColor;

  /// Abstract: Payment method controller.
  TextEditingController get paymentMethodController;

  /// Abstract: Amount controller.
  TextEditingController get amountController;

  /// Abstract: Payment date controller.
  TextEditingController get paymentDateController;

  /// Builds payment method dropdown field.
  Widget buildPaymentMethod() => DropdownButtonFormField<String>(
    initialValue: 'Tunai',
    decoration: _buildPaymentMethodDecoration(),
    items: _buildPaymentMethodItems(),
    onChanged: (value) {
      if (value != null) {
        paymentMethodController.text = value;
      }
    },
  );

  /// Builds decoration for payment method dropdown.
  InputDecoration _buildPaymentMethodDecoration() {
    const borderRadius = BorderRadius.all(Radius.circular(12));
    return InputDecoration(
      labelText: 'Metode Pembayaran',
      prefixIcon: Icon(Icons.payment, color: primaryColor, size: 20),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorUtils.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorUtils.slate200),
      ),
      filled: true,
      fillColor: ColorUtils.slate50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  /// Builds dropdown items for payment methods.
  List<DropdownMenuItem<String>> _buildPaymentMethodItems() => [
    DropdownMenuItem(
      value: 'Transfer Bank',
      child: Text(AppLocalizations.bankTransfer.tr),
    ),
    const DropdownMenuItem(value: 'Tunai', child: Text('Tunai')),
    DropdownMenuItem(
      value: 'Kartu Kredit/Debit',
      child: Text(AppLocalizations.creditCard.tr),
    ),
    const DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
  ];

  /// Builds amount input field.
  Widget buildAmount() => FinanceDialogTextField(
    controller: amountController,
    label: 'Jumlah Bayar',
    icon: Icons.attach_money,
    primaryColor: primaryColor,
    keyboardType: TextInputType.number,
  );

  /// Builds date picker field.
  Widget buildDate() => FinanceDialogTextField(
    controller: paymentDateController,
    label: 'Tanggal Bayar',
    icon: Icons.calendar_today,
    primaryColor: primaryColor,
    onTap: () async {
      final date = await showModernDatePicker(
        context: context,
        initialDate: DateTime.now(),
        title: 'Pilih Tanggal Bayar',
        lastDate: DateTime.now(),
      );
      if (date != null) {
        paymentDateController.text = date.toString().split(' ')[0];
      }
    },
  );
}
