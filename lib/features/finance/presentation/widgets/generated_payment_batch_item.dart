import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/circle_action_button.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A single row card representing one generated payment batch.
///
/// Displays the batch name, formatted month, amount badge, and bill count
/// badge — equivalent to a `<v-list-item>` row in the Vue finance view.
///
/// Pure [StatelessWidget]; all data and callbacks are passed in so this
/// widget owns zero state (like a presentational Vue component).
class GeneratedPaymentBatchItem extends StatelessWidget {
  /// The raw data map for this batch (same shape as the API response).
  final Map<String, dynamic> item;

  /// Formats a `"YYYY-MM"` string into a human-readable month label,
  /// e.g. `"2024-03"` → `"Maret 2024"`.
  /// Equivalent to the `_formatMonth` helper on the parent screen.
  final String Function(String) formatMonth;

  /// Formats a numeric/dynamic amount into a currency string,
  /// e.g. `150000` → `"Rp 150.000"`.
  /// Equivalent to the `_formatCurrency` helper on the parent screen.
  final String Function(dynamic) formatCurrency;

  /// The brand primary color used for icon backgrounds and badge text.
  /// Passed in instead of calling `_getPrimaryColor()` directly so this
  /// widget stays stateless (no BuildContext dependency on theme).
  final Color primaryColor;

  /// Called when the user taps the delete button for this batch.
  /// The parent screen passes `() => _deleteGeneratedBills(item)` here.
  final VoidCallback onDelete;

  const GeneratedPaymentBatchItem({
    super.key,
    required this.item,
    required this.formatMonth,
    required this.formatCurrency,
    required this.primaryColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? 'No Name';
    final monthStr = item['month'] ?? '';
    final formattedMonth = formatMonth(monthStr);
    final amount = formatCurrency(item['amount']);
    final count = item['count'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: ColorUtils.slate900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  formattedMonth,
                  style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        amount,
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.info600.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        '$count Tagihan',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.info600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          CircleActionButton(
            icon: Icons.delete_outline_rounded,
            color: ColorUtils.error600,
            onPressed: onDelete,
            tooltip: AppLocalizations.delete.tr,
          ),
        ],
      ),
    );
  }
}
