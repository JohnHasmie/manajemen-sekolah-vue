import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/controllers/parent_finance_controller.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/billing_card.dart';

class BillingList extends ConsumerWidget {
  final LanguageProvider languageProvider;

  const BillingList({super.key, required this.languageProvider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(parentFinanceProvider);

    return financeState.when(
      data: (state) {
        if (state.isLoading && state.billingItems.isEmpty) {
          return const SkeletonListLoading(
            padding: EdgeInsets.only(top: 8, bottom: 80),
            shrinkWrap: true,
          );
        }

        if (state.billingItems.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: languageProvider.getTranslatedText({
              'en': 'No Billing Found',
              'id': 'Tagihan Tidak Ditemukan',
            }),
            subtitle: languageProvider.getTranslatedText({
              'en': 'No billing records found for this student.',
              'id': 'Tidak ada catatan tagihan untuk siswa ini.',
            }),
          );
        }

        // The parent screen now hosts a single outer ListView so the
        // gradient hero scrolls with the body. shrinkWrap +
        // NeverScrollable lets this inner list size to its content
        // and defer scrolling to the outer list. RefreshIndicator
        // also lives on the screen now.
        return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: state.billingItems.length,
            itemBuilder: (context, index) {
              final billing = state.billingItems[index];
              final isRead =
                  billing['is_read'] == true ||
                  billing['is_read'] == 1 ||
                  billing['is_read'] == '1';

              // Mark as read when item is built (visible)
              if (!isRead) {
                ref
                    .read(parentFinanceProvider.notifier)
                    .markItemVisible(billing['id'].toString(), isRead);
              }

              return BillingCard(
                billing: billing,
                languageProvider: languageProvider,
                onTap: () {
                  // Navigate to detail or show payment dialog
                },
              );
            },
          );
      },
      loading: () => const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        shrinkWrap: true,
      ),
      error: (error, _) =>
          Center(child: Text('${AppLocalizations.error.tr}: $error')),
    );
  }
}
