// Reusable option tile for the "Pilih Cakupan Siswa" bottom sheet.
// Like a Vue component for a single selectable row with an icon, title, and subtitle.
// Tapping the tile pops the sheet and returns the [value] (bool) to the caller.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// A single tappable row used inside the scope-picker bottom sheet.
///
/// Constructor params replace all references to parent state:
/// - [ctx] -- the BuildContext of the bottom sheet (used to pop with a value)
/// - [value] -- the bool value to return when this tile is tapped
/// - [icon] -- leading icon
/// - [title] -- main label
/// - [subtitle] -- description text
/// - [color] -- accent color for icon background and border
class ScopeOptionTile extends StatelessWidget {
  final BuildContext ctx;
  final bool value;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const ScopeOptionTile({
    super.key,
    required this.ctx,
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AppNavigator.pop(ctx, value),
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ColorUtils.slate400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
