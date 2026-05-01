import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/parent_bill_checkout_screen.dart';

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

  /// Translate raw period strings to Indonesian. P0 #7 from
  /// UI_Redesign_Audit.md: parent billing displayed "ONCE" / "MONTHLY"
  /// in English while the rest of the app is Bahasa Indonesia. The API
  /// returns the period in either lower or upper case under `type` /
  /// `periode`; map both shapes here so callers can render directly.
  String _translatePeriod(String raw) {
    switch (raw.toLowerCase()) {
      case 'once':
      case 'sekali':
        return 'Sekali';
      case 'monthly':
      case 'bulanan':
        return 'Bulanan';
      case 'weekly':
      case 'mingguan':
        return 'Mingguan';
      case 'yearly':
      case 'tahunan':
        return 'Tahunan';
      case 'daily':
      case 'harian':
        return 'Harian';
      default:
        // Fall back to a friendly capitalize-each-word form rather than
        // the all-caps shout that triggered the original bug.
        if (raw.isEmpty) return '-';
        return raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
  }

  /// Format an ISO date string ("2026-05-15" or "2026-05-15T00:00:00")
  /// into a compact Indonesian short-date ("15 Mei 2026"). Returns an
  /// empty string when the input is null or unparseable so callers can
  /// hide the field gracefully.
  String _formatDueDate(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString();
    if (str.isEmpty) return '';
    DateTime? parsed;
    try {
      parsed = DateTime.parse(str);
    } catch (_) {
      return '';
    }
    const monthsId = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${parsed.day} ${monthsId[parsed.month - 1]} ${parsed.year}';
  }

  /// Phase-5 surface C+D — opens the new full-screen Bayar checkout.
  /// Replaces the previous AppAlertDialog stub. The bill payload is
  /// passed straight through; the checkout reads `amount`, `type`,
  /// `student.name`, `student_name` for its recap card.
  ///
  /// When the checkout returns `true` (payment + verification or
  /// upload completed), the caller can refresh the bill list to
  /// reflect the new status.
  Future<bool?> _openCheckout(BuildContext context) {
    return openParentBillCheckout(context, bill: billing);
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
                          // PR-10 / P0 #7: was `type.toUpperCase()` →
                          // "ONCE" / "MONTHLY" in English. Translated.
                          _translatePeriod(type),
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
                // Due-date row — P0 #9: parent rows previously had no
                // due-date visible. Try multiple field-name shapes the API
                // may return; render only when present.
                Builder(
                  builder: (_) {
                    final dueRaw = billing['due_date'] ??
                        billing['jatuh_tempo'] ??
                        billing['tanggal_jatuh_tempo'];
                    final formatted = _formatDueDate(dueRaw);
                    if (formatted.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 13,
                            color: ColorUtils.slate400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Due',
                              'id': 'Jatuh tempo',
                            }),
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatted,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Bayar Sekarang CTA — P0 #8. Only show when the bill is
                // actionable (unpaid). Verified / pending bills don't get
                // a pay button.
                if (status == 'unpaid' || status == 'belum_bayar') ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openCheckout(context),
                      icon: const Icon(
                        Icons.account_balance_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Pay Now',
                          'id': 'Bayar Sekarang',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.getRoleColor('wali'),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
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
