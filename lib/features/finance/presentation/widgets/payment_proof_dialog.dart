// Dialog for viewing a student's uploaded payment proof image.
//
// Extracted from `_showPaymentProof` in admin_finance_screen.dart.
// Like a Vue `<PaymentProofDialog :payment="p" />` modal that displays
// the receipt image with a gradient header and a brief payment info footer.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_info_row.dart';

/// Full-screen-ish dialog that shows the payment proof image for a payment.
///
/// Receives the raw [payment] map (same shape as `_pendingPaymentList` items),
/// a [formatCurrency] callback, and the resolved [primaryColor] / [cardGradient]
/// from the parent screen.  Stateless — no local mutations.
///
/// Guards against a missing proof file: if [payment] has no
/// `payment_proof` or `payment_receipt` field the caller should show a
/// warning snackbar instead of pushing this dialog (done in the thin
/// delegator in the parent screen).
class PaymentProofDialog extends StatelessWidget {
  /// Raw payment record from the API.
  final Map<String, dynamic> payment;

  /// Currency formatter from the parent screen (`_formatCurrency`).
  final String Function(dynamic) formatCurrency;

  /// Primary brand colour already resolved by the parent.
  final Color primaryColor;

  /// Gradient used in card/dialog headers throughout the screen.
  final LinearGradient cardGradient;

  const PaymentProofDialog({
    super.key,
    required this.payment,
    required this.formatCurrency,
    required this.primaryColor,
    required this.cardGradient,
  });

  /// Builds the full URL for the receipt image stored on the server.
  /// Mirrors `_getImageUrl` in the parent screen.
  String _imageUrl(String filename) =>
      '${ApiService.baseUrl.replaceFirst('/api', '')}'
      '/uploads/bukti-pembayaran/$filename';

  @override
  Widget build(BuildContext context) {
    final imageFile =
        payment['payment_proof'] ?? payment['payment_receipt'] as String?;

    // Guard: caller should have checked, but just in case.
    if (imageFile == null) {
      SnackBarUtils.showWarning(
          context, AppLocalizations.noPaymentProof.tr);
      return const SizedBox.shrink();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient Header ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.photo_library,
                      color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'Bukti Pembayaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                    onPressed: () => AppNavigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Payment Proof Image ──────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _imageUrl(imageFile.toString()),
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: ColorUtils.error600, size: 40),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            AppLocalizations.failedToLoadImage.tr,
                            style:
                                TextStyle(color: ColorUtils.error600),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'File: $imageFile',
                            style: TextStyle(
                              fontSize: 10,
                              color: ColorUtils.slate400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── Payment Info Footer ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Pembayaran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FinanceInfoRow(
                    label: 'Siswa',
                    value: payment['siswa_nama'] ?? '-',
                  ),
                  FinanceInfoRow(
                    label: 'Kelas',
                    value: payment['kelas_nama'] ?? '-',
                  ),
                  FinanceInfoRow(
                    label: 'Jenis',
                    value: payment['jenis_pembayaran_nama'] ?? '-',
                  ),
                  FinanceInfoRow(
                    label: 'Jumlah',
                    value: formatCurrency(payment['amount']),
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
