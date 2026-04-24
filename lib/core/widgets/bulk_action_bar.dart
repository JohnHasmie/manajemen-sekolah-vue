// Floating bulk-action bar for multi-select screens (admin data lists).
//
// Why this exists
// ---------------
// The admin Siswa / Guru / Kelas / Mapel flows all need a "select N rows →
// export / archive / delete / message" affordance. Before this widget,
// each screen either:
//   • shipped its own bespoke bar (inconsistent colors, spacing, safe-area
//     bugs on Samsung), or
//   • had no bulk actions at all and forced row-by-row taps.
//
// This widget locks the pattern: a navy bar anchored to the bottom of the
// scaffold that slides in when [selectedCount] > 0, shows an accent "count
// pill" on the left, a configurable list of icon+label action buttons on
// the right, and a dismiss (✕) affordance to clear selection. It respects
// the iPhone home-indicator / Samsung gesture bar via [SafeArea].
//
// Pair with:
//   • [AdminCrudScaffold] — exposes a `bulkActionBar:` slot.
//   • A parent controller that owns a `Set<String> _selectedIds`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Describes a single action in a [BulkActionBar].
///
/// Each action is rendered as an icon-over-label column; tapping invokes
/// [onTap]. Use [isDestructive] for delete-style actions — renders the
/// icon/label in red.
class BulkAction {
  /// Icon displayed above the label.
  final IconData icon;

  /// Short label under the icon (max ~8 chars for visual fit).
  final String label;

  /// Called when the action is tapped.
  final VoidCallback onTap;

  /// When true, the action is styled in red to signal an irreversible or
  /// destructive operation (delete, archive permanently, etc.).
  final bool isDestructive;

  /// When false, the action button is visually dimmed and non-tappable.
  /// Use this for "Export" on an empty selection, for example.
  final bool enabled;

  const BulkAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });
}

/// A bottom-anchored multi-select action bar.
///
/// Visible only when [selectedCount] > 0 — the caller is expected to pass
/// the current selection size; the widget itself does no selection-state
/// management. Returns [SizedBox.shrink] when the selection is empty so the
/// parent can unconditionally include it in its widget tree.
///
/// Example:
/// ```dart
/// BulkActionBar(
///   selectedCount: _selectedIds.length,
///   onClear: () => setState(() => _selectedIds.clear()),
///   actions: [
///     BulkAction(
///       icon: Icons.file_download_outlined,
///       label: 'Ekspor',
///       onTap: _exportSelected,
///     ),
///     BulkAction(
///       icon: Icons.archive_outlined,
///       label: 'Arsip',
///       onTap: _archiveSelected,
///     ),
///     BulkAction(
///       icon: Icons.delete_outline,
///       label: 'Hapus',
///       onTap: _deleteSelected,
///       isDestructive: true,
///     ),
///   ],
/// )
/// ```
class BulkActionBar extends StatelessWidget {
  /// Number of items currently selected. When zero, the bar is not shown.
  final int selectedCount;

  /// Called when the user taps the ✕ icon to clear the selection.
  final VoidCallback onClear;

  /// Actions rendered right-aligned after the count pill.
  ///
  /// 3–4 actions comfortably fit on a 360 px wide phone; past that the row
  /// scrolls horizontally.
  final List<BulkAction> actions;

  /// Accent color used for the count pill background and the icons. Defaults
  /// to the admin navy (`0xFF0F172A`) which matches the gradient headers.
  final Color accentColor;

  /// Base bar background color. Defaults to white — the bar casts a subtle
  /// drop shadow to lift it off the content.
  final Color backgroundColor;

  /// Noun used in the count label (e.g., "siswa" → "3 siswa terpilih").
  /// Default: 'item'.
  final String itemNoun;

  /// Trailing suffix after the count noun. Default: 'terpilih'.
  final String selectedSuffix;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.actions,
    this.accentColor = const Color(0xFF0F172A),
    this.backgroundColor = Colors.white,
    this.itemNoun = 'item',
    this.selectedSuffix = 'terpilih',
  });

  @override
  Widget build(BuildContext context) {
    // When nothing is selected, collapse entirely. Letting the parent keep
    // this widget in its tree unconditionally avoids layout jumps when the
    // selection transitions 0 → 1.
    if (selectedCount <= 0) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _CountPill(
              count: selectedCount,
              accentColor: accentColor,
              noun: itemNoun,
              suffix: selectedSuffix,
            ),
            const SizedBox(width: AppSpacing.sm),
            // Clear-selection button; sits next to the pill for quick dismiss.
            IconButton(
              tooltip: 'Batalkan pilihan',
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            const Spacer(),
            // The action list. Horizontal scroll protects against label
            // truncation on very narrow devices.
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      _ActionButton(
                        action: actions[i],
                        accentColor: accentColor,
                      ),
                      if (i < actions.length - 1)
                        const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The count chip: "3 siswa terpilih" in an accent-tinted pill.
class _CountPill extends StatelessWidget {
  final int count;
  final Color accentColor;
  final String noun;
  final String suffix;

  const _CountPill({
    required this.count,
    required this.accentColor,
    required this.noun,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$noun $suffix',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single icon-over-label action button.
class _ActionButton extends StatelessWidget {
  final BulkAction action;
  final Color accentColor;

  const _ActionButton({required this.action, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = action.isDestructive
        ? Colors.red.shade600
        : accentColor;
    final opacity = action.enabled ? 1.0 : 0.35;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: action.enabled ? action.onTap : null,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 20, color: effectiveColor),
              const SizedBox(height: 2),
              Text(
                action.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
