// Reusable bottom-sheet scaffold for "pick one of many" pickers.
//
// Composes the standard chrome — drag handle, brand-azure tinted
// icon header with title + subtitle, hero "Saat ini" card, "GANTI KE"
// section, scrollable tile list, optional empty message — into one
// widget so each role's picker is just data:
//
//   showModalBottomSheet(
//     context: ctx,
//     backgroundColor: Colors.transparent,
//     isScrollControlled: true,
//     useSafeArea: true,
//     builder: (_) => BrandHeroSheet(
//       icon: Icons.school_rounded,
//       title: 'Pilih Sekolah',
//       subtitle: 'Akun terhubung ke 2 sekolah',
//       hero: SelectionHeroCard(...),
//       tiles: [SelectionTile(...), ...],
//     ),
//   );
//
// Replaces the per-feature sheet body that was duplicated by the
// language picker, school switcher, role switcher, and tahun-ajaran
// switcher.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class BrandHeroSheet extends StatelessWidget {
  /// Header icon — rendered in a 40×40 brand-azure-tinted disc.
  final IconData icon;

  /// Sheet title. Keep it Bahasa.
  final String title;

  /// Sheet subtitle, typically the count of items ("Akun terhubung
  /// ke 3 sekolah", "Akun terdaftar di 2 peran").
  final String subtitle;

  /// "Saat ini" hero card. Pass null when there's no active selection
  /// (e.g., when the user has no school active yet).
  final Widget? hero;

  /// Section label above the alternatives list. Defaults to 'GANTI KE'
  /// when [hero] is non-null and 'PILIH' when [hero] is null. Pass
  /// an explicit value to override; pass an empty string to hide.
  final String? sectionLabel;

  /// Alternatives — typically [SelectionTile]s. Rendered in a
  /// vertically-scrollable column with 8px gaps.
  final List<Widget> tiles;

  /// Optional message shown when [tiles] is empty (e.g., "no other
  /// schools available"). Rendered in slate-500.
  final String? emptyMessage;

  /// Maximum height of the scrollable tiles area as a fraction of
  /// screen height. Defaults to 0.45 — large enough for ~5 tiles
  /// before scrolling.
  final double tilesMaxHeightFactor;

  const BrandHeroSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.hero,
    this.sectionLabel,
    required this.tiles,
    this.emptyMessage,
    this.tilesMaxHeightFactor = 0.45,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSectionLabel =
        sectionLabel ?? (hero == null ? 'PILIH' : 'GANTI KE');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header row: tinted icon disc + title + subtitle
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorUtils.brandAzure.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: ColorUtils.brandAzureDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Hero "Saat ini" card
          if (hero != null) hero!,
          if (hero != null) const SizedBox(height: AppSpacing.md),

          // Alternatives section
          if (tiles.isNotEmpty) ...[
            if (effectiveSectionLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                child: Text(
                  effectiveSectionLabel,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate400,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * tilesMaxHeightFactor,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      tiles[i],
                      if (i != tiles.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Empty state when nothing to switch to
          if (tiles.isEmpty && emptyMessage != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: AppSpacing.md,
              ),
              child: Text(
                emptyMessage!,
                style: TextStyle(fontSize: 11.5, color: ColorUtils.slate500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
