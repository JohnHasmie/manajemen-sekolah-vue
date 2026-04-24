import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_dashboard_tab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_payment_types_tab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_verification_tab.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/class_report_tab.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';

/// Widget for building tab content.
class FinanceTabContent extends StatelessWidget {
  final int currentTabIndex;
  final Map<String, dynamic> dashboardData;
  final List<dynamic> pendingPaymentList;
  final List<dynamic> billList;
  final LanguageProvider languageProvider;
  final Color primaryColor;
  final bool isReadOnly;
  final VoidCallback onVerifyNow;
  final List<dynamic> Function() calculateBatchesFromBills;
  final String Function(String?) formatMonth;
  final String Function(dynamic) formatCurrency;
  final Future<void> Function(Map<String, dynamic>) onDeleteBatch;
  final Future<void> Function() onRefresh;
  final List<dynamic> filteredPaymentTypes;
  final TextEditingController searchController;
  final bool hasActiveFilter;
  final VoidCallback onShowFilterSheet;
  final VoidCallback onClearAllFilters;
  final List<ActiveFilter> Function() buildFilterChips;
  final String Function(dynamic) getGoalDescription;
  final String Function(String?) getTranslatedPeriod;
  final Function(int) onGenerateBills;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final ScrollController pendingScrollController;
  final bool hasMorePending;
  final Function(int) onVerify;
  final Function(int) onShowProof;
  final List<dynamic> classList;
  final Map<String, List<dynamic>> studentsByClass;
  final Map<String, List<dynamic>> billsByStudent;
  final bool isLoading;

  const FinanceTabContent({
    required this.currentTabIndex,
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
    required this.filteredPaymentTypes,
    required this.searchController,
    required this.hasActiveFilter,
    required this.onShowFilterSheet,
    required this.onClearAllFilters,
    required this.buildFilterChips,
    required this.getGoalDescription,
    required this.getTranslatedPeriod,
    required this.onGenerateBills,
    required this.onEdit,
    required this.onDelete,
    required this.pendingScrollController,
    required this.hasMorePending,
    required this.onVerify,
    required this.onShowProof,
    required this.classList,
    required this.studentsByClass,
    required this.billsByStudent,
    required this.isLoading,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: currentTabIndex,
      children: [
        FinanceDashboardTab(
          dashboardData: dashboardData,
          pendingPaymentList: pendingPaymentList,
          billList: billList,
          languageProvider: languageProvider,
          primaryColor: primaryColor,
          isReadOnly: isReadOnly,
          onVerifyNow: onVerifyNow,
          calculateBatchesFromBills: calculateBatchesFromBills,
          formatMonth: formatMonth,
          formatCurrency: formatCurrency,
          onDeleteBatch: onDeleteBatch,
          onRefresh: onRefresh,
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
          onGenerateBills: onGenerateBills,
          onEdit: onEdit,
          onDelete: onDelete,
          onRefresh: onRefresh,
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
        ClassReportTab(
          isLoading: isLoading,
          classList: classList,
          studentsByClass: studentsByClass,
          billsByStudent: billsByStudent,
        ),
      ],
    );
  }
}
