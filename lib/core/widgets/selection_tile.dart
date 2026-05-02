// Reusable compact tile for selection bottom sheets.
//
// Pairs with [SelectionHeroCard] under a "GANTI KE" section header
// to render the alternatives the user can switch to. Used by the
// school + role switchers today; future tahun-ajaran or class
// switchers will reuse it.
//
// Layout
// ------
//   ┌────────────────────────────────────┐
//   │ [avatar] Title                     │
//   │          Subtitle                  │
//   └────────────────────────────────────┘
//
// No trailing chevron — the tile itself is the affordance, since
// tapping always dismisses the sheet and switches selection. White
// background with a slate200 border keeps it visually distinct
// from the gradient hero.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class SelectionTile extends StatelessWidget {
  /// Avatar widget on the left. Typically an [InitialsAvatar] or a
  /// gradient-filled disc with an icon.
  final Widget avatar;

  /// Headline.
  final String title;

  /// Optional one-line secondary text below the title.
  final String? subtitle;

  /// Tap handler — invoked when the user picks this option. The
  /// caller is responsible for dismissing the host sheet.
  final VoidCallback onTap;

  const SelectionTile({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
