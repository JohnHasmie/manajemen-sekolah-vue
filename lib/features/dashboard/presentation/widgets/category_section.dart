// Expandable category section for organizing dashboard navigation items.
//
// Like a Vue `<CollapsibleSection>` component or a Bootstrap accordion panel
// in a Laravel dashboard sidebar. Groups related menu items under a collapsible
// header with an animated expand/collapse transition. Each item renders as a
// MenuItemCard (like a `<router-link>` card in Vue).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/dashboard_typography.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Data class for a single menu item in a [CategorySection].
/// Like a route definition object `{ title, icon, path }` in a Vue router config.
class MenuItem {
  final String title;
  final dynamic icon;
  final VoidCallback onTap;
  final int? badgeCount;

  MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });
}

/// Expandable category section for organized dashboard navigation.
///
/// Like a Vue `<CollapsePanel>` or Bootstrap `<b-collapse>` component.
/// Groups menu items into collapsible categories with an animated
/// expand/collapse transition. Each category has a colored header with
/// icon and title, and expands to show a list of [MenuItemCard] widgets.
///
/// Uses `AnimationController` for smooth rotation of the arrow icon and
/// `AnimatedSize` for the expand/collapse content area (like Vue's `<transition>`).
class CategorySection extends StatefulWidget {
  /// Title of the category
  final String title;

  /// Icon for the category
  final IconData icon;

  /// Accent color for the category
  final Color accentColor;

  /// List of menu items in this category
  final List<MenuItem> items;

  /// Whether category starts expanded
  final bool initiallyExpanded;

  /// Key for persisting expansion state
  final String? persistenceKey;

  /// Primary color for menu item cards
  final Color? primaryColor;

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
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;

    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _iconRotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Toggles the expanded/collapsed state with animation.
  /// Like Vue's `this.isExpanded = !this.isExpanded` triggering a `<transition>`.
  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpansion,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: ColorUtils.categoryHeaderDecoration(
                  accentColor: widget.accentColor,
                  isExpanded: _isExpanded,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 18, color: widget.accentColor),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: DashboardTypography.categoryTitle(
                          color: widget.accentColor,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _iconRotation,
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: widget.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expandable content
          AnimatedSize(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded ? _buildGrid() : SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: widget.items.length,
      separatorBuilder: (context, index) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        return _buildAnimatedCard(item, index);
      },
    );
  }

  Widget _buildAnimatedCard(MenuItem item, int index) {
    // Staggered animation for cards
    final delay = index * 50;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: MenuItemCard(
        title: item.title,
        icon: item.icon,
        onTap: item.onTap,
        badgeCount: item.badgeCount,
        primaryColor: widget.primaryColor,
      ),
    );
  }
}
