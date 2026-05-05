// Admin Sistem hub shared components — Mockup #14.
//
// Two new widgets:
//   • CategoryGridHero — 2-column tile grid of admin settings
//                        categories. Each tile has a pastel-tinted
//                        icon square + title + subline + meta line.
//   • AuditLogPin       — sticky bottom card showing the latest audit
//                        log entry preview. Tap → navigates to a full
//                        audit log screen (caller's responsibility).
//
// Both consume only existing tokens (`ColorUtils.*`, `AppSpacing.*`)
// so they plug into the v3 admin language without further wiring.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// CategoryTile + CategoryGridHero
// =====================================================================

/// One settings category — drives a single tile in [CategoryGridHero].
///
/// `iconBg` is the pastel tint behind the icon (e.g. `#EEF2FF`),
/// `iconFg` is the icon's stroke color (e.g. admin navy). The grid
/// renders these so each tile reads as its own affordance without the
/// page going noisy.
class CategoryTile {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subline;
  final String? meta;
  final VoidCallback onTap;
  final String? trailingBadge;

  const CategoryTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subline,
    this.meta,
    required this.onTap,
    this.trailingBadge,
  });
}

/// 2-column grid of [CategoryTile]s sized to match the Sistem hub
/// mockup (170×120 tiles with 8px gap). Wraps into rows automatically
/// — pass any number of tiles.
class CategoryGridHero extends StatelessWidget {
  final List<CategoryTile> tiles;
  final int columns;
  final EdgeInsetsGeometry padding;

  const CategoryGridHero({
    super.key,
    required this.tiles,
    this.columns = 2,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // 170 × 120 from the mockup spec.
          childAspectRatio: 170 / 120,
        ),
        itemCount: tiles.length,
        itemBuilder: (context, i) => _CategoryTileView(tile: tiles[i]),
      ),
    );
  }
}

class _CategoryTileView extends StatelessWidget {
  final CategoryTile tile;
  const _CategoryTileView({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: tile.onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                offset: const Offset(0, 6),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon square
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tile.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(tile.icon, size: 20, color: tile.iconFg),
                  ),
                  const Spacer(),
                  if (tile.trailingBadge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tile.trailingBadge!,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                tile.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                tile.subline,
                style: TextStyle(
                  fontSize: 10.5,
                  color: ColorUtils.slate500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (tile.meta != null) ...[
                const SizedBox(height: 2),
                Text(
                  tile.meta!,
                  style: TextStyle(
                    fontSize: 10,
                    color: ColorUtils.slate300,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// AuditLogPin
// =====================================================================

/// Single audit log preview shown at the bottom of the Sistem hub.
class AuditLogEntry {
  final String actor;
  final String action;
  final String? timestamp;
  final String? ipAddress;

  const AuditLogEntry({
    required this.actor,
    required this.action,
    this.timestamp,
    this.ipAddress,
  });

  String get fullLine => '$actor · $action';
}

/// Sticky preview card showing the latest audit log entry, with a
/// chevron that drills into the full audit log screen. Renders a
/// muted "Belum ada aktivitas hari ini" placeholder when [latest] is
/// null so the slot still occupies space (avoids layout shift).
class AuditLogPin extends StatelessWidget {
  final AuditLogEntry? latest;
  final VoidCallback onSeeAll;
  final EdgeInsetsGeometry margin;

  const AuditLogPin({
    super.key,
    required this.latest,
    required this.onSeeAll,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onSeeAll,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              children: [
                const _DotMarker(),
                const SizedBox(width: 12),
                Expanded(child: _buildBody(context)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ColorUtils.slate500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (latest == null) {
      return Text(
        'Belum ada aktivitas hari ini',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: ColorUtils.slate500,
        ),
      );
    }
    final entry = latest!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AUDIT LOG · TERAKHIR',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          entry.fullLine,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (entry.timestamp != null || entry.ipAddress != null) ...[
          const SizedBox(height: 2),
          Text(
            [
              if (entry.timestamp != null) entry.timestamp!,
              if (entry.ipAddress != null) 'IP ${entry.ipAddress}',
            ].join(' · '),
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate300,
            ),
          ),
        ],
      ],
    );
  }
}

class _DotMarker extends StatelessWidget {
  const _DotMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF10B981),
        shape: BoxShape.circle,
      ),
    );
  }
}

// =====================================================================
// HealthPill
// =====================================================================

enum HealthState { ok, warn, error }

/// Realtime-style indicator pill rendered inside the admin Sistem
/// hero. Mirrors the dashboard "Sinkron · 1m lalu" pattern but binds
/// its color to a 3-state health enum so it works for any settings
/// posture (sehat / butuh perhatian / bermasalah).
class HealthPill extends StatelessWidget {
  final HealthState state;
  final String label;

  const HealthPill({
    super.key,
    required this.state,
    required this.label,
  });

  Color get _dotColor {
    switch (state) {
      case HealthState.ok:
        return const Color(0xFF22C55E);
      case HealthState.warn:
        return const Color(0xFFF59E0B);
      case HealthState.error:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
