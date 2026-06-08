import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/activate_month_picker_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_detail_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/target_selection_modal.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/verification_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_proof_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/admin_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';

/// Mixin for dialog and action handling.
mixin FinanceActionMixin on ConsumerState<FinanceScreen> {
  AdminFinanceController get controller;

  List<dynamic> get classList;

  Map<String, List<dynamic>> get studentsByClass;

  String formatCurrency(dynamic amount);

  String formatMonth(String? monthStr);

  String getGoalDescription(dynamic goalData);

  String getTranslatedPeriod(String? period);

  Color getPrimaryColor();

  LinearGradient getCardGradient();

  Future<void> loadDataAfterAction();

  void showAddEditPaymentType({Map<String, dynamic>? paymentType}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentTypeFormSheet(
        paymentType: paymentType,
        primaryColor: getPrimaryColor(),
        onSaved: loadDataAfterAction,
        onShowTargetSelection: showTargetSelectionModal,
      ),
    );
  }

  void showTargetSelectionModal({
    Map<String, dynamic>? paymentType,
    required Function(Map<String, dynamic>) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TargetSelectionModal(
        paymentType: paymentType,
        onSave: onSave,
        primaryColor: getPrimaryColor(),
        classList: classList,
        studentsByClass: studentsByClass,
      ),
    );
  }

  Future<void> deletePaymentType(Map<String, dynamic> paymentType) async {
    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: kFinDeletePaymentType.tr,
      message: kFinDeletePaymentTypeMsg.tr.replaceFirst(
        '\${paymentType[\'name\']}',
        '${paymentType['name']}',
      ),
      confirmText: kFinDelete.tr,
      isDestructive: true,
    );

    if (confirmed == true) {
      final result = await controller.deletePaymentType(paymentType);
      if (!mounted) return;
      if (result.ok) {
        SnackBarUtils.showSuccess(
          context,
          result.softDeleted ? kFinTypeDisabled.tr : kFinTypeDeletedSuccess.tr,
        );
        await loadDataAfterAction();
      } else {
        SnackBarUtils.showError(
          context,
          kFinDeleteError.tr.replaceFirst(
            '\${result.error}',
            '${result.error}',
          ),
        );
      }
    }
  }

  /// Toggles a payment type between `active` and `inactive` via the
  /// backend's PATCH /payment-types/{id}/status endpoint. Used by the
  /// detail sheet's quick "Aktifkan / Nonaktifkan" action so the
  /// admin doesn't have to reopen the full Edit form.
  ///
  /// For Bulanan Jenis being activated, opens a month-picker sheet
  /// first so the admin can choose which period to resume from. This
  /// matches Luay's request: "seumpama di nonaktifkan terus ameh
  /// diaktifkan iku pilih bulan". For other periodes the sheet is
  /// skipped because the backend derives the period from start_date.
  Future<void> togglePaymentTypeStatus(
    Map<String, dynamic> paymentType, {
    required bool active,
  }) async {
    final id = paymentType['id']?.toString();
    if (id == null || id.isEmpty) return;

    // Month picker — only for activating a monthly jenis.
    // Backend rename: `payment_types.periode` → `payment_types.period`,
    // values `bulanan` → `monthly`.
    String? selectedMonth;
    final periode = (paymentType['period'] ?? paymentType['periode'] ?? '')
        .toString()
        .toLowerCase();
    if (active && (periode == 'monthly' || periode == 'bulanan')) {
      final name = (paymentType['name'] ?? 'Jenis pembayaran').toString();
      selectedMonth = await showActivateMonthPickerSheet(
        context: context,
        primaryColor: getPrimaryColor(),
        jenisName: name,
      );
      if (!mounted) return;
      // Admin tapped Batal — abort the whole transition.
      if (selectedMonth == null) return;
    }

    final result = await controller.setPaymentTypeStatus(
      id,
      active: active,
      month: selectedMonth,
    );
    if (!mounted) return;

    if (result.isSuccess) {
      // Compose a precise toast: count of bills + which month, when
      // applicable. Falls back to the bland "diaktifkan" string when
      // nothing was generated (e.g. deactivation, or every bill
      // already existed for the chosen month).
      final toast = _composeStatusToast(
        active: active,
        billsGenerated: result.billsGenerated,
        monthApplied: result.monthApplied,
      );
      SnackBarUtils.showSuccess(context, toast);
      await loadDataAfterAction();
    } else {
      SnackBarUtils.showError(
        context,
        active
            ? 'Gagal mengaktifkan: ${result.error}'
            : 'Gagal menonaktifkan: ${result.error}',
      );
    }
  }

  /// Builds the success toast message based on what happened.
  ///   * deactivate          → "Jenis pembayaran dinonaktifkan."
  ///   * activate + 0 bills  → "Jenis diaktifkan." (e.g. bills already
  ///                            existed for the chosen period)
  ///   * activate + N bills  → "Jenis diaktifkan, N tagihan baru
  ///                            untuk September 2026."
  String _composeStatusToast({
    required bool active,
    required int billsGenerated,
    required String? monthApplied,
  }) {
    if (!active) return kFinTypeDisabledSuccess.tr;
    if (billsGenerated <= 0) return kFinTypeEnabledSuccess.tr;
    final monthLabel = monthApplied != null
        ? ' untuk ${_humanMonthLabel(monthApplied)}'
        : '';
    return kFinTypeEnabledWithBills.tr
        .replaceFirst('\$billsGenerated', '$billsGenerated')
        .replaceFirst('\$monthLabel', monthLabel);
  }

  /// Converts a `YYYY-MM` string into a human-readable
  /// "Bulan Tahun" Indonesian label. Defensive against bad input —
  /// just returns the raw string if parsing fails.
  String _humanMonthLabel(String yearMonth) {
    final parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return yearMonth;
    }
    const names = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${names[month - 1]} $year';
  }

  /// Tap on a Jenis row → opens the read-only detail sheet, which
  /// returns either `PaymentTypeDetailAction.edit`,
  /// `PaymentTypeDetailAction.delete`, or `null` (dismissed). We
  /// fan out to the existing edit form / destructive confirm sheet
  /// so the row card itself stays a thin presentation widget.
  ///
  /// Manual bill generation is no longer surfaced here — the Laravel
  /// scheduler in `routes/console.php` runs `finance:generate-bills`
  /// daily at 01:00, so the row's "Generate" mini-button used to be a
  /// race-prone manual override that confused admins. The detail
  /// sheet's helper line tells the admin what's happening.
  Future<void> showPaymentTypeDetail(Map<String, dynamic> paymentType) async {
    final action = await showPaymentTypeDetailSheet(
      context,
      paymentType: paymentType,
      primaryColor: getPrimaryColor(),
      formatCurrency: formatCurrency,
      getTranslatedPeriod: getTranslatedPeriod,
      getGoalDescription: getGoalDescription,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case PaymentTypeDetailAction.edit:
        showAddEditPaymentType(paymentType: paymentType);
        break;
      case PaymentTypeDetailAction.delete:
        await deletePaymentType(paymentType);
        break;
      case PaymentTypeDetailAction.activate:
        await togglePaymentTypeStatus(paymentType, active: true);
        break;
      case PaymentTypeDetailAction.deactivate:
        await togglePaymentTypeStatus(paymentType, active: false);
        break;
    }
  }

  void showVerificationDialog(Map<String, dynamic> payment) {
    showDialog(
      context: context,
      builder: (context) => VerificationDialog(
        payment: payment,
        apiService: ApiService(),
        formatCurrency: formatCurrency,
        primaryColor: getPrimaryColor(),
        onSuccess: loadDataAfterAction,
        onShowPaymentProof: () => showPaymentProof(payment),
      ),
    );
  }

  Future<void> deleteGeneratedBills(Map<String, dynamic> item) async {
    final name = item['name'] ?? 'Tagihan';
    final monthStr = item['month'] ?? '';
    final formattedMonth = formatMonth(monthStr);

    final confirmed = await ActionConfirmSheet.show(
      context: context,
      title: kFinDeleteBill.tr,
      message: kFinDeleteBillMsg.tr
          .replaceFirst('\$name', '$name')
          .replaceFirst('\$formattedMonth', formattedMonth),
      confirmText: kFinDeleteBill.tr,
      icon: Icons.delete_rounded,
      isDestructive: true,
    );

    if (confirmed == true) {
      updateIsLoadingForDelete(true);
      final error = await controller.deleteGeneratedBills(
        paymentTypeId: item['payment_type_id'].toString(),
        month: monthStr,
      );
      if (mounted) {
        if (error == null) {
          SnackBarUtils.showSuccess(
            context,
            kFinBillDeletedSuccess.tr
                .replaceFirst('\$name', '$name')
                .replaceFirst('\$formattedMonth', formattedMonth),
          );
          await loadDataAfterAction();
        } else {
          updateIsLoadingForDelete(false);
          SnackBarUtils.showError(context, 'Failed to delete: $error');
        }
      }
    }
  }

  void showPaymentProof(Map<String, dynamic> payment) {
    final imageFile = payment['payment_proof'] ?? payment['payment_receipt'];

    if (imageFile == null) {
      SnackBarUtils.showWarning(context, 'No payment proof available');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => PaymentProofDialog(
        payment: payment,
        formatCurrency: formatCurrency,
        primaryColor: getPrimaryColor(),
        cardGradient: getCardGradient(),
      ),
    );
  }

  void updateIsLoadingForDelete(bool value);
}
