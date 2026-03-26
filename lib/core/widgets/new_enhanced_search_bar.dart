// New enhanced search bar with a separate filter button and active-filter indicator.
//
// Like a Vue component `<SearchBarWithFilterButton>` where the search input
// and filter button are visually separated. The filter button shows a red
// badge dot when filters are active (similar to a notification badge in Vue).
// This is the newer version of EnhancedSearchBar with a cleaner design.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A search bar with a separate filter icon button that shows an active-filter badge.
///
/// Like a Vue `<NewEnhancedSearchBar>` component with props:
/// - [controller] - text controller (like `v-model`)
/// - [onChanged] - keystroke callback (like `@input`)
/// - [hintText] - placeholder text
/// - [showFilter] - whether to show the filter button (like `v-if`)
/// - [hasActiveFilter] - shows a red dot badge when true
/// - [onFilterPressed] - opens the filter sheet (like `@click` on the filter icon)
/// - [primaryColor] - theme color for the search icon and filter button
/// - [margin] - optional outer margin override
///
/// This is a StatelessWidget because all state is managed by the parent.
class NewEnhancedSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;
  final bool showFilter;
  final bool hasActiveFilter;
  final VoidCallback onFilterPressed;
  final Color? primaryColor;
  final EdgeInsetsGeometry? margin;

  const NewEnhancedSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.showFilter = true,
    this.hasActiveFilter = false,
    required this.onFilterPressed,
    this.primaryColor,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? ColorUtils.getRoleColor("guru");

        return Container(
          margin:
              margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: color),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              if (showFilter) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    color: hasActiveFilter ? color : color.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      IconButton(
                        onPressed: onFilterPressed,
                        icon: Icon(Icons.tune, color: Colors.white),
                        tooltip: languageProvider.getTranslatedText({
                          'en': 'Filter',
                          'id': 'Filter',
                        }),
                      ),
                      if (hasActiveFilter)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
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
            ],
          ),
        );
  }
}
