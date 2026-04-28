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
  /// gradient (e.g. `'PILIH ANAK'`). Pass null to hide.
  final String? sectionLabel;

  const ChildSelectorChipRow({
    super.key,
    required this.children,
    required this.selectedChildId,
    required this.onSelected,
    this.accentColor = const Color(0xFF21AFE6),
    this.sectionLabel = 'PILIH ANAK',
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
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final child = children[index];
              final isActive = child.id == selectedChildId;
              return _ChildChip(
                child: child,
                isActive: isActive,
                accentColor: accentColor,
                onTap: () => onSelected(child.id),
              );
            },
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
    final pillColor = isActive
        ? Colors.white
        : Colors.white.withValues(alpha: 0.16);
    final borderColor = isActive
        ? Colors.transparent
        : Colors.white.withValues(alpha: 0.28);
    final avatarColor = isActive ? accentColor : Colors.white.withValues(alpha: 0.28);
    final avatarTextColor = isActive ? Colors.white : Colors.white;
    final nameColor = isActive ? const Color(0xFF0F172A) : Colors.white;
    final klassColor = isActive
        ? const Color(0xFF64748B)
        : Colors.white.withValues(alpha: 0.78);

    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
        decoration: BoxDecoration(
          color: pillColor,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          border: Border.all(color: borderColor, width: isActive ? 0 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                child._resolvedInitials,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: avatarTextColor,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  child.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: nameColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  child.klass,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: klassColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
