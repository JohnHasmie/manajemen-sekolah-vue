import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
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
      title: 'Delete Payment Type',
      message:
          'Yakin ingin menghapus jenis pembayaran '
          '"${paymentType['name']}"?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirmed == true) {
      final error = await controller.deletePaymentType(paymentType);
      if (mounted) {
        if (error == null) {
          SnackBarUtils.showSuccess(
            context,
            'Jenis pembayaran berhasil dihapus',
          );
          await loadDataAfterAction();
        } else {
          SnackBarUtils.showError(context, 'Failed to delete: $error');
        }
      }
    }
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
      title: 'Hapus Tagihan',
      message:
          'Apakah Anda yakin ingin menghapus SEMUA '
          'tagihan untuk "$name" periode '
          '$formattedMonth? Ini tidak akan menghapus '
          'Jenis Pembayarannya.',
      confirmText: 'Hapus Tagihan',
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
            'Tagihan "$name" periode $formattedMonth '
            'berhasil dihapus',
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
