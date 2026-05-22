import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_level_settings_screen.dart';

/// Mixin for building reusable UI components.
mixin SchoolLevelUIBuildersMixin on State<SchoolLevelSettingsScreen> {
  /// Builds a styled text field for form inputs.
  Widget buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 20),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: ColorUtils.corporateBlue600,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  /// Builds an info card displaying school data.
  ///
  /// Legacy stacked-card variant. Kept for backwards-compat if any
  /// other surface still calls it. The hub now prefers
  /// [buildInfoTileGroup] which renders all rows inside a single
  /// rounded card with hairline separators — matches the mockup's
  /// `tile-card` pattern + the `DashboardListTile` spec.
  Widget buildInfoCard(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: ColorUtils.corporateBlue600, size: 22),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Single grouped tile-card holding several info rows separated by
  /// `slate-100` hairlines. Each [InfoTileRow] follows the
  /// `DashboardListTile` spec: 44×44 icon at 11dp radius with
  /// `color@10%` bg, title 14/w700 slate900, label 11/w500 slate500,
  /// chevron 20px slate400.
  Widget buildInfoTileGroup(List<InfoTileRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Column(
        children: List.generate(rows.length, (i) {
          final row = rows[i];
          final isLast = i == rows.length - 1;
          return InkWell(
            onTap: row.onTap,
            borderRadius: isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(14))
                : (i == 0
                      ? const BorderRadius.vertical(top: Radius.circular(14))
                      : BorderRadius.zero),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: ColorUtils.slate100),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: row.iconColor.withValues(alpha: 0.10),
                      borderRadius: const BorderRadius.all(Radius.circular(11)),
                    ),
                    child: Icon(row.icon, color: row.iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.value.isNotEmpty ? row.value : '-',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (row.onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: ColorUtils.slate400,
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// One row inside [buildInfoTileGroup]. [iconColor] drives both the
/// icon tint and the icon-frame's 10%-alpha background, so each row
/// can carry its own role tint (navy/violet/cobalt) without
/// re-styling the whole group.
class InfoTileRow {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const InfoTileRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });
}
