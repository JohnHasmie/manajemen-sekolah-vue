// Horizontal scrollable chip row of children for parent-role screens.
//
// Why this exists
// ---------------
// Five parent screens need the same "which child is this for?" picker
// inside their gradient hero (Kehadiran, Aktivitas Kelas, Ringkasan
// Rapor, Nilai, Tagihan). Without a shared widget every screen would
// roll its own — different chip sizes, different spacing, different
// active-state visuals — and the parent's mental model would fragment.
//
// Visual contract
// ---------------
//   • Active child: solid white pill (44 px tall), 14 px brand-coloured
//     avatar circle, black short name + slate class label.
//   • Inactive sibling: 16% white pill, 28% white avatar, white name +
//     78%-white class label.
//   • Single-child families: still rendered as one solid pill so the
//     widget always gives the same visual structure (no conditional
//     "Ganti" / popup paths to reason about).
//   • 8 px gap between chips, scrollable horizontally when total width
//     exceeds the screen.
//
// Sizing & alignment match the parent dashboard `SchoolPill` so the
// hero composition stays balanced.
import 'package:flutter/material.dart';

/// Lightweight model for a child in the selector row. Used by widgets
/// that build chip rows; not a domain model.
class ChildSummary {
  /// Stable identifier the parent's onSelected callback gets back.
  final String id;

  /// Short display name (1-2 words). e.g. `Rania`, `Faiz`.
  final String shortName;

  /// Class line shown under the name. e.g. `Kelas 8B`.
  final String klass;

  /// Optional initials. Derived from [shortName] if null.
  final String? avatarInitials;

  const ChildSummary({
    required this.id,
    required this.shortName,
    required this.klass,
    this.avatarInitials,
  });

  String get _resolvedInitials {
    if (avatarInitials != null && avatarInitials!.isNotEmpty) {
      return avatarInitials!.toUpperCase();
    }
    final parts = shortName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

/// Horizontal scrollable chip row of children, used inside parent
/// gradient headers.
///
/// Example:
/// ```dart
/// ChildSelectorChipRow(
///   children: [
///     ChildSummary(id: '1', shortName: 'Rania', klass: 'Kelas 8B'),
///     ChildSummary(id: '2', shortName: 'Faiz',  klass: 'Kelas 5A'),
///   ],
///   selectedChildId: '1',
///   onSelected: (id) => setState(() => _childId = id),
///   accentColor: ColorUtils.brandAzure,
/// );
/// ```
class ChildSelectorChipRow extends StatelessWidget {
  /// Available children for the logged-in parent. Caller is responsible
  /// for fetching and passing them in.
  final List<ChildSummary> children;

  /// Currently selected child's id. Should match exactly one entry in
  /// [children]; if no match, every chip renders as inactive.
  final String selectedChildId;

  /// Tap callback — fires with the new child id.
  final ValueChanged<String> onSelected;

  /// Accent colour for the active child's avatar circle. Defaults to
  /// the brand azure (parent role); override for teacher/admin reuse.
  final Color accentColor;

  /// Optional small caption rendered above the chip row inside the
  /// gradient (e.g. `'PILIH ANAK'`). Defaults to null in compact v2 —
  /// the avatar chips are self-describing, so the label was redundant
  /// vertical space. Pass a non-null value to opt back in.
  final String? sectionLabel;

  const ChildSelectorChipRow({
    super.key,
    required this.children,
    required this.selectedChildId,
    required this.onSelected,
    this.accentColor = const Color(0xFF21AFE6),
    this.sectionLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sectionLabel != null) ...[
          Text(
            sectionLabel!,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
        ],
        // Row of Expanded chips so they stretch to fill the gradient
        // header width — matches the v3 mockup (chips share the row
        // 50/50 for two children, 33/33 for three, etc.). With ≥5
        // children the inner Column ellipsizes the name to keep
        // chips readable. We don't horizontal-scroll because the
        // chip's inner Expanded would be unbounded inside a scroll
        // viewport.
        SizedBox(
          height: 36,
          child: Row(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _ChildChip(
                    child: children[i],
                    isActive: children[i].id == selectedChildId,
                    accentColor: accentColor,
                    onTap: () => onSelected(children[i].id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ChildChip extends StatelessWidget {
  final ChildSummary child;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _ChildChip({
    required this.child,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Hard colors only — no semi-transparent whites. The active chip
    // is solid white with dark text; the inactive chip is a solid
    // 22%-fill pill with solid-white text and a hairline white border
    // for definition. Reads cleanly on the brand-azure gradient.
    final pillColor = isActive
        ? Colors.white
        : const Color(0x38FFFFFF); // 22% white, solid
    final borderColor = isActive ? Colors.transparent : Colors.white;
    final avatarColor = isActive
        ? accentColor
        : const Color(0x66FFFFFF); // 40% white
    const avatarTextColor = Colors.white;
    final nameColor = isActive ? const Color(0xFF0F172A) : Colors.white;
    final klassColor = isActive ? const Color(0xFF475569) : Colors.white;

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          border: Border.all(color: borderColor, width: isActive ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                child._resolvedInitials,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: avatarTextColor,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // The chip's parent (Row of Expanded slots in
            // ChildSelectorChipRow) governs the available width now,
            // so the name+class column just needs to flex inside the
            // pill. Ellipsis still kicks in for very long names.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    child.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: nameColor,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    child.klass,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: klassColor,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
