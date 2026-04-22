// A small pill-shaped drag indicator for bottom sheets.
//
// Replaces 14+ identical Container(width: 40, height: 4, ...) patterns
// scattered across feature-specific bottom sheets.
import 'package:flutter/material.dart';

/// A small pill-shaped drag indicator typically placed at the top
/// of a modal bottom sheet.
///
/// Two styles are provided:
/// - Default (grey on white background)
/// - `DragHandle.onGradient()` (semi-transparent white for gradient headers)
///
/// Example:
/// ```dart
/// Column(children: [
///   const DragHandle(),          // grey on white
///   const DragHandle.onGradient(), // white on gradient
/// ])
/// ```
class DragHandle extends StatelessWidget {
  /// Pill color. Defaults to `Colors.grey.shade300`.
  final Color? color;

  /// Top margin. Defaults to 12.
  final double topMargin;

  /// Bottom margin. Defaults to 0.
  final double bottomMargin;

  const DragHandle({
    super.key,
    this.color,
    this.topMargin = 12,
    this.bottomMargin = 0,
  });

  /// A variant with semi-transparent white for use on gradient headers.
  const DragHandle.onGradient({
    super.key,
    this.topMargin = 0,
    this.bottomMargin = 16,
  }) : color = const Color(0x59FFFFFF); // Colors.white @ 0.35

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(top: topMargin, bottom: bottomMargin),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
