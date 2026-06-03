// Per-method payment cards for the parent Bayar checkout screen —
// QRIS, Virtual Account, and manual transfer surfaces.

part of '../parent_bill_checkout_screen.dart';

extension _ParentBillCheckoutMethodCards on _ParentBillCheckoutScreenState {
  Widget _buildMethodContent() {
    switch (_method) {
      case _PayMethod.qris:
        return _buildQrisCard();
      case _PayMethod.va:
        return _buildVaCard();
      case _PayMethod.manual:
        return _buildManualCard();
    }
  }

  Widget _buildQrisCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ParentCheckoutCountdownChip(expires: _session.expiresAt),
              const Spacer(),
              InkWell(
                onTap: _onCopyQrString,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    'Salin kode QR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.brandAzureDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Big QR placeholder. Real implementation passes
          // _session.qrString to a QR painter (e.g. qr_flutter).
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 160,
              height: 160,
              color: const Color(0xFF0F172A),
              alignment: Alignment.center,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  'QRIS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.brandAzureDeep,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Salin nominal pill
          ParentCheckoutCopyPill(
            label: 'Nominal',
            value: _formatRupiah(_session.totalFor(_method)),
            onCopy: () => _toastCopied('Nominal'),
          ),
        ],
      ),
    );
  }

  Widget _buildVaCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bank logo placeholder
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F4FAA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _session.vaBank,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'NOMOR VIRTUAL ACCOUNT',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _session.vaNumber,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              ParentCheckoutCopyPill(
                value: 'Salin',
                onCopy: () => _toastCopied('Nomor VA'),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Text(
            'JUMLAH',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(_session.totalFor(_method)),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '+ admin ${_formatRupiah(_session.adminFeeFor(_method))}',
                style: TextStyle(fontSize: 9.5, color: ColorUtils.slate500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualCard() {
    return Container(
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
            'TRANSFER KE REKENING SEKOLAH',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final bank in _session.manualBankList) ...[
            ParentCheckoutBankRow(
              bank: bank.$1,
              account: bank.$2,
              owner: bank.$3,
              onCopy: () => _toastCopied('Nomor rekening ${bank.$1}'),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          // Upload bukti CTA — taps fire `_pickAndUploadProof`, which
          // pushes through ApiService.uploadFile → backend
          // POST /bill/{id}/payment-proof (parent-owned bills only,
          // status forced to 'pending'). Shows a spinner while in
          // flight so the user can't double-submit.
          InkWell(
            onTap: _isUploading ? null : _pickAndUploadProof,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ColorUtils.brandAzureDeep,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.upload_file_rounded,
                      size: 16,
                      color: ColorUtils.brandAzureDeep,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _isUploading
                        ? 'Mengunggah bukti…'
                        : 'Sudah transfer? Upload bukti',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.brandAzureDeep,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
