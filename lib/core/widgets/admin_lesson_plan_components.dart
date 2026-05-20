// Admin RPP review-queue shared components — Mockup #09.
//
// Three new widgets:
//   • QueueCountTile     — single hero KPI tile (count + delta).
//   • SwipeableQueueCard — card with 4px tier-color left edge and
//                          right-swipe action peek (approve/reject).
//   • ReviewQueueColumn  — sectioned vertical list with tier headers
//                          (color dot + label + count). Each tier
//                          collapses to its first 5 cards with a
//                          "lihat semua →" expansion.
//
// Pure presentation widgets — caller owns state and wires the
// approve/reject/regen actions.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// Tier tone tokens
// =====================================================================

enum QueueTone { warn, good, bad }

extension QueueToneTokens on QueueTone {
  /// Card left-edge stripe + tier dot accent. Mockup uses Tailwind
  /// 600-weight tints (amber-600 / green-600 / red-600) for these
  /// stripes — a touch darker than the previous 500s so they read
  /// against the white card background instead of bleeding in.
  Color get accent {
    switch (this) {
      case QueueTone.warn:
        return ColorUtils.warning600;
      case QueueTone.good:
        return ColorUtils.green600;
      case QueueTone.bad:
        return ColorUtils.error600;
    }
  }
}

// =====================================================================
// QueueCountTile (lives inside the hero)
// =====================================================================

class QueueCountTile extends StatelessWidget {
  final String label;
  final int count;
  final QueueTone tone;
  final String? deltaLabel;
  final VoidCallback? onTap;

  const QueueCountTile({
    super.key,
    required this.label,
    required this.count,
    required this.tone,
    this.deltaLabel,
    this.onTap,
  });

  Color _deltaColor() {
    switch (tone) {
      case QueueTone.warn:
        return const Color(0xFFFBBF24);
      case QueueTone.good:
        return const Color(0xFF86EFAC);
      case QueueTone.bad:
        return const Color(0xFFFCA5A5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPrimary = tone == QueueTone.warn;
    final bg = isPrimary
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.10);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deltaLabel ?? ' ',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _deltaColor(),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// SwipeableQueueCard
// =====================================================================

class SwipeableQueueCard extends StatelessWidget {
  final String subtitle; // "Bahasa Arab · Kelas 8B"
  final String title;
  final String footer;
  final String? rejectionReason;
  final List<Widget> meta; // chips + timestamp
  final QueueTone tone;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRegen;
  final List<Widget>? actionsRow;

  /// Optional pill that sits before the status pill in the meta row —
  /// surfaces the RPP format (K13 / Modul Ajar / 1 Halaman / Upload).
  /// Pass null on tiers where format-by-format readout would be noise.
  final Widget? formatBadge;

  /// "Kembalikan ke guru" quick action. When provided, the right-rail
  /// column adds an amber ⤺ button between Approve (✓) and Reject (✗).
  final VoidCallback? onSendBack;

  /// Teacher avatar initials — rendered as a 22dp cobalt circle next
  /// to the footer text. Pass null/empty to keep the older "footer
  /// only" rendering.
  final String? avatarInitials;

  const SwipeableQueueCard({
    super.key,
    required this.subtitle,
    required this.title,
    required this.footer,
    this.rejectionReason,
    this.meta = const [],
    required this.tone,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.onRegen,
    this.actionsRow,
    this.formatBadge,
    this.onSendBack,
    this.avatarInitials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: tone == QueueTone.bad
            ? Border.all(color: const Color(0xFFFEE2E2), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                // Mockup `.rpp-card .accent` is 3 px — keep card visual
                // density consistent with the design system.
                Container(width: 3, color: tone.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row — format pill + meta chips (status
                        // pill, updated_at). Mockup `.row1` layout.
                        if (formatBadge != null || meta.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (formatBadge != null) formatBadge!,
                              ...meta,
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (rejectionReason != null &&
                            rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '"${rejectionReason!}"',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: tone.accent,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Footer with dashed top border per mockup
                        // `.rpp-foot`. Holds the teacher avatar +
                        // name on the left and the 3-button quick
                        // action column on the right.
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: ColorUtils.slate200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              if ((avatarInitials ?? '').isNotEmpty) ...[
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ColorUtils.brandCobalt,
                                  ),
                                  child: Text(
                                    avatarInitials!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  footer,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (onApprove != null ||
                                  onSendBack != null ||
                                  onReject != null) ...[
                                if (onApprove != null)
                                  _QuickActionButton(
                                    icon: Icons.check_rounded,
                                    bg: const Color(0xFFDCFCE7),
                                    fg: ColorUtils.success700,
                                    onTap: onApprove!,
                                    tooltip: 'Setujui cepat',
                                  ),
                                if (onSendBack != null) ...[
                                  const SizedBox(width: 4),
                                  _QuickActionButton(
                                    icon: Icons.reply_rounded,
                                    bg: const Color(0xFFFEF3C7),
                                    fg: ColorUtils.warning700,
                                    onTap: onSendBack!,
                                    tooltip: 'Kembalikan ke guru',
                                  ),
                                ],
                                if (onReject != null) ...[
                                  const SizedBox(width: 4),
                                  _QuickActionButton(
                                    icon: Icons.close_rounded,
                                    bg: const Color(0xFFFEE2E2),
                                    fg: ColorUtils.error700,
                                    onTap: onReject!,
                                    tooltip: 'Tolak',
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        if (actionsRow != null) ...[
                          const SizedBox(height: 8),
                          Row(children: actionsRow!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// ReviewQueueColumn
// =====================================================================

class ReviewTier {
  final String key;
  final String label;
  final int totalCount;
  final QueueTone tone;
  final List<Widget> cards;
  final bool collapsed;
  final VoidCallback? onSeeAll;

  const ReviewTier({
    required this.key,
    required this.label,
    required this.totalCount,
    required this.tone,
    required this.cards,
    this.collapsed = false,
    this.onSeeAll,
  });
}

class ReviewQueueColumn extends StatelessWidget {
  final List<ReviewTier> tiers;
  const ReviewQueueColumn({super.key, required this.tiers});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiers.length; i++) ...[
          _TierHeader(
            tone: tiers[i].tone,
            label: tiers[i].label,
            count: tiers[i].totalCount,
            collapsed: tiers[i].collapsed,
            onSeeAll: tiers[i].onSeeAll,
          ),
          const SizedBox(height: 8),
          if (tiers[i].cards.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Belum ada item',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: ColorUtils.slate500,
                ),
              ),
            )
          else
            for (var j = 0; j < tiers[i].cards.length; j++) ...[
              tiers[i].cards[j],
              if (j < tiers[i].cards.length - 1) const SizedBox(height: 8),
            ],
          if (i < tiers.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _TierHeader extends StatelessWidget {
  final QueueTone tone;
  final String label;
  final int count;
  final bool collapsed;
  final VoidCallback? onSeeAll;

  const _TierHeader({
    required this.tone,
    required this.label,
    required this.count,
    required this.collapsed,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tone.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 10.5, color: ColorUtils.slate500),
          ),
          if (collapsed && onSeeAll != null) ...[
            const Spacer(),
            InkWell(
              onTap: onSeeAll,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  'lihat semua →',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.getRoleColor('admin'),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 30dp square button used by the SwipeableQueueCard footer row to
/// surface ✓ approve / ⤺ kembalikan / ✗ tolak quick actions. Mockup
/// `.quick-btn` — pill-rounded with status-tinted bg + fg.
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final String tooltip;

  const _QuickActionButton({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}
