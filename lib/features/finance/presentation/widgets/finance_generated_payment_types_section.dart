// Section showing the list of generated payment batches on the dashboard tab.
//
// Extracted from `_buildGeneratedPaymentTypesSection` in admin_finance_screen.dart.
// Like a Vue `<GeneratedPaymentTypesSection>` component wrapping a list of batch rows.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_section_header.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/generated_payment_batch_item.dart';

/// Renders the "Active Bills" section header + the list of generated batches.
///
/// If [generatedBatches] is empty a centred placeholder text is shown instead.
/// Equivalent to calling `_buildGeneratedPaymentTypesSection()` on the parent screen.
///
/// Pure [StatelessWidget] — every piece of data and every callback is injected
/// through constructor params (no `ref`, no `setState`), like a presentational
/// Vue component.
class FinanceGeneratedPaymentTypesSection extends StatelessWidget {
  /// The list of batch maps to display (same shape as the API response for
  /// `generated_batches`).  May be empty — an empty-state message is shown
  /// when the list is empty.
  final List<dynamic> generatedBatches;

  /// Formats a `"YYYY-MM"` string into a human-readable month label.
  /// Passed in so this widget has no dependency on `_formatMonth` in the parent.
  final String Function(String?) formatMonth;

  /// Formats a numeric/dynamic amount into a `"Rp X"` currency string.
  final String Function(dynamic) formatCurrency;

  /// Brand primary colour used for the section header accent and item icons.
  final Color primaryColor;

  /// The [LanguageProvider] used for translating section title text.
  final LanguageProvider languageProvider;

  /// Called when the user requests deletion of a batch row.
  /// The parent passes `(item) => _deleteGeneratedBills(item)` here.
  final void Function(Map<String, dynamic>) onDeleteBatch;

  const FinanceGeneratedPaymentTypesSection({
    super.key,
    required this.generatedBatches,
    required this.formatMonth,
    required this.formatCurrency,
    required this.primaryColor,
    required this.languageProvider,
    required this.onDeleteBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FinanceSectionHeader(
          title: languageProvider.getTranslatedText({
            'en': 'Active Bills',
            'id': 'Tagihan Berjalan',
          }),
          icon: Icons.receipt_long_rounded,
          color: primaryColor,
        ),
        if (generatedBatches.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: Text(
                'Belum ada tagihan yang digenerate',
                textAlign: TextAlign.center,
                style: TextStyle(color: ColorUtils.slate400, fontSize: 13),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: generatedBatches.length,
            itemBuilder: (context, index) {
              final item = generatedBatches[index] as Map<String, dynamic>;
              return GeneratedPaymentBatchItem(
                item: item,
                formatMonth: formatMonth,
                formatCurrency: formatCurrency,
                primaryColor: primaryColor,
                onDelete: () => onDeleteBatch(item),
              );
            },
          ),
      ],
    );
  }
}
