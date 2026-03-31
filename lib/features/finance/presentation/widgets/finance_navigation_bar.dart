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

  /// Key applied to the currently selected tab item (used by the coach-mark tour).
  final GlobalKey tabBarKey;

  /// Number of pending payments — displayed as a red badge on tab 2.
  final int pendingCount;

  /// Primary theme colour already resolved by the parent.
  final Color primaryColor;

  /// Called when the user taps a tab with the new index.
  final ValueChanged<int> onTabSelected;

  const FinanceNavigationBar({
    super.key,
    required this.currentIndex,
    required this.tabBarKey,
    required this.pendingCount,
    required this.primaryColor,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'icon': Icons.dashboard_rounded,
        'label': AppLocalizations.dashboard.tr,
        'index': 0,
      },
      {
        'icon': Icons.payment_rounded,
        'label': AppLocalizations.paymentTypes.tr,
        'index': 1,
      },
      {
        'icon': Icons.verified_rounded,
        'label': AppLocalizations.verification.tr,
        'index': 2,
        'badge': pendingCount,
      },
      {
        'icon': Icons.school_rounded,
        'label': AppLocalizations.classReport.tr,
        'index': 3,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: items.map((item) {
          final index = item['index'] as int;
          final isSelected = currentIndex == index;
          final badge = item['badge'] as int? ?? 0;

          return Expanded(
            child: GestureDetector(
              // Attach the tour key to whichever tab is currently selected.
              key: isSelected ? tabBarKey : null,
              onTap: () => onTabSelected(index),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: isSelected
                        ? primaryColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 22,
                          color: isSelected ? primaryColor : ColorUtils.slate400,
                        ),
                        if (badge > 0)
                          Positioned(
                            right: -8,
                            top: -4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: badge > 9 ? 4 : 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.error600,
                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                              ),
                              child: Text(
                                badge > 99 ? '99+' : '$badge',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? primaryColor : ColorUtils.slate500,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
