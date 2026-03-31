// Custom tab switcher component with icon + label tab buttons.
//
// Like a Vue `<v-tabs>` or `<b-tabs>` component that renders a horizontal
// row of tab buttons. Each tab has an icon and label, and the active tab
// is highlighted with the primary color. Similar to a Bootstrap tab bar
// in a Laravel Blade layout.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A horizontal tab switcher with icon and label for each tab.
///
/// Like a Vue `<TabSwitcher>` component with props:
/// - [tabController] - Flutter's TabController (like Vue's `v-model` for active tab index)
/// - [tabs] - list of [TabItem] objects defining label and icon for each tab
/// - [primaryColor] - highlight color for the selected tab
///
/// Uses `tabController.animateTo(index)` when a tab is tapped, which triggers
/// the associated `TabBarView` to switch pages (like Vue's `<v-tabs-items>`).
class TabSwitcher extends StatelessWidget {
  final TabController tabController;
  final List<TabItem> tabs;
  final Color? primaryColor;

  const TabSwitcher({
    super.key,
    required this.tabController,
    required this.tabs,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? ColorUtils.getRoleColor('guru');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          return Expanded(child: _buildTabButton(index, tab, color));
        }).toList(),
      ),
    );
  }

  /// Builds a single tab button with icon and label.
  /// Highlights with [primaryColor] when selected.
  Widget _buildTabButton(int tabIndex, TabItem tab, Color primaryColor) {
    final isSelected = tabController.index == tabIndex;

    return Material(
      color: isSelected
          ? primaryColor.withValues(alpha: 0.85)
          : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        onTap: () {
          tabController.animateTo(tabIndex);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tab.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data class representing a single tab's label and icon.
/// Like a simple object `{ label: 'Students', icon: Icons.people }` in Vue.
class TabItem {
  final String label;
  final IconData icon;

  TabItem({required this.label, required this.icon});
}
