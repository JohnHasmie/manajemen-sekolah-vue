// A card displaying a single statistic with icon, value, and label.
//
// Used in summary rows at the top of management/report screens.
// Replaces duplicated stat card patterns in attendance, finance,
// grades, and dashboard screens.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A card showing a single metric with an icon, value, and label.
///
/// Example:
/// ```dart
/// StatSummaryCard(
///   label: 'Hadir',
///   value: '156',
///   icon: Icons.check_circle,
///   color: Colors.green,
/// )
/// ```
class StatSummaryCard extends StatelessWidget {
  /// Descriptive label below the value (e.g., "Hadir", "Total").
  final String label;

  /// The metric value to display prominently (e.g., "156", "92%").
  final String value;

  /// Icon shown in a circular container above the value.
  final IconData icon;

  /// Accent color for the icon, value text, and background tints.
  final Color color;

  /// Optional secondary text below the label.
  final String? subtitle;

  /// Called when the card is tapped. If null, card is not tappable.
  final VoidCallback? onTap;

  /// Fixed width of the card. If null, the card expands to fill
  /// available space (use inside an [Expanded] or [StatSummaryRow]).
  final double? width;

  const StatSummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          AppSpacing.v8,

          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),

          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),

          // Subtitle (optional)
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

/// A horizontal row of [StatSummaryCard]s with equal spacing.
///
/// Automatically distributes cards evenly across the available width.
///
/// Example:
/// ```dart
/// StatSummaryRow(
///   cards: [
/// StatSummaryCard(label: 'Hadir', value: '24', icon: Icons.check, color:
/// Colors.green),
/// StatSummaryCard(label: 'Sakit', value: '2', icon: Icons.healing, color:
/// Colors.orange),
/// StatSummaryCard(label: 'Alpha', value: '1', icon: Icons.close, color:
/// Colors.red),
///   ],
/// )
/// ```
class StatSummaryRow extends StatelessWidget {
  /// The stat cards to display in a row.
  final List<StatSummaryCard> cards;

  /// Padding around the entire row.
  final EdgeInsets padding;

  /// Spacing between cards.
  final double spacing;

  /// If true, the row is horizontally scrollable. Default: false.
  final bool scrollable;

  const StatSummaryRow({
    super.key,
    required this.cards,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(children: _buildCardList()),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        children: cards.asMap().entries.map((entry) {
          final isLast = entry.key == cards.length - 1;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : spacing),
              child: entry.value,
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildCardList() {
    final List<Widget> widgets = [];
    for (int i = 0; i < cards.length; i++) {
      widgets.add(cards[i]);
      if (i < cards.length - 1) {
        widgets.add(SizedBox(width: spacing));
      }
    }
    return widgets;
  }
}
