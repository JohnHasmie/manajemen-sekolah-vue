// Three-card stats row shown at the top of the finance dashboard tab.
//
// Extracted from `_buildDashboardStats` in admin_finance_screen.dart.
// Like a Vue `<FinanceDashboardStats>` presentational component.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_stat_card.dart';

/// A horizontal row of three [FinanceStatCard] tiles: unpaid, verified, pending.
///
/// Equivalent to calling `_buildDashboardStats()` on the parent screen.
/// Pure [StatelessWidget] — all data is passed in via constructor params
/// so this widget owns zero state (like a presentational Vue component).
class FinanceDashboardStats extends StatelessWidget {
  /// Raw value from `dashboardData['tagihan_belum_dibayar']`.
  final dynamic unpaidCount;

  /// Raw value from `dashboardData['tagihan_terverifikasi']`.
  final dynamic verifiedCount;

  /// Total pending payment count (from `_totalPendingPayments` in the parent).
  final int totalPendingPayments;

  /// The [LanguageProvider] used for translating label text.
  /// Passed in rather than read via `ref` so the widget stays stateless.
  final LanguageProvider languageProvider;

  /// Brand primary colour forwarded to each card's colour tint.
  final Color primaryColor;

  const FinanceDashboardStats({
    super.key,
    required this.unpaidCount,
    required this.verifiedCount,
    required this.totalPendingPayments,
    required this.languageProvider,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: FinanceStatCard(
              icon: Icons.receipt_long_rounded,
              value: '${unpaidCount ?? 0}',
              label: languageProvider.getTranslatedText(
                AppLocalizations.unpaid,
              ),
              color: ColorUtils.warning600,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: FinanceStatCard(
              icon: Icons.verified_rounded,
              value: '${verifiedCount ?? 0}',
              label: languageProvider.getTranslatedText(
                AppLocalizations.verified,
              ),
              color: ColorUtils.success600,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: FinanceStatCard(
              icon: Icons.pending_actions_rounded,
              value: '$totalPendingPayments',
              label: languageProvider.getTranslatedText({
                'en': 'Pending',
                'id': 'Menunggu',
              }),
              color: ColorUtils.corporateBlue600,
            ),
          ),
        ],
      ),
    );
  }
}
