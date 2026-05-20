import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_manual_payment_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_payment_options_sheet.dart';

/// Mixin for payment-related operations in class finance report.
mixin ClassFinancePaymentMixin on State<ClassFinanceReportScreen> {
  late ApiService apiService;
  late File? selectedFile;

  /// Shows manual payment form dialog with file upload.
  void showManualPaymentForm(dynamic bill) {
    final paymentMethodController = TextEditingController(text: 'Tunai');
    final amountController = TextEditingController(
      text: (bill['amount'] ?? 0).toString(),
    );
    final paymentDateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    selectedFile = null;

    showManualPaymentSheet(
      context: context,
      bill: bill,
      primaryColor: getPrimaryColor(),
      selectedFile: selectedFile,
      formatCurrency: formatCurrency,
      onPickFile: pickFile,
      getFileTypeText: getFileTypeText,
      paymentMethodController: paymentMethodController,
      amountController: amountController,
      paymentDateController: paymentDateController,
      onSave:
          ({
            required String paymentMethod,
            required double amount,
            required String date,
            File? file,
          }) {
            uploadManualPayment(
              bill: bill,
              paymentMethod: paymentMethod,
              amount: amount,
              date: date,
              file: file,
            );
          },
    );
  }

  /// Uploads manual payment to the server.
  Future<void> uploadManualPayment({
    required dynamic bill,
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  }) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      await submitPaymentData(bill, paymentMethod, amount, date, file);

      if (mounted) AppNavigator.pop(context);
      onPaymentSuccess();
      // ignore: use_build_context_synchronously
      SnackBarUtils.showSuccess(
        context,
        AppLocalizations.paymentRecordedSuccessfully.tr,
      );
    } catch (e) {
      if (mounted) AppNavigator.pop(context);
      // ignore: use_build_context_synchronously
      SnackBarUtils.showError(context, '${AppLocalizations.error.tr}:$e');
    }
  }

  Future<void> submitPaymentData(
    dynamic bill,
    String paymentMethod,
    double amount,
    String date,
    File? file,
  ) async {
    final data = {
      'bill_id': bill['id'],
      'payment_method': paymentMethod,
      'amount': amount.toString(),
      'payment_date': date,
      'status': 'verified',
    };

    if (file != null) {
      await apiService.uploadFile(
        '/payment/manual',
        file,
        fileField: 'payment_receipt',
        data: data,
      );
    } else {
      await apiService.post('/payment/manual', data);
    }
  }

  /// Processes manual payment (mark as paid or cancel).
  Future<void> processManualPayment(dynamic bill, bool markAsPaid) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      if (markAsPaid) {
        await handleMarkAsPaid(bill);
      } else {
        await handleCancelPayment(bill);
      }

      if (mounted) AppNavigator.pop(context);
      onPaymentSuccess();

      if (mounted) {
        final message = markAsPaid
            ? AppLocalizations.paymentRecordedSuccessfully.tr
            : AppLocalizations.paymentCancelled.tr;
        SnackBarUtils.showInfo(context, message);
      }
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context);
        SnackBarUtils.showError(context, '${AppLocalizations.error.tr}: $e');
      }
    }
  }

  Future<void> handleMarkAsPaid(dynamic bill) async {
    final pendingId = findPaymentByStatus(bill, 'pending');

    if (pendingId != null) {
      await apiService.put(
        '/payment/manual/$pendingId',
        buildPaymentData(bill),
      );
    } else {
      await apiService.post('/payment/manual', {
        'bill_id': bill['id'],
        ...buildPaymentData(bill),
        'status': 'verified',
      });
    }
  }

  Future<void> handleCancelPayment(dynamic bill) async {
    final verifiedId = findPaymentByStatus(bill, 'verified');

    if (verifiedId != null) {
      await apiService.put('/payment/manual/$verifiedId', {
        'status': 'pending',
        'amount': bill['amount'] ?? 0,
        'payment_method': 'Manual',
        'payment_date': DateTime.now().toIso8601String(),
      });
    }

    try {
      await apiService.put('/bills/${bill['id']}', {'status': 'pending'});
    } catch (_) {}
  }

  String? findPaymentByStatus(dynamic bill, String status) {
    if (bill['payments'] == null || (bill['payments'] as List).isEmpty) {
      return null;
    }

    final payments = List.from(bill['payments']);
    final payment = payments.lastWhere(
      (p) => p['status'] == status,
      orElse: () => null,
    );

    return payment?['id']?.toString();
  }

  Map<String, dynamic> buildPaymentData(dynamic bill) {
    return {
      'amount': bill['amount'] ?? bill['bill_amount'] ?? 0,
      'payment_method': 'Manual',
      'payment_date': DateTime.now().toIso8601String(),
    };
  }

  /// Shows payment options bottom sheet.
  void showPaymentOptions(dynamic bill) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClassFinancePaymentOptionsSheet(
        bill: bill,
        primaryColor: getPrimaryColor(),
        onManualPay: () => showManualPaymentForm(bill),
        onCancelPayment: () => processManualPayment(bill, false),
        onViewDetail: () => showDetailDialog(bill),
      ),
    );
  }

  /// Callback after payment operation succeeds.
  void onPaymentSuccess();

  /// Must be implemented by State to provide primary color.
  Color getPrimaryColor();

  /// Must be implemented by State to format currency.
  String formatCurrency(dynamic amount);

  /// Must be implemented by State to get file type text.
  String getFileTypeText(String filePath);

  /// Must be implemented by State to pick file.
  Future<void> pickFile(StateSetter setDialogState);

  /// Must be implemented by State to show detail dialog.
  void showDetailDialog(dynamic bill);
}
