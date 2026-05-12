// Dashboard "pending inbox" — grouped list of items needing admin action.
//
// Why this exists
// ---------------
// The admin dashboard has to surface several tiny worklists in one place:
// verifikasi pembayaran, draft pengumuman, pendaftaran siswa baru, permintaan
// izin. Before this widget, each of those sat in its own card with different
// padding / typography / CTA, and the dashboard felt like three pasted-on
// widgets.
//
// `PendingInboxCard` is a single vertical card with:
//   • a header (title + total count + "Lihat semua" link)
//   • N grouped rows, each with (icon, label, count, tap target, color cue)
//   • an empty-state row when all groups are zero
//
// The same widget backs the teacher "tindakan perlu dilakukan" card on the
// teacher dashboard and the orangtua "perlu ditinjau" card — the only thing
// that changes is the group list.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';

/// One row in the [PendingInboxCard].
///
/// Each entry represents a worklist (e.g., "Verifikasi pembayaran · 8 belum
/// diproses"). Tapping invokes [onTap] — typically a navigator push to the
/// corresponding filter-scoped list screen.
class PendingInboxEntry {
  /// Leading icon displayed inside a colored disc.
  final IconData icon;

  /// Short label shown next to the icon (e.g., "Verifikasi pembayaran").
  final String label;

  /// Count badge on the right edge. When 0, the entry still shows but the
  /// badge reads "0" in a muted grey so users see the row as "no work".
  final int count;

  /// Accent color used for the icon disc and the count badge.
  final Color color;

  /// Optional secondary line under the label ("3 menunggu lebih dari 24 jam").
  final String? subtitle;

  /// Tap handler — routes to the corresponding worklist.
  final VoidCallback? onTap;

  const PendingInboxEntry({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.subtitle,
    this.onTap,
  });
}

/// Dashboard card that aggregates several pending worklists.
///
/// Example:
/// ```dart
/// PendingInboxCard(
///   title: 'Perlu tindakan',
///   totalLabel: 'total',
///   onSeeAll: () => _openAllPending(),
///   entries: [
///     PendingInboxEntry(
///       icon: Icons.receipt_long_outlined,
///       label: 'Verifikasi pembayaran',
///       count: 8,
///       color: Colors.amber.shade700,
///       subtitle: '3 menunggu > 24 jam',
///       onTap: _openFinanceVerification,
///     ),
///     PendingInboxEntry(
///       icon: Icons.campaign_outlined,
///       label: 'Draft pengumuman',
///       count: 2,
///       color: Colors.indigo,
///       onTap: _openAnnouncementDrafts,
///     ),
///   ],
/// )
/// ```
class PendingInboxCard extends StatelessWidget {
  /// Card title displayed in the header.
  final String title;

  /// Entries to render as rows. Order is respected. Used by the
  /// admin + parent dashboards which compose their lists locally
  /// from `state.stats` counts.
  final List<PendingInboxEntry> entries;

  /// Server-ranked priority-inbox items. When non-null, this list
  /// takes precedence over [entries] and the card renders the
  /// priority layout (severity dot + relative-time chip, no icon
  /// disc, count badge only when >1). Used by the teacher dashboard
  /// once FF.* wiring lands.
  final List<PriorityInboxItem>? priorityItems;

  /// Tap handler invoked when a priority row is tapped. Receives
  /// the item so the caller can resolve [PriorityInboxItem.targetRoute]
  /// to a concrete screen push. Ignored when [priorityItems] is null.
  final void Function(PriorityInboxItem item)? onPriorityTap;

  /// Long-press handler invoked when a priority row is held. Used
  /// by GG.9 to surface the local snooze sheet. Optional — when
  /// null the row just has no long-press feedback. Ignored when
  /// [priorityItems] is null.
  final void Function(PriorityInboxItem item)? onPriorityLongPress;

  /// "Now" reference used to compute the relative-time chip. Defaults
  /// to `DateTime.now()` if omitted. Override in tests to pin time.
  final DateTime? nowOverride;

  /// Called when the "Lihat semua" link in the header is tapped.
  final VoidCallback? onSeeAll;

  /// Label for the see-all link. Default: 'Lihat semua'.
  final String seeAllLabel;

  /// Suffix in the header summary, e.g., "14 total" → 'total'.
  /// Pass an empty string to hide the summary.
  final String totalLabel;

  /// Empty-state copy used when every entry has `count == 0` (or
  /// when [priorityItems] is an empty list).
  final String emptyStateTitle;

  /// Empty-state subtitle.
  final String emptyStateSubtitle;

  /// Accent color used for the header, "lihat semua" link, and empty-state
  /// icon. Defaults to admin navy.
  final Color accentColor;

  const PendingInboxCard({
    super.key,
    required this.title,
    required this.entries,
    this.onSeeAll,
    this.seeAllLabel = 'Lihat semua',
    this.totalLabel = 'total',
    this.emptyStateTitle = 'Semua beres',
    this.emptyStateSubtitle = 'Tidak ada item yang menunggu.',
    this.accentColor = const Color(0xFF0F172A),
  }) : priorityItems = null,
       onPriorityTap = null,
       onPriorityLongPress = null,
       nowOverride = null;

  /// Server-driven variant — renders [PriorityInboxItem]s directly
  /// from the backend's `priority_inbox` array. Each row shows a
  /// severity dot + label + subtitle + relative-time chip. The
  /// count badge appears only when an item has `count > 1`.
  const PendingInboxCard.priorityItems({
    super.key,
    required this.title,
    required List<PriorityInboxItem> items,
    required this.onPriorityTap,
    this.onPriorityLongPress,
    this.onSeeAll,
    this.seeAllLabel = 'Lihat semua',
    this.totalLabel = '',
    this.emptyStateTitle = 'Semua aman',
    this.emptyStateSubtitle = 'Tidak ada yang perlu perhatian saat ini.',
    this.accentColor = const Color(0xFF0F172A),
    this.nowOverride,
  }) : entries = const [],
       priorityItems = items;

  // ── Totals ──
  // Priority mode counts items with count >= 1 (drops zero rows is
  // already handled server-side, so the active row count equals the
  // list length). Legacy mode sums the entry count badges.
  int get _total => priorityItems != null
      ? priorityItems!.length
      : entries.fold(0, (sum, e) => sum + e.count);

  @override
  Widget build(BuildContext context) {
    final isPriorityMode = priorityItems != null;
    final isEmpty = isPriorityMode ? priorityItems!.isEmpty : _total == 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: accentColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            title: title,
            totalCount: _total,
            totalLabel: totalLabel,
            accentColor: accentColor,
            onSeeAll: onSeeAll,
            seeAllLabel: seeAllLabel,
          ),
          if (isEmpty)
            _InboxEmptyState(
              title: emptyStateTitle,
              subtitle: emptyStateSubtitle,
              accentColor: accentColor,
            )
          else if (isPriorityMode)
            ..._buildPriorityRows(nowOverride ?? DateTime.now())
          else
            ..._buildEntries(),
        ],
      ),
    );
  }

  // Builds one row per entry, separated by 1 px dividers. The divider between
  // adjacent rows is indented to align under the label (keeps the icon column
  // visually isolated).
  List<Widget> _buildEntries() {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      rows.add(_InboxRow(entry: entries[i]));
      if (i < entries.length - 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        );
      }
    }
    return rows;
  }

  // Priority-mode rows. Uses the same divider treatment so the two
  // styles blend visually across the admin/parent legacy variant.
  List<Widget> _buildPriorityRows(DateTime now) {
    final items = priorityItems!;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      rows.add(
        _PriorityInboxRow(
          item: item,
          now: now,
          onTap: onPriorityTap == null ? null : () => onPriorityTap!(item),
          onLongPress: onPriorityLongPress == null
              ? null
              : () => onPriorityLongPress!(item),
        ),
      );
      if (i < items.length - 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Divider(height: 1, color: Colors.grey.shade200),
          ),
        );
      }
    }
    return rows;
  }
}

class _Header extends StatelessWidget {
  final String title;
  final int totalCount;
  final String totalLabel;
  final Color accentColor;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;

  const _Header({
    required this.title,
    required this.totalCount,
    required this.totalLabel,
    required this.accentColor,
    required this.onSeeAll,
    required this.seeAllLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                if (totalLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$totalCount $totalLabel',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            InkWell(
              onTap: onSeeAll,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seeAllLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: accentColor,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final PendingInboxEntry entry;

  const _InboxRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    // "Muted zero": when a worklist is empty, we still render the row but
    // soften the badge so the user perceives it as done.
    final isZero = entry.count == 0;
    final badgeColor = isZero ? Colors.grey.shade400 : entry.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: isZero ? 0.06 : 0.14),
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  entry.icon,
                  size: 16,
                  color: isZero ? Colors.grey.shade500 : entry.color,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        entry.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _CountBadge(count: entry.count, color: badgeColor),
              if (entry.onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Server-driven inbox row used by [PendingInboxCard.priorityItems].
///
/// Layout differs from the legacy [_InboxRow]:
///   • severity dot replaces the icon disc (more honest for
///     heterogeneous signal sources)
///   • subtitle is mandatory
///   • right edge: relative-time chip ("3 hari lalu") + optional
///     "·N" count chip when count > 1
///   • no chevron clutter when there's no tap handler
class _PriorityInboxRow extends StatelessWidget {
  final PriorityInboxItem item;
  final DateTime now;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _PriorityInboxRow({
    required this.item,
    required this.now,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.severity.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Severity dot — small disc on the left so the row
              // colour-codes at a glance.
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4, right: 12, left: 2),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.relativeTime(now),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (item.count > 1) ...[
                    const SizedBox(height: 4),
                    _CountBadge(count: item.count, color: accent),
                  ],
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _InboxEmptyState({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
