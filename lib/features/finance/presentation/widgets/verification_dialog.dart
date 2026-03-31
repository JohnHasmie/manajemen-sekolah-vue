// Dialog for verifying or rejecting a pending payment.
//
// Extracted from `_showVerificationDialog` in admin_finance_screen.dart.
// Like a Vue `<VerificationDialog>` component that receives the payment map,
// API service, and callbacks as props.
//
// The admin can toggle between 'verified' / 'rejected', add optional notes,
// then confirm to call PUT /payment/{id}/verify on the backend.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_info_item.dart';

/// Dialog widget for verifying or rejecting a student payment.
///
/// Accepts the raw payment map from the API (same shape as the pending
/// payment list items) plus callbacks/services that it needs from the
/// parent screen.
///
/// In Vue terms this is like a `<VerificationDialog :payment="p" @success="reload" />`
/// component that emits a success event after the API call succeeds.
class VerificationDialog extends ConsumerStatefulWidget {
  /// The raw payment record from the API (e.g. `_pendingPaymentList[i]`).
  final Map<String, dynamic> payment;

  /// Injected API service — same instance the parent screen uses.
  final ApiService apiService;

  /// Currency formatter from the parent screen (`_formatCurrency`).
  final String Function(dynamic) formatCurrency;

  /// Primary theme colour already resolved by the parent (`_getPrimaryColor()`).
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
  ConsumerState<VerificationDialog> createState() =>
      _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<VerificationDialog> {
  // Holds the optional admin notes.  Like a Vue `data()` ref.
  final _notesController = TextEditingController();

  // Current selected verification status ('verified' or 'rejected').
  // Starts as 'verified' — the most common action.
  String _status = 'verified';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ─── Helpers (inlined from FinanceScreenState private methods) ──────────────

  /// Builds a styled text field used for the admin notes input.
  ///
  /// Mirrors `_buildDialogTextField` from the parent screen, but uses
  /// [widget.primaryColor] for the prefix icon tint instead of calling
  /// `_getPrimaryColor()`.
  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          // Use the pre-resolved primary colour passed from the parent.
          prefixIcon: Icon(icon, color: widget.primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  /// Builds a styled dropdown field for selecting verification status.
  ///
  /// Mirrors `_buildDropdownField` from the parent screen.  Reads
  /// [languageProvider] from riverpod to localise the 'verified' label.
  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Guard: if the current value is not in items, fall back to the first one.
    final String selectedValue = items.contains(value) ? value : items.first;

    // Read language provider for localised dropdown labels — same pattern as
    // the parent screen's `ref.watch(languageRiverpod)` in build().
    final languageProvider = ref.watch(languageRiverpod);

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonFormField<String>(
          initialValue: selectedValue,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: widget.primaryColor, size: 20),
            border: InputBorder.none,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item == 'aktif'
                    ? 'Aktif'
                    : item == 'non-aktif'
                    ? 'Non-Aktif'
                    : item == 'sekali bayar'
                    ? 'Sekali Bayar'
                    : item == 'bulanan'
                    ? 'Bulanan'
                    : item == 'semester'
                    ? 'Semester'
                    : item == 'tahunan'
                    ? 'Tahunan'
                    : item == 'verified'
                    ? languageProvider.getTranslatedText(
                        AppLocalizations.verified,
                      )
                    : item == 'rejected'
                    ? 'Ditolak'
                    : item,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── Gradient header (mirrors _getCardGradient in the parent screen) ────────

  LinearGradient _cardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        widget.primaryColor,
        widget.primaryColor.withValues(alpha: 0.85),
      ],
    );
  }

  // ─── Confirm button handler ──────────────────────────────────────────────────

  Future<void> _handleConfirm() async {
    try {
      await widget.apiService.put(
        '/payment/${widget.payment['id']}/verify',
        {
          'status': _status,
          'admin_notes': _notesController.text.isEmpty
              ? null
              : _notesController.text,
        },
      );

      if (!mounted) return;
      // Close this dialog first, then reload the parent list.
      AppNavigator.pop(context);
      widget.onSuccess();
      if (mounted) {
        SnackBarUtils.showSuccess(
          context,
          _status == 'verified'
              ? AppLocalizations.paymentVerifiedSuccessfully.tr
              : AppLocalizations.paymentRejectedSuccessfully.tr,
        );
      }
    } catch (error) {
      AppLogger.error('finance', error);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToVerify.tr}: ${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Read language provider for the payment-type label localisation.
    final languageProvider = ref.watch(languageRiverpod);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient header ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: _cardGradient(),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Verifikasi Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment info rows
                  FinanceInfoItem(
                    label: 'Siswa',
                    value: widget.payment['siswa_nama'] ?? '-',
                  ),
                  FinanceInfoItem(
                    label: 'Kelas',
                    value: widget.payment['kelas_nama'] ?? '-',
                  ),
                  FinanceInfoItem(
                    label: languageProvider.getTranslatedText(
                      AppLocalizations.paymentTypes,
                    ),
                    value: widget.payment['jenis_pembayaran_nama'] ?? '-',
                  ),
                  FinanceInfoItem(
                    label: 'Jumlah Bayar',
                    value: widget.formatCurrency(widget.payment['amount']),
                  ),
                  FinanceInfoItem(
                    label: 'Metode Bayar',
                    value: widget.payment['metode_bayar'] ?? '-',
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  Divider(),
                  const SizedBox(height: AppSpacing.lg),

                  // Payment proof banner — shown only when a receipt exists.
                  if (widget.payment['payment_receipt'] != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    GestureDetector(
                      onTap: widget.onShowPaymentProof,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: ColorUtils.corporateBlue600.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(
                            color: ColorUtils.corporateBlue600.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.photo_library,
                              color: ColorUtils.corporateBlue600,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bukti Pembayaran Tersedia',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: ColorUtils.corporateBlue600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Klik untuk melihat gambar',
                                    style: TextStyle(
                                      color: ColorUtils.corporateBlue600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: ColorUtils.corporateBlue600,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Verification status dropdown
                  _buildDropdownField(
                    value: _status,
                    label: 'Status Verifikasi',
                    icon: Icons.check_circle,
                    items: ['verified', 'rejected'],
                    onChanged: (value) {
                      setState(() {
                        _status = value!;
                      });
                    },
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Optional admin notes text field
                  _buildDialogTextField(
                    controller: _notesController,
                    label: 'Catatan (Opsional)',
                    icon: Icons.note,
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            // ── Action buttons ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: ColorUtils.slate300),
                      ),
                      child: Text(
                        AppLocalizations.cancel.tr,
                        style: TextStyle(color: ColorUtils.slate700),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Confirm button — colour reflects current status
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _status == 'verified'
                            ? ColorUtils.success600
                            : ColorUtils.error600,
                        shape: RoundedRectangleBorder(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _status == 'verified' ? 'Terima' : 'Tolak',
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
  }
}
