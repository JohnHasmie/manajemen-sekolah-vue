// "Regenerasi Semua Field" button card. Extracted from lesson_plan_detail_screen.dart.
// Displays a gradient banner that triggers bulk AI re-generation of all RPP fields.
// Like a `<RegenAllBanner>` Vue component — shows loading state, fires callback on tap.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tappable card that initiates "regenerate all fields" via AI.
///
/// Constructor params:
/// - [isRegenerating]  — when true, swaps the icon for a spinner and disables tap
/// - [primaryColor]    — brand colour used for gradients and the icon
/// - [onTap]           — callback fired when the user taps (should open a confirm dialog)
class LessonPlanRegenAllButton extends StatelessWidget {
  final bool isRegenerating;
  final Color primaryColor;
  final VoidCallback onTap;

  const LessonPlanRegenAllButton({
    super.key,
    required this.isRegenerating,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withValues(alpha: 0.08),
            primaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          onTap: isRegenerating ? null : onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: isRegenerating
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.auto_awesome,
                          color: primaryColor,
                          size: 20,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRegenerating
                            ? 'Sedang memproses...'
                            : 'Regenerasi Semua Field',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Generate ulang seluruh konten RPP dengan AI',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: ColorUtils.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
