// Lifecycle-grouped announcement list for the admin Pengumuman screen
// (Mockup #10). Groups every page into Pinned / Terjadwal / Terkirim /
// Draft sections, drops a navy section header above each non-empty
// group, and keeps the existing infinite-scroll pagination.
//
// State pattern:
//   • parent owns the flat `announcements` list, loading flags, etc.
//   • this widget transforms the flat list into a `_FeedItem` stream
//     that interleaves [_HeaderItem] markers with the [_CardItem]s.
//   • PaginatedListView receives the flattened stream and dispatches
//     to the right builder based on the runtime type.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_card.dart';

/// Lifecycle stage of a single announcement record. Order matters —
/// the enum index controls the section order in the rendered list.
enum AnnouncementLifecycle { pinned, scheduled, sent, draft }

extension AnnouncementLifecycleLabel on AnnouncementLifecycle {
  String get label {
    switch (this) {
      case AnnouncementLifecycle.pinned:
        return 'Pinned';
      case AnnouncementLifecycle.scheduled:
        return 'Terjadwal';
      case AnnouncementLifecycle.sent:
        return 'Terkirim';
      case AnnouncementLifecycle.draft:
        return 'Draft';
    }
  }

  IconData get icon {
    switch (this) {
      case AnnouncementLifecycle.pinned:
        return Icons.push_pin_rounded;
      case AnnouncementLifecycle.scheduled:
        return Icons.schedule_rounded;
      case AnnouncementLifecycle.sent:
        return Icons.send_rounded;
      case AnnouncementLifecycle.draft:
        return Icons.edit_note_rounded;
    }
  }

  Color tone(Color admin) {
    switch (this) {
      case AnnouncementLifecycle.pinned:
        return const Color(0xFFB45309); // amber-700
      case AnnouncementLifecycle.scheduled:
        return const Color(0xFF6D28D9); // violet-700
      case AnnouncementLifecycle.sent:
        return admin;
      case AnnouncementLifecycle.draft:
        return ColorUtils.slate500;
    }
  }
}

/// Bucket [items] into the four ordered lifecycle groups.
///
/// Pinned wins above everything else (`is_pinned == true`). Otherwise
/// the row falls into one of three buckets based on its own metadata:
///   • `scheduled_at` future → Terjadwal
///   • `status == 'draft'`   → Draft
///   • everything else        → Terkirim
Map<AnnouncementLifecycle, List<Map<String, dynamic>>> bucketAnnouncements(
  List<Map<String, dynamic>> items,
) {
  final now = DateTime.now();
  final out = <AnnouncementLifecycle, List<Map<String, dynamic>>>{
    AnnouncementLifecycle.pinned: [],
    AnnouncementLifecycle.scheduled: [],
    AnnouncementLifecycle.sent: [],
    AnnouncementLifecycle.draft: [],
  };

  for (final raw in items) {
    final pinned = raw['is_pinned'] == true;
    if (pinned) {
      out[AnnouncementLifecycle.pinned]!.add(raw);
      continue;
    }

    final scheduledRaw = raw['scheduled_at']?.toString();
    final scheduled = scheduledRaw == null
        ? null
        : DateTime.tryParse(scheduledRaw);
    if (scheduled != null && scheduled.isAfter(now)) {
      out[AnnouncementLifecycle.scheduled]!.add(raw);
      continue;
    }

    final status = (raw['status'] ?? '').toString().toLowerCase();
    if (status == 'draft') {
      out[AnnouncementLifecycle.draft]!.add(raw);
      continue;
    }

    out[AnnouncementLifecycle.sent]!.add(raw);
  }

  return out;
}

/// Marker type for the synthetic feed list. Either a section header
/// (with stage + count) or a card (raw map).
sealed class _FeedItem {
  const _FeedItem();
}

class _HeaderItem extends _FeedItem {
  final AnnouncementLifecycle stage;
  final int count;
  const _HeaderItem(this.stage, this.count);
}

class _CardItem extends _FeedItem {
  final Map<String, dynamic> data;
  const _CardItem(this.data);
}

List<_FeedItem> _buildFeed(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return const [];
  final buckets = bucketAnnouncements(items);
  final feed = <_FeedItem>[];
  for (final stage in AnnouncementLifecycle.values) {
    final rows = buckets[stage]!;
    if (rows.isEmpty) continue;
    feed.add(_HeaderItem(stage, rows.length));
    for (final row in rows) {
      feed.add(_CardItem(row));
    }
  }
  return feed;
}

/// Drop-in replacement for [AnnouncementListContent] that adds
/// lifecycle section headers above each group of cards.
class AnnouncementGroupedList extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<dynamic> announcements;
  final bool isLoadingMore;
  final bool hasMoreData;
  final Color primaryColor;
  final ScrollController scrollController;
  final LanguageProvider languageProvider;
  final String searchText;
  final VoidCallback onRetry;
  final VoidCallback onCreateTap;
  final void Function(Map<String, dynamic>) onItemVisible;
  final String Function(String?) formatDate;
  final String Function(Map<String, dynamic>) getTargetText;
  final String importantLabel;
  final void Function(Map<String, dynamic>) onItemTap;
  final Set<String> selectedIds;
  final void Function(String) onToggleSelection;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;

  const AnnouncementGroupedList({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.announcements,
    required this.isLoadingMore,
    required this.hasMoreData,
    required this.primaryColor,
    required this.scrollController,
    required this.languageProvider,
    required this.searchText,
    required this.onRetry,
    required this.onCreateTap,
    required this.onItemVisible,
    required this.formatDate,
    required this.getTargetText,
    required this.importantLabel,
    required this.onItemTap,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return ErrorScreen(errorMessage: errorMessage!, onRetry: onRetry);
    }

    final feed = _buildFeed(announcements.cast<Map<String, dynamic>>());

    return PaginatedListView<_FeedItem>(
      items: feed,
      itemBuilder: (context, item, index) {
        if (item is _HeaderItem) {
          return _LifecycleSectionHeader(
            stage: item.stage,
            count: item.count,
            primaryColor: primaryColor,
          );
        }
        if (item is _CardItem) {
          final data = item.data;
          onItemVisible(data);
          return AnnouncementCard(
            announcementData: data,
            primaryColor: primaryColor,
            formattedDate: formatDate(data['created_at']?.toString()),
            targetText: getTargetText(data),
            importantLabel: importantLabel,
            isSelected: selectedIds.contains(data['id'].toString()),
            onTap: () => onItemTap(data),
            onLongPress: () => onToggleSelection(data['id'].toString()),
          );
        }
        return const SizedBox.shrink();
      },
      onLoadMore: onLoadMore,
      hasMore: hasMoreData,
      isLoadingMore: isLoadingMore,
      isInitialLoading: isLoading && announcements.isEmpty,
      loadingState: const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      ),
      emptyState: EmptyState(
        icon: Icons.announcement_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Announcements',
          'id': 'Tidak Ada Pengumuman',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': searchText.isNotEmpty
              ? 'No announcements found for your search'
              : 'Start creating announcements to share information',
          'id': searchText.isNotEmpty
              ? 'Tidak ada pengumuman yang sesuai dengan pencarian'
              : 'Mulai buat pengumuman untuk berbagi informasi',
        }),
        buttonText: languageProvider.getTranslatedText({
          'en': 'Create Announcement',
          'id': 'Buat Pengumuman',
        }),
        onPressed: onCreateTap,
      ),
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      onRefresh: onRefresh,
    );
  }
}

class _LifecycleSectionHeader extends StatelessWidget {
  final AnnouncementLifecycle stage;
  final int count;
  final Color primaryColor;

  const _LifecycleSectionHeader({
    required this.stage,
    required this.count,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final tone = stage.tone(primaryColor);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stage.icon, size: 14, color: tone),
          ),
          const SizedBox(width: 10),
          Text(
            stage.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: tone,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ),
          const Spacer(),
          Container(height: 1, width: 36, color: ColorUtils.slate200),
        ],
      ),
    );
  }
}
