// Bottom navigation bar for the admin finance screen.
//
// Extracted from `_buildNavigationBar` in admin_finance_screen.dart.
// Like a Vue `<FinanceNavigationBar>` component — stateless, receives the
// active tab index, badge count, primary colour, and a callback for tab
// selection.
//
// The four tabs are: Dashboard (0), Payment Types (1), Verification (2),
// Class Report (3).  Tab 2 shows a badge when there are pending payments.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Horizontal tab-bar that sits at the top of the finance screen body.
///
/// Stateless — the parent [FinanceScreenState] owns [currentIndex] and calls
/// [onTabSelected] when the user taps a tab, just like Vue `v-model` on tabs.
class FinanceNavigationBar extends StatelessWidget {
  /// Index of the currently active tab (0–3).
  final int currentIndex;

  /// Number of pending payments — displayed as a red badge on tab 2.
  final int pendingCount;

  /// Primary theme colour already resolved by the parent.
  final Color primaryColor;

  /// Called when the user taps a tab with the new index.
  final ValueChanged<int> onTabSelected;

  const FinanceNavigationBar({
    super.key,
    required this.currentIndex,
    required this.pendingCount,
    required this.primaryColor,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: AppLocalizations.dashboard.tr,
      ),
      _NavItem(
        icon: Icons.payments_rounded,
        label: AppLocalizations.paymentTypes.tr,
      ),
      _NavItem(
        icon: Icons.verified_rounded,
        label: AppLocalizations.verification.tr,
        badge: pendingCount,
      ),
      _NavItem(
        icon: Icons.school_rounded,
        label: AppLocalizations.classReport.tr,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: ColorUtils.slate200, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = currentIndex == index;
          return Expanded(
            child: _TabPill(
              item: item,
              isSelected: isSelected,
              primaryColor: primaryColor,
              onTap: () => onTabSelected(index),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int badge;

  const _NavItem({required this.icon, required this.label, this.badge = 0});
}

class _TabPill extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _TabPill({
    required this.item,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm + 2,
          horizontal: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? primaryColor : ColorUtils.slate500,
                ),
                if (item.badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: item.badge > 9 ? 4 : 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        item.badge > 99 ? '99+' : '${item.badge}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10.5,
                color: isSelected ? primaryColor : ColorUtils.slate600,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
