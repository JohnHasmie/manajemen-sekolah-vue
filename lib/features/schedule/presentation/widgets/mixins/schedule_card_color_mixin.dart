import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for color and styling calculations in schedule cards.
mixin ScheduleCardColorMixin {
  // Abstract members requiring implementation.
  void setState(VoidCallback fn);
  BuildContext get context;

  // State properties.
  bool get isPast => false;
  bool get isCurrent => false;
  bool get isNext => false;

  // Summary data access — overridden by ScheduleCardDataMixin with
  // per-hour logic. Defaults here are safe fallbacks.
  bool hasAttendance(Map<String, dynamic>? summary) => false;
  bool hasActivity(Map<String, dynamic>? summary) => false;
  bool hasMaterial(Map<String, dynamic>? summary) => false;

  /// Returns color record with text, background, border, and accent.
  ({
    Color textColor,
    Color subTextColor,
    Color accentColor,
    Color cardBg,
    Color cardBorder,
    double borderWidth,
  })
  getCardColors(Color primary, Map<String, dynamic>? summary) {
    final accentColor = isPast ? ColorUtils.slate400 : primary;
    final subTextColor = isPast ? ColorUtils.slate400 : ColorUtils.slate500;

    return (
      textColor: ColorUtils.slate900,
      subTextColor: subTextColor,
      accentColor: accentColor,
      cardBg: getCardBackground(primary, summary),
      cardBorder: getCardBorder(primary),
      borderWidth: getCardBorderWidth(),
    );
  }

  /// Determines card background based on state and completion.
  Color getCardBackground(Color primary, Map<String, dynamic>? summary) {
    final allFilled =
        hasAttendance(summary) && hasActivity(summary) && hasMaterial(summary);

    if (allFilled || isCurrent) {
      return primary.withValues(alpha: 0.08);
    }
    return isNext ? primary.withValues(alpha: 0.04) : Colors.white;
  }

  /// Determines card border color based on card state.
  Color getCardBorder(Color primary) {
    if (isCurrent) {
      return primary.withValues(alpha: 0.5);
    }
    return isNext ? primary.withValues(alpha: 0.2) : ColorUtils.slate200;
  }

  /// Determines border width based on card state.
  double getCardBorderWidth() => isCurrent ? 1.5 : (isNext ? 1.2 : 1.0);

  /// Returns shadow list based on card state.
  List<BoxShadow> getCardShadow(Color primary) {
    if (isCurrent) {
      return [
        BoxShadow(
          color: primary.withValues(alpha: 0.15),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
    }
    return isPast ? [] : ColorUtils.corporateShadow(elevation: 1.0);
  }
}
