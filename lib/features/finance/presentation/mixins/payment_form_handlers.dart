import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/currency_formatter.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';

/// Mixin for handling submission logic in payment form.
mixin PaymentFormHandlersMixin on ConsumerState<PaymentTypeFormSheet> {
  /// Validates and submits payment type form data.
  /// Handles both create and update scenarios via API.
  Future<void> handleFormSubmit(
    BuildContext context, {
    required TextEditingController nameController,
    required TextEditingController amountController,
    required TextEditingController periodController,
    required String status,
    required Map<String, dynamic>? goalData,
    required Map<String, dynamic>? paymentType,
    required VoidCallback onSaved,
    required TextEditingController descriptionController,
  }) async {
    // Validate required fields
    if (nameController.text.isEmpty || amountController.text.isEmpty) {
      SnackBarUtils.showError(context, 'Nama dan jumlah harus diisi');
      return;
    }

    // Validate amount
    final parsedAmount = CurrencyInputFormatter.parseCurrency(
      amountController.text,
    );

    if (parsedAmount <= 0) {
      SnackBarUtils.showError(context, 'Jumlah harus lebih besar dari Rp 0');
      return;
    }

    // Validate goal selection
    if (goalData == null) {
      SnackBarUtils.showError(context, 'Tujuan pembayaran harus dipilih');
      return;
    }

    try {
      final data = {
        'name': nameController.text,
        'description': descriptionController.text,
        'amount': CurrencyInputFormatter.parseCurrency(amountController.text),
        'periode': periodController.text,
        'status': status == 'active' ? 'active' : 'inactive',
        'goal': goalData,
      };

      final apiService = ApiService();
      if (paymentType == null) {
        await apiService.post('/payment-types', data);
      } else {
        await apiService.put('/payment-types/${paymentType['id']}', data);
      }

      if (context.mounted) {
        AppNavigator.pop(context);
      }
      onSaved();

      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'Data berhasil disimpan');
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal menyimpan: '
          '${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }
}
