import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';

/// Mixin providing UI-building methods for ScheduleScreenHeader.
///
/// Extracted to reduce widget complexity. Provides builders for:
/// - Top action bar (back, title, toggle view)
/// - Search and filter row
/// - Active filter chips display
mixin ScheduleHeaderUiMixin {
  /// Primary color for UI elements and actions.
  Color get primaryColor;

  /// Flag indicating table vs card view mode.
  bool get isTableView;

  /// Flag indicating active filter state.
  bool get hasActiveFilter;

  /// Title text for the header.
  String get title;

  /// Subtitle text under the title.
  String get subtitle;

  /// Hint text for search input.
  String get searchHint;

  /// Tooltip text for filter button.
  String get filterTooltip;

  /// Label for clear-all filters button.
  String get clearAllLabel;

  /// Key for toggle view button (for testing).
  GlobalKey get toggleViewKey;

  /// Key for search/filter row (for testing).
  GlobalKey get searchFilterKey;

  /// Controller for search text field.
  TextEditingController get searchController;

  /// List of active filter chips: [{'label': ..., 'onRemove': ...}]
  List<ActiveFilter> get filterChips;

  /// Callback when back button is tapped.
  VoidCallback get onBack;

  /// Callback when toggle view button is tapped.
  VoidCallback get onToggleView;

  /// Callback when search is submitted.
  VoidCallback get onSearch;

  /// Callback when filter button is tapped.
  VoidCallback get onShowFilter;

  /// Callback when clear-all filters is tapped.
  VoidCallback get onClearAllFilters;

  /// Build top action bar: back button, title, toggle view.
  Widget buildTopBar() {
    return Row(
      children: [
        _buildBackButton(),
        const SizedBox(width: AppSpacing.md),
        _buildTitleColumn(),
        _buildToggleViewButton(),
      ],
    );
  }

  /// Build back button with semi-transparent background.
  Widget _buildBackButton() {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }

  /// Build title and subtitle column.
  Widget _buildTitleColumn() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// Build view toggle button (card ↔ table icon).
  Widget _buildToggleViewButton() {
    return GestureDetector(
      key: toggleViewKey,
      onTap: onToggleView,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(
          isTableView
              ? Icons.view_agenda_outlined
              : Icons.calendar_view_day_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  /// Build search bar with filter button and active indicator.
  Widget buildSearchFilterRow() {
    return Row(
      key: searchFilterKey,
      children: [
        Expanded(child: _buildSearchContainer()),
        const SizedBox(width: AppSpacing.sm),
        _buildFilterButton(),
      ],
    );
  }

  /// Build search input container with icon button.
  Widget _buildSearchContainer() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSearchField()),
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: Icon(Icons.search, color: primaryColor, size: 20),
              onPressed: onSearch,
            ),
          ),
        ],
      ),
    );
  }

  /// Build text field for search input.
  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: searchHint,
        hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onSubmitted: (_) {
        onSearch();
        // Note: context is not available in mixin; call unfocus from widget
      },
    );
  }

  /// Build filter button with active indicator dot.
  Widget _buildFilterButton() {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: hasActiveFilter
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            onPressed: onShowFilter,
            icon: Icon(
              Icons.tune,
              color: hasActiveFilter ? primaryColor : Colors.white,
              size: 20,
            ),
            tooltip: filterTooltip,
          ),
          if (hasActiveFilter)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ColorUtils.error600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build scrollable row of active filter chips with clear-all button.
  Widget buildFilterChipsRow() {
    if (!hasActiveFilter) return const SizedBox.shrink();

    return ActiveFilterChips(
      filters: filterChips,
      primaryColor: primaryColor,
      onClearAll: onClearAllFilters,
      clearAllLabel: clearAllLabel,
      transparentStyle: true,
      padding: EdgeInsets.zero,
    );
  }
}
