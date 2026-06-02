// Summary view for announcements grouped by month with sticky headers.
// Always expanded — items are shown directly under each month header.
// Uses `flutter_sticky_header` for pinned month labels (same pattern as
// TeacherScheduleCardView).
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';

/// Displays announcements grouped by month with sticky month headers.
/// All groups are always expanded (no collapse toggle).
class AnnouncementSummaryView extends StatefulWidget {
  final List<Map<String, dynamic>>? summaryData;
  final List<dynamic> announcements;
  final Color primaryColor;
  final String Function(String priority) priorityLabel;
  final Color Function(String priority) priorityColor;
  final void Function(Map<String, dynamic> item) onView;
  final Future<List<Map<String, dynamic>>> Function(String monthKey)?
  onLoadMonthItems;

  const AnnouncementSummaryView({
    super.key,
    this.summaryData,
    required this.announcements,
    required this.primaryColor,
    required this.priorityLabel,
    required this.priorityColor,
    required this.onView,
    this.onLoadMonthItems,
  });

  @override
  State<AnnouncementSummaryView> createState() =>
      _AnnouncementSummaryViewState();
}

class _AnnouncementSummaryViewState extends State<AnnouncementSummaryView> {
  final Map<String, List<Map<String, dynamic>>> _loadedItems = {};
  final Set<String> _loadingMonths = {};
  final Set<String> _fetchedMonths = {};

  /// Group paginated items by month key for fallback / initial display.
  Map<String, List<Map<String, dynamic>>> _buildItemsByMonth() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in widget.announcements) {
      final lp = item as Map<String, dynamic>;
      final createdAt = lp['created_at']?.toString() ?? '';
      final monthKey = createdAt.length >= 7
          ? createdAt.substring(0, 7)
          : 'unknown';
      groups.putIfAbsent(monthKey, () => []).add(lp);
    }
    return groups;
  }

  List<_MonthGroup> _buildGroups() {
    final itemsByMonth = _buildItemsByMonth();

    if (widget.summaryData != null && widget.summaryData!.isNotEmpty) {
      final groups = widget.summaryData!.map((entry) {
        final monthKey = entry['month_key']?.toString() ?? 'unknown';
        final total = (entry['total'] as int?) ?? 0;
        final rawPriorities = entry['priorities'];
        final priorities = <String, int>{};
        if (rawPriorities is Map) {
          for (final e in rawPriorities.entries) {
            priorities[e.key.toString()] = (e.value as int?) ?? 0;
          }
        }
        return _MonthGroup(
          monthKey: monthKey,
          total: total,
          priorities: priorities,
          items: _loadedItems[monthKey] ?? itemsByMonth[monthKey] ?? [],
        );
      }).toList();

      return groups;
    }

    // Fallback: client-side grouping
    final groups = <_MonthGroup>[];
    final sortedKeys = itemsByMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final monthKey in sortedKeys) {
      final items = itemsByMonth[monthKey]!;
      final priorities = <String, int>{};
      for (final item in items) {
        // Backend canonical: `low` / `normal` / `high` / `urgent`
        // (was `biasa` / `penting`). Default to `normal`.
        final p = (item['priority'] ?? 'normal').toString().toLowerCase();
        priorities[p] = (priorities[p] ?? 0) + 1;
      }
      groups.add(
        _MonthGroup(
          monthKey: monthKey,
          total: items.length,
          priorities: priorities,
          items: items,
        ),
      );
    }
    return groups;
  }

  /// Auto-fetch all items for a month when its items are incomplete.
  void _ensureMonthLoaded(_MonthGroup group) {
    final key = group.monthKey;
    if (_fetchedMonths.contains(key) ||
        _loadingMonths.contains(key) ||
        widget.onLoadMonthItems == null) {
      return;
    }
    if (group.items.length >= group.total) {
      _fetchedMonths.add(key);
      return;
    }
    _fetchMonthItems(key);
  }

  Future<void> _fetchMonthItems(String monthKey) async {
    if (_loadingMonths.contains(monthKey)) return;
    setState(() => _loadingMonths.add(monthKey));

    try {
      final items = await widget.onLoadMonthItems!(monthKey);
      if (mounted) {
        setState(() {
          _loadedItems[monthKey] = items;
          _loadingMonths.remove(monthKey);
          _fetchedMonths.add(monthKey);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingMonths.remove(monthKey);
          _fetchedMonths.add(monthKey);
        });
      }
    }
  }

  String _formatMonthLabel(String monthKey) {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final date = DateTime(year, month);
      return DateFormat('MMMM yyyy', 'id').format(date);
    } catch (_) {
      return monthKey;
    }
  }

  bool _isCurrentMonth(String monthKey) {
    final now = DateTime.now();
    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return monthKey == currentKey;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups();

    // Trigger loading for all groups that need it
    for (final group in groups) {
      _ensureMonthLoaded(group);
    }

    final slivers = <Widget>[
      const SliverPadding(padding: EdgeInsets.only(top: 4)),
    ];

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      final isLoading = _loadingMonths.contains(group.monthKey);
      final isCurrent = _isCurrentMonth(group.monthKey);

      slivers.add(
        SliverStickyHeader(
          sticky: true,
          header: Container(
            color: ColorUtils.slate50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _MonthHeader(
              monthLabel: _formatMonthLabel(group.monthKey),
              total: group.total,
              priorities: group.priorities,
              isCurrent: isCurrent,
              primaryColor: widget.primaryColor,
              priorityLabel: widget.priorityLabel,
              priorityColor: widget.priorityColor,
            ),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              _buildItemsForGroup(group, isLoading),
            ),
          ),
        ),
      );
    }

    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 100)));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
  }

  List<Widget> _buildItemsForGroup(_MonthGroup group, bool isLoading) {
    final widgets = <Widget>[];

    if (isLoading && group.items.isEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.primaryColor,
              ),
            ),
          ),
        ),
      );
      return widgets;
    }

    for (int i = 0; i < group.items.length; i++) {
      final item = group.items[i];
      final isLast = i == group.items.length - 1 && !isLoading;
      widgets.add(
        _AnnouncementItemCard(
          item: item,
          isLast: isLast,
          primaryColor: widget.primaryColor,
          onTap: () => widget.onView(item),
        ),
      );
    }

    if (isLoading && group.items.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.primaryColor,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

class _MonthGroup {
  final String monthKey;
  final int total;
  final Map<String, int> priorities;
  final List<Map<String, dynamic>> items;

  const _MonthGroup({
    required this.monthKey,
    required this.total,
    required this.priorities,
    required this.items,
  });
}

/// Sticky month header with icon, label, count badge, and priority chips.
class _MonthHeader extends StatelessWidget {
  final String monthLabel;
  final int total;
  final Map<String, int> priorities;
  final bool isCurrent;
  final Color primaryColor;
  final String Function(String) priorityLabel;
  final Color Function(String) priorityColor;

  const _MonthHeader({
    required this.monthLabel,
    required this.total,
    required this.priorities,
    required this.isCurrent,
    required this.primaryColor,
    required this.priorityLabel,
    required this.priorityColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(
          color: isCurrent ? color.withValues(alpha: 0.3) : ColorUtils.slate200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCurrent ? Icons.today_rounded : Icons.calendar_month_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            monthLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: Text(
                'Bulan Ini',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
          const Spacer(),
          // Priority chips (compact)
          ...priorities.entries.map((e) {
            final c = priorityColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Total count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Text(
              '$total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single announcement card within a month group.
class _AnnouncementItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AnnouncementItemCard({
    required this.item,
    required this.isLast,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final model = Announcement.fromJson(item);
    // Backend canonical priorities: `low` / `normal` / `high` / `urgent`.
    // Legacy: `biasa` → normal, `penting` → high.
    final isImportant = [
      'high',
      'urgent',
      'penting',
      'important',
    ].contains((item['priority'] ?? '').toString().toLowerCase());
    final accentColor = isImportant ? ColorUtils.warning600 : primaryColor;
    final isUnread = !model.isRead;

    String dateStr = '';
    try {
      final date = DateTime.parse(item['created_at']?.toString() ?? '');
      dateStr = DateFormat('d MMM', 'id').format(date);
    } catch (_) {
      dateStr = '';
    }

    final roleTarget = (item['role_target'] ?? '').toString().toLowerCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          child: InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(10)),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Left accent bar
                    Container(
                      width: 3.5,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10),
                        ),
                      ),
                    ),

                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row + unread dot
                            Row(
                              children: [
                                if (isUnread)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.error600,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    model.title.isNotEmpty
                                        ? model.title
                                        : 'Tanpa Judul',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: ColorUtils.slate800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isImportant)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      'Penting',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtils.warning600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Content preview
                            if (model.content.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                model.content,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate500,
                                  height: 1.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 6),

                            // Meta row: date · target
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_outlined,
                                  size: 11,
                                  color: ColorUtils.slate400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.people_outline,
                                  size: 11,
                                  color: ColorUtils.slate400,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _getTargetLabel(roleTarget),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Chevron
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: ColorUtils.slate300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTargetLabel(String roleTarget) {
    switch (roleTarget) {
      case 'all':
        return 'Semua';
      case 'teacher':
      case 'guru':
        return 'Guru';
      case 'student':
      case 'siswa':
        return 'Siswa';
      case 'wali':
      case 'orang_tua':
        return 'Wali Murid';
      default:
        return roleTarget;
    }
  }
}
