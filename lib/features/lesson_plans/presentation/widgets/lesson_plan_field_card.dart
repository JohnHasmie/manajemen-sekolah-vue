// Single RPP field card with AI regen button. Extracted from
// lesson_plan_detail_screen.dart.
// Shows a labelled section (e.g. "Kompetensi Inti") with a regen count badge
// and trigger button.
// Like a `<FieldCard>` Vue component — display + one interaction delegated via
// callback.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Card for one RPP content field with optional AI regeneration controls.
///
/// Constructor params:
/// - [fieldKey]         — API key (e.g. 'core_competence'), used to match
///                        regen info
/// - [fieldLabel]       — human-readable label shown in the card header
/// - [value]            — the field's current HTML-stripped text content
/// - [regenInfo] — regen quota map from the API: {remaining, max, used}
/// (nullable)
/// - [isLoadingLimits]  — true while regen limits are being fetched from the
///                        API
/// - [isRegeneratingThis] — true when this field (or all fields) is being
/// regenerated
/// - [primaryColor]     — brand colour for header, icons, and borders
/// - [onRegenTap]       — callback fired when the regen icon is tapped
/// - [stripHtml] — function that strips HTML from the value string (from
/// parent)
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

  /// Optional pencil button next to the regen icon. When non-null,
  /// renders a small edit pill that opens the per-section editor
  /// sheet — the new edit affordance from `_design/teacher_rpp_edit_redesign.html`
  /// (Frame A → B). Pre-existing call sites that don't pass this
  /// stay unchanged (admin web app etc.).
  final VoidCallback? onEditTap;

  /// Optional format-specific body widget. When non-null, replaces the
  /// generic `HtmlWidget(value)` body — used by AI RPP preview to
  /// render K13 identitas as a 2×2 grid, langkah_kegiatan as numbered
  /// step rows, Modul Ajar tujuan as TP cards, etc. See
  /// `lesson_plan_section_renderers.dart`.
  final Widget? customBody;

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
    this.onEditTap,
    this.customBody,
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
                // Edit pencil — opens per-section editor sheet.
                // Renders only when a callback is supplied, so the
                // admin web app's read-only field card is unaffected.
                if (onEditTap != null) ...[
                  Material(
                    color: Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: InkWell(
                      onTap: isRegeneratingThis ? null : onEditTap,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ColorUtils.slate100,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                          border: Border.all(color: ColorUtils.slate200),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 14,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
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
          // Field content. Priority chain:
          //   1) customBody (format-specific renderer like K13 identitas
          //      grid, Pendahuluan/Inti/Penutup step rows, TP cards)
          //   2) HtmlWidget rendering of `value` so headings/lists/tables/
          //      bold-italic survive
          //   3) "—" placeholder when value is empty
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: customBody != null
                ? customBody!
                : value.trim().isEmpty
                ? Text(
                    '—',
                    style: TextStyle(fontSize: 14, color: ColorUtils.slate400),
                  )
                : HtmlWidget(
                    value,
                    textStyle: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: ColorUtils.slate700,
                    ),
                    customStylesBuilder: (e) {
                      switch (e.localName) {
                        case 'h1':
                        case 'h2':
                        case 'h3':
                          return {
                            'font-size': '14px',
                            'font-weight': '800',
                            'color': '#0f172a',
                            'margin': '8px 0 4px',
                          };
                        case 'strong':
                        case 'b':
                          return {'font-weight': '800', 'color': '#0f172a'};
                        case 'p':
                          return {'margin': '0 0 6px'};
                        case 'ol':
                        case 'ul':
                          return {
                            'margin': '4px 0 6px',
                            'padding-left': '18px',
                          };
                        case 'li':
                          return {'margin-bottom': '3px'};
                        case 'td':
                          return {
                            'padding': '4px 8px',
                            'vertical-align': 'top',
                          };
                      }
                      return null;
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
