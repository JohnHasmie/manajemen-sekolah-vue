// Dialog for verifying or rejecting a pending payment.
//
// Extracted from `_showVerificationDialog` in admin_finance_screen.dart.
// Like a Vue `<VerificationDialog>` component that receives the payment map,
// API service, and callbacks as props.
//
// The admin can toggle between 'verified' / 'rejected', add optional notes,
// then confirm to call PUT /payment/{id}/verify on the backend.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/verification_dialog_header_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/verification_dialog_form_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/verification_dialog_payment_info_mixin.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/mixins/verification_dialog_actions_mixin.dart';

/// Dialog widget for verifying or rejecting a student payment.
///
/// Accepts the raw payment map from the API (same shape as the pending
/// payment list items) plus callbacks/services that it needs from the
/// parent screen.
///
/// In Vue terms this is like a
/// `<VerificationDialog :payment="p" @success="reload" />`
/// component that emits a success event after the API call succeeds.
class VerificationDialog extends ConsumerStatefulWidget {
  /// The raw payment record from the API (e.g. `_pendingPaymentList[i]`).
  final Map<String, dynamic> payment;

  /// Injected API service — same instance the parent screen uses.
  final ApiService apiService;

  /// Currency formatter from the parent screen (`_formatCurrency`).
  final String Function(dynamic) formatCurrency;

  /// Primary theme colour already resolved by the parent
  /// (`_getPrimaryColor()`).
  final Color primaryColor;

  /// Called after a successful verify/reject API call so the parent can
  /// reload its data (equivalent to `_loadData(useCache: false)`).
  final VoidCallback onSuccess;

  /// Called when the user taps the payment proof banner, so the parent
  /// screen can open its full-screen image viewer (`_showPaymentProof`).
  final VoidCallback onShowPaymentProof;

  const VerificationDialog({
    super.key,
    required this.payment,
    required this.apiService,
    required this.formatCurrency,
    required this.primaryColor,
    required this.onSuccess,
    required this.onShowPaymentProof,
  });

  @override
  ConsumerState<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<VerificationDialog>
    with
        VerificationDialogHeaderMixin,
        VerificationDialogFormMixin,
        VerificationDialogPaymentInfoMixin,
        VerificationDialogActionsMixin {
  final _notesController = TextEditingController();
  String _status = 'verified';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ─── Mixin implementations (abstract getters/setters) ────────────────────

  @override
  Map<String, dynamic> get payment => widget.payment;

  ApiService get apiService => widget.apiService;

  @override
  String Function(dynamic) get formatCurrency => widget.formatCurrency;

  @override
  Color get primaryColor => widget.primaryColor;

  VoidCallback get onSuccess => widget.onSuccess;

  @override
  VoidCallback get onShowPaymentProof => widget.onShowPaymentProof;

  @override
  String get status => _status;

  @override
  Future<void> Function() get handleConfirmFn => _handleConfirm;

  // ─── Confirm button handler ──────────────────────────────────────────────

  Future<void> _handleConfirm() async {
    try {
      await apiService.put('/payment/${payment['id']}/verify', {
        'status': _status,
        'admin_notes': _notesController.text.isEmpty
            ? null
            : _notesController.text,
      });

      if (!context.mounted) return;
      AppNavigator.pop(context);
      onSuccess();
      if (context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          _status == 'verified'
              ? AppLocalizations.paymentVerifiedSuccessfully.tr
              : AppLocalizations.paymentRejectedSuccessfully.tr,
        );
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToVerify.tr}: '
          '${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogHeader(),
            _buildDialogBody(),
            buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Helper to build the dialog body content.
  Widget _buildDialogBody() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildPaymentInfoSection(),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          buildPaymentProofBanner(),
          _buildStatusDropdown(),
          const SizedBox(height: AppSpacing.md),
          _buildNotesField(),
        ],
      ),
    );
  }

  /// Helper to build the status dropdown.
  Widget _buildStatusDropdown() {
    return buildDropdownField(
      value: _status,
      label: 'Status Verifikasi',
      icon: Icons.check_circle,
      items: ['verified', 'rejected'],
      onChanged: (value) {
        setState(() {
          _status = value!;
        });
      },
    );
  }

  /// Helper to build the notes text field.
  Widget _buildNotesField() {
    return buildDialogTextField(
      controller: _notesController,
      label: 'Catatan (Opsional)',
      icon: Icons.note,
      maxLines: 3,
    );
  }
}
