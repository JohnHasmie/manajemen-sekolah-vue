// Horizontal chip row of teaching roles for teacher-role screens.
//
// Why this exists
// ---------------
// Teacher-side screens that have both a "mengajar" view (subjects the
// teacher teaches across all their classes) and a "wali kelas" view
// (homeroom-class-scoped data) need a switcher that's symmetric with
// the parent role's child selector — same hero-gradient placement,
// same chip metrics, same ellipsis story, same active-state visuals.
//
// The original `RoleToggle` was a fixed two-position switch (Mengajar
// vs Wali Kelas). It assumed a teacher had at most one homeroom
// assignment. In practice some teachers carry multiple, and forcing
// them to multiplex through a single Wali Kelas pill made the per-
// class state implicit. This widget replaces it with a strip:
//
//   • One `Mengajar` chip that always exists.
//   • One chip per homeroom class — `Wali Kelas 7B`, `Wali Kelas 8A`, …
//   • The current selection is the active pill, identical visuals
//     to `ChildSelectorChipRow`'s active state.
//
// Single-role teachers (no homeroom assignment) get a no-op widget
// (`SizedBox.shrink()`) so the screen never shows a chooser with a
// single option.
//
// Visual contract (matches `ChildSelectorChipRow` 1:1)
// --------------------------------------------------------------------
//   • Strip height: 36 px.
//   • Active chip: solid white pill, brand-coloured 22dp avatar
//     circle, black role label + slate sub-label.
//   • Inactive chip: 22% white solid fill, hairline white border,
//     40% white avatar circle, white label + 78%-white sub-label.
//   • 6 px gap between chips, Expanded so the row fills the gradient
//     header. With ≥5 chips, sub-labels ellipsize first, then names.
import 'package:flutter/material.dart';

/// One option in [RoleToggleChipRow]. The widget pre-builds the two
/// canonical roles for you via [RoleOption.mengajar] and
/// [RoleOption.waliKelas], but you can construct custom entries if a
/// future screen has more than the two standard buckets.
class RoleOption {
  /// Stable identifier the host's onSelected callback gets back.
  /// `'mengajar'` for the teaching view; `'wali:<classId>'` for the
  /// per-homeroom-class entries.
  final String id;

  /// Short display name shown bold in the pill.
  /// e.g. `Mengajar`, `Wali Kelas`.
  final String shortName;

  /// Sub-label shown smaller below. e.g. `3 kelas · 4 mapel`,
  /// `Kelas 7B`, `10 siswa`. Pass an empty string to suppress the
  /// sub-line; the chip will center the label vertically.
  final String subLabel;

  /// Optional initials shown inside the avatar circle. Defaults to
  /// the first letter of [shortName] (uppercased).
  final String? avatarInitials;

  const RoleOption({
    required this.id,
    required this.shortName,
    required this.subLabel,
    this.avatarInitials,
  });

  /// Canonical "Mengajar" entry — every teacher has it.
  factory RoleOption.mengajar({String subLabel = ''}) =>
      RoleOption(
        id: 'mengajar',
        shortName: 'Mengajar',
        subLabel: subLabel,
        avatarInitials: 'M',
      );

  /// Canonical "Wali Kelas" entry for one homeroom class.
  ///
  /// `classId` becomes the chip's stable id with a `wali:` prefix so
  /// hosts can pattern-match. `className` (e.g. `7B`) drives the
  /// label and the avatar initials (`7B` → `7B`).
  factory RoleOption.waliKelas({
    required String classId,
    required String className,
    String subLabel = '',
  }) =>
      RoleOption(
        id: 'wali:$classId',
        shortName: 'Wali $className',
        subLabel: subLabel,
        avatarInitials: className.isEmpty
            ? 'W'
            : className.length <= 2
                ? className.toUpperCase()
                : className.substring(0, 2).toUpperCase(),
      );

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

/// Teacher-role chip row, used inside teacher gradient headers.
///
/// Example:
/// ```dart
/// RoleToggleChipRow(
///   roles: [
///     RoleOption.mengajar(subLabel: '3 kelas · 4 mapel'),
///     RoleOption.waliKelas(classId: '...', className: '7B',
///                          subLabel: '10 siswa'),
///     RoleOption.waliKelas(classId: '...', className: '8A',
///                          subLabel: '11 siswa'),
///   ],
///   selectedRoleId: 'mengajar',
///   onSelected: (id) => setState(() => _roleId = id),
///   accentColor: ColorUtils.brandCobalt,
/// );
/// ```
///
/// When [roles] has fewer than 2 entries the widget renders nothing —
/// a one-option switcher is dead weight.
class RoleToggleChipRow extends StatelessWidget {
  /// Roles available to the logged-in teacher.
  final List<RoleOption> roles;

  /// Currently selected role's id. Should match exactly one entry in
  /// [roles]; if no match, every chip renders inactive.
  final String selectedRoleId;

  /// Tap callback — fires with the new role id.
  final ValueChanged<String> onSelected;

  /// Accent colour for the active role's avatar circle. Defaults to
  /// the brand cobalt (teacher role); override if a host wants a
  /// different active accent.
  final Color accentColor;

  const RoleToggleChipRow({
    super.key,
    required this.roles,
    required this.selectedRoleId,
    required this.onSelected,
    this.accentColor = const Color(0xFF1E40AF),
  });

  @override
  Widget build(BuildContext context) {
    if (roles.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          for (var i = 0; i < roles.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _RoleChip(
                role: roles[i],
                isActive: roles[i].id == selectedRoleId,
                accentColor: accentColor,
                onTap: () => onSelected(roles[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final RoleOption role;
  final bool isActive;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleChip({
    required this.role,
    required this.isActive,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillColor = isActive
        ? Colors.white
        : const Color(0x38FFFFFF); // 22% white, solid
    final borderColor =
        isActive ? Colors.transparent : Colors.white;
    final avatarColor =
        isActive ? accentColor : const Color(0x66FFFFFF); // 40% white
    const avatarTextColor = Colors.white;
    final nameColor = isActive ? const Color(0xFF0F172A) : Colors.white;
    final subColor = isActive ? const Color(0xFF475569) : Colors.white;

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
                role._resolvedInitials,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: avatarTextColor,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    role.shortName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: nameColor,
                      height: 1.1,
                    ),
                  ),
                  if (role.subLabel.isNotEmpty)
                    Text(
                      role.subLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: subColor,
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
