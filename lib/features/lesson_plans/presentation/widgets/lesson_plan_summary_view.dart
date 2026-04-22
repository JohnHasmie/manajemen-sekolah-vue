// Grouped summary view for RPP list — groups by subject with inline preview.
// Redesigned to match kegiatan kelas pattern: compact card header,
// 2-3 latest items preview, "Lihat Semua" footer, no expand/collapse.
//
// Uses backend `/rpp/summary` API data for accurate total counts per subject
// and status, while still displaying individual items from the paginated list.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';

/// Groups RPP items by subject and displays a summary card per group.
/// Shows 2-3 latest RPPs inline, with "Lihat Semua" to expand full list.
///
/// [summaryData] comes from `GET /rpp/summary` — provides accurate counts.
/// [lessonPlans] is the paginated list used for preview items.
class LessonPlanSummaryView extends StatefulWidget {
  /// Backend summary data: list of { subject_id, subject_name, total, statuses }.
  final List<Map<String, dynamic>>? summaryData;

  /// Paginated lesson plan items — used for preview rows.
  final List<dynamic> lessonPlans;
  final Color primaryColor;
  final String Function(String status) statusLabel;
  final Color Function(String status) statusColor;
  final void Function(Map<String, dynamic> lp) onView;
  final void Function(Map<String, dynamic> lp) onEdit;
  final void Function(Map<String, dynamic> lp) onDelete;

  /// Called when a group is expanded and needs all its items.
  final Future<List<Map<String, dynamic>>> Function(String subjectId)?
      onLoadSubjectItems;

  const LessonPlanSummaryView({
    super.key,
    this.summaryData,
    required this.lessonPlans,
    required this.primaryColor,
    required this.statusLabel,
    required this.statusColor,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    this.onLoadSubjectItems,
  });

  @override
  State<LessonPlanSummaryView> createState() => _LessonPlanSummaryViewState();
}

class _LessonPlanSummaryViewState extends State<LessonPlanSummaryView> {
  /// Tracks which groups are fully expanded (showing all items).
  final Set<String> _expandedGroups = {};

  /// Caches fully-loaded items per subject ID after on-demand fetch.
  final Map<String, List<Map<String, dynamic>>> _loadedSubjectItems = {};

  /// Tracks which subjects are currently loading items.
  final Set<String> _loadingSubjects = {};

  /// Subject icon rotation for visual variety.
  static const _subjectIcons = [
    Icons.menu_book_rounded,
    Icons.science_rounded,
    Icons.calculate_rounded,
    Icons.language_rounded,
    Icons.public_rounded,
    Icons.palette_rounded,
    Icons.sports_soccer_rounded,
    Icons.computer_rounded,
  ];

  static const _subjectColors = [
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // emerald
    Color(0xFF8B5CF6), // violet
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF06B6D4), // cyan
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
  ];

  /// How many preview items to show before "Lihat Semua".
  static const _previewCount = 3;

  /// Index paginated items by subject name for quick lookup.
  Map<String, List<Map<String, dynamic>>> _buildItemsBySubject() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in widget.lessonPlans) {
      final lp = item as Map<String, dynamic>;
      final model = LessonPlan.fromJson(lp);
      final subject =
          (model.subjectName ?? '').isNotEmpty ? model.subjectName! : 'Lainnya';
      groups.putIfAbsent(subject, () => []).add(lp);
    }
    return groups;
  }

  /// Build groups from backend summary data, sorted alphabetically.
  List<_SummaryGroup> _buildSummaryGroups() {
    final itemsBySubject = _buildItemsBySubject();

    if (widget.summaryData != null && widget.summaryData!.isNotEmpty) {
      final groups = widget.summaryData!.map((entry) {
        final subjectId = entry['subject_id']?.toString() ?? '';
        final subjectName =
            (entry['subject_name'] as String?)?.isNotEmpty == true
                ? entry['subject_name'] as String
                : 'Lainnya';
        final total = (entry['total'] as int?) ?? 0;
        final rawStatuses = entry['statuses'];
        final statuses = <String, int>{};
        if (rawStatuses is Map) {
          for (final e in rawStatuses.entries) {
            statuses[e.key.toString()] = (e.value as int?) ?? 0;
          }
        }

        final items = _loadedSubjectItems[subjectId] ??
            itemsBySubject[subjectName] ??
            [];

        return _SummaryGroup(
          subjectId: subjectId,
          subjectName: subjectName,
          total: total,
          statusCounts: statuses,
          items: items,
        );
      }).toList();

      groups.sort((a, b) {
        if (a.subjectName == 'Lainnya') return 1;
        if (b.subjectName == 'Lainnya') return -1;
        return a.subjectName.compareTo(b.subjectName);
      });
      return groups;
    }

    // Fallback: client-side grouping
    final groups = <_SummaryGroup>[];
    final sortedKeys = itemsBySubject.keys.toList()
      ..sort((a, b) {
        if (a == 'Lainnya') return 1;
        if (b == 'Lainnya') return -1;
        return a.compareTo(b);
      });
    for (final subject in sortedKeys) {
      final items = itemsBySubject[subject]!;
      final statuses = <String, int>{};
      for (final item in items) {
        final status = LessonPlan.fromJson(item).status;
        final label = status.isNotEmpty ? status : 'draft';
        statuses[label] = (statuses[label] ?? 0) + 1;
      }
      groups.add(_SummaryGroup(
        subjectId: '',
        subjectName: subject,
        total: items.length,
        statusCounts: statuses,
        items: items,
      ));
    }
    return groups;
  }

  /// Expands a group to show all items (fetches if needed).
  void _expandGroup(_SummaryGroup group) {
    final name = group.subjectName;
    if (_expandedGroups.contains(name)) {
      setState(() => _expandedGroups.remove(name));
      return;
    }

    setState(() => _expandedGroups.add(name));

    final alreadyLoaded = _loadedSubjectItems.containsKey(group.subjectId);
    if (alreadyLoaded ||
        widget.onLoadSubjectItems == null ||
        group.subjectId.isEmpty) {
      return;
    }
    if (group.items.length >= group.total) return;

    _fetchSubjectItems(group.subjectId);
  }

  Future<void> _fetchSubjectItems(String subjectId) async {
    if (_loadingSubjects.contains(subjectId)) return;
    setState(() => _loadingSubjects.add(subjectId));

    try {
      final items = await widget.onLoadSubjectItems!(subjectId);
      if (mounted) {
        setState(() {
          _loadedSubjectItems[subjectId] = items;
          _loadingSubjects.remove(subjectId);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSubjects.remove(subjectId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildSummaryGroups();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 100, left: 16, right: 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isExpanded = _expandedGroups.contains(group.subjectName);
        final isLoading = _loadingSubjects.contains(group.subjectId);

        return _SubjectGroupCard(
          group: group,
          index: index,
          isExpanded: isExpanded,
          isLoadingItems: isLoading,
          previewCount: _previewCount,
          primaryColor: widget.primaryColor,
          statusLabel: widget.statusLabel,
          statusColor: widget.statusColor,
          subjectIcon: _subjectIcons[index % _subjectIcons.length],
          subjectColor: _subjectColors[index % _subjectColors.length],
          onExpand: () => _expandGroup(group),
          onView: widget.onView,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        );
      },
    );
  }
}

/// Internal model holding one subject group's summary + loaded items.
class _SummaryGroup {
  final String subjectId;
  final String subjectName;
  final int total;
  final Map<String, int> statusCounts;
  final List<Map<String, dynamic>> items;

  const _SummaryGroup({
    required this.subjectId,
    required this.subjectName,
    required this.total,
    required this.statusCounts,
    required this.items,
  });
}

/// Subject group card matching kegiatan kelas pattern: compact header,
/// status chips, 2-3 latest items preview, "Lihat Semua" footer.
class _SubjectGroupCard extends StatelessWidget {
  final _SummaryGroup group;
  final int index;
  final bool isExpanded;
  final bool isLoadingItems;
  final int previewCount;
  final Color primaryColor;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final IconData subjectIcon;
  final Color subjectColor;
  final VoidCallback onExpand;
  final void Function(Map<String, dynamic>) onView;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  const _SubjectGroupCard({
    required this.group,
    required this.index,
    required this.isExpanded,
    this.isLoadingItems = false,
    required this.previewCount,
    required this.primaryColor,
    required this.statusLabel,
    required this.statusColor,
    required this.subjectIcon,
    required this.subjectColor,
    required this.onExpand,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final previewItems =
        group.items.take(previewCount).toList();
    final allItems = group.items;
    final hasMore = group.total > previewCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + subject + count badge ──
          _buildHeader(),

          // ── Status chips ──
          if (group.statusCounts.isNotEmpty) _buildStatusChips(),

          // ── Preview / expanded items ──
          if (previewItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildItemsList(isExpanded ? allItems : previewItems),
          ],

          // ── Loading indicator ──
          if (isLoadingItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: subjectColor,
                  ),
                ),
              ),
            ),

          // ── Footer: "Lihat Semua" ──
          if (hasMore) _buildFooter(),

          if (!hasMore) const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Row(
        children: [
          // Subject icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: subjectColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(subjectIcon, size: 18, color: subjectColor),
          ),
          const SizedBox(width: 10),

          // Subject name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.subjectName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${group.total} RPP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: subjectColor,
                  ),
                ),
              ],
            ),
          ),

          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: subjectColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${group.total}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: subjectColor,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'RPP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: subjectColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips() {
    // Canonical order for status display
    const statusOrder = ['approved', 'draft', 'pending', 'rejected'];

    // Deduplicate Indonesian/English variants
    final merged = <String, int>{};
    for (final e in group.statusCounts.entries) {
      final key = e.key.toLowerCase();
      final canonical = switch (key) {
        'disetujui' || 'approved' => 'approved',
        'menunggu' || 'pending' => 'pending',
        'ditolak' || 'rejected' => 'rejected',
        _ => key,
      };
      merged[canonical] = (merged[canonical] ?? 0) + e.value;
    }

    final sorted = merged.entries.toList()
      ..sort((a, b) {
        final ai = statusOrder.indexOf(a.key);
        final bi = statusOrder.indexOf(b.key);
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: sorted.map((e) {
          final color = statusColor(e.key);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${e.value}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  statusLabel(e.key),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemsList(List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final lp = entry.value;
            final model = LessonPlan.fromJson(lp);
            final sColor = statusColor(model.status);
            final isLast = entry.key == items.length - 1;

            return InkWell(
              onTap: () => onView(lp),
              borderRadius: isLast && entry.key == 0
                  ? const BorderRadius.all(Radius.circular(10))
                  : entry.key == 0
                      ? const BorderRadius.vertical(
                          top: Radius.circular(10))
                      : isLast
                          ? const BorderRadius.vertical(
                              bottom: Radius.circular(10))
                          : BorderRadius.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: ColorUtils.slate200.withValues(alpha: 0.5),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    // Status dot
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color: sColor,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Title + date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            model.title.isNotEmpty
                                ? model.title
                                : 'Tanpa Judul',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: ColorUtils.slate700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if ((model.className ?? '').isNotEmpty) ...[
                                Text(
                                  model.className!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  child: Text(
                                    '·',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ColorUtils.slate300,
                                    ),
                                  ),
                                ),
                              ],
                              Text(
                                model.createdAtDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ColorUtils.slate400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sColor.withValues(alpha: 0.08),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                      ),
                      child: Text(
                        statusLabel(model.status),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: sColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return InkWell(
      onTap: onExpand,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            if (!isExpanded) ...[
              Icon(
                Icons.update_rounded,
                size: 13,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${group.total - previewCount} RPP lainnya',
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate400,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: subjectColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isExpanded ? 'Sembunyikan' : 'Lihat Semua',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subjectColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.chevron_right_rounded,
                    size: 14,
                    color: subjectColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
