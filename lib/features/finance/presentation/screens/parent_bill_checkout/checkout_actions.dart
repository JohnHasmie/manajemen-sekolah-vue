// User actions for the parent Bayar checkout screen — upload proof,
// help sheet, copy QR, check status, and small helpers.

part of '../parent_bill_checkout_screen.dart';

extension _ParentBillCheckoutActions on _ParentBillCheckoutScreenState {
  /// Open the native file picker and upload the chosen receipt to the
  /// backend. Backend route is the parent-only
  /// POST /bill/{billId}/payment-proof, which checks ownership and
  /// forces the payment row to `status='pending'` — the parent can
  /// never self-verify here.
  ///
  /// Errors are surfaced via [SnackBarUtils] without leaving the
  /// screen; the user can retry. Success pops back with `true` so the
  /// bills list refreshes and shows the new "pending" status row.
  Future<void> _pickAndUploadProof() async {
    if (_isUploading) return;

    final billId = widget.bill['id']?.toString();
    if (billId == null || billId.isEmpty) {
      SnackBarUtils.showError(context, 'ID tagihan tidak valid.');
      return;
    }

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'heic',
          'heif',
          'webp',
        ],
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      AppLogger.error('parent-bill-pick', e);
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Gagal membuka pemilih file.');
      return;
    }

    if (picked == null || picked.files.isEmpty) return; // user cancelled

    final filePath = picked.files.first.path;
    if (filePath == null || filePath.isEmpty) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'File tidak dapat dibaca.');
      return;
    }

    final file = File(filePath);
    final sizeMb = (await file.length()) / (1024 * 1024);
    if (sizeMb > 5) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Ukuran file ${sizeMb.toStringAsFixed(1)}MB melebihi batas 5MB. '
        'Mohon kompres atau pilih file lain.',
      );
      return;
    }

    _applyState(() => _isUploading = true);
    try {
      final response = await ApiService().uploadFile(
        '/bill/$billId/payment-proof',
        file,
        fileField: 'payment_receipt',
        data: const {'payment_method': 'manual_transfer'},
      );

      // Bill state has changed (unpaid → pending) — drop the cached
      // checkout session so a re-open hits the API and reflects the
      // new status instead of replaying the pre-upload snapshot.
      _sessionCache.remove(_cacheKey(billId));

      if (!mounted) return;

      // Extract the just-stored proof URL and payment ID from the upload
      // response
      // so the success screen can wire its "Unduh Bukti" / "Bagikan"
      // actions to it without an extra network round-trip.
      String? proofUrl;
      String? paymentId;
      if (response is Map) {
        final data = response['data'];
        if (data is Map) {
          proofUrl = data['payment_proof_url']?.toString();
          final payment = data['payment'];
          if (payment is Map) {
            paymentId = payment['id']?.toString();
          }
        }
      }

      final billName =
          widget.bill['type']?.toString() ??
          widget.bill['name']?.toString() ??
          'Tagihan';
      final studentName =
          widget.bill['student_name']?.toString() ??
          widget.bill['student']?['name']?.toString() ??
          'Anak';

      // Push the success screen so the parent gets immediate visible
      // confirmation (timeline + bukti actions). Once they tap
      // Selesai (or back out), we pop the checkout with `true` so
      // the billing list refreshes and shows the new pending row.
      final successResult = await AppNavigator.push<bool>(
        context,
        ParentPaymentSuccessScreen(
          billName: billName,
          studentName: studentName,
          methodLabel: 'Transfer manual',
          amount: _session.amount,
          adminFee: _session.adminFeeFor(_method),
          isManualPending: true,
          paymentProofUrl: proofUrl,
          paymentId: paymentId,
        ),
      );

      if (!mounted) return;
      if (successResult == true) {
        AppNavigator.pop(context, true);
      }
    } catch (e) {
      AppLogger.error('parent-bill-upload', e);
      if (!mounted) return;
      _applyState(() => _isUploading = false);
      SnackBarUtils.showError(
        context,
        'Gagal mengunggah bukti. Mohon coba lagi.',
      );
    }
  }

  /// Bottom sheet shown when the user taps the top-right help icon.
  /// Lists the three payment methods with short guidance and a
  /// fallback contact line. Kept lightweight on purpose — the full
  /// step-by-step lives in the in-page accordion.
  void _showHelpSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        Widget bullet(IconData icon, String label, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: ColorUtils.brandAzureDeep.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: ColorUtils.brandAzureDeep),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Bantuan Pembayaran',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih metode yang paling nyaman untuk Anda.',
                  style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
                ),
                const SizedBox(height: 12),
                bullet(
                  Icons.qr_code_scanner_rounded,
                  'QRIS',
                  'Pembayaran tercepat. '
                      'Status tagihan terupdate otomatis < 1 menit.',
                ),
                bullet(
                  Icons.account_balance_rounded,
                  'Virtual Account',
                  'Transfer via m-banking ke nomor VA unik. '
                      'Status terupdate otomatis.',
                ),
                bullet(
                  Icons.upload_file_rounded,
                  'Transfer Manual',
                  'Transfer ke rekening sekolah lalu unggah bukti. '
                      'Verifikasi admin 1–24 jam.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 16,
                        color: Color(0xFF92400E),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ada kendala? Hubungi admin sekolah untuk bantuan.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
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
      },
    );
  }

  /// Copy the QRIS code string to the clipboard. The string is what a
  /// payment app would have scanned, so power users can paste it into
  /// the bank app's "Paste QRIS" flow when scanning doesn't work
  /// (e.g., poor lighting, single-device flow).
  Future<void> _onCopyQrString() async {
    final qr = _session.qrString;
    if (qr.isEmpty) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Kode QR belum tersedia.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: qr));
    if (!mounted) return;
    _toastCopied('Kode QR');
  }

  Future<void> _onCheckStatus() async {
    // Stub: pretend the gateway confirmed payment. Real
    // implementation polls /bill/{id}/status here and only pushes
    // success when the response is "paid".
    final billName = widget.bill['type']?.toString() ?? 'Tagihan';
    final studentName =
        widget.bill['student_name']?.toString() ??
        widget.bill['student']?['name']?.toString() ??
        'Anak';
    // For QRIS / VA the bill is already paid by the time we land
    // here (stub gateway), so the success screen renders in receipt
    // mode — pass through whatever bill fields we have so the
    // kuitansi line items aren't all "—".
    final classes = widget.bill['student']?['classes'];
    final className = classes is List && classes.isNotEmpty
        ? (classes.first is Map ? classes.first['name']?.toString() : null)
        : null;
    final periodStr = widget.bill['month']?.toString();

    final result = await AppNavigator.push<bool>(
      context,
      ParentPaymentSuccessScreen(
        billName: billName,
        studentName: studentName,
        methodLabel: _methodLabel,
        amount: _session.amount,
        adminFee: _session.adminFeeFor(_method),
        isManualPending: _method == _PayMethod.manual,
        // Bill payload already carries `payment_proof_url` when a
        // previous upload exists for this bill — surface it so the
        // success screen's Unduh / Bagikan actions stay live even
        // when the parent re-enters the checkout from the list.
        paymentProofUrl: widget.bill['payment_proof_url']?.toString(),
        paymentId: widget.bill['latest_payment_relation']?['id']?.toString(),
        schoolName:
            (widget.bill['school']?['name'] ??
                    widget.bill['school']?['school_name'])
                ?.toString(),
        className: className,
        period: periodStr != null && periodStr.isNotEmpty
            ? _humanMonthFromBill(periodStr)
            : null,
        paidAt: DateTime.now(), // gateway just confirmed
        verifiedAt: DateTime.now(), // gateway-paid = instantly verified
        billId: widget.bill['id']?.toString(),
      ),
    );
    if (result == true && mounted) {
      AppNavigator.pop(context, true);
    }
  }

  String get _methodLabel {
    switch (_method) {
      case _PayMethod.qris:
        return 'QRIS';
      case _PayMethod.va:
        return '${_session.vaBank} Virtual Account';
      case _PayMethod.manual:
        return 'Transfer manual';
    }
  }

  void _toastCopied(String label) {
    SnackBarUtils.showSuccess(context, '$label berhasil disalin');
  }
}
