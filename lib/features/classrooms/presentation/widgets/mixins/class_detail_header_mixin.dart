import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building the gradient header section of
/// [ClassDetailDialog].
///
/// Provides [buildHeaderSection] to render avatar, name,
/// grade badge, and close button.
mixin ClassDetailHeaderMixin {
  /// Provides access to BuildContext for navigation.
  BuildContext get context;

  /// Provides access to class data Map.
  Map<String, dynamic> get classData;

  /// Provides access to pre-formatted grade string.
  String get gradeText;

  /// Builds the gradient header widget with avatar,
  /// name, grade badge, and close button.
  ///
  /// Returns a Container with LinearGradient background
  /// and a Stack containing the main column and positioned
  /// close button.
  Widget buildHeaderSection() {
    final name = classData['name'] ?? 'C';
    final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
    final avatarColor = ColorUtils.getColorForIndex(nameHash);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Stack(
        children: [_buildHeaderColumn(name, avatarColor), _buildCloseButton()],
      ),
    );
  }

  /// Builds the main column with avatar, name, and
  /// grade badge.
  Widget _buildHeaderColumn(String name, Color avatarColor) {
    return Column(
      children: [
        _buildAvatar(name, avatarColor),
        const SizedBox(height: AppSpacing.md),
        _buildNameText(name),
        const SizedBox(height: 6),
        _buildGradgeBadge(),
      ],
    );
  }

  /// Builds the circular avatar container with initials.
  Widget _buildAvatar(String name, Color avatarColor) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColor,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Builds the classroom name text.
  Widget _buildNameText(String name) {
    return Text(
      name,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the grade badge with icon.
  Widget _buildGradgeBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers_outlined, size: 12, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Text(
                gradeText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the close button positioned in top-right
  /// corner.
  Widget _buildCloseButton() {
    return Positioned(
      top: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => AppNavigator.pop(context),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
