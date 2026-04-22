// Extracted from parent_attendance_screen.dart (_buildHeader).
// Like a Vue `<AttendanceHeader>` component -- the gradient top bar with
// back button, student name, search field, filter button, and active-filter
// chips. All callbacks are passed in as props so the widget stays stateless.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Gradient header bar for the parent attendance screen.
///
/// Stateless: the parent screen owns all state; this widget only renders
/// and fires callbacks. Like a Vue `<HeaderBar>` receiving computed props.
///
/// Parameters (like Vue props):
/// - [gradient]          -- LinearGradient for the background
/// - [primaryColor]      -- role-based accent color
/// - [studentName]       -- child's full name (null while loading)
/// - [hasActiveFilter]   -- true when any filter is applied (shows dot badge)
/// - [searchController]  -- TextEditingController shared with the screen state
/// - [filterChips]       -- list of active-filter chip descriptors
///                          Each map has 'label' (String) and 'onRemove' (VoidCallback)
/// - [languageProvider]  -- used for translating all labels
/// - [onSearchChanged]   -- fires on every keystroke in the search field
/// - [onFilterTap]       -- opens the filter bottom sheet
/// - [onClearAllFilters] -- removes all active filters
/// - [onRefresh]         -- triggers a cache-busting data reload
class ParentAttendanceHeader extends StatelessWidget {
  final LinearGradient gradient;
  final Color primaryColor;
  final String? studentName;
  final bool hasActiveFilter;
  final TextEditingController searchController;
  final List<Map<String, dynamic>> filterChips;
  final LanguageProvider languageProvider;
  final VoidCallback onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onClearAllFilters;
  final VoidCallback onRefresh;

  const ParentAttendanceHeader({
    super.key,
    required this.gradient,
    required this.primaryColor,
    required this.studentName,
    required this.hasActiveFilter,
    required this.searchController,
    required this.filterChips,
    required this.languageProvider,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onClearAllFilters,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back button, title + student name, overflow menu
          Row(
            children: [
              GestureDetector(
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kehadiran Anak',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (studentName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        studentName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'refresh') onRefresh();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: ColorUtils.info600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(AppLocalizations.updateData.tr),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Search + filter button row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => onSearchChanged(),
                    style: TextStyle(color: ColorUtils.slate900),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search subject or status...',
                        'id': 'Cari mapel atau status...',
                      }),
                      hintStyle: TextStyle(color: ColorUtils.slate400),
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
              ),
              const SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: onFilterTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.tune_rounded,
                          color: hasActiveFilter ? primaryColor : Colors.white,
                          size: 22,
                        ),
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
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Active-filter chips (only when a filter is applied)
          if (hasActiveFilter) ...[
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...filterChips.map((chip) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: chip['onRemove'] as VoidCallback,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(10),
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chip['label'] as String,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  InkWell(
                    onTap: onClearAllFilters,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Clear All',
                          'id': 'Hapus Semua',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
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
