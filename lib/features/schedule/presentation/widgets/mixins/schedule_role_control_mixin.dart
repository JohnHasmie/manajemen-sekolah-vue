import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin providing UI-building methods for ScheduleRoleSegmentedControl.
///
/// Extracted to reduce widget complexity and improve maintainability.
/// Provides segment building and class picker presentation logic.
mixin ScheduleRoleControlMixin {
  /// Primary color for active states and icons.
  Color get primaryColor;

  /// Current selection state: true = homeroom view, false = teaching view.
  bool get isHomeroomView;

  /// List of available homeroom classes. Empty if not applicable.
  List<dynamic> get homeroomClassesList;

  /// Callback when a role/class is selected.
  void Function(dynamic) get onRoleSelected;

  /// Build a single segment (teaching or homeroom) with label and icon.
  ///
  /// If [showDropdown] is true, appends a dropdown indicator icon.
  /// Handles both simple tap and picker menu scenarios.
  Widget buildSegment({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    bool showDropdown = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? primaryColor
                  : Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? primaryColor
                      : Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: primaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Show a popup menu to select from available homeroom classes.
  ///
  /// Positions the menu near the header center-right. Calls
  /// [onRoleSelected] with the selected class map.
  void showClassPicker(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(
        screenSize.width - 200,
        220, // Approx header role switcher height
        screenSize.width - 16,
        0,
      ),
      items: homeroomClassesList
          .map(
            (c) => PopupMenuItem(
              value: c,
              child: Text('Wali Kelas - ${c['name'] ?? c['nama']}'),
            ),
          )
          .toList(),
    ).then((value) {
      if (value != null) onRoleSelected(value);
    });
  }
}
