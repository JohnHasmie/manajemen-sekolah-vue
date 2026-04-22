import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_dashboard_stats.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_pending_section.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_generated_payment_types_section.dart';

/// Widget for the dashboard tab.
class FinanceDashboardTab extends StatelessWidget {
  const FinanceDashboardTab({
    required this.dashboardData,
    required this.pendingPaymentList,
    required this.billList,
    required this.languageProvider,
    required this.primaryColor,
    required this.isReadOnly,
    required this.onVerifyNow,
    required this.calculateBatchesFromBills,
    required this.formatMonth,
    required this.formatCurrency,
    required this.onDeleteBatch,
    required this.onRefresh,
    super.key,
  });

  final Map<String, dynamic> dashboardData;
  final List<dynamic> pendingPaymentList;
  final List<dynamic> billList;
  final dynamic languageProvider;
  final Color primaryColor;
  final bool isReadOnly;
  final VoidCallback onVerifyNow;
  final List<dynamic> Function() calculateBatchesFromBills;
  final String Function(String?) formatMonth;
  final String Function(dynamic) formatCurrency;
  final Function(Map<String, dynamic>) onDeleteBatch;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          FinanceDashboardStats(
            unpaidCount: dashboardData['tagihan_belum_dibayar'],
            verifiedCount: dashboardData['tagihan_terverifikasi'],
            totalPendingPayments: pendingPaymentList.length,
            languageProvider: languageProvider,
            primaryColor: primaryColor,
          ),
          if (pendingPaymentList.isNotEmpty)
            FinancePendingSection(
              pendingCount: pendingPaymentList.length,
              isReadOnly: isReadOnly,
              onVerifyNow: onVerifyNow,
              verifyNowLabel: languageProvider.getTranslatedText({
                'en': 'Verify Now',
                'id':
                    'Verifikasi '
                    'Sekarang',
              }),
              paymentsNeedVerificationLabel: languageProvider
                  .getTranslatedText({
                    'en':
                        'payments need '
                        'verification',
                    'id':
                        'pembayaran perlu '
                        'diverifikasi',
                  }),
            ),
          FinanceGeneratedPaymentTypesSection(
            generatedBatches: () {
              List<dynamic> batches = dashboardData['generated_batches'] ?? [];
              if (batches.isEmpty && billList.isNotEmpty) {
                batches = calculateBatchesFromBills();
              }
              return batches;
            }(),
            formatMonth: formatMonth,
            formatCurrency: formatCurrency,
            primaryColor: primaryColor,
            languageProvider: languageProvider,
            onDeleteBatch: onDeleteBatch,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
