import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';

/// Data class for a single menu item.
class MenuItem {
  final String title;
  final String? subtitle;
  final dynamic icon;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? iconColor;

  MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.badgeCount,
    this.iconColor,
  });
}

/// Menu section with a label + grouped list rows.
class CategorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<MenuItem> items;
  final Color? primaryColor;

  // Kept for API compat but ignored
  final bool initiallyExpanded;
  final String? persistenceKey;

  const CategorySection({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.items,
    this.initiallyExpanded = true,
    this.persistenceKey,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = primaryColor ?? ColorUtils.corporateBlue600;

    // Strip emoji prefix from title
    final cleanTitle = title.replaceAll(RegExp(r'^[^\w]*\s*'), '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10, top: 2),
          child: Text(
            cleanTitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate400,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Grouped card with list rows
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate100),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isLast = i == items.length - 1;
              return Column(
                children: [
                  MenuItemCard(
                    title: item.title,
                    subtitle: item.subtitle,
                    icon: item.icon,
                    onTap: item.onTap,
                    badgeCount: item.badgeCount,
                    primaryColor: p,
                    iconColor: item.iconColor,
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 56),
                      child: Divider(height: 1, color: ColorUtils.slate100),
                    ),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
