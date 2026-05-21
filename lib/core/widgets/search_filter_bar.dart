// Search text field with adjacent filter icon button.
//
// Designed for use inside gradient headers (transparent style) or body
// sections (solid white style). Replaces 8+ identical search + filter
// Row() implementations across teacher and admin screens.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A search input with an optional filter button and active-filter badge.
///
/// Two visual modes:
/// - **Transparent** (`transparentStyle: true`): white semi-transparent
///   background for use inside gradient headers.
/// - **Solid** (`transparentStyle: false`): white card with shadow for
///   use in body sections.
///
/// Example:
/// ```dart
/// SearchFilterBar(
///   controller: _searchController,
///   hintText: 'Search class or subject...',
///   onSubmitted: (_) => _refresh(),
///   onFilterTap: () => _showFilterSheet(),
///   hasActiveFilter: _hasActiveFilter,
///   primaryColor: primaryColor,
/// )
/// ```
class SearchFilterBar extends StatelessWidget {
  /// Text editing controller for the search field.
  final TextEditingController controller;

  /// Placeholder text shown when the field is empty.
  final String hintText;

  /// Called on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the search (keyboard done/enter).
  final ValueChanged<String>? onSubmitted;

  /// Called when the search icon button is pressed.
  final VoidCallback? onSearchTap;

  /// Called when the filter icon button is pressed. If null, the filter
  /// button is hidden.
  final VoidCallback? onFilterTap;

  /// When true, shows a red badge on the filter icon to indicate
  /// that filters are active.
  final bool hasActiveFilter;

  /// Number of active filters. When > 0, shows a count badge instead of a dot.
  final int activeFilterCount;

  /// When true, uses semi-transparent white styling for gradient headers.
  /// When false, uses solid white with shadow for body placement.
  final bool transparentStyle;

  /// Accent color for the search icon and filter badge.
  final Color? primaryColor;

  /// Optional GlobalKey for tour/onboarding targeting.
  final Key? searchFieldKey;

  const SearchFilterBar({
    super.key,
    required this.controller,
    this.hintText = 'Cari...',
    this.onChanged,
    this.onSubmitted,
    this.onSearchTap,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.activeFilterCount = 0,
    this.transparentStyle = true,
    this.primaryColor,
    this.searchFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? ColorUtils.getRoleColor('guru');

    return Row(
      children: [
        // Search field
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: transparentStyle
                  ? Colors.white.withValues(alpha: 0.95)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: transparentStyle
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: searchFieldKey,
                    controller: controller,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onChanged: onChanged,
                    onSubmitted: (value) {
                      onSubmitted?.call(value);
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.search, color: color, size: 20),
                    onPressed: () {
                      if (onSearchTap != null) {
                        onSearchTap!.call();
                      } else {
                        onSubmitted?.call(controller.text);
                      }
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filter button (optional)
        if (onFilterTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _FilterButton(
            onTap: onFilterTap!,
            hasActiveFilter: hasActiveFilter,
            activeFilterCount: activeFilterCount,
            primaryColor: color,
            transparentStyle: transparentStyle,
          ),
        ],
      ],
    );
  }
}

/// The filter icon button with optional active-filter count badge.
class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveFilter;
  final int activeFilterCount;
  final Color primaryColor;
  final bool transparentStyle;

  const _FilterButton({
    required this.onTap,
    required this.hasActiveFilter,
    this.activeFilterCount = 0,
    required this.primaryColor,
    required this.transparentStyle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: hasActiveFilter
              ? Colors.white
              : transparentStyle
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: transparentStyle
              ? Border.all(color: Colors.white.withValues(alpha: 0.3))
              : null,
          boxShadow: !transparentStyle
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune,
              color: hasActiveFilter
                  ? primaryColor
                  : transparentStyle
                  ? Colors.white
                  : ColorUtils.slate500,
              size: 20,
            ),
            if (hasActiveFilter && activeFilterCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: ColorUtils.error600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '$activeFilterCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
            else if (hasActiveFilter)
              Positioned(
                right: 4,
                top: 4,
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
      ),
    );
  }
}
