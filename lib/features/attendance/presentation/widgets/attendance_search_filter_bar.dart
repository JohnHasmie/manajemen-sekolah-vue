// Extracted from teacher_attendance_screen.dart (_buildSearchAndFilter).
// Like a Vue `<AttendanceSearchFilterBar>` component -- renders the search
// text field alongside the optional filter-icon button in the Results tab.
//
// Stateless: the TextEditingController is owned by the parent (so the search
// query persists across rebuilds), and all actions fire callbacks. In Laravel
// terms this is a Blade partial that only renders; it never mutates state.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Search bar + optional filter button row used in the attendance Results tab.
///
/// Parameters (like Vue props / emits):
/// - [searchController]  -- the TextEditingController owned by the parent
///                          so search text survives widget rebuilds
/// - [searchFilterKey]   -- GlobalKey for the tour highlight on this row
/// - [hasActiveFilter]   -- whether at least one filter chip is active;
///                          colours the filter button to indicate state
/// - [primaryColor]      -- role-based accent colour
/// - [showFilterButton]  -- set to true on the Results tab, false elsewhere
/// - [languageProvider]  -- for translating placeholder text
/// - [onSearchChanged]   -- called on every keystroke; parent calls setState
/// - [onFilterTap]       -- called when the filter icon is tapped; parent
///                          shows the filter bottom sheet
class AttendanceSearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final GlobalKey searchFilterKey;
  final bool hasActiveFilter;
  final Color primaryColor;
  final bool showFilterButton;
  final LanguageProvider languageProvider;
  final VoidCallback onSearchChanged;
  final VoidCallback onFilterTap;

  const AttendanceSearchFilterBar({
    super.key,
    required this.searchController,
    required this.searchFilterKey,
    required this.hasActiveFilter,
    required this.primaryColor,
    required this.showFilterButton,
    required this.languageProvider,
    required this.onSearchChanged,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        key: searchFilterKey,
        children: [
          // Search text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: ColorUtils.slate900, fontSize: 14),
                decoration: InputDecoration(
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Search attendance...',
                    'id': 'Cari absensi...',
                  }),
                  hintStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: ColorUtils.slate400,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => onSearchChanged(),
              ),
            ),
          ),

          // Filter toggle button -- only shown in the Results tab
          if (showFilterButton) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: hasActiveFilter ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasActiveFilter ? primaryColor : ColorUtils.slate200,
                ),
                boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
              ),
              child: IconButton(
                onPressed: onFilterTap,
                icon: Icon(
                  Icons.tune,
                  color: hasActiveFilter ? Colors.white : ColorUtils.slate600,
                  size: 20,
                ),
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Filter',
                  'id': 'Filter',
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
