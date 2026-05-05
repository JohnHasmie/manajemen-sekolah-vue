import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_payment_types_tab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_verification_tab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/tagihan_tab.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';

/// Widget for building tab content.
///
/// v3 layout (Mockup #13 Phase Final):
///   Tab 0 — Tagihan       (TagihanTab with sub-filters + InvoiceRows)
///   Tab 1 — Pembayaran    (FinanceVerificationTab — pending payments)
///   Tab 2 — Jenis         (FinancePaymentTypesTab)
///
/// The legacy 4-tab `Dashboard / Payment Types / Verification /
/// ClassReport` IndexedStack has been folded down — Dashboard's stat
/// strip / generated-batches strip moves out of the hub (the v3 hero
/// covers the same KPIs) and ClassFinanceReport is now reachable via
/// the navy-tinted [ClassReportDrillCard] pinned at the bottom of
/// Tagihan rather than its own tab.
class FinanceTabContent extends StatelessWidget {
  final int currentTabIndex;
  final List<dynamic> pendingPaymentList;
  final List<dynamic> billList;
  final LanguageProvider languageProvider;
  final Color primaryColor;
  final bool isReadOnly;
  final String Function(dynamic) formatCurrency;
  final Future<void> Function() onRefresh;
  final List<dynamic> filteredPaymentTypes;
  final TextEditingController searchController;
  final bool hasActiveFilter;
  final VoidCallback onShowFilterSheet;
  final VoidCallback onClearAllFilters;
  final List<ActiveFilter> Function() buildFilterChips;
  final String Function(dynamic) getGoalDescription;
  final String Function(String?) getTranslatedPeriod;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final ScrollController pendingScrollController;
  final bool hasMorePending;
  final Function(int) onVerify;
  final Function(int) onShowProof;

  // Tagihan tab wiring (Mockup #13)
  final String tagihanFilterKey;
  final ValueChanged<String> onTagihanFilterChanged;
  final int overdueCount;
  final void Function(Map<String, dynamic> bill)? onTagihBill;
  final void Function(Map<String, dynamic> bill)? onTapBill;
  final VoidCallback onClassReportTap;

  // Tagihan jenis + bulan filter wiring
  final Set<String> tagihanSelectedJenisIds;
  final String? tagihanSelectedMonth;
  final VoidCallback onOpenTagihanFilter;
  final VoidCallback onClearTagihanFilter;

  const FinanceTabContent({
    required this.currentTabIndex,
    required this.pendingPaymentList,
    required this.billList,
    required this.languageProvider,
    required this.primaryColor,
    required this.isReadOnly,
    required this.formatCurrency,
    required this.onRefresh,
    required this.filteredPaymentTypes,
    required this.searchController,
    required this.hasActiveFilter,
    required this.onShowFilterSheet,
    required this.onClearAllFilters,
    required this.buildFilterChips,
    required this.getGoalDescription,
    required this.getTranslatedPeriod,
    required this.onEdit,
    required this.onDelete,
    required this.pendingScrollController,
    required this.hasMorePending,
    required this.onVerify,
    required this.onShowProof,
    required this.tagihanFilterKey,
    required this.onTagihanFilterChanged,
    required this.overdueCount,
    required this.onClassReportTap,
    required this.tagihanSelectedJenisIds,
    required this.tagihanSelectedMonth,
    required this.onOpenTagihanFilter,
    required this.onClearTagihanFilter,
    this.onTagihBill,
    this.onTapBill,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: currentTabIndex.clamp(0, 2),
      children: [
        TagihanTab(
          billList: billList,
          activeFilterKey: tagihanFilterKey,
          onFilterChanged: onTagihanFilterChanged,
          overdueCount: overdueCount,
          onTagih: onTagihBill,
          onTap: onTapBill,
          onClassReportTap: onClassReportTap,
          onRefresh: onRefresh,
          selectedJenisIds: tagihanSelectedJenisIds,
          selectedMonth: tagihanSelectedMonth,
          onOpenFilterSheet: onOpenTagihanFilter,
          onClearFilters: onClearTagihanFilter,
          primaryColor: primaryColor,
        ),
        FinanceVerificationTab(
          pendingPaymentList: pendingPaymentList,
          hasMorePending: hasMorePending,
          isReadOnly: isReadOnly,
          scrollController: pendingScrollController,
          formatCurrency: formatCurrency,
          primaryColor: primaryColor,
          onVerify: onVerify,
          onShowProof: onShowProof,
        ),
        FinancePaymentTypesTab(
          filteredPaymentTypes: filteredPaymentTypes,
          searchController: searchController,
          hasActiveFilter: hasActiveFilter,
          primaryColor: primaryColor,
          onShowFilterSheet: onShowFilterSheet,
          onClearAllFilters: onClearAllFilters,
          buildFilterChips: buildFilterChips,
          formatCurrency: formatCurrency,
          getGoalDescription: getGoalDescription,
          getTranslatedPeriod: getTranslatedPeriod,
          onEdit: onEdit,
          onDelete: onDelete,
          onRefresh: onRefresh,
        ),
      ],
    );
  }
}
