import 'package:flutter/material.dart';

/// Builds the card container with proper theming and styling.
class ScheduleCardContainer extends StatelessWidget {
  final Color cardBg;
  final Color cardBorder;
  final double borderWidth;
  final List<BoxShadow> boxShadow;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Widget child;

  const ScheduleCardContainer({
    super.key,
    required this.cardBg,
    required this.cardBorder,
    required this.borderWidth,
    required this.boxShadow,
    required this.onTap,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: borderRadius,
              border: Border.all(color: cardBorder, width: borderWidth),
              boxShadow: boxShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
