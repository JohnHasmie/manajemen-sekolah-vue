import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_invalidation_service.dart';
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
  ///
  /// The sheet owns its own file-picker state now — we don't pass
  /// `selectedFile` or `onPickFile` anymore. The picked file comes back via
  /// the `file` arg on [onSave] and gets uploaded via [uploadManualPayment].
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
      formatCurrency: formatCurrency,
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
            return uploadManualPayment(
              bill: bill,
              paymentMethod: paymentMethod,
              amount: amount,
              date: date,
              file: file,
            );
          },
    );
  }

  /// Uploads a manual payment to the server.
  ///
  /// Contract:
  ///   * NO `showDialog` here. The earlier version pushed a loading
  ///     spinner via `showDialog`, which defaults to
  ///     `useRootNavigator: true` — that put the dialog on the app's
  ///     root navigator while the manual-payment sheet sat on the
  ///     Keuangan tab's nested navigator (`_TabBranch`). When we then
  ///     called `AppNavigator.pop(context)` to "dismiss the loading
  ///     dialog", the pop walked up to the TAB navigator and popped
  ///     the sheet instead, leaving the dialog stuck on root and
  ///     accidentally cascading to also pop the ClassFinanceReport
  ///     screen. Removing the dialog removes the whole cross-navigator
  ///     hazard — the sheet's Simpan button shows a "Menyimpan..."
  ///     label + disabled state while the future is in flight, which
  ///     is sufficient loading feedback.
  ///   * Caller (`_ManualPaymentSheetContentState._handleSave`) AWAITS
  ///     this and pops the manual-payment sheet itself when we return
  ///     `true`. Single owner = single pop = no over-popping.
  ///   * On success: invalidates the finance cache (bills, dashboard,
  ///     parent billing) before triggering [onPaymentSuccess] so the
  ///     report screen's `loadData()` refetch can't be served stale rows.
  ///   * Returns `true` when the payment was persisted and the report
  ///     refresh fired, `false` if anything threw — the sheet stays open
  ///     on `false` so the admin can retry without re-typing.
  Future<bool> uploadManualPayment({
    required dynamic bill,
    required String paymentMethod,
    required double amount,
    required String date,
    File? file,
  }) async {
    try {
      await submitPaymentData(bill, paymentMethod, amount, date, file);

      // Flush any finance / dashboard caches so the report screen's
      // post-success `loadData()` sees the fresh bill status. The bill
      // fetch itself doesn't cache, but parallel surfaces (dashboard
      // KPIs, parent billing) do.
      await CacheInvalidationService.onFinanceChanged();

      if (!mounted) return true;
      onPaymentSuccess(); // triggers report `loadData()`
      // ignore: use_build_context_synchronously
      SnackBarUtils.showSuccess(
        context,
        AppLocalizations.paymentRecordedSuccessfully.tr,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      // ignore: use_build_context_synchronously
      SnackBarUtils.showError(context, _friendlyUploadError(e));
      return false;
    }
  }

  /// Pulls the most actionable message out of whatever the payment POST
  /// threw.
  ///
  /// `ApiService.uploadFile` wraps the underlying `DioException` in a
  /// generic `Exception('Upload error: $error')`, which prints as
  /// "DioException [unknown]: null" — useless to the admin. The real
  /// validation message (e.g. "Jumlah pembayaran melebihi sisa tagihan")
  /// lives inside the `DioException.error` payload as an
  /// [ApiException] (see `dio_client.dart`'s `ErrorInterceptor`).
  ///
  /// This helper digs through the wrappers and returns the friendly
  /// message when it can find one. Falls back to a generic copy
  /// otherwise so the admin never sees "DioException [unknown]: null".
  String _friendlyUploadError(Object error) {
    // 1. Direct ApiException — preferred path.
    if (error is ApiException) {
      return error.message;
    }
    // 2. DioException wrapping an ApiException via the interceptor.
    if (error is DioException) {
      final inner = error.error;
      if (inner is ApiException) return inner.message;
      // Some endpoints return the message in response.data.message
      // directly; fall back to that before giving up.
      final data = error.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    }
    // 3. ApiService.uploadFile's `Exception('Upload error: $cause')`
    //    string-wraps the DioException, so the friendly message is
    //    GONE by the time we catch it here. Best we can do is strip
    //    the noisy prefix and unhelpful tail, then ask the admin to
    //    retry.
    final raw = error.toString();
    if (raw.contains('DioException') ||
        raw.contains('Upload error') ||
        raw.contains('[unknown]')) {
      return 'Gagal menyimpan pembayaran. Periksa koneksi atau coba '
          'lagi beberapa saat lagi.';
    }
    return raw;
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
  ///
  /// Note on navigator scoping: `showDialog` defaults to
  /// `useRootNavigator: true` so the spinner is pushed on the app's
  /// ROOT navigator. The pop below must therefore also target the
  /// root navigator — using `Navigator.pop(context)` (or
  /// `AppNavigator.pop`) would walk up to the Keuangan tab's nested
  /// navigator (`_TabBranch`) and pop the wrong route, dropping the
  /// admin onto the class list with the spinner stuck on root.
  Future<void> processManualPayment(dynamic bill, bool markAsPaid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (markAsPaid) {
        await handleMarkAsPaid(bill);
      } else {
        await handleCancelPayment(bill);
      }
      // Cancel flow mutates payments + bills — flush finance caches so
      // the report's post-success reload sees the new state.
      await CacheInvalidationService.onFinanceChanged();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // root dialog
      onPaymentSuccess();
      final message = markAsPaid
          ? AppLocalizations.paymentRecordedSuccessfully.tr
          : AppLocalizations.paymentCancelled.tr;
      // ignore: use_build_context_synchronously
      SnackBarUtils.showInfo(context, message);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      // ignore: use_build_context_synchronously
      SnackBarUtils.showError(context, '${AppLocalizations.error.tr}: $e');
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

  /// Shows the right entry-point for a tapped bill cell.
  ///
  /// Paid bills (status `paid` / `verified` / `success`) skip the options
  /// sheet entirely and open the detail sheet directly — admins should
  /// see the receipt + payment metadata, not be offered "Bayar Manual"
  /// for a bill that's already settled. Unpaid bills still go through
  /// the options sheet so the admin can choose between manual entry and
  /// viewing detail.
  void showPaymentOptions(dynamic bill) {
    final status = (bill?['status'] ?? '').toString();
    final isPaid =
        status == 'paid' || status == 'verified' || status == 'success';
    if (isPaid) {
      showDetailDialog(bill);
      return;
    }

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
  ///
  /// Kept on the mixin contract because `ClassFinanceUtilsMixin` provides
  /// the implementation and other parts of the report still use it for
  /// inline file-type labels. The manual-payment sheet now owns its own
  /// labelling so the abstract `pickFile(StateSetter)` was retired.
  String getFileTypeText(String filePath);

  /// Must be implemented by State to show detail dialog.
  void showDetailDialog(dynamic bill);
}
