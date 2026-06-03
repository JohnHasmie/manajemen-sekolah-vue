import 'package:flutter/material.dart';

// =====================================================================
// Hero chip — used in the BrandPageHeader bottomSlot
// =====================================================================

/// Translucent white chip rendered on the brand gradient. The
/// "filled" variant sits at 18% alpha (used for the semester chip);
/// the unfilled variant uses 14% bg + dashed white border (used for
/// UTS / UAS toggle chips). The active state flips the fill so the
/// chip reads as selected without going opaque.
class ParentRaporHeroChip extends StatelessWidget {
  const ParentRaporHeroChip({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.active = false,
    this.width,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool active;
  final double? width;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final fillAlpha = filled ? 0.22 : (active ? 0.32 : 0.14);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          height: 36,
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: fillAlpha),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: filled
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: active ? 0.6 : 0.32),
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
