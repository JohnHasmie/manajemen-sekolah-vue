// "Cara bayar" accordion for the parent Bayar checkout screen — an
// expandable per-method step list.

part of '../parent_bill_checkout_screen.dart';

extension _ParentBillCheckoutHowTo on _ParentBillCheckoutScreenState {
  Widget _buildHowToAccordion() {
    final tip = switch (_method) {
      _PayMethod.qris => 'Buka GoPay / OVO / Dana / m-banking → Scan',
      _PayMethod.va => 'Buka m-banking → m-Transfer → Virtual Account',
      _PayMethod.manual => 'Transfer lalu unggah foto bukti di atas',
    };
    final title = switch (_method) {
      _PayMethod.qris => 'Cara bayar dengan QRIS',
      _PayMethod.va => 'Cara bayar via Virtual Account',
      _PayMethod.manual => 'Cara bayar transfer manual',
    };
    final steps = _howToStepsFor(_method);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _applyState(() => _howToExpanded = !_howToExpanded),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tip,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _howToExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      '▾',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.brandAzureDeep,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: _howToExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          for (var i = 0; i < steps.length; i++) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  margin: const EdgeInsets.only(top: 1),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.brandAzureDeep.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: ColorUtils.brandAzureDeep,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    steps[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.4,
                                      color: ColorUtils.slate700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (i < steps.length - 1) const SizedBox(height: 8),
                          ],
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step-by-step instructions per payment method. Kept here (and not
  /// in a separate widget file) because the accordion is the only
  /// surface that needs them and inlining keeps the strings near the
  /// UI they belong to.
  List<String> _howToStepsFor(_PayMethod method) {
    switch (method) {
      case _PayMethod.qris:
        return const [
          'Buka aplikasi pembayaran '
              '(GoPay, OVO, Dana, ShopeePay, atau m-banking).',
          'Pilih menu "Scan QRIS".',
          'Arahkan kamera ke QR di layar ini.',
          'Periksa nominal, lalu konfirmasi pembayaran.',
          'Status tagihan akan terupdate otomatis dalam kurang dari 1 menit.',
        ];
      case _PayMethod.va:
        return const [
          'Buka aplikasi m-banking bank Anda.',
          'Pilih menu "Transfer" → "Virtual Account / BI-Fast".',
          'Masukkan nomor Virtual Account yang tertera di layar.',
          'Pastikan nama tujuan adalah Yayasan Sekolah.',
          'Konfirmasi nominal dan selesaikan transfer.',
          'Status tagihan akan terupdate otomatis dalam kurang dari 1 menit.',
        ];
      case _PayMethod.manual:
        return const [
          'Transfer ke salah satu rekening sekolah yang tertera di atas.',
          'Pastikan nominal transfer sesuai dengan total tagihan.',
          'Simpan struk atau screenshot bukti transfer Anda.',
          'Tap tombol "Sudah transfer? Upload bukti" lalu pilih foto bukti.',
          'Admin akan memverifikasi pembayaran dalam 1–24 jam.',
        ];
    }
  }
}
