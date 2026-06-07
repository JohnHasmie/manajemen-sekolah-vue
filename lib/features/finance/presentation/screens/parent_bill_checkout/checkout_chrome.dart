// Page chrome for the parent Bayar checkout screen — title bar, bill
// recap hero, method tabs, status hint, and the sticky footer CTA.

part of '../parent_bill_checkout_screen.dart';

extension _ParentBillCheckoutChrome on _ParentBillCheckoutScreenState {
  Widget _buildTitleBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => AppNavigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: ColorUtils.slate600,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Bayar Tagihan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
          ),
          // Help button — opens a bottom sheet with method-specific
          // payment instructions and a fallback contact line.
          InkWell(
            onTap: _showHelpSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.help_outline_rounded,
                size: 18,
                color: ColorUtils.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRecap() {
    final billName = widget.bill['type']?.toString() ?? 'Tagihan';
    final studentName =
        widget.bill['student_name']?.toString() ??
        widget.bill['student']?['name']?.toString() ??
        '';
    final headerLabel = studentName.isEmpty
        ? billName.toUpperCase()
        : '${billName.toUpperCase()} · ${studentName.toUpperCase()}';
    final adminFee = _session.adminFeeFor(_method);
    final total = _session.totalFor(_method);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Use the canonical wali gradient helper so this recap card stays
        // in lockstep with every other parent hero/recap surface. The
        // explicit two-stop `[brandAzure, brandAzureDeep]` it replaced is
        // literally what `brandGradient('wali')` returns.
        gradient: ColorUtils.brandGradient('wali'),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headerLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Total dibayar',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (adminFee > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '+ admin ${_formatRupiah(adminFee)} ▾',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTabs() {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ParentCheckoutMethodTab(
            label: kFinQRIS.tr,
            caption: '⚡ Tercepat',
            active: _method == _PayMethod.qris,
            onTap: () => _applyState(() {
              _method = _PayMethod.qris;
              _howToExpanded = false;
            }),
          ),
          ParentCheckoutMethodTab(
            label: kFinVirtualAccount.tr,
            caption: 'BCA / Mandiri',
            active: _method == _PayMethod.va,
            onTap: () => _applyState(() {
              _method = _PayMethod.va;
              _howToExpanded = false;
            }),
          ),
          ParentCheckoutMethodTab(
            label: kFinManual.tr,
            caption: 'Upload bukti',
            active: _method == _PayMethod.manual,
            onTap: () => _applyState(() {
              _method = _PayMethod.manual;
              _howToExpanded = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHint() {
    final manual = _method == _PayMethod.manual;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: manual ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: manual ? const Color(0xFFF59E0B) : ColorUtils.success600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              manual
                  ? 'Verifikasi admin 1–24 jam setelah upload bukti'
                  : 'Status akan terupdate otomatis < 1 menit',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: manual ? const Color(0xFF92400E) : ColorUtils.success600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _onCheckStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorUtils.brandAzureDeep,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Saya sudah bayar — Cek status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
