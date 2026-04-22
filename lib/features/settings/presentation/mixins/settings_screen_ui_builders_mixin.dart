import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin for UI builder methods in SettingsScreen.
mixin SettingsScreenUIBuildersMixin {
  // Abstract property needed by builders
  Color get primaryColor;

  /// Builds an info row with icon and label-value.
  Widget buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoIcon(icon),
        const SizedBox(width: 14),
        Expanded(child: _buildInfoText(label, value)),
      ],
    );
  }

  /// Builds info icon container.
  Widget _buildInfoIcon(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Icon(icon, color: primaryColor, size: 18),
    );
  }

  /// Builds info text (label and value).
  Widget _buildInfoText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: ColorUtils.slate500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '-',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }

  /// Builds a section card with children.
  Widget buildSectionCard({
    required IconData sectionIcon,
    required String sectionTitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(sectionIcon, sectionTitle),
            const SizedBox(height: 14),
            Divider(color: ColorUtils.slate100, height: 1),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Builds section header with icon and title.
  Widget _buildSectionHeader(IconData sectionIcon, String sectionTitle) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Icon(sectionIcon, color: primaryColor, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          sectionTitle,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }
}
