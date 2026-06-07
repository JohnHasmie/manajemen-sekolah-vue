// Dialog for viewing a student's uploaded payment proof.
//
// Reads the absolute proof URL from `payment['payment_proof_url']` —
// the backend's Payment model exposes this as an accessor that goes
// through `Storage::disk('public')->url()`, so the URL is correct
// whether the file lives on the local public disk OR on MinIO/S3
// when `FILESYSTEM_DISK=s3`.
//
// IMPORTANT — MinIO routing: in dockerised dev/prod, the raw bucket
// URL ends up at `http://minio:9000/...` which mobile devices can't
// resolve. The backend now also exposes `payment_proof_proxy_url`
// that points at a Laravel route which streams the file. The
// upstream call site (`class_finance_ui_mixin._openReceiptViewer`)
// rewrites `payment_proof_url` to the proxy variant before opening
// this dialog, so we still read a single key here.
//
// PDFs (`.pdf` files) can't be rendered with `Image.network`. For
// those we show a centered "Buka PDF" CTA that launches the file in
// the OS's external PDF viewer via `url_launcher`.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

class PaymentProofDialog extends StatelessWidget {
  /// Raw payment record from the API, already enriched by the caller
  /// with `siswa_nama` / `kelas_nama` / `jenis_pembayaran_nama` so the
  /// info card below the preview can render without "-" placeholders.
  final Map<String, dynamic> payment;

  /// Currency formatter from the parent screen.
  final String Function(dynamic) formatCurrency;

  /// Primary brand colour already resolved by the parent.
  final Color primaryColor;

  /// Gradient used in card/dialog headers throughout the screen.
  final LinearGradient cardGradient;

  /// HTTP headers to attach when the receipt URL is fetched via
  /// `Image.network` (or `launchUrl`). The caller passes the same
  /// Bearer token + X-School-ID that the rest of the API uses so the
  /// Laravel proxy route can authenticate the request. Without these
  /// the proxy returns 401 and the user sees "Gagal Memuat Gambar"
  /// even though the URL is correct.
  final Map<String, String>? imageHeaders;

  const PaymentProofDialog({
    super.key,
    required this.payment,
    required this.formatCurrency,
    required this.primaryColor,
    required this.cardGradient,
    this.imageHeaders,
  });

  /// Get the payment ID from the payment object.
  String? _getPaymentId() => payment['id']?.toString();

  /// Read the absolute proof URL. We deliberately don't reconstruct
  /// it on the client — that worked for the local `/storage/...`
  /// path but always 404'd against MinIO/S3 because the bucket URL
  /// is different. The upstream caller already prefers the proxy
  /// variant when the backend exposes it.
  String? _resolveProofUrl() {
    final preBuilt = payment['payment_proof_url']?.toString();
    if (preBuilt != null && preBuilt.isNotEmpty) return preBuilt;
    return null;
  }

  bool _isPdf(String url) {
    // Strip any querystring before checking the extension so a
    // signed S3 URL like `…/file.pdf?X-Amz-…` still classifies as PDF.
    final clean = url.split('?').first.toLowerCase();
    return clean.endsWith('.pdf');
  }

  String _normaliseDate(dynamic raw) {
    if (raw == null) return '-';
    final s = raw.toString();
    if (s.isEmpty) return '-';
    final cut = s.indexOf(RegExp(r'[T ]'));
    return cut == -1 ? s : s.substring(0, cut);
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveProofUrl();
    final paymentId = _getPaymentId();

    if (url == null) {
      SnackBarUtils.showWarning(context, AppLocalizations.noPaymentProof.tr);
      return const SizedBox.shrink();
    }

    final isPdf = _isPdf(url);
    final siswa = payment['siswa_nama']?.toString() ?? '-';
    final kelas = payment['kelas_nama']?.toString() ?? '-';
    final jenis = payment['jenis_pembayaran_nama']?.toString() ?? '-';
    final tanggal = _normaliseDate(payment['payment_date']);
    final metode = payment['payment_method']?.toString() ?? '-';
    final amount = formatCurrency(payment['amount']);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProofHeader(
              gradient: cardGradient,
              fileType: isPdf ? 'PDF' : 'GAMBAR',
            ),
            // Preview area — image inline, PDF placeholder with Buka.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: isPdf
                    ? _PdfProofView(url: url, paymentId: paymentId)
                    : _ImageProofView(
                        url: url,
                        headers: imageHeaders,
                        paymentId: paymentId,
                      ),
              ),
            ),
            _ProofInfoCard(
              siswa: siswa,
              kelas: kelas,
              jenis: jenis,
              metode: metode,
              tanggal: tanggal,
              amount: amount,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Branded header — gradient band with title pill on the left and a
/// rounded close button on the right. Pulled out so the dialog body
/// can focus on the file preview.
class _ProofHeader extends StatelessWidget {
  final LinearGradient gradient;
  final String fileType;
  const _ProofHeader({required this.gradient, required this.fileType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bukti Pembayaran',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        fileType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'File terverifikasi',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => AppNavigator.pop(context),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded info card — siswa / kelas / jenis on top, then a clean
/// 3-cell strip for Metode / Tanggal / Jumlah. Replaces the older
/// `FinanceInfoRow` strip that always rendered "-".
class _ProofInfoCard extends StatelessWidget {
  final String siswa;
  final String kelas;
  final String jenis;
  final String metode;
  final String tanggal;
  final String amount;
  final Color primaryColor;

  const _ProofInfoCard({
    required this.siswa,
    required this.kelas,
    required this.jenis,
    required this.metode,
    required this.tanggal,
    required this.amount,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_ind_outlined,
                size: 13,
                color: ColorUtils.slate500,
              ),
              const SizedBox(width: 5),
              Text(
                'INFORMASI PEMBAYARAN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Siswa + Kelas inline (avatar-style chips).
          Row(
            children: [
              Expanded(
                child: _ProofInfoTile(
                  icon: Icons.person_outline_rounded,
                  label: kFinStudent.tr,
                  value: siswa,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProofInfoTile(
                  icon: Icons.class_outlined,
                  label: kFinClass.tr,
                  value: kelas,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProofInfoTile(
            icon: Icons.category_outlined,
            label: kFinPaymentType.tr,
            value: jenis,
            accent: primaryColor,
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: ColorUtils.slate200),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProofMetaCell(
                  label: kFinMethod.tr,
                  value: metode,
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProofMetaCell(
                  label: kFinDate.tr,
                  value: tanggal,
                  icon: Icons.event_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _ProofMetaCell(
                  label: kFinAmount.tr,
                  value: amount,
                  icon: Icons.attach_money_rounded,
                  valueColor: ColorUtils.success600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProofInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const _ProofInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tone = accent ?? ColorUtils.slate500;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 15, color: tone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofMetaCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _ProofMetaCell({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: ColorUtils.slate400),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: valueColor ?? ColorUtils.slate900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Inline image preview for JPG/PNG/etc. proofs. Downloads the file
/// through the authenticated API endpoint so MinIO authorization works,
/// then displays it locally. Falls back to an error block if the download
/// fails, with a "Download & Open" CTA to view via the OS handler.
class _ImageProofView extends StatefulWidget {
  final String url;
  final Map<String, String>? headers;
  final String? paymentId;

  const _ImageProofView({required this.url, this.headers, this.paymentId});

  @override
  State<_ImageProofView> createState() => _ImageProofViewState();
}

class _ImageProofViewState extends State<_ImageProofView> {
  late Future<Uint8List> _downloadFuture;

  @override
  void initState() {
    super.initState();
    _downloadFuture = _downloadProof();
  }

  Future<Uint8List> _downloadProof() async {
    try {
      if (widget.paymentId == null || widget.paymentId!.isEmpty) {
        throw Exception('Payment ID not available');
      }
      return await ApiService.downloadFile(
        '/payment/${widget.paymentId}/receipt',
      );
    } catch (e) {
      AppLogger.error('payment-proof-download', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: Container(
        color: ColorUtils.slate100,
        width: double.infinity,
        child: FutureBuilder<Uint8List>(
          future: _downloadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: ColorUtils.slate600),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: ColorUtils.error600,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Gagal memuat pratinjau',
                      style: TextStyle(
                        color: ColorUtils.error600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Download file untuk melihat.',
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () => _downloadAndOpen(context),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download & Buka'),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return Center(
                child: Text(
                  'Tidak ada data',
                  style: TextStyle(color: ColorUtils.slate500),
                ),
              );
            }
            return Image.memory(
              snapshot.data!,
              width: double.infinity,
              fit: BoxFit.contain,
            );
          },
        ),
      ),
    );
  }

  Future<void> _downloadAndOpen(BuildContext context) async {
    if (!context.mounted) return;
    try {
      SnackBarUtils.showInfo(context, 'Mengunduh file...');
      final bytes = await _downloadFuture;

      // Determine file extension
      String ext = 'jpg';
      if (widget.url.contains('.png')) {
        ext = 'png';
      } else if (widget.url.contains('.pdf')) {
        ext = 'pdf';
      } else if (widget.url.contains('.webp')) {
        ext = 'webp';
      }

      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final fileName = 'Bukti_Pembayaran_$ts.$ext';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, 'File berhasil diunduh');

      await OpenFile.open(file.path);
    } catch (e) {
      AppLogger.error('payment-proof-download-open', e);
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal membuka file');
      }
    }
  }
}

/// PDF proofs — download through authenticated API endpoint and open
/// via the OS PDF viewer. Matches the parent success screen pattern.
class _PdfProofView extends StatefulWidget {
  final String url;
  final String? paymentId;

  const _PdfProofView({required this.url, this.paymentId});

  @override
  State<_PdfProofView> createState() => _PdfProofViewState();
}

class _PdfProofViewState extends State<_PdfProofView> {
  bool _isDownloading = false;

  Future<void> _downloadAndOpen() async {
    if (!mounted) return;
    if (_isDownloading) return;
    if (widget.paymentId == null || widget.paymentId!.isEmpty) {
      SnackBarUtils.showError(context, 'Payment ID tidak valid');
      return;
    }

    setState(() => _isDownloading = true);
    try {
      SnackBarUtils.showInfo(context, 'Mengunduh PDF...');
      final bytes = await ApiService.downloadFile(
        '/payment/${widget.paymentId}/receipt',
      );
      if (!mounted) return;

      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final fileName = 'Bukti_Pembayaran_$ts.pdf';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      SnackBarUtils.showSuccess(context, 'PDF berhasil diunduh');

      await OpenFile.open(file.path);
    } catch (e) {
      AppLogger.error('payment-proof-pdf-download', e);
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal membuka PDF');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 60,
            color: ColorUtils.error600,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Bukti pembayaran berupa file PDF',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Download file untuk melihat di aplikasi PDF.',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _isDownloading ? null : _downloadAndOpen,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Download & Buka PDF'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
