import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A single item in the "Modul lain" horizontal strip.
///
/// Displays an icon + label, with optional badge count. Tap fires the
/// [onTap] callback.
class ModulLainStripItem {
  /// Display label for the tile, e.g. "Jadwal", "Nilai"
  final String label;

  /// Outlined Material icon to display
  final IconData icon;

  /// Callback fired on tile tap
  final VoidCallback onTap;

  /// Optional red badge count shown in top-right. If null or 0, no badge.
  final int? badgeCount;

  const ModulLainStripItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });
}

/// Horizontal strip of 4 module tiles + optional "+N Lainnya" overflow tile.
///
/// Used on all three role dashboards (admin, guru, wali) to surface
/// additional modules not in the quick action grid. Displays 4 visible items
/// with icon + label. If [overflowItems] is non-empty, shows a 5th dark tile
/// labeled "+N Lainnya" (navy fill, white text). Tap opens a bottom sheet
/// listing all overflow items.
///
/// Visual treatment matches the Phase 3 SVG mockup:
/// - Row of 4 tiles (88×96 each with rounded corners, light bg, outlined icon)
/// - Label centered below icon in slate text
/// - 5th "+N" tile with navy fill if overflow exists
/// - Bottom sheet shows full list on overlay
class ModulLainStrip extends StatelessWidget {
  /// Section header text, always "Modul lain"
  final String title;

  /// Right-side header text, e.g. "10 modul"
  final String? totalLabel;

  /// 4 tiles to display horizontally (max 4)
  final List<ModulLainStripItem> visibleItems;

  /// Additional items shown in bottom sheet when "+N Lainnya" is tapped
  final List<ModulLainStripItem> overflowItems;

  /// Primary color for accent. Used for the "+N" tile fill and header.
  /// Typically navy (#0F172A) for admin, teal for guru, violet for wali.
  final Color accentColor;

  const ModulLainStrip({
    super.key,
    this.title = 'Modul lain',
    this.totalLabel,
    required this.visibleItems,
    this.overflowItems = const [],
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverflow = overflowItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: "Modul lain" + "10 modul"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0,
                ),
              ),
              if (totalLabel != null)
                Text(
                  totalLabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Horizontal scrollable or wrapped row of tiles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ...visibleItems.map((item) => _buildTile(context, item)),
              if (hasOverflow)
                _buildOverflowTile(context)
              else
                // Placeholder spacer if no overflow to keep alignment
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a single module tile: icon on top, label on bottom.
  ///
  /// Size: ~88×96 with rounded corners, light slate background.
  /// Icon is 40×40 inside a 40×40 circle background.
  /// Label is centered below, single-line, slate color.
  /// Badge count (if non-zero) shown as red dot in top-right.
  Widget _buildTile(BuildContext context, ModulLainStripItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  size: 28,
                  color: const Color(0xFF334155),
                ),
              ),
              // Badge count (red dot in top-right)
              if (item.badgeCount != null && item.badgeCount! > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 64,
            height: 26, // fixed height for 2-line labels
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "+N Lainnya" overflow tile (navy fill, white text).
  ///
  /// Tap opens bottom sheet with full list of overflow items.
  Widget _buildOverflowTile(BuildContext context) {
    return GestureDetector(
      onTap: () => _showOverflowSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '+${overflowItems.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 64,
            height: 26, // match _buildTile label height
            child: Text(
              'Lainnya',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows bottom sheet listing all overflow items in a vertical grid.
  void _showOverflowSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // isScrollControlled lets the sheet size to its content rather
      // than being clamped to 50% of screen height — important when
      // the overflow list has only 2-3 short rows. Without it the
      // sheet looked half-empty (large gap between the rows and the
      // sheet bottom edge).
      isScrollControlled: true,
      builder: (context) => _OverflowSheet(
        items: overflowItems,
        title: title,
        accentColor: accentColor,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      useSafeArea: true,
    );
  }
}

/// Bottom sheet showing the full list of overflow items.
///
/// Displayed as a vertical list with icon + label per row. Each item
/// is tappable and calls its onTap callback (which closes the sheet).
class _OverflowSheet extends StatelessWidget {
  final List<ModulLainStripItem> items;
  final String title;
  final Color accentColor;

  const _OverflowSheet({
    required this.items,
    required this.title,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Content-sized layout. Capped at 70% of screen height so a long
    // overflow list still scrolls instead of pushing the sheet off
    // the top — but with 2-7 short rows the sheet is just tall
    // enough for the rows + header + 24dp footer breathing room.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with drag handle
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          // List of overflow items — Flexible so it shrinks when the
          // list is short (3 rows) but still scrolls when it would
          // exceed the 70% cap.
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildOverflowItem(context, item);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Single item in overflow sheet: icon + label, full width, tappable.
  Widget _buildOverflowItem(BuildContext context, ModulLainStripItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        item.onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 24, color: const Color(0xFF334155)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            if (item.badgeCount != null && item.badgeCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.badgeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}
