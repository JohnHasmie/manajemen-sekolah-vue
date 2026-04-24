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

  /// Entries to render as rows. Order is respected.
  final List<PendingInboxEntry> entries;

  /// Called when the "Lihat semua" link in the header is tapped.
  final VoidCallback? onSeeAll;

  /// Label for the see-all link. Default: 'Lihat semua'.
  final String seeAllLabel;

  /// Suffix in the header summary, e.g., "14 total" → 'total'.
  /// Pass an empty string to hide the summary.
  final String totalLabel;

  /// Empty-state copy used when every entry has `count == 0`.
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
  });

  int get _total => entries.fold(0, (sum, e) => sum + e.count);

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final isEmpty = total == 0;

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
            totalCount: total,
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
