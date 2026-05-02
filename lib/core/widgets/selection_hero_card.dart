// Reusable "Saat ini" hero card for selection bottom sheets.
//
// One widget, every role:
//   • School switcher — brand-azure gradient, KA initials, school name
//   • Role switcher    — role gradient (admin navy / guru cobalt /
//                        wali azure), role icon, role name
//   • Future tahun ajaran switcher — same shape, different gradient
//
// Layout
// ------
//   ┌────────────────────────────────────┐
//   │ SAAT INI               [AKTIF]     │
//   │                                    │
//   │ [avatar] Title                     │
//   │          Subtitle                  │
//   └────────────────────────────────────┘
//
// The avatar is a generic [Widget] so the caller picks an
// `InitialsAvatar.onDark`, an `Icon`, or a custom mark depending
// on the surface. The gradient + AKTIF chip + SAAT INI kicker are
// inherent to the variant — change them and you've made a different
// widget.
import 'package:flutter/material.dart';

class SelectionHeroCard extends StatelessWidget {
  /// Gradient fill for the card. Use `ColorUtils.brandGradient(role)`
  /// for role surfaces, or a hand-picked LinearGradient for non-role
  /// pickers (e.g., the brand-azure gradient for schools).
  final Gradient gradient;

  /// Avatar displayed to the left of the title block. Typically an
  /// [InitialsAvatar.onDark] or an [Icon] in white.
  final Widget avatar;

  /// Headline — usually the active selection's display name.
  final String title;

  /// Optional one-line secondary text below the title.
  final String? subtitle;

  /// Kicker label above the title row. Defaults to 'SAAT INI'.
  /// Override when the surface uses different copy ('AKUN AKTIF',
  /// 'TAHUN AKTIF', etc.).
  final String kicker;

  /// Status chip on the right side of the kicker row. Defaults to
  /// 'AKTIF'. Set to null to hide.
  final String? statusChip;

  /// Optional tap handler. When non-null the card becomes an
  /// `InkWell`; the typical use is to dismiss the host sheet on tap
  /// (since you're already on the active selection).
  final VoidCallback? onTap;

  const SelectionHeroCard({
    super.key,
    required this.gradient,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.kicker = 'SAAT INI',
    this.statusChip = 'AKTIF',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                kicker,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              if (statusChip != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    statusChip!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              avatar,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}
