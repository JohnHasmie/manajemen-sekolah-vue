// Perlu Perhatian — full-screen "Lihat Semua" inbox for the
// parent dashboard (Inbox C.5).
//
// Mirrors `AdminInboxScreen` (B.5) one-for-one so the brand language
// stays consistent across roles. Differences:
//   * Hero kicker reads "Beranda · Wali" + parent azure gradient.
//   * Calls `DashboardService.getParentPriorityInboxAll` (uncapped
//     parent variant — 10 parent aggregators fan out across every
//     child the wali is responsible for, without a top-N cap).
//   * Tap routing handed back to the caller via `onItemTap` so the
//     deep-link table lives on the dashboard body (single source).
//
// Snooze/dismiss isn't wired yet — same as the admin path. Phase 2
// can land that once the parent surface proves out.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';

/// Filter buckets — same shape as the admin / teacher inbox.
enum _ParentInboxFilter { all, critical, warning, info }

extension on _ParentInboxFilter {
  String get label => switch (this) {
    _ParentInboxFilter.all => 'Semua',
    _ParentInboxFilter.critical => 'Kritis',
    _ParentInboxFilter.warning => 'Peringatan',
    _ParentInboxFilter.info => 'Info',
  };

  bool matches(PriorityInboxItem item) => switch (this) {
    _ParentInboxFilter.all => true,
    _ParentInboxFilter.critical =>
      item.severity == PriorityInboxSeverity.critical,
    _ParentInboxFilter.warning =>
      item.severity == PriorityInboxSeverity.warning,
    _ParentInboxFilter.info => item.severity == PriorityInboxSeverity.info,
  };
}

class ParentPriorityInboxScreen extends ConsumerStatefulWidget {
  /// Items the dashboard already has in memory (the capped list).
  /// Used as the optimistic first paint while the uncapped fetch
  /// runs in the background.
  final List<PriorityInboxItem>? initialItems;

  /// Tap routing — invoked when the parent taps a row. Caller owns
  /// the deep-link switch (same one used by the dashboard card).
  final void Function(PriorityInboxItem item) onItemTap;

  /// Optional child scope — when set, restricts the inbox to one
  /// child. Omit to fan out across every child the wali manages.
  final String? studentId;

  /// Academic-year scope. Defaults to "current" on the backend when null.
  final String? academicYearId;

  const ParentPriorityInboxScreen({
    super.key,
    required this.onItemTap,
    this.initialItems,
    this.studentId,
    this.academicYearId,
  });

  @override
  ConsumerState<ParentPriorityInboxScreen> createState() =>
      _ParentPriorityInboxScreenState();
}

class _ParentPriorityInboxScreenState
    extends ConsumerState<ParentPriorityInboxScreen> {
  _ParentInboxFilter _filter = _ParentInboxFilter.all;
  List<PriorityInboxItem> _items = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      _items = widget.initialItems!;
      _isLoading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final raw = await DashboardService.getParentPriorityInboxAll(
      studentId: widget.studentId,
      academicYearId: widget.academicYearId,
    );
    if (!mounted) return;
    setState(() {
      _items = PriorityInboxItem.parseList(raw);
      _isLoading = false;
    });
  }

  Map<_ParentInboxFilter, int> _countsOf(List<PriorityInboxItem> visible) {
    int crit = 0, warn = 0, info = 0;
    for (final it in visible) {
      switch (it.severity) {
        case PriorityInboxSeverity.critical:
          crit++;
          break;
        case PriorityInboxSeverity.warning:
          warn++;
          break;
        case PriorityInboxSeverity.info:
          info++;
          break;
      }
    }
    return {
      _ParentInboxFilter.all: visible.length,
      _ParentInboxFilter.critical: crit,
      _ParentInboxFilter.warning: warn,
      _ParentInboxFilter.info: info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items;
    final filtered = visible.where(_filter.matches).toList(growable: false);
    final counts = _countsOf(visible);
    final total = counts[_ParentInboxFilter.all] ?? 0;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _load,
        color: ColorUtils.brandAzure,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(total)),
            SliverToBoxAdapter(child: _buildFilterChips(counts)),
            if (_isLoading && _items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: BrandEmptyState(
                    icon: Icons.inbox_outlined,
                    tone: BrandEmptyStateTone.info,
                    kicker: 'Tidak ada item',
                    title: _filter == _ParentInboxFilter.all
                        ? 'Semua aman 🎉'
                        : 'Bersih untuk filter ini',
                    message: _filter == _ParentInboxFilter.all
                        ? 'Tidak ada hal yang perlu perhatian saat ini.'
                        : 'Coba kategori lain untuk melihat item lainnya.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final item = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ParentInboxRow(
                        item: item,
                        onTap: () {
                          // Pop the screen first so the deep-link
                          // navigation happens from the dashboard
                          // route context (cleaner back-stack than
                          // pushing on top of the inbox).
                          AppNavigator.pop(context);
                          widget.onItemTap(item);
                        },
                      ),
                    );
                  }, childCount: filtered.length),
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(int total) {
    final statusBar = MediaQuery.of(context).viewPadding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandAzure, ColorUtils.brandAzureDeep],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        statusBar + AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => AppNavigator.pop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Beranda · Wali',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Perlu Perhatian',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              total > 0 ? '$total item perlu tindak lanjut' : 'Tidak ada item',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Map<_ParentInboxFilter, int> counts) {
    const entries = _ParentInboxFilter.values;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final e = entries[i];
          final selected = e == _filter;
          final count = counts[e] ?? 0;
          return GestureDetector(
            onTap: () => setState(() => _filter = e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? ColorUtils.brandAzure : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? ColorUtils.brandAzure : ColorUtils.slate200,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : ColorUtils.slate700,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.22)
                            : ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : ColorUtils.slate700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Row
// ─────────────────────────────────────────────────────────────────────

/// One row in the parent inbox. Severity drives the left border + chip
/// colour. The label / subtitle / relativeTime come from the model.
class _ParentInboxRow extends StatelessWidget {
  final PriorityInboxItem item;
  final VoidCallback onTap;

  const _ParentInboxRow({required this.item, required this.onTap});

  Color _severityColor() => switch (item.severity) {
    PriorityInboxSeverity.critical => ColorUtils.error600,
    PriorityInboxSeverity.warning => ColorUtils.warning600,
    PriorityInboxSeverity.info => ColorUtils.info600,
  };

  String _severityLabel() => switch (item.severity) {
    PriorityInboxSeverity.critical => 'KRITIS',
    PriorityInboxSeverity.warning => 'PERINGATAN',
    PriorityInboxSeverity.info => 'INFO',
  };

  @override
  Widget build(BuildContext context) {
    final color = _severityColor();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 4)),
            boxShadow: [
              BoxShadow(
                color: ColorUtils.slate900.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _severityLabel(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.relativeTime(DateTime.now()),
                          style: TextStyle(
                            fontSize: 10,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (item.count > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: ColorUtils.slate400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
