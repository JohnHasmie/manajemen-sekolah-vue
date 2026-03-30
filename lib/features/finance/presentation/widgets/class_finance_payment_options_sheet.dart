// Bottom-sheet showing payment options (manual pay, cancel, view detail) for a bill.
//
// Extracted from `_showPaymentOptions` in class_finance_report_screen.dart.
// Like a Vue component `<PaymentOptionsSheet :bill="bill" @manualPay="..." @cancel="..." @detail="..." />`
// that emits the chosen action back to the parent screen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Bottom-sheet widget that shows contextual payment options for a [bill].
///
/// Displays "Bayar Manual", "Batalkan Pembayaran", or "Lihat Detail" tiles
/// depending on the current bill status.  Each tile closes the sheet and
/// calls the corresponding callback so the parent screen handles the action.
class ClassFinancePaymentOptionsSheet extends StatelessWidget {
  final dynamic bill;
  final Color primaryColor;

  /// Called when the admin chooses "Bayar Manual".
  final VoidCallback onManualPay;

  /// Called when the admin chooses "Batalkan Pembayaran".
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

  LinearGradient get _cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
      );

  @override
  Widget build(BuildContext context) {
    final String currentStatus = bill['status'] ?? 'pending';
    final bool isPaid = currentStatus == 'verified';
    final statusColor =
        isPaid ? ColorUtils.success600 : ColorUtils.error600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorUtils.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              gradient: _cardGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payment_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opsi Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            isPaid
                                ? 'Status: Lunas'
                                : 'Status: Belum Lunas',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Options
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                if (!isPaid)
                  _buildOptionTile(
                    context: context,
                    icon: Icons.payment_rounded,
                    title: 'Bayar Manual',
                    subtitle: 'Tandai tagihan sebagai lunas',
                    color: ColorUtils.success600,
                    onTap: () {
                      AppNavigator.pop(context);
                      onManualPay();
                    },
                  ),
                if (isPaid) ...[
                  _buildOptionTile(
                    context: context,
                    icon: Icons.cancel_outlined,
                    title: 'Batalkan Pembayaran',
                    subtitle: 'Kembalikan status ke belum lunas',
                    color: ColorUtils.error600,
                    onTap: () {
                      AppNavigator.pop(context);
                      onCancelPayment();
                    },
                  ),
                ],
                AppSpacing.v10,
                _buildOptionTile(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'Lihat Detail',
                  subtitle: 'Riwayat dan informasi tagihan',
                  color: ColorUtils.corporateBlue600,
                  onTap: () {
                    AppNavigator.pop(context);
                    onViewDetail();
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    AppSpacing.v2,
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: ColorUtils.slate400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
