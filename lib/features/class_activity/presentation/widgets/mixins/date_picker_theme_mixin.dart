import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building date picker theme
mixin DatePickerThemeMixin {
  /// Builds the themed DatePickerThemeData for the calendar
  ThemeData buildDatePickerTheme(Color primaryColor) {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      colorScheme: _buildColorScheme(primaryColor),
      datePickerTheme: _buildDatePickerThemeData(primaryColor),
    );
  }

  /// Builds the color scheme
  ColorScheme _buildColorScheme(Color primary) {
    return ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ColorUtils.slate800,
      secondary: primary,
    );
  }

  /// Builds the date picker theme data
  DatePickerThemeData _buildDatePickerThemeData(Color primary) {
    return DatePickerThemeData(
      headerBackgroundColor: primary,
      headerForegroundColor: Colors.white,
      backgroundColor: Colors.white,
      elevation: 0,
      dayForegroundColor: WidgetStateProperty.resolveWith(
        _dayForegroundResolver,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => _dayBackgroundResolver(states, primary),
      ),
      todayForegroundColor: WidgetStateProperty.all(primary),
      todayBackgroundColor: WidgetStateProperty.all(
        primary.withValues(alpha: 0.1),
      ),
    );
  }

  /// Resolves day text foreground color
  Color _dayForegroundResolver(Set<WidgetState> states) {
    return states.any(
          (s) => s == WidgetState.selected || s == WidgetState.pressed,
        )
        ? Colors.white
        : ColorUtils.slate800;
  }

  /// Resolves day background color
  Color _dayBackgroundResolver(Set<WidgetState> states, Color primary) {
    return states.any(
          (s) => s == WidgetState.selected || s == WidgetState.pressed,
        )
        ? primary
        : Colors.transparent;
  }
}
