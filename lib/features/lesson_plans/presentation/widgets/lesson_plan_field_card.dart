// Single RPP field card with AI regen button. Extracted from lesson_plan_detail_screen.dart.
// Shows a labelled section (e.g. "Kompetensi Inti") with a regen count badge and trigger button.
// Like a `<FieldCard>` Vue component — display + one interaction delegated via callback.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Card for one RPP content field with optional AI regeneration controls.
///
/// Constructor params:
/// - [fieldKey]         — API key (e.g. 'core_competence'), used to match regen info
/// - [fieldLabel]       — human-readable label shown in the card header
/// - [value]            — the field's current HTML-stripped text content
/// - [regenInfo]        — regen quota map from the API: {remaining, max, used} (nullable)
/// - [isLoadingLimits]  — true while regen limits are being fetched from the API
/// - [isRegeneratingThis] — true when this field (or all fields) is being regenerated
/// - [primaryColor]     — brand colour for header, icons, and borders
/// - [onRegenTap]       — callback fired when the regen icon is tapped
/// - [stripHtml]        — function that strips HTML from the value string (from parent)
class LessonPlanFieldCard extends StatelessWidget {
  final String fieldKey;
  final String fieldLabel;
  final String value;
  final Map<String, dynamic>? regenInfo;
  final bool isLoadingLimits;
  final bool isRegeneratingThis;
  final Color primaryColor;
  final VoidCallback onRegenTap;
  final String Function(String) stripHtml;

  const LessonPlanFieldCard({
    super.key,
    required this.fieldKey,
    required this.fieldLabel,
    required this.value,
    required this.regenInfo,
    required this.isLoadingLimits,
    required this.isRegeneratingThis,
    required this.primaryColor,
    required this.onRegenTap,
    required this.stripHtml,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = regenInfo?['remaining'] ?? 2;
    final max = regenInfo?['max'] ?? 2;
    final used = regenInfo?['used'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field header row: label, regen count badge, regen icon button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fieldLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
                // Regen quota badge: "used/max" — hidden while limits are loading
                if (regenInfo != null && !isLoadingLimits) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: remaining > 0
                          ? primaryColor.withValues(alpha: 0.1)
                          : ColorUtils.slate200,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      '$used/$max',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: remaining > 0
                            ? primaryColor
                            : ColorUtils.slate400,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                // Regen trigger button (star icon)
                Material(
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: InkWell(
                    onTap: isRegeneratingThis ? null : onRegenTap,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: remaining > 0
                            ? primaryColor.withValues(alpha: 0.1)
                            : ColorUtils.slate100,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        border: Border.all(
                          color: remaining > 0
                              ? primaryColor.withValues(alpha: 0.2)
                              : ColorUtils.slate200,
                        ),
                      ),
                      child: isRegeneratingThis
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryColor,
                              ),
                            )
                          : Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: remaining > 0
                                  ? primaryColor
                                  : ColorUtils.slate400,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Field content (HTML stripped by caller-provided function)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(
              stripHtml(value),
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: ColorUtils.slate700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
