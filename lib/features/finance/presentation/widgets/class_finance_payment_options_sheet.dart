// Options bottom sheet for an UNPAID bill row.
//
// Triggered when admin taps a "Belum" cell on the class finance report.
// Paid bills bypass this sheet entirely — `showPaymentOptions` on
// `ClassFinancePaymentMixin` routes them straight to the detail sheet
// since "Bayar Manual" doesn't make sense for an already-settled bill.
//
// Built on top of the shared `AppBottomSheet` so the navy gradient
// header + safe-area padding + drag handle match every other admin
// sheet in the app.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';

class ClassFinancePaymentOptionsSheet extends StatelessWidget {
  final dynamic bill;
  final Color primaryColor;

  /// Called when the admin chooses "Bayar Manual".
  final VoidCallback onManualPay;

  /// Called when the admin chooses "Batalkan Pembayaran" — only relevant
  /// when the bill is paid. Currently never invoked because paid bills
  /// skip this sheet, but the prop is kept so the report screen wiring
  /// doesn't need to change.
  final VoidCallback onCancelPayment;

  /// Called when the admin chooses "Lihat Detail".
  final VoidCallback onViewDetail;

  const ClassFinancePaymentOptionsSheet({
    super.key,
    required this.bill,
    required this.primaryColor,
    required this.onManualPay,
    required this.onCancelPayment,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    // Sheet is only shown for unpaid bills now — see
    // `ClassFinancePaymentMixin.showPaymentOptions`. We keep an
    // internal flag rather than removing the paid branch entirely so
    // that if a caller in another part of the app reaches this widget
    // with a paid bill, it still degrades gracefully.
    final String status = (bill?['status'] ?? 'pending').toString();
    final bool isPaid =
        status == 'paid' || status == 'verified' || status == 'success';

    return AppBottomSheet(
      title: kFinPaymentOptions.tr,
      subtitle: isPaid ? 'Status: Lunas' : 'Status: Belum Lunas',
      icon: Icons.account_balance_wallet_rounded,
      primaryColor: primaryColor,
      maxHeightFactor: 0.5,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isPaid)
            _OptionTile(
              icon: Icons.payments_rounded,
              title: kFinManualPayment.tr,
              subtitle: 'Catat pembayaran tunai / transfer',
              tone: _OptionTone.success,
              onTap: () {
                AppNavigator.pop(context);
                onManualPay();
              },
            ),
          if (!isPaid) const SizedBox(height: AppSpacing.sm),
          _OptionTile(
            icon: Icons.receipt_long_rounded,
            title: kFinViewDetails.tr,
            subtitle: kFinBillInfoHistory.tr,
            tone: _OptionTone.neutral,
            onTap: () {
              AppNavigator.pop(context);
              onViewDetail();
            },
          ),
          if (isPaid) ...[
            const SizedBox(height: AppSpacing.sm),
            _OptionTile(
              icon: Icons.undo_rounded,
              title: kFinCancelPaymentBtn.tr,
              subtitle: kFinRevertToUnpaid.tr,
              tone: _OptionTone.danger,
              onTap: () {
                AppNavigator.pop(context);
                onCancelPayment();
              },
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionTone { success, neutral, danger }

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _OptionTone tone;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  Color get _accent => switch (tone) {
    _OptionTone.success => ColorUtils.success600,
    _OptionTone.danger => ColorUtils.error600,
    _OptionTone.neutral => ColorUtils.corporateBlue600,
  };

  @override
  Widget build(BuildContext context) {
    final color = _accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: ColorUtils.slate400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
