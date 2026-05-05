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
  Color get accent {
    switch (this) {
      case QueueTone.warn:
        return const Color(0xFFF59E0B);
      case QueueTone.good:
        return const Color(0xFF10B981);
      case QueueTone.bad:
        return const Color(0xFFDC2626);
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
                Container(width: 4, color: tone.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: meta,
                          ),
                        ],
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
                        const SizedBox(height: 6),
                        Text(
                          footer,
                          style: TextStyle(
                            fontSize: 10,
                            color: ColorUtils.slate300,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (actionsRow != null) ...[
                          const SizedBox(height: 10),
                          Row(children: actionsRow!),
                        ],
                      ],
                    ),
                  ),
                ),
                if (onApprove != null && tone == QueueTone.warn)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Material(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onApprove,
                        child: const SizedBox(
                          width: 38,
                          height: 32,
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
            ),
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
