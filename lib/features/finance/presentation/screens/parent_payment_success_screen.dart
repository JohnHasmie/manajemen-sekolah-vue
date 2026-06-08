// Pembayaran berhasil — Phase 5 surface D.
//
// Pushed by the Bayar checkout (surface C) when the gateway poll
// returns "paid". The page mirrors the v3 mockup:
//
//   • Success-green hero (gradient + dotted confetti accent), big
//     white check disc, "Pembayaran Berhasil" title, subtitle with
//     bill + student
//   • White card under the hero with the total amount + via-method
//     line
//   • Receipt timeline (3 dots): created → confirmed → recorded
//   • Action row: Unduh PDF + Bagikan + Selesai
//
// Pending variant
// ---------------
// For the manual-transfer flow (`isManualPending = true`) the hero
// flips to amber, the title becomes "Menunggu Verifikasi", and the
// timeline ends at step 2. Same widget — same call site, just one
// flag.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ParentPaymentSuccessScreen extends StatelessWidget {
  final String billName;
  final String studentName;
  final String methodLabel;
  final double amount;
  final double adminFee;

  /// True = manual flow finished upload, awaiting admin verification.
  /// Flips the hero from green to amber and the timeline to a
  /// 2-of-3 state.
  final bool isManualPending;

  /// URL of the payment proof file on the server (the bukti the
  /// parent just uploaded, or the receipt picked up from a paid
  /// bill). When non-null the "Unduh Bukti" / "Bagikan" actions are
  /// wired up; when null the row is hidden because there's nothing
  /// to download or share yet.
  final String? paymentProofUrl;

  /// Dynamic payment ID from the database, used to construct device-reachable
  /// authenticated proxy endpoints for the receipt image/PDF.
  final String? paymentId;

  // ─── Receipt-mode fields (used only when isManualPending=false) ─
  //
  // When the bill is verified/paid, the screen renders a printable
  // receipt card (KUITANSI PEMBAYARAN — school header, line-item
  // table, signature note) using these fields. They're optional so
  // the pending mode (which doesn't need them) can keep its current
  // hero+timeline layout untouched.

  /// School name printed at the top of the kuitansi.
  final String? schoolName;

  /// Class label (e.g., "7A") — line item on the kuitansi.
  final String? className;

  /// Bill period (e.g., "Mei 2026"). Only meaningful for recurring
  /// bills like SPP; null for one-time bills.
  final String? period;

  /// When the payment was made (or the parent's upload time for
  /// manual flow). Falls back to "now" when not provided.
  final DateTime? paidAt;

  /// When the admin verified the payment. Null until verified.
  final DateTime? verifiedAt;

  /// Admin who verified the payment. Falls back to "Admin Sekolah".
  final String? verifierName;

  /// Bill id — used to derive the receipt number when one isn't
  /// supplied. Format: `KW-{YYYYMMDD}-{first 6 of billId, upper}`.
  final String? billId;

  const ParentPaymentSuccessScreen({
    super.key,
    required this.billName,
    required this.studentName,
    required this.methodLabel,
    required this.amount,
    required this.adminFee,
    this.isManualPending = false,
    this.paymentProofUrl,
    this.paymentId,
    this.schoolName,
    this.className,
    this.period,
    this.paidAt,
    this.verifiedAt,
    this.verifierName,
    this.billId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    // Pending → amount + timeline (existing flow);
                    // Paid → kuitansi receipt card (school header,
                    // line items, verifikasi info). The two states
                    // intentionally diverge: pending is "tracking
                    // your upload", paid is "here's your receipt".
                    if (isManualPending) ...[
                      _buildAmountCard(),
                      AppSpacing.v16,
                      _buildTimelineCard(),
                    ] else
                      _buildReceiptCard(),
                    AppSpacing.v16,
                    _buildActionsRow(context),
                    AppSpacing.v8,
                    _buildSelesaiButton(context),
                    AppSpacing.v16,
                    Text(
                      isManualPending
                          ? 'Bukti diteruskan ke admin sekolah '
                                'untuk verifikasi.'
                          : 'Notifikasi lunas otomatis dikirim '
                                'ke admin sekolah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────── pieces ──────────────

  Widget _buildHero() {
    final gradientStart = isManualPending
        ? const Color(0xFFF59E0B)
        : ColorUtils.success600;
    final gradientEnd = isManualPending
        ? const Color(0xFFB45309)
        : const Color(0xFF059669);
    final iconColor = isManualPending
        ? const Color(0xFFB45309)
        : ColorUtils.success600;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isManualPending ? Icons.access_time_rounded : Icons.check_rounded,
              color: iconColor,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isManualPending ? 'Menunggu Verifikasi' : 'Pembayaran Berhasil',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$billName · $studentName',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    final total = amount + adminFee;
    final color = isManualPending
        ? const Color(0xFFB45309)
        : ColorUtils.success600;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isManualPending ? 'NOMINAL DIKIRIM' : 'JUMLAH DIBAYAR',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatRupiah(total),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'via $methodLabel · ${_formatTodayShort()}',
            style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }

  /// Printable kuitansi card for verified payments. Mirrors the
  /// shape of a paper receipt: school header → receipt number → line
  /// items → total → verifikasi footer. Designed to look right when
  /// the parent screenshots the screen and forwards it.
  Widget _buildReceiptCard() {
    final total = amount + adminFee;
    final receiptNo = _resolveReceiptNumber();
    final dateLabel = _formatDate(paidAt ?? DateTime.now());
    final verifiedLabel = verifiedAt != null
        ? '${_formatDate(verifiedAt!)} • ${verifierName ?? 'Admin Sekolah'}'
        : (verifierName ?? 'Admin Sekolah');

    Widget row(String label, String value, {bool emphasized = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
              ),
            ),
            Text(
              ':  ',
              style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: emphasized ? 13 : 11.5,
                  fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — kuitansi label + receipt number ────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ColorUtils.success600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'KUITANSI PEMBAYARAN',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.success600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                receiptNo,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if ((schoolName ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              schoolName!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate900,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const _DottedDivider(),
          const SizedBox(height: AppSpacing.md),

          // ── Line items ─────────────────────────────────────────
          row('Siswa', studentName),
          if ((className ?? '').isNotEmpty) row('Kelas', className!),
          row('Jenis', billName),
          if ((period ?? '').isNotEmpty) row('Periode', period!),
          row('Tanggal', dateLabel),
          row('Metode', methodLabel),
          row('Diverifikasi', verifiedLabel),

          const SizedBox(height: AppSpacing.md),
          const _DottedDivider(),
          const SizedBox(height: AppSpacing.md),

          // ── Total line — emphasized, like a restaurant receipt ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'TOTAL DIBAYAR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                _formatRupiah(total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.success600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (adminFee > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Termasuk admin ${_formatRupiah(adminFee)}',
                  style: TextStyle(fontSize: 9.5, color: ColorUtils.slate500),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // ── Verified stamp — gives the screenshot some authority ─
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ColorUtils.success600.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ColorUtils.success600.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: ColorUtils.success600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LUNAS DAN TERVERIFIKASI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.success600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Diterbitkan secara elektronik oleh KamilEdu.',
                        style: TextStyle(
                          fontSize: 10,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build receipt number from billId + paid date, or fall back to a
  /// date-only format. The format reads like a real receipt code
  /// (KW-YYYYMMDD-XXXXXX) so screenshots feel official.
  String _resolveReceiptNumber() {
    final date = paidAt ?? DateTime.now();
    final ymd =
        '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
    final tail = (billId == null || billId!.length < 6)
        ? date.millisecondsSinceEpoch.toString().substring(0, 6)
        : billId!.replaceAll('-', '').substring(0, 6).toUpperCase();
    return 'KW-$ymd-$tail';
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Widget _buildTimelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIWAYAT',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _TimelineStep(
            label: kFinPaymentCreated.tr,
            sub: '${_formatTimeShort()} · $methodLabel',
            done: true,
          ),
          const _TimelineConnector(done: true),
          _TimelineStep(
            label: isManualPending
                ? 'Bukti pembayaran diunggah'
                : 'Pembayaran dikonfirmasi',
            sub: isManualPending
                ? '${_formatTimeShort()} · menunggu admin verifikasi'
                : '${_formatTimeShort()} · gateway',
            done: true,
          ),
          _TimelineConnector(done: !isManualPending),
          _TimelineStep(
            label: isManualPending
                ? 'Verifikasi admin (1–24 jam)'
                : 'Tagihan ditandai LUNAS',
            sub: isManualPending
                ? 'Status akan berubah otomatis'
                : '${_formatTimeShort()} · Kuitansi tersedia',
            done: !isManualPending,
            isPending: isManualPending,
          ),
        ],
      ),
    );
  }

  /// Build the Unduh / Bagikan action row. Returns an empty
  /// `SizedBox.shrink()` when there's no proof URL to act on — for
  /// gateway-confirmed payments without a generated PDF receipt yet
  /// the row would just be two non-functional buttons, which is what
  /// confused the user originally.
  Widget _buildActionsRow(BuildContext context) {
    final hasProof = paymentProofUrl != null && paymentProofUrl!.isNotEmpty;
    if (!hasProof) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: _SecondaryButton(
            icon: Icons.download_rounded,
            label: kFinDownloadProof.tr,
            onTap: () => _onDownloadProof(context),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SecondaryButton(
            icon: Icons.share_rounded,
            label: kFinShare.tr,
            onTap: () => _onShareProof(context),
          ),
        ),
      ],
    );
  }

  /// Open the uploaded bukti in the OS's external handler (browser
  /// for images / PDF viewer for PDFs). url_launcher with
  /// `LaunchMode.externalApplication` is the lightest path that
  /// doesn't require a download-manager package; the browser handles
  /// the save-to-device gesture from there.
  Future<void> _onDownloadProof(BuildContext context) async {
    final id = paymentId;
    if (id != null && id.isNotEmpty) {
      SnackBarUtils.showInfo(context, 'Mengunduh bukti pembayaran…');
      try {
        final bytes = await ApiService.downloadFile('/payment/$id/receipt');

        String ext = 'jpg';
        if (paymentProofUrl != null) {
          final cleanUrl = paymentProofUrl!.split('?').first.toLowerCase();
          if (cleanUrl.endsWith('.pdf')) {
            ext = 'pdf';
          } else if (cleanUrl.endsWith('.png')) {
            ext = 'png';
          } else if (cleanUrl.endsWith('.webp')) {
            ext = 'webp';
          }
        }

        final fileName = 'Bukti_Pembayaran_${id.substring(0, 8)}.$ext';
        final dir = await getTemporaryDirectory();
        final localFile = File('${dir.path}/$fileName');
        await localFile.writeAsBytes(bytes, flush: true);

        if (!context.mounted) return;
        SnackBarUtils.showSuccess(
          context,
          'Bukti pembayaran berhasil diunduh.',
        );

        final result = await OpenFile.open(localFile.path);
        if (result.type != ResultType.done && context.mounted) {
          SnackBarUtils.showError(
            context,
            kFinFileOpenError.tr.replaceFirst(
              '\${result.message}',
              result.message,
            ),
          );
        }
        return;
      } catch (e) {
        AppLogger.error('parent-success-download-proxy', e);
        // Fall back to direct url launch
      }
    }

    final raw = paymentProofUrl;
    if (raw == null || raw.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showInfo(context, 'Bukti belum tersedia.');
      }
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'URL bukti tidak valid.');
      }
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        SnackBarUtils.showError(context, 'Tidak dapat membuka bukti.');
      }
    } catch (e) {
      AppLogger.error('parent-success-download', e);
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal membuka bukti.');
      }
    }
  }

  /// Copy a share-friendly summary (label, nominal, status, bukti
  /// URL) to the clipboard so the parent can paste it into WhatsApp /
  /// email. A native share-sheet would be nicer but requires the
  /// share_plus package — clipboard is good enough for now and
  /// doesn't add a dependency.
  Future<void> _onShareProof(BuildContext context) async {
    final url = paymentProofUrl;
    if (url == null || url.isEmpty) {
      SnackBarUtils.showInfo(context, 'Belum ada bukti untuk dibagikan.');
      return;
    }
    final total = amount + adminFee;
    final statusLine = isManualPending
        ? 'Status: Menunggu verifikasi admin'
        : 'Status: Lunas';
    final summary = [
      '$billName · $studentName',
      'Nominal: ${_formatRupiah(total)}',
      'Metode: $methodLabel',
      'Tanggal: ${_formatTodayShort()}',
      statusLine,
      'Bukti: $url',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: summary));
    if (!context.mounted) return;
    SnackBarUtils.showSuccess(
      context,
      'Detail tersalin — paste ke WhatsApp / email.',
    );
  }

  Widget _buildSelesaiButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          // Let the caller handle the pop to avoid double-pop race conditions
          Navigator.of(context).pop(true);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorUtils.brandAzureDeep,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Selesai',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Dotted horizontal divider — the receipt-paper aesthetic between
/// the header, line items, and total. Paints a row of small dots
/// across the available width.
class _DottedDivider extends StatelessWidget {
  const _DottedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dotSize = 2.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dotSize + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dotSize,
              height: dotSize,
              margin: const EdgeInsets.symmetric(horizontal: gap / 2),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final String sub;
  final bool done;
  final bool isPending;

  const _TimelineStep({
    required this.label,
    required this.sub,
    required this.done,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPending
        ? const Color(0xFFF59E0B)
        : (done ? ColorUtils.success600 : const Color(0xFFCBD5E1));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(
            isPending
                ? Icons.access_time_rounded
                : (done ? Icons.check_rounded : Icons.circle_outlined),
            size: 12,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: done ? ColorUtils.slate900 : ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  final bool done;

  const _TimelineConnector({required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(
        width: 2,
        height: 16,
        color: done ? ColorUtils.success600 : const Color(0xFFCBD5E1),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: ColorUtils.brandAzureDeep),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatRupiah(double amount) {
  final whole = amount.round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final remain = s.length - i;
    buf.write(s[i]);
    if (remain > 1 && (remain - 1) % 3 == 0) buf.write('.');
  }
  return 'Rp $buf';
}

String _formatTodayShort() {
  final n = DateTime.now();
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${n.day} ${months[n.month - 1]} ${n.year}';
}

String _formatTimeShort() {
  final n = DateTime.now();
  final h = n.hour.toString().padLeft(2, '0');
  final m = n.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
