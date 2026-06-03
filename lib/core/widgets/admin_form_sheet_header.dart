// AdminFormSheetHeader — shared header for admin add/edit bottom sheets.
//
// Mirrors the v3 actions mockup (frames B + C):
//
//   ┌──────────────────────────────────────────────────────────┐
//   │ ⬛+   TAMBAH BARU                                     ✕   │
//   │      Tambah Siswa                                         │
//   └──────────────────────────────────────────────────────────┘
//
// In edit mode the icon tile flips to amber pencil + kicker reads
// "EDIT DATA". When [contextLabel] is provided it shows a small amber
// "MENGEDIT: …" strip below the header — the v3 pattern that confirms
// to the user which entity they're modifying.
//
// Usage from a per-feature add/edit sheet:
// ```dart
// Column(children: [
//   AdminFormSheetHeader(
//     title: 'Tambah Siswa',
//     isEditMode: false,
//     onClose: () => AppNavigator.pop(context),
//   ),
//   ... form body ...
// ])
// ```
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class AdminFormSheetHeader extends StatelessWidget {
  /// Big title — typically `Tambah Siswa` / `Edit Siswa`.
  final String title;

  /// Whether to render the edit (amber pencil) variant or the add (navy
  /// plus) variant. Drives the icon, the icon-tile background, and the
  /// kicker color/copy.
  final bool isEditMode;

  /// Optional close handler. Defaults to `AppNavigator.pop(context)`.
  final VoidCallback? onClose;

  /// Optional override for the kicker label. Defaults to
  /// `'TAMBAH BARU'` / `'EDIT DATA'` based on [isEditMode].
  final String? kicker;

  /// Optional "MENGEDIT: `<name>`" context strip rendered below the header
  /// in edit mode. Pass `null` (the default) to hide it.
  final AdminFormContext? editingContext;

  /// Drag handle visibility. The host sheet usually renders one outside,
  /// so this defaults to `false`.
  final bool showDragHandle;

  const AdminFormSheetHeader({
    super.key,
    required this.title,
    required this.isEditMode,
    this.onClose,
    this.kicker,
    this.editingContext,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor('admin');
    final close = onClose ?? () => AppNavigator.pop(context);
    final isEdit = isEditMode;
    final iconBg = isEdit ? const Color(0xFFFEF3C7) : accent;
    final iconColor = isEdit ? const Color(0xFF92400E) : Colors.white;
    final kickerColor = isEdit ? const Color(0xFF92400E) : ColorUtils.slate500;
    final defaultKicker = isEdit ? 'EDIT DATA' : 'TAMBAH BARU';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 14, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        kicker ?? defaultKicker,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: kickerColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Material(
                color: const Color(0xFFF4F7FB),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: close,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF5B6E8C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isEdit && editingContext != null)
          _EditingContextStrip(ctx: editingContext!, accent: accent),
      ],
    );
  }
}

/// Small "MENGEDIT: …" context strip rendered below the header in edit
/// mode. Confirms which entity the user is currently modifying.
class AdminFormContext {
  /// Display name of the entity being edited (e.g. `Ahmad Yahya · 7A`).
  final String label;

  /// Initials shown in the small leading avatar.
  final String initials;

  const AdminFormContext({required this.label, required this.initials});
}

class _EditingContextStrip extends StatelessWidget {
  final AdminFormContext ctx;
  final Color accent;

  const _EditingContextStrip({required this.ctx, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF7E0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: ColorUtils.brandGradient('admin'),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _shortInitials(ctx.initials),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'MENGEDIT',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ctx.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
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

  String _shortInitials(String src) {
    if (src.isEmpty) return '?';
    final parts = src.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
