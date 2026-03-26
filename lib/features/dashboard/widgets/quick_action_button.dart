// Quick action button for common dashboard tasks in a horizontal scroll.
//
// Like a Vue `<QuickAction>` component displayed in a horizontal `<v-slide-group>`,
// or a shortcut button row in a Laravel admin panel. Each button has an icon,
// label, and optional notification badge. Similar to iOS-style quick action
// buttons below a hero section.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A quick action button with icon, label, and optional badge.
///
/// Like a Vue `<QuickActionButton>` in a horizontal scrollable row:
/// - [label] - button text below the icon
/// - [icon] - Material icon
/// - [onTap] - action callback (like `@click`)
/// - [color] - accent color for the icon container
/// - [badgeCount] - optional notification count badge (like Vue's `<v-badge>`)
///
/// Displayed in a horizontal scroll below the hero section on the dashboard.
class QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final int? badgeCount;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.color,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon container with shadow
            Container(
              width: 65,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: ColorUtils.slate200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      icon,
                      color: color,
                      size: 22,
                    ),
                  ),
                  // Badge
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: ColorUtils.error600,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount! > 9 ? '9+' : badgeCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 6),

            // Label
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
