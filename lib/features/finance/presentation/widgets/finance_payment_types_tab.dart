import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_card.dart';

/// Widget for the payment types tab.
///
/// Renders a search + filter row, active filter chips, result count, and a
/// [PaginatedListView] of [PaymentTypeCard] tiles. Payment types load in one
/// shot (no server pagination), so the paginated list is used purely for
/// empty-state, refresh, and layout consistency with the other admin screens.
class FinancePaymentTypesTab extends StatelessWidget {
  const FinancePaymentTypesTab({
    required this.filteredPaymentTypes,
    required this.searchController,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.onShowFilterSheet,
    required this.onClearAllFilters,
    required this.buildFilterChips,
    required this.formatCurrency,
    required this.getGoalDescription,
    required this.getTranslatedPeriod,
    required this.onGenerateBills,
    required this.onEdit,
    required this.onDelete,
    this.onRefresh,
    this.languageProvider,
    super.key,
  });

  final List<dynamic> filteredPaymentTypes;
  final TextEditingController searchController;
  final bool hasActiveFilter;
  final Color primaryColor;
  final VoidCallback onShowFilterSheet;
  final VoidCallback onClearAllFilters;
  final List<ActiveFilter> Function() buildFilterChips;
  final String Function(dynamic) formatCurrency;
  final String Function(dynamic) getGoalDescription;
  final String Function(String?) getTranslatedPeriod;
  final Function(int) onGenerateBills;
  final Function(int) onEdit;
  final Function(int) onDelete;
  final Future<void> Function()? onRefresh;
  final dynamic languageProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchAndFilter(),
        if (hasActiveFilter) ...[
          _buildFilterChips(),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (filteredPaymentTypes.isNotEmpty) _buildResultCount(),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: PaginatedListView<dynamic>(
            items: filteredPaymentTypes,
            onLoadMore: () async {},
            hasMore: false,
            isLoadingMore: false,
            onRefresh: onRefresh,
            refreshRole: 'admin',
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
            emptyState: _buildEmptyState(),
            itemBuilder: (context, item, index) {
              return PaymentTypeCard(
                item: item,
                index: index,
                formatCurrency: formatCurrency,
                primaryColor: primaryColor,
                getGoalDescription: getGoalDescription,
                getTranslatedPeriod: getTranslatedPeriod,
                onGenerateBills: () => onGenerateBills(index),
                onEdit: () => onEdit(index),
                onDelete: () => onDelete(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onSubmitted: (_) {},
                      decoration: InputDecoration(
                        hintText:
                            'Cari jenis '
                            'pembayaran...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: ColorUtils.slate400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.search, color: primaryColor),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: hasActiveFilter ? primaryColor : ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: hasActiveFilter ? primaryColor : ColorUtils.slate200,
              ),
            ),
            child: Stack(
              children: [
                IconButton(
                  onPressed: onShowFilterSheet,
                  icon: Icon(
                    Icons.tune,
                    color: hasActiveFilter ? Colors.white : ColorUtils.slate700,
                  ),
                  tooltip: 'Filter',
                ),
                if (hasActiveFilter)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ActiveFilterChips(
        filters: buildFilterChips(),
        primaryColor: primaryColor,
        onClearAll: onClearAllFilters,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildResultCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            '${filteredPaymentTypes.length} '
            'jenis pembayaran '
            'ditemukan',
            style: TextStyle(color: ColorUtils.slate600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyState(
      title:
          'Tidak ada jenis '
          'pembayaran',
      subtitle: searchController.text.isEmpty && !hasActiveFilter
          ? 'Tap + untuk menambah '
                'jenis pembayaran'
          : 'Tidak ditemukan hasil '
                'pencarian',
      icon: Icons.payment,
    );
  }
}
