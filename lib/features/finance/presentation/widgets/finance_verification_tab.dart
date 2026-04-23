import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/pending_payment_card.dart';

/// Widget for the verification/pending payments tab.
class FinanceVerificationTab extends StatelessWidget {
  const FinanceVerificationTab({
    required this.pendingPaymentList,
    required this.hasMorePending,
    required this.isReadOnly,
    required this.scrollController,
    required this.formatCurrency,
    required this.primaryColor,
    required this.onVerify,
    required this.onShowProof,
    super.key,
  });

  final List<dynamic> pendingPaymentList;
  final bool hasMorePending;
  final bool isReadOnly;
  final ScrollController scrollController;
  final String Function(dynamic) formatCurrency;
  final Color primaryColor;
  final Function(int) onVerify;
  final Function(int) onShowProof;

  @override
  Widget build(BuildContext context) {
    return pendingPaymentList.isEmpty
        ? const EmptyState(
            title:
                'Tidak ada '
                'pembayaran menunggu '
                'verifikasi',
            subtitle:
                'Semua pembayaran telah '
                'diverifikasi',
            icon: Icons.verified_user,
          )
        : ListView.builder(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: pendingPaymentList.length + (hasMorePending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == pendingPaymentList.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return PendingPaymentCard(
                payment: pendingPaymentList[index],
                index: index,
                isReadOnly: isReadOnly,
                onVerify: () => onVerify(index),
                onShowProof: () => onShowProof(index),
                formatCurrency: formatCurrency,
                primaryColor: primaryColor,
              );
            },
          );
  }
}
