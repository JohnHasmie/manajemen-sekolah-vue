import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_builders.dart';
import 'package:manajemensekolah/features/finance/presentation/mixins/payment_form_parsers.dart';

/// Mixin for building input sections (period, goal, status).
mixin PaymentFormInputsMixin
    on
        ConsumerState<PaymentTypeFormSheet>,
        PaymentFormBuildersMixin,
        PaymentFormParsersMixin {
  /// Builds the period selection section with chips.
  Widget buildPeriodSection(
    TextEditingController periodController,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 15, color: ColorUtils.slate600),
            const SizedBox(width: 6),
            Text(
              'Periode Pembayaran',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: buildPeriodChip(
                'sekali bayar',
                'Sekali Bayar',
                Icons.looks_one_rounded,
                periodController,
                primaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: buildPeriodChip(
                'bulanan',
                'Bulanan',
                Icons.calendar_view_month_rounded,
                periodController,
                primaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: buildPeriodChip(
                'semester',
                'Semester',
                Icons.date_range_rounded,
                periodController,
                primaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: buildPeriodChip(
                'tahunan',
                'Tahunan',
                Icons.calendar_today_rounded,
                periodController,
                primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the goal selection section.
  Widget buildGoalSection(Map<String, dynamic>? goalData, VoidCallback onTap) {
    final hasGoal = goalData != null && goalData.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.groups_rounded, size: 15, color: ColorUtils.slate600),
            const SizedBox(width: 6),
            Text(
              'Tujuan Pembayaran',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasGoal
                  ? ColorUtils.success600.withValues(alpha: 0.06)
                  : ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: hasGoal
                    ? ColorUtils.success600.withValues(alpha: 0.4)
                    : ColorUtils.slate200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        (hasGoal
                                ? ColorUtils.success600
                                : ColorUtils.corporateBlue600)
                            .withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    hasGoal ? Icons.check_circle_rounded : Icons.groups_rounded,
                    size: 18,
                    color: hasGoal
                        ? ColorUtils.success600
                        : ColorUtils.corporateBlue600,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasGoal ? 'Tujuan Dipilih' : 'Belum ada tujuan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasGoal
                              ? ColorUtils.success600
                              : ColorUtils.slate600,
                        ),
                      ),
                      Text(
                        getGoalDescription(goalData),
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.slate400,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the status selection section.
  Widget buildStatusSection(
    String currentStatus,
    Function(String) onStatusChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.toggle_on_rounded, size: 15, color: ColorUtils.slate600),
            const SizedBox(width: 6),
            Text(
              'Status',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onStatusChanged('active'),
                child: buildStatusChip(
                  'active',
                  'Aktif',
                  ColorUtils.success600,
                  Icons.check_circle_rounded,
                  currentStatus,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onStatusChanged('inactive'),
                child: buildStatusChip(
                  'inactive',
                  'Non-Aktif',
                  ColorUtils.error600,
                  Icons.cancel_rounded,
                  currentStatus,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
