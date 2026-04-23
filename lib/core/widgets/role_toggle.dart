// Animated toggle switch for Teaching ↔ Homeroom (Wali Kelas) view.
//
// Replaces 5+ identical `_buildRoleToggle()` implementations across
// teacher screens (attendance, schedule, grades, class activity, materials).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// An animated two-tab toggle for switching between Teaching and Homeroom views.
///
/// Designed for use inside gradient headers with semi-transparent styling.
/// The active tab slides with a white pill indicator behind it.
///
/// Example:
/// ```dart
/// RoleToggle(
///   isHomeroomView: _isHomeroomView,
///   onChanged: (isHomeroom) {
///     setState(() => _isHomeroomView = isHomeroom);
///     _forceRefresh();
///   },
///   primaryColor: ColorUtils.getRoleColor('guru'),
///   homeroomClassName: _selectedHomeroomClass?['name'],
/// )
/// ```
class RoleToggle extends StatelessWidget {
  /// Whether the homeroom tab is currently active.
  final bool isHomeroomView;

  /// Called when the user taps either tab.
  final ValueChanged<bool> onChanged;

  /// The primary accent color used for text/icon when a tab is active.
  final Color primaryColor;

  /// Optional homeroom class name shown in the homeroom tab
  /// (e.g., "Kelas 10A" instead of generic "Wali Kelas").
  final String? homeroomClassName;

  /// Label for the teaching tab. Defaults to 'Mengajar'.
  final String teachingLabel;

  /// Label for the homeroom tab. Defaults to 'Wali Kelas'.
  final String homeroomLabel;

  /// Icon for the teaching tab. Defaults to [Icons.person_outline_rounded].
  final IconData teachingIcon;

  /// Icon for the homeroom tab. Defaults to [Icons.class_outlined].
  final IconData homeroomIcon;

  const RoleToggle({
    super.key,
    required this.isHomeroomView,
    required this.onChanged,
    required this.primaryColor,
    this.homeroomClassName,
    this.teachingLabel = 'Mengajar',
    this.homeroomLabel = 'Wali Kelas',
    this.teachingIcon = Icons.person_outline_rounded,
    this.homeroomIcon = Icons.class_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sliding white pill indicator
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: isHomeroomView
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Teaching tab
              Expanded(
                child: _RoleTab(
                  icon: teachingIcon,
                  label: teachingLabel,
                  isActive: !isHomeroomView,
                  primaryColor: primaryColor,
                  onTap: () {
                    if (isHomeroomView) onChanged(false);
                  },
                ),
              ),

              // Homeroom tab
              Expanded(
                child: _RoleTab(
                  icon: homeroomIcon,
                  label: homeroomClassName != null && isHomeroomView
                      ? 'Kelas $homeroomClassName'
                      : homeroomLabel,
                  isActive: isHomeroomView,
                  primaryColor: primaryColor,
                  onTap: () {
                    if (!isHomeroomView) onChanged(true);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single tab within the [RoleToggle].
class _RoleTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color primaryColor;
  final VoidCallback onTap;

  const _RoleTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? primaryColor : Colors.white.withValues(alpha: 0.9);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
