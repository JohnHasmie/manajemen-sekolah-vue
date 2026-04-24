import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';

/// Mixin for UI building helpers.
///
/// Provides methods for building UI components like header menu items,
/// search bar, and filter chips. Assumes the State provides context,
/// ref, and color utilities.
mixin ClassroomUiMixin on ConsumerState<AdminClassManagementScreen> {
  // Abstract state fields
  bool get hasActiveFilter;
  TextEditingController get searchController;

  GlobalKey get menuKey;
  GlobalKey get filterKey;

  Color getPrimaryColor();

  /// Builds the menu items for the header action menu.
  List<PopupMenuEntry<String>> buildMenuItems(
    LanguageProvider languageProvider,
  ) {
    return [
      PopupMenuItem<String>(
        value: 'refresh',
        child: Row(
          children: [
            Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
            const SizedBox(width: AppSpacing.sm),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Refresh Data',
                'id': 'Perbarui Data',
              }),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'export',
        child: Row(
          children: [
            const Icon(Icons.download, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Export to Excel',
                'id': 'Export ke Excel',
              }),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'import',
        child: Row(
          children: [
            const Icon(Icons.upload, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Import from Excel',
                'id': 'Import dari Excel',
              }),
            ),
          ],
        ),
      ),
      PopupMenuItem<String>(
        value: 'template',
        child: Row(
          children: [
            const Icon(Icons.file_download, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Download Template',
                'id': 'Download Template',
              }),
            ),
          ],
        ),
      ),
    ];
  }

  /// Builds the filter button widget.
  Widget buildFilterButton(
    LanguageProvider languageProvider,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: hasActiveFilter
            ? Colors.white
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          IconButton(
            onPressed: onPressed,
            icon: Icon(
              Icons.tune,
              color: hasActiveFilter ? getPrimaryColor() : Colors.white,
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
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the filter chips bar.
  Widget buildFilterChipsBar(
    LanguageProvider languageProvider,
    List<Map<String, dynamic>> chips,
    VoidCallback onClearAll,
  ) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          _buildFilterIcon(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _buildChipsList(chips)),
          const SizedBox(width: AppSpacing.sm),
          _buildClearButton(onClearAll),
        ],
      ),
    );
  }

  Widget _buildFilterIcon() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: const Icon(Icons.filter_alt, size: 18, color: Colors.white),
    );
  }

  Widget _buildChipsList(List<Map<String, dynamic>> chips) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [...chips.map(_buildChip)],
    );
  }

  Widget _buildChip(Map<String, dynamic> filter) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(
          filter['label'],
          style: TextStyle(
            fontSize: 12,
            color: getPrimaryColor(),
            fontWeight: FontWeight.w500,
          ),
        ),
        deleteIcon: Icon(Icons.close, size: 16, color: getPrimaryColor()),
        onDeleted: filter['onRemove'],
        backgroundColor: getPrimaryColor().withValues(alpha: 0.1),
        side: BorderSide(
          color: getPrimaryColor().withValues(alpha: 0.3),
          width: 1,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.only(left: 4),
      ),
    );
  }

  Widget _buildClearButton(VoidCallback onClearAll) {
    return InkWell(
      onTap: onClearAll,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: const Icon(Icons.clear_all, size: 18, color: Colors.white),
      ),
    );
  }

  /// Called when menu item is selected.
  void onMenuSelected(String value);

  /// Called when search is submitted.
  void onSearchSubmitted();
}
