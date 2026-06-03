// FinanceSubFilterStrip — Mockup #13.
//
// Sub-filter chips for the Tagihan tab: a horizontal scrollable strip
// of pills that re-scope the bill list.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Sub-filter chip for the Tagihan tab. A pill that flips between an
/// outlined neutral state, an active navy state, and an overdue
/// red-tinted variant when [tone] == [SubFilterTone.danger].
enum SubFilterTone { neutral, danger }

class SubFilterChipData {
  final String key;
  final String label;
  final int? badge;
  final SubFilterTone tone;
  const SubFilterChipData({
    required this.key,
    required this.label,
    this.badge,
    this.tone = SubFilterTone.neutral,
  });
}

/// Horizontal scrollable strip of [SubFilterChipData] pills. Lives
/// directly under the FinanceTabBar on the Tagihan tab. Tapping a chip
/// re-scopes the bill list. Mockup #13 spec: `Semua` / `Belum bayar` /
/// `Jatuh tempo · 32` (last one tinted red when overdue ≥ 1).
class FinanceSubFilterStrip extends StatelessWidget {
  final List<SubFilterChipData> chips;
  final String activeKey;
  final ValueChanged<String> onSelect;
  final EdgeInsetsGeometry padding;

  const FinanceSubFilterStrip({
    super.key,
    required this.chips,
    required this.activeKey,
    required this.onSelect,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              _SubFilterChip(
                data: chips[i],
                active: chips[i].key == activeKey,
                onTap: () => onSelect(chips[i].key),
              ),
              if (i < chips.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubFilterChip extends StatelessWidget {
  final SubFilterChipData data;
  final bool active;
  final VoidCallback onTap;

  const _SubFilterChip({
    required this.data,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final isDanger = data.tone == SubFilterTone.danger;

    final Color bg;
    final Color fg;
    final Color border;
    if (active) {
      bg = isDanger ? const Color(0xFFFEF2F2) : navy;
      fg = isDanger ? const Color(0xFF991B1B) : Colors.white;
      border = isDanger ? const Color(0xFFFCA5A5) : navy;
    } else if (isDanger) {
      bg = const Color(0xFFFEF2F2);
      fg = const Color(0xFF991B1B);
      border = const Color(0xFFFCA5A5);
    } else {
      bg = Colors.white;
      fg = const Color(0xFF334155);
      border = const Color(0xFFCBD5E1);
    }

    final label = data.badge != null && data.badge! > 0
        ? '${data.label} · ${data.badge}'
        : data.label;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active || isDanger ? FontWeight.w800 : FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
