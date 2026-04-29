import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for content state UI (loading, error, empty, list).
mixin ContentStateMixin on ConsumerState<ParentAnnouncementScreen> {
  bool get isLoading;

  String? get errorMessage;

  Future<void> forceRefresh();

  Color getPrimaryColor();

  List<dynamic> get filteredAnnouncement;

  TextEditingController get searchController;

  GlobalKey? get listKey;

  void onItemVisible(Map<String, dynamic> announcement);

  Widget buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
    void Function(Map<String, dynamic>) onTap,
  );

  void showAnnouncementDetail(Map<String, dynamic> announcementData);

  Widget buildContent(LanguageProvider languageProvider) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (filteredAnnouncement.isEmpty) {
      return _buildEmptyState(languageProvider);
    }

    return _buildListContent();
  }

  Widget _buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 3,
      baseColor: getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: getPrimaryColor().withValues(alpha: 0.05),
      shrinkWrap: true,
    );
  }

  Widget _buildErrorState() {
    return ErrorScreen(errorMessage: errorMessage!, onRetry: forceRefresh);
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return EmptyState(
      icon: Icons.announcement_outlined,
      title: languageProvider.getTranslatedText({
        'en': 'No Announcements',
        'id': 'Tidak Ada Pengumuman',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': searchController.text.isNotEmpty
            ? 'No results'
            : 'No announcements',
        'id': searchController.text.isNotEmpty
            ? 'Tidak ada hasil'
            : 'Tidak ada pengumuman',
      }),
      buttonText: languageProvider.getTranslatedText({
        'en': 'Refresh',
        'id': 'Muat Ulang',
      }),
      onPressed: forceRefresh,
    );
  }

  Widget _buildListContent() {
    // Group announcements by month for section-header rendering — matches
    // the teacher version (T11) which already groups by month with priority
    // counts. P0 #10 from UI_Redesign_Audit.md: parent was a flat list.
    final grouped = _groupByMonth(filteredAnnouncement);

    // The parent screen now wraps body in an outer ListView so the
    // gradient hero scrolls with content. shrinkWrap + Never-
    // ScrollableScrollPhysics let this inner list size to its
    // content and defer scrolling to the outer list — and the
    // RefreshIndicator now lives one level up in the screen.
    return ListView.builder(
        key: listKey,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped[index];
          if (entry is _MonthSectionHeader) {
            return _buildMonthHeader(entry.label, entry.count);
          }
          final item = (entry as _MonthAnnouncementItem).announcement;
          return Builder(
            builder: (context) {
              onItemVisible(item);
              // Original list-index isn't preserved across grouping; pass 0
              // since downstream usage is cosmetic (animation stagger only).
              return buildAnnouncementCard(item, 0, showAnnouncementDetail);
            },
          );
        },
      );
  }

  /// Walks [items] and emits an interleaved list of section headers + cards.
  /// Section header format: "MMMM yyyy" in Indonesian (e.g. "April 2026"),
  /// with the count of items in that month.
  List<_MonthListEntry> _groupByMonth(List<dynamic> items) {
    if (items.isEmpty) return const [];
    const monthsId = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    final byMonth = <String, List<Map<String, dynamic>>>{};
    final monthOrder = <String>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final dateStr = (map['created_at'] ?? map['tanggal'] ?? map['date'])
          ?.toString();
      String key;
      if (dateStr == null || dateStr.isEmpty) {
        key = 'Lainnya';
      } else {
        final dt = DateTime.tryParse(dateStr);
        key = dt == null
            ? 'Lainnya'
            : '${monthsId[dt.month - 1]} ${dt.year}';
      }
      if (!byMonth.containsKey(key)) {
        monthOrder.add(key);
      }
      (byMonth[key] ??= []).add(map);
    }

    final result = <_MonthListEntry>[];
    for (final month in monthOrder) {
      final bucket = byMonth[month]!;
      result.add(_MonthSectionHeader(label: month, count: bucket.length));
      for (final item in bucket) {
        result.add(_MonthAnnouncementItem(item));
      }
    }
    return result;
  }

  Widget _buildMonthHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tagged union for the interleaved month-grouped list.
sealed class _MonthListEntry {
  const _MonthListEntry();
}

class _MonthSectionHeader extends _MonthListEntry {
  final String label;
  final int count;
  const _MonthSectionHeader({required this.label, required this.count});
}

class _MonthAnnouncementItem extends _MonthListEntry {
  final Map<String, dynamic> announcement;
  const _MonthAnnouncementItem(this.announcement);
}
