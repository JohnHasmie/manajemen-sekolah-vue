import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/finance/domain/models/bill_group.dart';
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
  /// Aggregated Tagihan rows from `/finance/bill-groups`. Replaces
  /// the old per-bill `billList` that the hub used to download and
  /// group client-side — the per-student detail screen now fetches
  /// its own bills on demand via the bucket's payment_type_id +
  /// class_id filter.
  final List<BillGroup> billGroups;
  /// Active academic year id — forwarded to the Tagihan tab so the
  /// detail-screen fetch can scope to the same AY as the hub.
  final String? academicYearId;
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

  /// Optional — only passed when the Pembayaran tab owns its own
  /// scrollable (legacy mode). In the new hub layout the tab is hosted
  /// inside a `NestedScrollView` body and attaches to its provided
  /// `PrimaryScrollController` instead, so the screen leaves this null.
  final ScrollController? pendingScrollController;
  final bool hasMorePending;
  final Function(int) onVerify;
  final Function(int) onShowProof;

  // Tagihan tab wiring (Mockup #13). Status / jenis / bulan filters
  // are now header-owned (BrandFilterChipStrip) — the screen passes
  // the resolved filter values through, the tab just renders.
  final String tagihanFilterKey;
  final void Function(Map<String, dynamic> bill)? onTagihBill;
  final void Function(Map<String, dynamic> bill)? onTapBill;
  final VoidCallback onClassReportTap;
  final Set<String> tagihanSelectedJenisIds;
  final int? filterYear;
  final int? filterMonth;

  const FinanceTabContent({
    required this.currentTabIndex,
    required this.pendingPaymentList,
    required this.billGroups,
    required this.academicYearId,
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
    required this.hasMorePending,
    this.pendingScrollController,
    required this.onVerify,
    required this.onShowProof,
    required this.tagihanFilterKey,
    required this.onClassReportTap,
    required this.tagihanSelectedJenisIds,
    this.filterYear,
    this.filterMonth,
    this.onTagihBill,
    this.onTapBill,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Switched from IndexedStack → single-tab render. The hub now
    // hosts the tabs inside a `NestedScrollView`, and IndexedStack
    // kept ALL three inner scrollables alive simultaneously — each
    // would have tried to attach to NestedScrollView's
    // PrimaryScrollController and throw "ScrollController attached to
    // multiple scroll views". Building only the active tab keeps a
    // single client on the controller. Scroll position resets on tab
    // switch, but tab DATA is owned by the screen state, so nothing
    // is actually lost.
    final idx = currentTabIndex.clamp(0, 2);
    switch (idx) {
      case 0:
        return TagihanTab(
          billGroups: billGroups,
          activeFilterKey: tagihanFilterKey,
          onTagih: onTagihBill,
          onTap: onTapBill,
          onClassReportTap: onClassReportTap,
          onRefresh: onRefresh,
          academicYearId: academicYearId,
        );
      case 1:
        return FinanceVerificationTab(
          pendingPaymentList: pendingPaymentList,
          hasMorePending: hasMorePending,
          isReadOnly: isReadOnly,
          scrollController: pendingScrollController,
          formatCurrency: formatCurrency,
          primaryColor: primaryColor,
          onVerify: onVerify,
          onShowProof: onShowProof,
        );
      default:
        return FinancePaymentTypesTab(
          filteredPaymentTypes: filteredPaymentTypes,
          searchController: searchController,
          hasActiveFilter: hasActiveFilter,
          hasActiveHeaderFilter: hasActiveFilter,
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
        );
    }
  }
}
