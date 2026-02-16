import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

/// Professional menu item card for dashboard navigation
/// Replaces the old _buildDashboardCard with improved styling
class MenuItemCard extends StatelessWidget {
  /// Title of the menu item
  final String title;

  /// Icon to display (can be IconData or String for emoji)
  final dynamic icon;

  /// Callback when card is tapped
  final VoidCallback onTap;

  /// Optional badge count for notifications
  final int? badgeCount;

  /// Primary color for the card accent
  final Color? primaryColor;

  const MenuItemCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.badgeCount,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePrimaryColor = primaryColor ?? ColorUtils.corporateBlue600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 66,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ColorUtils.slate200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: effectivePrimaryColor.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container with border
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectivePrimaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: effectivePrimaryColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: _buildIconWidget(icon, effectivePrimaryColor),
              ),
              SizedBox(width: 12),

              // Title and badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                              letterSpacing: -0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Notification badge
                        if (badgeCount != null && badgeCount! > 0)
                          Container(
                            margin: EdgeInsets.only(left: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.error600,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: ColorUtils.error600.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              badgeCount! > 99 ? '99+' : badgeCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                Icons.chevron_right,
                size: 20,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWidget(dynamic iconData, Color color) {
    if (iconData is IconData) {
      return Icon(
        iconData,
        size: 24,
        color: color,
      );
    } else if (iconData is String) {
      // Handle emoji
      return Center(
        child: Text(
          iconData,
          style: TextStyle(fontSize: 24),
        ),
      );
    }
    return SizedBox.shrink();
  }
}
