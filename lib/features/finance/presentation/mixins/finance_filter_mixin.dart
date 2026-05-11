import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/finance_filter_sheet.dart';
import 'package:manajemensekolah/features/finance/presentation/screens/admin_finance_screen.dart';

/// Mixin for filter and search functionality.
mixin FinanceFilterMixin on ConsumerState<FinanceScreen> {
  TextEditingController get searchController;

  String? get selectedStatusFilter;

  String? get selectedPeriodFilter;

  bool get hasActiveFilter;

  Color getPrimaryColor();

  void updateStatusFilter(String? status);

  void updatePeriodFilter(String? period);

  void updateHasActiveFilter(bool value);

  Future<void> loadDataAfterFilter();

  void checkActiveFilter() {
    updateHasActiveFilter(
      selectedStatusFilter != null || selectedPeriodFilter != null,
    );
  }

  void clearAllFilters() {
    updateStatusFilter(null);
    updatePeriodFilter(null);
    checkActiveFilter();
  }

  List<ActiveFilter> buildFilterChips(LanguageProvider languageProvider) {
    final List<ActiveFilter> filterChips = [];

    if (selectedStatusFilter != null) {
      final statusText = selectedStatusFilter == 'active'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Non-Aktif',
            });
      final statusLabel = languageProvider.getTranslatedText({
        'en': 'Status',
        'id': 'Status',
      });
      filterChips.add(
        ActiveFilter(
          label: '$statusLabel: $statusText',
          onRemove: () {
            updateStatusFilter(null);
            checkActiveFilter();
            loadDataAfterFilter();
          },
        ),
      );
    }

    if (selectedPeriodFilter != null) {
      final periodText = selectedPeriodFilter == 'bulanan'
          ? languageProvider.getTranslatedText({
              'en': 'Monthly',
              'id': 'Bulanan',
            })
          : languageProvider.getTranslatedText({
              'en': 'Yearly',
              'id': 'Tahunan',
            });
      final periodLabel = languageProvider.getTranslatedText({
        'en': 'Period',
        'id': 'Periode',
      });
      filterChips.add(
        ActiveFilter(
          label: '$periodLabel: $periodText',
          onRemove: () {
            updatePeriodFilter(null);
            checkActiveFilter();
            loadDataAfterFilter();
          },
        ),
      );
    }

    return filterChips;
  }

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FinanceFilterSheet(
        currentStatus: selectedStatusFilter,
        currentPeriod: selectedPeriodFilter,
        languageProvider: ref.read(languageRiverpod),
        primaryColor: getPrimaryColor(),
        onApply: (status, period) {
          updateStatusFilter(status);
          updatePeriodFilter(period);
          checkActiveFilter();
        },
      ),
    );
  }
}
