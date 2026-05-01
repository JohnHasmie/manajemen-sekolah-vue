// Dashboard shortcut grid — the 4-up (or 3-up) tile grid under the hero row.
//
// Why this exists
// ---------------
// Every role's dashboard has a "what do I want to do right now" grid:
// admin → Tambah siswa / Rekap keuangan / Buat pengumuman / Pengaturan;
// teacher → Input nilai / Presensi / Materi / Jadwal;
// orangtua → Lihat nilai / Presensi anak / Jadwal / Pengumuman.
//
// Three roles, same idea, three slightly different card implementations.
// This widget collapses them to one: a responsive grid of tappable tiles
// with icon, label, optional 1-line caption, and an accent color. Pass an
// arbitrary list of [QuickAction]s; the grid handles layout (3 or 4 per row)
// and spacing itself.
//
// Not to be confused with the bottom-sheet `QuickActionGrid`-lookalikes in
// feature screens — those are local; this one is the dashboard composition.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A single cell in [QuickActionGrid].
class QuickAction {
  /// Leading icon rendered inside an accent-tinted square.
  final IconData icon;

  /// Short label (max ~14 chars) under the icon.
  final String label;

  /// Accent color for the icon background and a thin left-edge cue.
  final Color color;

  /// Optional single-line caption below the label ("3 draft", "Belum ada").
  final String? caption;

  /// Tap handler.
  final VoidCallback onTap;

  /// When true, a small dot badge is drawn on the icon corner.
  /// Use to surface "new" / "needs attention" cues.
  final bool showBadge;

  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.caption,
    this.showBadge = false,
  });
}

/// Responsive grid of [QuickAction] tiles.
///
/// Lays out [actions] in rows of [columnsPerRow] tiles each, with equal
/// horizontal spacing. All tiles share the same height for a clean baseline.
///
/// Example:
/// ```dart
/// QuickActionGrid(
///   columnsPerRow: 4,
///   actions: [
///     QuickAction(
///       icon: Icons.person_add_alt_1_rounded,
///       label: 'Tambah siswa',
///       color: Colors.indigo,
///       onTap: _openAddStudentSheet,
///     ),
///     QuickAction(
///       icon: Icons.payments_rounded,
///       label: 'Rekap keuangan',
///       color: Colors.teal,
///       onTap: _openFinance,
///     ),
///     ...
///   ],
/// )
/// ```
class QuickActionGrid extends StatelessWidget {
  /// Actions to render. Order is respected.
  final List<QuickAction> actions;

  /// Number of tiles per row. Common values: 3 (roomy), 4 (compact admin).
  final int columnsPerRow;

  /// Gap between tiles.
  final double spacing;

  /// Padding around the whole grid.
  final EdgeInsets padding;

  const QuickActionGrid({
    super.key,
    required this.actions,
    this.columnsPerRow = 4,
    this.spacing = AppSpacing.sm,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    // Chunk into rows of columnsPerRow. Any tail row with fewer items gets
    // spacer cells so the last-row tiles don't stretch to full width.
    final rows = <List<QuickAction?>>[];
    for (var i = 0; i < actions.length; i += columnsPerRow) {
      final slice = actions.sublist(
        i,
        (i + columnsPerRow).clamp(0, actions.length),
      );
      final row = <QuickAction?>[...slice];
      while (row.length < columnsPerRow) {
        row.add(null);
      }
      rows.add(row);
    }

    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < rows[r].length; c++) ...[
                    Expanded(
                      child: rows[r][c] == null
                          ? const SizedBox.shrink()
                          : _QuickActionTile(action: rows[r][c]!),
                    ),
                    if (c < rows[r].length - 1) SizedBox(width: spacing),
                  ],
                ],
              ),
            ),
            if (r < rows.length - 1) SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: action.color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(action.icon, color: action.color, size: 20),
                  ),
                  if (action.showBadge)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              AppSpacing.v8,
              // FittedBox+scaleDown so single-word labels longer than
              // the column (e.g. "Pengumuman" at columnsPerRow:4 on
              // narrow viewports) shrink to fit on ONE line instead of
              // breaking mid-word into "Pengumum / an". Short labels
              // render at full size — scaleDown only kicks in when
              // overflow would occur.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  action.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              if (action.caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  action.caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
