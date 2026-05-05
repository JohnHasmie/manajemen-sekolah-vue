// Brand-aligned list row card — the canonical "data row" visual used by
// every admin CRUD list (Siswa, Guru, Kelas, Mapel, Jadwal) plus parent /
// teacher lists that want the same look.
//
// Visual contract (matches the user's preferred SS2 design):
//   ┌──────────────────────────────────────────────────────────┐
//   │ ⬛AY  7A · NIS 1234567                          Detail →  │
//   │      Ahmad Yahya Hasymi                                   │
//   │      • Aktif                                              │
//   └──────────────────────────────────────────────────────────┘
//
//   • Outer:    white card, 14 px radius, slate-200 0.75 px border,
//               14 px padding, 12 px vertical / 16 px horizontal margin.
//   • Leading:  44×44 widget slot — typically a SOLID InitialsAvatar
//               (admin navy / teacher cobalt / parent azure).
//   • Top meta: 11.5 pt w500 slate-500 — small kicker line above title.
//   • Title:    15 pt w800 slate-900 — the bold headline (name).
//   • Status:   inline 6 px dot + 11 pt w600 colored text (no chip bg).
//   • Trail:    "Detail →" text CTA in brand color, top-right.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tone for the inline status indicator (dot + text, no background).
enum BrandStatusTone { success, warning, danger, info, neutral }

/// One inline status row — small colored dot + label text. No background
/// pill. Use this for the primary status of the row (Aktif, Cuti, Lunas,
/// Pending, etc.). For richer multi-chip layouts pass [chips] instead.
class BrandRowStatus {
  final String label;
  final BrandStatusTone tone;
  final Color? colorOverride;

  const BrandRowStatus({
    required this.label,
    this.tone = BrandStatusTone.success,
    this.colorOverride,
  });

  const BrandRowStatus.success(this.label)
    : tone = BrandStatusTone.success,
      colorOverride = null;
  const BrandRowStatus.warning(this.label)
    : tone = BrandStatusTone.warning,
      colorOverride = null;
  const BrandRowStatus.danger(this.label)
    : tone = BrandStatusTone.danger,
      colorOverride = null;
  const BrandRowStatus.info(this.label)
    : tone = BrandStatusTone.info,
      colorOverride = null;
  const BrandRowStatus.neutral(this.label)
    : tone = BrandStatusTone.neutral,
      colorOverride = null;

  Color get color {
    if (colorOverride != null) return colorOverride!;
    switch (tone) {
      case BrandStatusTone.success:
        return const Color(0xFF15803D);
      case BrandStatusTone.warning:
        return const Color(0xFFB45309);
      case BrandStatusTone.danger:
        return const Color(0xFFDC2626);
      case BrandStatusTone.info:
        return const Color(0xFF1E40AF);
      case BrandStatusTone.neutral:
        return ColorUtils.slate500;
    }
  }
}

/// Optional richer chip — used when a row needs a 2nd badge that does
/// have a background pill (e.g. Wali Kelas role chip on the Guru list).
enum BrandChipTone { success, warning, danger, info, neutral }

class BrandRowChip {
  final String label;
  final BrandChipTone tone;
  final bool withDot;

  const BrandRowChip({
    required this.label,
    this.tone = BrandChipTone.info,
    this.withDot = false,
  });

  const BrandRowChip.role(this.label)
    : tone = BrandChipTone.warning,
      withDot = false;
  const BrandRowChip.info(this.label)
    : tone = BrandChipTone.info,
      withDot = false;
  const BrandRowChip.success(this.label)
    : tone = BrandChipTone.success,
      withDot = true;
}

/// The canonical brand-aligned list row.
class BrandListRow extends StatelessWidget {
  /// Leading widget — typically a [InitialsAvatar] in solid mode. Sized 44×44.
  final Widget leading;

  /// Optional small kicker line above the title (e.g. `'7A · NIS 1234567'`).
  /// Renders as 11.5 pt w500 slate-500.
  final String? topMeta;

  /// Bold headline — the row's primary label (name, subject, etc.).
  final String title;

  /// Optional inline status row (dot + colored text) below the title.
  final BrandRowStatus? status;

  /// Optional secondary chip rendered next to [status]. Useful for the
  /// Wali Kelas role chip on the Guru list, or a "Belum diverifikasi"
  /// flag on the Siswa list.
  final BrandRowChip? secondaryChip;

  /// Optional bottom subtitle line (descriptive sentence). Use sparingly —
  /// most rows do without it now that [topMeta] carries the meta.
  final String? subtitle;

  /// Right-trail CTA label (e.g. `'Detail'`). Renders as `'Detail →'` in
  /// brand color. Pass null to hide and show a chevron instead.
  final String? trailingActionLabel;

  /// Color override for the trail action. Defaults to admin navy.
  final Color? trailingActionColor;

  /// When [trailingActionLabel] is null, show a chevron in the trail.
  final bool showChevron;

  /// Tap handler — typically opens the detail screen.
  final VoidCallback? onTap;

  /// Long-press handler — typically enters bulk-select mode.
  final VoidCallback? onLongPress;

  /// When true, paint with brandAzure tint border + check icon overlay.
  final bool selected;

  const BrandListRow({
    super.key,
    required this.leading,
    required this.title,
    this.topMeta,
    this.status,
    this.secondaryChip,
    this.subtitle,
    this.trailingActionLabel = 'Detail',
    this.trailingActionColor,
    this.showChevron = true,
    this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = trailingActionColor ?? ColorUtils.getRoleColor('admin');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.04) : Colors.white,
              border: Border.all(
                color:
                    selected ? accent : const Color(0xFFE2E8F0), // slate-200
                width: selected ? 1.4 : 0.75,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 44, height: 44, child: leading),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (topMeta != null && topMeta!.isNotEmpty) ...[
                        Text(
                          topMeta!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: ColorUtils.slate500,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: ColorUtils.slate500,
                            height: 1.2,
                          ),
                        ),
                      ],
                      if (status != null || secondaryChip != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (status != null) _StatusInline(status: status!),
                            if (status != null && secondaryChip != null)
                              const SizedBox(width: 8),
                            if (secondaryChip != null)
                              _SecondaryChipView(chip: secondaryChip!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Trailing(
                  selected: selected,
                  label: trailingActionLabel,
                  showChevron: showChevron,
                  accent: accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusInline extends StatelessWidget {
  final BrandRowStatus status;

  const _StatusInline({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: status.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status.label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: status.color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

class _SecondaryChipView extends StatelessWidget {
  final BrandRowChip chip;

  const _SecondaryChipView({required this.chip});

  ({Color bg, Color fg}) _palette() {
    switch (chip.tone) {
      case BrandChipTone.success:
        return (bg: const Color(0xFFE6F7EE), fg: const Color(0xFF15803D));
      case BrandChipTone.warning:
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFF92400E));
      case BrandChipTone.danger:
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFF991B1B));
      case BrandChipTone.info:
        return (bg: const Color(0xFFE0EBFF), fg: const Color(0xFF1E40AF));
      case BrandChipTone.neutral:
        return (bg: const Color(0xFFF1F5F9), fg: ColorUtils.slate700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip.withDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: p.fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            chip.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: p.fg,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Trailing extends StatelessWidget {
  final bool selected;
  final String? label;
  final bool showChevron;
  final Color accent;

  const _Trailing({
    required this.selected,
    required this.label,
    required this.showChevron,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Icon(Icons.check_circle_rounded, size: 22, color: accent);
    }
    if (label != null && label!.isNotEmpty) {
      return Text(
        '$label →',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: accent,
          height: 1.0,
        ),
      );
    }
    if (showChevron) {
      return Icon(
        Icons.chevron_right_rounded,
        size: 22,
        color: ColorUtils.slate400,
      );
    }
    return const SizedBox.shrink();
  }
}
