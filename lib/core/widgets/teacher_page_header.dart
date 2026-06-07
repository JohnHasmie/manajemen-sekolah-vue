// Extended gradient header for teacher and parent screens.
//
// Combines GradientPageHeader base with role toggle, search bar,
// and active filter chips. Replaces ~80 lines × 10+ screens of
// duplicated header code.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/role_toggle.dart';
import 'package:manajemensekolah/core/widgets/search_filter_bar.dart';

/// A gradient header that combines the base GradientPageHeader pattern
/// with optional role toggle, search bar, and active filter chips.
///
/// Active filter chips are rendered in a white bar below the gradient
/// header, matching the standard filter UI pattern.
class TeacherPageHeader extends StatelessWidget {
  // ── Base header props ──

  /// Page title.
  final String title;

  /// Subtitle text below the title.
  final String subtitle;

  /// Gradient base color.
  final Color primaryColor;

  /// Override for back button behavior. Falls back to Navigator.pop.
  final VoidCallback? onBackPressed;

  /// Whether to show the back button. Default: auto-detects.
  final bool? showBackButton;

  /// Icon shown in the back button. Defaults to `Icons.arrow_back`. Use
  /// `Icons.close_rounded` (or similar) when the screen is opened modally
  /// — e.g. as a bottom sheet or full-screen dialog — so the affordance
  /// reads as "dismiss" rather than "navigate back".
  final IconData backIcon;

  /// Optional trailing widget in the title row (e.g., popup menu, view toggle).
  final Widget? trailing;

  // ── Role toggle props ──

  /// Whether to show the teaching/homeroom toggle. Default: false.
  final bool showRoleToggle;

  /// Whether the homeroom tab is currently active.
  final bool isHomeroomView;

  /// Called when the role toggle changes.
  final ValueChanged<bool>? onRoleChanged;

  /// Homeroom class name shown in the toggle label.
  final String? homeroomClassName;

  /// Label for teaching mode. Default: 'Mengajar'.
  final String teachingLabel;

  /// Label for homeroom mode. Default: 'Wali Kelas'.
  final String homeroomLabel;

  // ── Search + filter props ──

  /// Whether to show the search + filter bar. Default: false.
  final bool showSearchFilter;

  /// Text controller for the search field.
  final TextEditingController? searchController;

  /// Called on each keystroke in the search field.
  final ValueChanged<String>? onSearchChanged;

  /// Called when the search field is submitted.
  final ValueChanged<String>? onSearchSubmitted;

  /// Called when the search icon is pressed.
  final VoidCallback? onSearchTap;

  /// Called when the filter button is pressed.
  final VoidCallback? onFilterTap;

  /// Whether the filter button shows an active-filter badge.
  final bool hasActiveFilter;

  /// Search placeholder text.
  final String searchHintText;

  /// Optional key for tour targeting the search field.
  final Key? searchFieldKey;

  // ── Active filter chips ──

  /// List of active filters displayed as dismissible chips
  /// in a white bar below the gradient header.
  final List<ActiveFilter>? activeFilters;

  /// Called when the "Clear all" button is tapped.
  final VoidCallback? onClearAllFilters;

  const TeacherPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    this.onBackPressed,
    this.showBackButton,
    this.backIcon = Icons.arrow_back,
    this.trailing,
    // Role toggle
    this.showRoleToggle = false,
    this.isHomeroomView = false,
    this.onRoleChanged,
    this.homeroomClassName,
    this.teachingLabel = 'Mengajar',
    this.homeroomLabel = 'Wali Kelas',
    // Search + filter
    this.showSearchFilter = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchTap,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.searchHintText = 'Cari...',
    this.searchFieldKey,
    // Filter chips
    this.activeFilters,
    this.onClearAllFilters,
  });

  @override
  Widget build(BuildContext context) {
    final canPop =
        showBackButton ??
        (onBackPressed != null || AppNavigator.canPop(context));
    final filterCount = activeFilters?.length ?? 0;
    final showChips = activeFilters != null && activeFilters!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gradient header
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + AppSpacing.lg,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
            ),
            boxShadow: showChips
                ? null
                : [
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
              // Title row: back + title/subtitle + trailing
              Row(
                children: [
                  if (canPop) ...[
                    GestureDetector(
                      onTap: onBackPressed ?? () => AppNavigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(10),
                          ),
                        ),
                        child: Icon(backIcon, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
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
                  ),
                  if (trailing != null) trailing!,
                ],
              ),

              // Role toggle
              if (showRoleToggle && onRoleChanged != null) ...[
                const SizedBox(height: AppSpacing.md),
                RoleToggle(
                  isHomeroomView: isHomeroomView,
                  onChanged: onRoleChanged!,
                  primaryColor: primaryColor,
                  homeroomClassName: homeroomClassName,
                  teachingLabel: teachingLabel,
                  homeroomLabel: homeroomLabel,
                ),
              ],

              // Search + filter bar
              if (showSearchFilter && searchController != null) ...[
                const SizedBox(height: AppSpacing.md),
                SearchFilterBar(
                  controller: searchController!,
                  hintText: searchHintText,
                  onChanged: onSearchChanged,
                  onSubmitted: onSearchSubmitted,
                  onSearchTap: onSearchTap,
                  onFilterTap: onFilterTap,
                  hasActiveFilter: hasActiveFilter,
                  activeFilterCount: filterCount,
                  transparentStyle: true,
                  primaryColor: primaryColor,
                  searchFieldKey: searchFieldKey,
                ),
              ],
            ],
          ),
        ),

        // Active filter chips — white bar below the gradient
        if (showChips)
          ActiveFilterChips(
            filters: activeFilters!,
            primaryColor: primaryColor,
            onClearAll: onClearAllFilters,
            clearAllLabel: kCorWidClear.tr,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            transparentStyle: false,
          ),
      ],
    );
  }
}
