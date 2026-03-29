// ActivitySearchFilterBar — search field + filter icon button for Step 2.
//
// Extracted from `ClassActivityScreenState._buildSearchAndFilter`.
// Think of this like a Vue `<SearchFilterBar @search="..." @filter="..." />`
// component. It is purely presentational: all state (controller, active-filter
// flag, callbacks) is owned by the parent screen.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Search text field + filter toggle button row shown above the activity list.
///
/// Props (constructor params — like Vue props):
/// - [searchController]   — the TextEditingController owned by the parent State
/// - [searchFilterKey]    — GlobalKey used by the onboarding tour highlight
/// - [primaryColor]       — theme colour passed from the screen
/// - [hasActiveFilter]    — when true the filter icon button turns filled/coloured
/// - [languageProvider]   — translation helper (read-only)
/// - [onSearchSubmitted]  — called when the user submits the search field or taps
///                          the search icon button; parent resets pagination
/// - [onFilterPressed]    — called when the filter icon button is tapped;
///                          parent opens the filter bottom sheet
class ActivitySearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final GlobalKey searchFilterKey;
  final Color primaryColor;
  final bool hasActiveFilter;
  final LanguageProvider languageProvider;

  /// Called when the user submits the text field or taps the search icon.
  final VoidCallback onSearchSubmitted;

  /// Called when the filter icon button is tapped.
  final VoidCallback onFilterPressed;

  const ActivitySearchFilterBar({
    super.key,
    required this.searchController,
    required this.searchFilterKey,
    required this.primaryColor,
    required this.hasActiveFilter,
    required this.languageProvider,
    required this.onSearchSubmitted,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        key: searchFilterKey,
        children: [
          // ── Search text field ─────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate300),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      style: TextStyle(color: ColorUtils.slate900),
                      decoration: InputDecoration(
                        hintText: languageProvider.getTranslatedText({
                          'en': 'Search activities...',
                          'id': 'Cari kegiatan...',
                        }),
                        hintStyle: TextStyle(color: ColorUtils.slate400),
                        prefixIcon: Icon(
                          Icons.search,
                          color: ColorUtils.slate400,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => onSearchSubmitted(),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.search, color: primaryColor),
                      onPressed: onSearchSubmitted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm),

          // ── Filter icon button (filled when a filter is active) ───────
          Container(
            decoration: BoxDecoration(
              color: hasActiveFilter ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveFilter ? primaryColor : ColorUtils.slate300,
              ),
            ),
            child: IconButton(
              onPressed: onFilterPressed,
              icon: Icon(
                Icons.tune,
                color: hasActiveFilter ? Colors.white : ColorUtils.slate700,
              ),
              tooltip: languageProvider.getTranslatedText({
                'en': 'Filter',
                'id': 'Filter',
              }),
            ),
          ),
        ],
      ),
    );
  }
}
