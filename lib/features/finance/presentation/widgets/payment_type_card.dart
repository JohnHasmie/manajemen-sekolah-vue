// PaymentTypeCard - extracted from admin_finance_screen.dart _buildPaymentTypeCard.
//
// Displays a single payment type (jenis pembayaran) with its details and action buttons.
// Like a Vue component `<PaymentTypeCard />` that receives all data and callbacks as props.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/circle_action_button.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Card widget for a single payment type entry.
///
/// Extracted from [FinanceScreen._buildPaymentTypeCard] to keep the parent file
/// manageable — like splitting a large Vue SFC into smaller child components.
class PaymentTypeCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int index;
  final String Function(dynamic) formatCurrency;
  final Color primaryColor;
  final String Function(dynamic) getGoalDescription;
  final String Function(String?) getTranslatedPeriod;
  final VoidCallback onGenerateBills;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PaymentTypeCard({
    super.key,
    required this.item,
    required this.index,
    required this.formatCurrency,
    required this.primaryColor,
    required this.getGoalDescription,
    required this.getTranslatedPeriod,
    required this.onGenerateBills,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: icon + name + status chip
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
                      child: Icon(
                        Icons.payment_rounded,
                        color: ColorUtils.getColorForIndex(index),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'No Name',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            formatCurrency(item['amount']),
                            style: TextStyle(
                              fontSize: 13,
                              color: ColorUtils.slate600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Status chip
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            (item['status'] == 'aktif'
                                    ? ColorUtils.success600
                                    : ColorUtils.error600)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (item['status'] == 'aktif'
                                      ? ColorUtils.success600
                                      : ColorUtils.error600)
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: item['status'] == 'aktif'
                                  ? ColorUtils.success600
                                  : ColorUtils.error600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 5),
                          Text(
                            item['status'] == 'aktif' ? 'Aktif' : 'Non-Aktif',
                            style: TextStyle(
                              color: item['status'] == 'aktif'
                                  ? ColorUtils.success600
                                  : ColorUtils.error600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (item['description'] != null &&
                    item['description'].isNotEmpty) ...[
                  SizedBox(height: 10),
                  Text(
                    item['description'],
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: 10),
                Divider(color: ColorUtils.slate100, height: 1),
                SizedBox(height: 10),

                // Tags row: periode + tujuan
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 10,
                            color: primaryColor,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            getTranslatedPeriod(item['periode']),
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item['goal'] != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.info600.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 10,
                              color: ColorUtils.info600,
                            ),
                            SizedBox(width: AppSpacing.xs),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 160),
                              child: Text(
                                getGoalDescription(item['goal']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ColorUtils.info600,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                SizedBox(height: AppSpacing.md),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleActionButton(
                      icon: Icons.autorenew_rounded,
                      color: ColorUtils.corporateBlue600,
                      onPressed: onGenerateBills,
                      tooltip: 'Generate Tagihan',
                    ),
                    SizedBox(width: AppSpacing.sm),
                    CircleActionButton(
                      icon: Icons.edit_rounded,
                      color: primaryColor,
                      onPressed: onEdit,
                      tooltip: AppLocalizations.edit.tr,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    CircleActionButton(
                      icon: Icons.delete_rounded,
                      color: ColorUtils.error600,
                      onPressed: onDelete,
                      tooltip: AppLocalizations.delete.tr,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
