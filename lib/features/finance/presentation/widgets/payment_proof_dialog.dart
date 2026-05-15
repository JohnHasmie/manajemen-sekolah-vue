// Dialog for viewing a student's uploaded payment proof.
//
// Reads the absolute proof URL from `payment['payment_proof_url']` —
// the backend's Payment model exposes this as an accessor that goes
// through `Storage::disk('public')->url()`, so the URL is correct
// whether the file lives on the local public disk OR on MinIO/S3
// when `FILESYSTEM_DISK=s3`. The frontend never reconstructs the
// URL — earlier versions that did broke on MinIO deployments
// (the "Gagal Memuat Gambar" + wrong `/uploads/bukti-pembayaran/`
// path admins were seeing).
//
// PDFs (`.pdf` files) can't be rendered with `Image.network`. For
// those we show a centered "Buka PDF" CTA that launches the file in
// the OS's external PDF viewer via `url_launcher` — same pattern the
// parent success screen uses for its Unduh Bukti button.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_info_row.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Read the absolute proof URL the backend resolved through
  /// `Storage::disk('public')->url()`. We deliberately don't
  /// reconstruct the URL on the client — that worked for the local
  /// `/storage/...` path but always 404'd against MinIO/S3 because
  /// the bucket URL is different. If the backend didn't send a URL
  /// the proof isn't viewable; show an empty state.
  String? _resolveProofUrl() {
    final preBuilt = payment['payment_proof_url']?.toString();
    if (preBuilt != null && preBuilt.isNotEmpty) return preBuilt;
    return null;
  }

  bool _isPdf(String url) => url.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final url = _resolveProofUrl();

    if (url == null) {
      SnackBarUtils.showWarning(context, AppLocalizations.noPaymentProof.tr);
      return const SizedBox.shrink();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
                  const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 20,
                  ),
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => AppNavigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Payment Proof Body ──────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _isPdf(url)
                    ? _PdfProofView(url: url)
                    : _ImageProofView(url: url),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

/// Inline image preview for JPG/PNG/etc. proofs. Falls back to a
/// retry-friendly error block (matches the original behaviour).
class _ImageProofView extends StatelessWidget {
  final String url;

  const _ImageProofView({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Image.network(
        url,
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
              Icon(
                Icons.error_outline,
                color: ColorUtils.error600,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppLocalizations.failedToLoadImage.tr,
                style: TextStyle(color: ColorUtils.error600),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'URL: $url',
                style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _openExternally(context, url),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Buka di browser'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// PDF proofs can't render with `Image.network` — show a CTA that
/// hands off to the OS PDF viewer via `url_launcher`. Same path the
/// parent success screen uses for its Unduh Bukti button, so admin
/// and parent share one rendering strategy for PDFs.
class _PdfProofView extends StatelessWidget {
  final String url;

  const _PdfProofView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 56,
            color: ColorUtils.error600,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Bukti pembayaran berupa file PDF',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Buka di aplikasi PDF untuk melihat detail.',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: () => _openExternally(context, url),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Buka PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Launch the proof URL in the OS's default handler (browser / PDF
/// viewer). Used by both the image-error fallback and the PDF view
/// so we have a single error path.
Future<void> _openExternally(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    SnackBarUtils.showError(context, 'URL bukti tidak valid.');
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      SnackBarUtils.showError(context, 'Tidak dapat membuka file.');
    }
  } catch (e) {
    AppLogger.error('payment-proof-open', e);
    if (context.mounted) {
      SnackBarUtils.showError(context, 'Gagal membuka file.');
    }
  }
}
