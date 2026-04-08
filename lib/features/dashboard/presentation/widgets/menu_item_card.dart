import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Full-width list row menu item — icon, title, subtitle, badge, chevron.
class MenuItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final dynamic icon;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? primaryColor;
  final Color? iconColor;

  const MenuItemCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.badgeCount,
    this.primaryColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = iconColor ?? primaryColor ?? ColorUtils.corporateBlue600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildIconWidget(icon, p),
              ),
              const SizedBox(width: 14),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate400,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Badge
              if (badgeCount != null && badgeCount! > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColorUtils.error600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeCount! > 99 ? '99+' : badgeCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Chevron
              Icon(Icons.chevron_right_rounded, size: 20, color: ColorUtils.slate300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconWidget(dynamic iconData, Color color) {
    if (iconData is IconData) {
      return Icon(iconData, size: 20, color: color);
    } else if (iconData is String) {
      return Center(child: Text(iconData, style: const TextStyle(fontSize: 18)));
    }
    return const SizedBox.shrink();
  }
}
