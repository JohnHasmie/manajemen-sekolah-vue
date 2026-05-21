import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/confirmation_dialog.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/class_finance_report_screen.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_finance_report_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_report_models.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_proof_dialog.dart';

/// Mixin for UI building methods in class finance report.
mixin ClassFinanceUIMixin on State<ClassFinanceReportScreen> {
  /// Builds a filter chip widget.
  Widget buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 12, color: getPrimaryColor()),
      ),
      backgroundColor: getPrimaryColor().withValues(alpha: 0.1),
      deleteIcon: Icon(Icons.close, size: 16, color: getPrimaryColor()),
      onDeleted: onDeleted,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: getPrimaryColor().withValues(alpha: 0.2)),
      ),
    );
  }

  /// Shows filter sheet modal.
  void showFilterSheet(
    List<MonthGroup> monthGroups,
    String selectedStatus,
    String? selectedMonthKey,
    String? selectedPaymentTypeId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClassFinanceReportFilterSheet(
        primaryColor: getPrimaryColor(),
        selectedStatus: selectedStatus,
        selectedMonthKey: selectedMonthKey,
        selectedPaymentTypeId: selectedPaymentTypeId,
        monthGroups: monthGroups,
        onStatusChanged: onStatusFilterChanged,
        onMonthChanged: onMonthFilterChanged,
        onPaymentTypeChanged: onPaymentTypeFilterChanged,
      ),
    );
  }

  /// Shows the rich bill detail sheet.
  ///
  /// Rebuilt from the prior thin "Status / Jumlah / Tanggal / …"
  /// key-value list. The new layout has four bands:
  ///   1. Status hero (green / red / amber based on bill.status)
  ///   2. Bill info card — jenis, jumlah tagihan, tanggal buat, jatuh
  ///      tempo, keterangan
  ///   3. Latest verified payment block (only when the bill is paid)
  ///      with the receipt thumbnail / "Lihat Bukti" CTA. Tapping the
  ///      receipt opens the existing [PaymentProofDialog] image viewer
  ///      / PDF launcher.
  ///   4. Footer — "Tutup" + (paid only) "Batalkan Pembayaran" via the
  ///      [processManualPayment] hook the state already exposes.
  void showDetailDialog(dynamic bill) {
    if (bill == null) return;

    final status = (bill['status'] ?? '').toString();
    final isPaid =
        status == 'paid' || status == 'verified' || status == 'success';
    final hasPending = _hasPendingPayment(bill);

    AppBottomSheet.show<void>(
      context: context,
      title: 'Detail Tagihan',
      subtitle:
          bill['payment_type']?['name']?.toString() ??
          bill['jenis_pembayaran_nama']?.toString() ??
          'Tagihan siswa',
      icon: Icons.receipt_long_rounded,
      primaryColor: getPrimaryColor(),
      maxHeightFactor: 0.85,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusHero(isPaid: isPaid, hasPending: hasPending),
          const SizedBox(height: AppSpacing.md),
          _BillInfoCard(
            bill: bill,
            formatCurrency: formatRupiah,
            formatDate: formatDate,
          ),
          if (isPaid) ...[
            const SizedBox(height: AppSpacing.md),
            _PaymentReceiptCard(
              payment: _latestVerifiedPayment(bill),
              formatCurrency: formatRupiah,
              formatDate: formatDate,
              primaryColor: getPrimaryColor(),
              onTapReceipt: (p) => _openReceiptViewer(p, bill),
            ),
            // Destructive action lives in its own danger zone card,
            // *not* in the footer. Earlier we used a side-by-side
            // footer with the "Batalkan Pembayaran" label wrapping
            // onto two lines on phones — the dedicated zone is both
            // more legible and more typical of admin Zona Berbahaya
            // patterns in the rest of the app.
            const SizedBox(height: AppSpacing.md),
            _DangerZoneCancelCard(onTap: () => _confirmCancelPayment(bill)),
          ],
        ],
      ),
      // Single-button footer — Batal is gone because there's nothing
      // pending to discard on a detail sheet. We render the chrome
      // (hairline divider + safe-area) inline instead of reaching for
      // [BottomSheetFooter] which always renders the two-button row.
      footer: _DetailSheetFooter(
        primaryColor: getPrimaryColor(),
        onClose: () => AppNavigator.pop(context),
      ),
    );
  }

  /// Shows the danger-themed [ConfirmationDialog] before delegating to
  /// [processManualPayment] for the actual cancel call. Splitting the
  /// confirm step out lives here so other future entry-points (a
  /// payments list, etc.) can re-use it.
  Future<void> _confirmCancelPayment(dynamic bill) async {
    // We pop the detail sheet *first* so the confirmation dialog
    // doesn't stack on top of a sheet that the admin is still
    // looking at. After confirm-or-cancel, the parent state's
    // `processManualPayment` will refresh the list — the admin
    // doesn't need to be back on the detail anyway.
    AppNavigator.pop(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmationDialog(
        title: 'Batalkan Pembayaran?',
        content:
            'Status tagihan akan kembali ke "Belum Lunas" dan bukti pembayaran tetap tersimpan untuk arsip. Tindakan ini tidak dapat dibatalkan.',
        confirmText: 'Ya, Batalkan',
        confirmColor: ColorUtils.error600,
      ),
    );
    if (confirmed == true && mounted) {
      processManualPayment(bill, false);
    }
  }

  /// Implemented by the state class via ClassFinancePaymentMixin.
  /// Declared here so the detail sheet's "Batalkan Pembayaran" footer
  /// can call into the cancel flow without an explicit relay.
  Future<void> processManualPayment(dynamic bill, bool markAsPaid);

  // ── Detail sheet helpers ───────────────────────────────────────────

  bool _hasPendingPayment(dynamic bill) {
    final payments = bill['payments'];
    if (payments is! List) return false;
    for (final p in payments) {
      if (p is! Map) continue;
      final s = (p['status'] ?? '').toString();
      if (s == 'pending') return true;
    }
    return false;
  }

  Map<String, dynamic>? _latestVerifiedPayment(dynamic bill) {
    final payments = bill['payments'];
    if (payments is! List || payments.isEmpty) return null;
    Map<String, dynamic>? best;
    for (final p in payments) {
      if (p is! Map) continue;
      final s = (p['status'] ?? '').toString();
      if (s != 'verified' && s != 'success' && s != 'paid') continue;
      final m = Map<String, dynamic>.from(p);
      if (best == null) {
        best = m;
        continue;
      }
      final aDate = DateTime.tryParse((m['payment_date'] ?? '').toString());
      final bDate = DateTime.tryParse((best['payment_date'] ?? '').toString());
      if (aDate != null && bDate != null && aDate.isAfter(bDate)) {
        best = m;
      }
    }
    return best;
  }

  /// Open the receipt viewer for a paid bill's latest verified payment.
  ///
  /// We enrich the payment map with the bill's student / class / jenis
  /// context *before* handing it to [PaymentProofDialog] because the
  /// dialog's "Informasi Pembayaran" footer looks for keys like
  /// `siswa_nama`, `kelas_nama`, `jenis_pembayaran_nama` directly. The
  /// raw payment row from `bill.payments[]` doesn't carry those — they
  /// live on the parent bill — so without this step the dialog
  /// showed "-" for every field.
  ///
  /// Also prefers `payment_proof_proxy_url` over `payment_proof_url`
  /// when the backend provides it. The proxy URL streams through the
  /// Laravel API instead of a docker-internal MinIO hostname, which
  /// is what causes the "Gagal Memuat Gambar" error on iOS sim /
  /// Android emulator / real devices.
  Future<void> _openReceiptViewer(
    Map<String, dynamic> payment,
    dynamic bill,
  ) async {
    final enriched = Map<String, dynamic>.from(payment);

    // Build the proxy URL on the *client* side using ApiService.baseUrl —
    // this is whatever hostname the device is actually using to reach
    // the API (iOS sim → http://localhost:8001, Android emu →
    // http://10.0.2.2:8001, real device → the LAN IP). Trusting the
    // backend's `payment_proof_proxy_url` (built from `config('app.url')`
    // server-side) breaks when the Laravel APP_URL doesn't match the
    // mobile build's API_BASE_URL — which is exactly why we saw
    // "Gagal Memuat Gambar" again after the previous fix.
    //
    // The raw `payment_proof_url` from the backend points at the MinIO
    // bucket directly (`http://minio:9000/...`) and is never device-
    // reachable in dev — so we always overwrite when a payment id is
    // present.
    final paymentId = enriched['id']?.toString();
    if (paymentId != null && paymentId.isNotEmpty) {
      final base = ApiService.baseUrl;
      if (base.isNotEmpty) {
        final cleaned = base.endsWith('/')
            ? base.substring(0, base.length - 1)
            : base;
        // baseUrl typically already includes `/api`; strip it so we
        // don't double up when joining the receipt path.
        final root = cleaned.endsWith('/api')
            ? cleaned.substring(0, cleaned.length - 4)
            : cleaned;
        enriched['payment_proof_url'] = '$root/api/payment/$paymentId/receipt';
        // Pass the bearer token along too — the proxy route sits
        // behind `auth:sanctum`, so the viewer needs to send the same
        // auth headers the rest of the API uses.
        enriched['_proxy_auth_required'] = true;
      }
    }

    // Pull siswa / kelas / jenis names off the parent bill. Backend
    // returns these under both nested object form (`student.name`)
    // and pre-flattened form depending on which endpoint hydrated
    // the bill — we accept both.
    String? pick(Map src, List<String> keys) {
      for (final k in keys) {
        final parts = k.split('.');
        dynamic v = src;
        for (final p in parts) {
          if (v is Map && v[p] != null) {
            v = v[p];
          } else {
            v = null;
            break;
          }
        }
        if (v is String && v.isNotEmpty) return v;
        if (v != null) return v.toString();
      }
      return null;
    }

    if (bill is Map) {
      enriched['siswa_nama'] =
          enriched['siswa_nama'] ??
          pick(bill, ['student.name', 'siswa_nama', 'student_name']);
      enriched['kelas_nama'] =
          enriched['kelas_nama'] ??
          pick(bill, [
            'student.classes.name',
            'student.class.name',
            'kelas_nama',
            'class_name',
          ]);
      enriched['jenis_pembayaran_nama'] =
          enriched['jenis_pembayaran_nama'] ??
          pick(bill, [
            'payment_type.name',
            'jenis_pembayaran_nama',
            'payment_type_name',
          ]);
      // Carry the bill amount as a sensible fallback when the payment
      // row has no `amount` (rare, but defensive).
      enriched['amount'] =
          enriched['amount'] ??
          bill['amount'] ??
          bill['bill_amount'] ??
          bill['total_amount'];
    }

    // The proxy route sits behind `auth:sanctum`. Image.network won't
    // attach the app's Bearer token automatically, so we fetch the
    // headers here and pass them through to the dialog — without this
    // the proxy returns 401 and the user sees "Gagal Memuat Gambar"
    // even though the URL is correct.
    final headers = await ApiService.getHeaders();
    // Drop Content-Type — only the auth bits are useful for a GET.
    headers.remove('Content-Type');
    headers.remove('Accept');

    if (!mounted) return;
    showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      builder: (_) => PaymentProofDialog(
        payment: enriched,
        formatCurrency: formatRupiah,
        primaryColor: getPrimaryColor(),
        cardGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            getPrimaryColor(),
            getPrimaryColor().withValues(alpha: 0.78),
          ],
        ),
        imageHeaders: headers,
      ),
    );
  }

  String formatRupiah(dynamic value) {
    if (value == null) return 'Rp 0';
    final n = num.tryParse(value.toString());
    if (n == null) return 'Rp $value';
    // Thousand-grouped with `.` per ID locale, no decimals.
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${buf.toString()}';
  }

  /// Normalise a backend date / datetime string to a plain `YYYY-MM-DD`.
  ///
  /// The backend sends two flavours: ISO-with-T (`2026-05-21T08:30:00Z`)
  /// from JSON serialization, and SQL-format (`2026-05-21 00:00:00`)
  /// from raw casts. Earlier we only stripped on `T`, which left the
  /// space-form rendering as `2026-05-21 00:00:00` in the detail
  /// sheet's Tanggal cell. Splitting on both characters covers both
  /// cases — empty/null still returns `-`.
  String formatDate(dynamic date) {
    if (date == null) return '-';
    final raw = date.toString();
    if (raw.isEmpty) return '-';
    final cut = raw.indexOf(RegExp(r'[T ]'));
    return cut == -1 ? raw : raw.substring(0, cut);
  }

  /// Must be implemented by State to provide primary color.
  Color getPrimaryColor();

  /// Callback when status filter changes.
  void onStatusFilterChanged(String status);

  /// Callback when month filter changes.
  void onMonthFilterChanged(String? month);

  /// Callback when payment type filter changes.
  void onPaymentTypeFilterChanged(String? paymentTypeId);
}

// ======================================================================
// Detail sheet building blocks
// ======================================================================

/// Single-button footer for the detail sheet. Replaces the shared
/// [BottomSheetFooter] for this surface because a detail screen never
/// needs a Batal/Cancel — there's nothing pending to discard. The
/// chrome (hairline divider, safe-area padding, full-width primary)
/// is otherwise identical so the sheet still feels at home next to
/// every other admin sheet in the app.
class _DetailSheetFooter extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onClose;
  const _DetailSheetFooter({required this.primaryColor, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onClose,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Tutup',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Top "hero" inside the detail sheet — full-width status badge with
/// a soft tinted background and a leading icon. Colour-coded so the
/// admin gets the bill state in one glance before they read the meta
/// grid below.
class _StatusHero extends StatelessWidget {
  final bool isPaid;
  final bool hasPending;
  const _StatusHero({required this.isPaid, required this.hasPending});

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final IconData icon;
    final String label;
    final String sub;
    if (isPaid) {
      accent = ColorUtils.success600;
      icon = Icons.check_circle_rounded;
      label = 'Lunas';
      sub = 'Pembayaran telah diverifikasi admin.';
    } else if (hasPending) {
      accent = ColorUtils.warning600;
      icon = Icons.hourglass_top_rounded;
      label = 'Menunggu Verifikasi';
      sub = 'Bukti pembayaran sudah diunggah, menunggu admin.';
    } else {
      accent = ColorUtils.error600;
      icon = Icons.error_outline_rounded;
      label = 'Belum Lunas';
      sub = 'Belum ada pembayaran tercatat untuk tagihan ini.';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ColorUtils.slate600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bill metadata card — Jenis Pembayaran (with money pill on the right
/// = jumlah tagihan), then a 2-col grid for tanggal buat / jatuh tempo,
/// and an optional Keterangan row.
class _BillInfoCard extends StatelessWidget {
  final dynamic bill;
  final String Function(dynamic) formatCurrency;
  final String Function(dynamic) formatDate;

  const _BillInfoCard({
    required this.bill,
    required this.formatCurrency,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final jenis =
        bill['payment_type']?['name']?.toString() ??
        bill['jenis_pembayaran_nama']?.toString() ??
        '-';
    final jumlah =
        bill['amount'] ?? bill['bill_amount'] ?? bill['total_amount'];
    final created = formatDate(bill['created_at']);
    final due = formatDate(bill['due_date']);
    final desc = (bill['description']?.toString() ?? '').trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenis Pembayaran',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate500,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      jenis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatCurrency(jumlah),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.corporateBlue600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: ColorUtils.slate100),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateBlock(
                  label: 'Tanggal Buat',
                  value: created,
                  icon: Icons.event_note_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBlock(
                  label: 'Jatuh Tempo',
                  value: due,
                  icon: Icons.event_busy_outlined,
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty && desc != '-') ...[
            const SizedBox(height: 12),
            Text(
              'KETERANGAN',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate500,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DateBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: ColorUtils.slate500),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }
}

/// Card surfacing the latest verified payment for a paid bill —
/// method, date, amount, and a tap-to-view-receipt action that opens
/// the existing [PaymentProofDialog]. When the payment has no
/// `payment_proof_url` (cash entry with no upload), the receipt CTA
/// is replaced with a faded "Tidak ada bukti file" note.
class _PaymentReceiptCard extends StatelessWidget {
  final Map<String, dynamic>? payment;
  final String Function(dynamic) formatCurrency;
  final String Function(dynamic) formatDate;
  final Color primaryColor;
  final void Function(Map<String, dynamic> payment) onTapReceipt;

  const _PaymentReceiptCard({
    required this.payment,
    required this.formatCurrency,
    required this.formatDate,
    required this.primaryColor,
    required this.onTapReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    if (p == null) return const SizedBox.shrink();
    final method = (p['payment_method']?.toString() ?? '-');
    final date = formatDate(p['payment_date']);
    final amount = formatCurrency(p['amount']);
    final proofUrl = p['payment_proof_url']?.toString() ?? '';
    final hasProof = proofUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ColorUtils.success600.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ColorUtils.success600.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 14,
                color: ColorUtils.success600,
              ),
              const SizedBox(width: 6),
              Text(
                'BUKTI PEMBAYARAN',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.success600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Top row: Metode + Tanggal share the width (2 cells). Jumlah
          // gets its own emphasised pill underneath so the value has
          // room to breathe with a `Rp 1.500.000` string.
          Row(
            children: [
              Expanded(
                child: _ReceiptCell(
                  label: 'Metode',
                  value: method,
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReceiptCell(
                  label: 'Tanggal Bayar',
                  value: date,
                  icon: Icons.event_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ReceiptAmountPill(amount: amount),
          const SizedBox(height: 12),
          if (hasProof)
            Material(
              color: primaryColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => onTapReceipt(p),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        proofUrl.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lihat Bukti File',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: ColorUtils.slate500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tidak ada bukti file (pembayaran tunai)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _ReceiptCell({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: ColorUtils.slate400),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
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
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor ?? ColorUtils.slate900,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Inline destructive-action card shown on paid bills inside the detail
/// sheet. Replaces the cramped "Batalkan Pembayaran" footer-secondary
/// button that wrapped onto two lines on narrow devices. The CTA still
/// only fires the cancel after the admin confirms via
/// [ConfirmationDialog], wired by [_confirmCancelPayment] on the mixin.
class _DangerZoneCancelCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DangerZoneCancelCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final danger = ColorUtils.error600;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: danger),
              const SizedBox(width: 6),
              Text(
                'ZONA BERBAHAYA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: danger,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Membatalkan pembayaran akan mengembalikan status tagihan menjadi belum lunas. Lakukan hanya jika pembayaran tidak valid.',
            style: TextStyle(
              fontSize: 11.5,
              color: ColorUtils.slate600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.undo_rounded, size: 16),
              label: const Text(
                'Batalkan Pembayaran',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: danger,
                side: BorderSide(color: danger.withValues(alpha: 0.55)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dedicated full-width pill for the verified amount inside the receipt
/// card. Pulled out so the `Rp 1.500.000` value can lean into a softer
/// green panel without competing for width with Metode / Tanggal.
class _ReceiptAmountPill extends StatelessWidget {
  final String amount;
  const _ReceiptAmountPill({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ColorUtils.success600.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ColorUtils.success600.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_rounded, size: 14, color: ColorUtils.success600),
          const SizedBox(width: 8),
          Text(
            'Jumlah Disetor',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.success600,
              letterSpacing: 0.4,
            ),
          ),
          const Spacer(),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ColorUtils.success600,
            ),
          ),
        ],
      ),
    );
  }
}
