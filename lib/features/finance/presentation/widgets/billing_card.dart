import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class BillingCard extends StatelessWidget {
  final Map<String, dynamic> billing;
  final VoidCallback onTap;
  final LanguageProvider languageProvider;

  const BillingCard({
    super.key,
    required this.billing,
    required this.onTap,
    required this.languageProvider,
  });

  String _formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final double value = double.parse(amount.toString());
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      return formatter.format(value);
    } catch (e) {
      return 'Rp $amount';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = billing['status']?.toString().toLowerCase() ?? 'unpaid';
    final type =
        (billing['type'] ?? billing['periode'])?.toString().toLowerCase() ??
        'bulanan';
    final isRead =
        billing['is_read'] == true ||
        billing['is_read'] == 1 ||
        billing['is_read'] == '1';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'verified':
        statusColor = ColorUtils.success600;
        statusText = languageProvider.getTranslatedText({
          'en': 'Verified',
          'id': 'Terverifikasi',
        });
        statusIcon = Icons.check_circle_outline;
        break;
      case 'pending':
        statusColor = ColorUtils.warning600;
        statusText = languageProvider.getTranslatedText({
          'en': 'Pending',
          'id': 'Tertunda',
        });
        statusIcon = Icons.history;
        break;
      default:
        statusColor = ColorUtils.error600;
        statusText = languageProvider.getTranslatedText({
          'en': 'Unpaid',
          'id': 'Belum Bayar',
        });
        statusIcon = Icons.error_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: isRead
              ? ColorUtils.slate200
              : statusColor.withValues(alpha: 0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            billing['name'] ??
                                billing['title'] ??
                                billing['jenis_pembayaran_nama'] ??
                                '-',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          AppSpacing.v4,
                          Text(
                            billing['description'] ??
                                billing['jenis_pembayaran_deskripsi'] ??
                                '-',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1, color: ColorUtils.slate100),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Amount',
                            'id': 'Jumlah',
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate400,
                          ),
                        ),
                        AppSpacing.v2,
                        Text(
                          _formatCurrency(billing['amount']),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Method',
                            'id': 'Metode',
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate400,
                          ),
                        ),
                        AppSpacing.v2,
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isRead)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorUtils.primary.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'NEW',
                            'id': 'BARU',
                          }),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: ColorUtils.primary,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
