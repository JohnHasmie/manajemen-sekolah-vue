// Gradient header bar for the admin announcement screen.
// Contains the back button, title, search field, filter button, and active filter chips.
// Like a Vue <AnnouncementScreenHeader> component — purely presentational, driven by callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Gradient header for [AdminAnnouncementScreen].
///
/// In Vue terms this is a `<AnnouncementScreenHeader>` component that receives
/// all display data as props and fires events (callbacks) for every user action.
/// No state lives here — the parent screen owns everything and passes it down.
class AnnouncementScreenHeader extends StatelessWidget {
  /// The active language/translation provider.
  final LanguageProvider languageProvider;

  /// Primary brand color for this role (admin).
  final Color primaryColor;

  /// Gradient applied to the header background.
  final LinearGradient cardGradient;

  /// Controller bound to the search text field.
  final TextEditingController searchController;

  /// [GlobalKey] attached to the search field (used by the onboarding tour).
  final GlobalKey searchKey;

  /// [GlobalKey] attached to the filter button (used by the onboarding tour).
  final GlobalKey filterKey;

  /// Whether any filter is currently active — shows the badge dot and chip row.
  final bool hasActiveFilter;

  /// List of active filter chips to render.
  /// Each map has keys `label` (String) and `onRemove` (VoidCallback).
  final List<Map<String, dynamic>> filterChips;

  /// Called when the user taps the back arrow.
  final VoidCallback onBack;

  /// Called when the user selects "Refresh data" from the overflow menu.
  final VoidCallback onRefresh;

  /// Called when the user taps the filter (tune) button.
  final VoidCallback onFilterTap;

  /// Called when the user submits a search (enter key or search icon tap).
  final VoidCallback onSearch;

  /// Called when the user taps the red "clear all filters" button.
  final VoidCallback onClearAllFilters;

  const AnnouncementScreenHeader({
    super.key,
    required this.languageProvider,
    required this.primaryColor,
    required this.cardGradient,
    required this.searchController,
    required this.searchKey,
    required this.filterKey,
    required this.hasActiveFilter,
    required this.filterChips,
    required this.onBack,
    required this.onRefresh,
    required this.onFilterTap,
    required this.onSearch,
    required this.onClearAllFilters,
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
        gradient: cardGradient,
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
          // ── Top row: back button · title · overflow menu ──
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
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Announcement Management',
                        'id': 'Manajemen Pengumuman',
                      }),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Manage and create announcements',
                        'id': 'Kelola dan buat pengumuman',
                      }),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'refresh') onRefresh();
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 20,
                          color: ColorUtils.info600,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Update Data',
                            'id': 'Perbarui Data',
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Search bar + filter button row ──
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: searchKey,
                          controller: searchController,
                          style: TextStyle(color: ColorUtils.slate800),
                          decoration: InputDecoration(
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Search announcements...',
                              'id': 'Cari pengumuman...',
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
                          onSubmitted: (_) => onSearch(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: primaryColor),
                          onPressed: onSearch,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // ── Filter button with active-state badge dot ──
              Container(
                key: filterKey,
                decoration: BoxDecoration(
                  color: hasActiveFilter
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  children: [
                    IconButton(
                      onPressed: onFilterTap,
                      icon: Icon(
                        Icons.tune,
                        color: hasActiveFilter ? primaryColor : Colors.white,
                      ),
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

          // ── Active filter chip row (only shown when filters are applied) ──
          if (hasActiveFilter) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Icon(
                      Icons.filter_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...filterChips.map((filter) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(
                                filter['label'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              deleteIcon: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white70,
                              ),
                              onDeleted: filter['onRemove'] as VoidCallback,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1,
                              ),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8)),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 0,
                              ),
                              labelPadding: const EdgeInsets.only(left: 2),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InkWell(
                    onTap: onClearAllFilters,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                      child: const Icon(
                        Icons.clear_all,
                        size: 16,
                        color: Colors.white,
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
