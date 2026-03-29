// PendingPaymentCard - extracted from admin_finance_screen.dart _buildPembayaranPendingCard.
//
// Displays a single pending payment awaiting admin verification.
// Like a Vue component `<PendingPaymentCard />` that receives all data and callbacks as props.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Card widget for a single pending payment entry.
///
/// Extracted from [FinanceScreen._buildPembayaranPendingCard] to keep the
/// parent file manageable. [isReadOnly] controls whether the verify button
/// is shown — passed in by the parent so this widget stays a plain [StatelessWidget]
/// with no Riverpod dependency.
class PendingPaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final int index;
  final bool isReadOnly;
  final VoidCallback onVerify;
  final VoidCallback onShowProof;
  final String Function(dynamic) formatCurrency;
  final Color primaryColor;

  const PendingPaymentCard({
    super.key,
    required this.payment,
    required this.index,
    required this.isReadOnly,
    required this.onVerify,
    required this.onShowProof,
    required this.formatCurrency,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onVerify,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: avatar + name + status badge
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ColorUtils.getColorForIndex(
                          index,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColorUtils.getColorForIndex(
                            index,
                          ).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (payment['siswa_nama'] ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.getColorForIndex(index),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment['siswa_nama'] ?? '-',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kelas ${payment['kelas_nama'] ?? '-'}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.warning600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.warning600.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: ColorUtils.warning600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Menunggu',
                            style: TextStyle(
                              color: ColorUtils.warning600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 10),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),

                // Info rows
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payment_rounded,
                            size: 10,
                            color: ColorUtils.slate500,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            payment['jenis_pembayaran_nama'] ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            size: 10,
                            color: ColorUtils.slate500,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            formatCurrency(payment['amount']),
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: ColorUtils.slate500,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            payment['payment_date']?.split('T')[0] ?? '-',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bukti Pembayaran
                if (payment['payment_receipt'] != null) ...[
                  SizedBox(height: 10),
                  GestureDetector(
                    onTap: onShowProof,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.corporateBlue600.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.photo_library_rounded,
                            size: 14,
                            color: ColorUtils.corporateBlue600,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Lihat Bukti Pembayaran',
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.corporateBlue600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: ColorUtils.corporateBlue600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Verifikasi button — only shown when not in read-only mode
                if (!isReadOnly) ...[
                  SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onVerify,
                      icon: Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Verifikasi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
