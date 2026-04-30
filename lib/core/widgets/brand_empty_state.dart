// Shared empty / filtered / error state for parent surfaces.
//
// One widget, four tones. Replaces a half-dozen ad-hoc per-feature
// empty states (`EmptyState`, `ActivityEmptyState`, `ParentGradeEmpty
// State`, etc.) with a single Phase-3 brand-aligned card, so every
// parent screen renders the same chrome when there's nothing to show.
//
// Visual contract (per Parent_Phase3_EmptyState_Mockup.svg):
//   • White card, 20px radius, slate-200 hairline border
//   • Round 88px tinted bubble icon at top
//   • Optional uppercase kicker label (tone-colored)
//   • Title — slate-900, 17px, 800
//   • Optional 2-line message — slate-600, 12px
//   • Optional primary button (azure-deep filled) + secondary
//     (white outline)
//   • Optional helper hint card below buttons
//
// Tone routes the bubble palette + kicker color only:
//   • info    → azure-50 / azure-deep
//   • warning → amber-100 / amber-700
//   • danger  → red-100 / red-700
//   • success → green-100 / green-700
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Visual tone bucket for a [BrandEmptyState]. Drives the bubble
/// palette and kicker color only — chrome stays constant.
enum BrandEmptyStateTone { info, warning, danger, success }

/// Optional action descriptor for the primary / secondary buttons.
class BrandEmptyStateAction {
  /// Button label.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Tap callback. When `null`, the button renders as a non-interactive
  /// hint (used by the secondary slot to show "Tarik untuk segarkan"
  /// without a real button gesture).
  final VoidCallback? onTap;

  const BrandEmptyStateAction({
    required this.label,
    this.icon,
    required this.onTap,
  });
}

/// Phase-3 empty / filtered / error state card.
///
/// Use this for any "we have nothing to show" surface across parent
/// screens. Pass props the same way you'd pass props to a Vue
/// component — only the ones you need are required, the rest are
/// optional and degrade gracefully.
class BrandEmptyState extends StatelessWidget {
  /// Big bubble icon (40×40 stroke inside an 88px tinted circle).
  final IconData icon;

  /// Tone bucket — info / warning / danger / success.
  final BrandEmptyStateTone tone;

  /// Optional small uppercase label above the title. Auto-uppercased,
  /// tone-colored. Pass `null` to skip the label entirely.
  final String? kicker;

  /// Big title — slate-900, 17px, weight 800.
  final String title;

  /// Optional supporting copy below the title — slate-600, 12px,
  /// multi-line. Soft-wraps on its own.
  final String? message;

  /// Optional primary action — renders a filled azure-deep button.
  final BrandEmptyStateAction? primaryAction;

  /// Optional secondary action — renders a white outline button.
  /// When `onTap` is null on the action, the button shows as a
  /// non-interactive hint (no ripple).
  final BrandEmptyStateAction? secondaryAction;

  /// Optional bottom helper card with a small info icon + 2 lines of
  /// slate copy. Used to point parents at the resolution path
  /// ("Belum diaktifkan oleh sekolah? Hubungi wali kelas.").
  final String? helperTitle;
  final String? helperMessage;

  /// Compact mode — drops the card chrome and shrinks the bubble to
  /// 56px so the widget can be embedded inside another card (used by
  /// per-section empty hints in the rapor detail screen).
  final bool compact;

  const BrandEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.tone = BrandEmptyStateTone.info,
    this.kicker,
    this.message,
    this.primaryAction,
    this.secondaryAction,
    this.helperTitle,
    this.helperMessage,
    this.compact = false,
  });

  ({Color bg, Color fg, Color border}) get _palette {
    switch (tone) {
      case BrandEmptyStateTone.info:
        return (
          bg: const Color(0xFFF0F9FF),
          fg: ColorUtils.brandAzureDeep,
          border: const Color(0xFFBAE6FD),
        );
      case BrandEmptyStateTone.warning:
        return (
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFB45309),
          border: const Color(0xFFFCD34D),
        );
      case BrandEmptyStateTone.danger:
        return (
          bg: const Color(0xFFFEE2E2),
          fg: const Color(0xFFB91C1C),
          border: const Color(0xFFFCA5A5),
        );
      case BrandEmptyStateTone.success:
        return (
          bg: const Color(0xFFDCFCE7),
          fg: const Color(0xFF15803D),
          border: const Color(0xFF86EFAC),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    final bubbleSize = compact ? 56.0 : 88.0;
    final iconSize = compact ? 24.0 : 36.0;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Bubble icon
        Container(
          width: bubbleSize,
          height: bubbleSize,
          decoration: BoxDecoration(
            color: palette.bg,
            shape: BoxShape.circle,
            border: Border.all(color: palette.border, width: 1),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: iconSize, color: palette.fg),
        ),
        if (kicker != null) ...[
          SizedBox(height: compact ? 12 : 18),
          Text(
            kicker!.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
        SizedBox(height: kicker != null ? 8 : (compact ? 12 : 18)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 14 : 17,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            height: 1.3,
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate600,
              height: 1.5,
            ),
          ),
        ],
        if (primaryAction != null) ...[
          const SizedBox(height: 20),
          _ActionButton(action: primaryAction!, primary: true),
        ],
        if (secondaryAction != null) ...[
          SizedBox(height: primaryAction != null ? 8 : 20),
          _ActionButton(action: secondaryAction!, primary: false),
        ],
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: body,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(color: ColorUtils.slate200, width: 0.75),
            ),
            child: body,
          ),
          if (helperTitle != null || helperMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                border: Border.all(color: ColorUtils.slate200, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: ColorUtils.slate400,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (helperTitle != null)
                          Text(
                            helperTitle!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        if (helperMessage != null) ...[
                          if (helperTitle != null) const SizedBox(height: 2),
                          Text(
                            helperMessage!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: ColorUtils.slate500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Internal button widget for the primary / secondary action slots.
class _ActionButton extends StatelessWidget {
  final BrandEmptyStateAction action;
  final bool primary;

  const _ActionButton({required this.action, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isDisabled = action.onTap == null;
    final fg = primary
        ? Colors.white
        : (isDisabled ? ColorUtils.slate500 : ColorUtils.slate900);
    final bg = primary ? ColorUtils.brandAzureDeep : Colors.white;
    final border = primary
        ? null
        : Border.all(color: ColorUtils.slate200, width: 1);

    final inner = Container(
      width: double.infinity,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: border,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, size: 16, color: fg),
            const SizedBox(width: 8),
          ],
          Text(
            action.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );

    if (isDisabled) return inner;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: inner,
      ),
    );
  }
}
