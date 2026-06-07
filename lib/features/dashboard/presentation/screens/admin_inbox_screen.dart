// Perlu Perhatian — full-screen "Lihat Semua" inbox for the
// admin dashboard (Inbox B.5).
//
// Mirrors `TeacherInboxScreen` (GG.7) one-for-one in structure so the
// brand language stays consistent across roles. Differences:
//   * Hero kicker reads "Beranda · Admin" + navy gradient.
//   * Calls `DashboardService.getAdminPriorityInboxAll` (uncapped
//     admin variant — 9 admin aggregators fan out without a top-N
//     cap).
//   * Tap routing handed back to the caller via `onItemTap` so the
//     deep-link table lives on the dashboard body (single source).
//
// No snooze/dismiss store wiring yet — Phase 2 (parity with teacher
// GG.9) can land that once the admin path proves out in production.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';

/// Filter buckets — same shape as the teacher inbox.
enum _AdminInboxFilter { all, critical, warning, info }

extension on _AdminInboxFilter {
  String get label => switch (this) {
    _AdminInboxFilter.all => kDasFilterAll.tr,
    _AdminInboxFilter.critical => kDasFilterCritical.tr,
    _AdminInboxFilter.warning => kDasFilterWarning.tr,
    _AdminInboxFilter.info => kDasFilterInfo.tr,
  };

  bool matches(PriorityInboxItem item) => switch (this) {
    _AdminInboxFilter.all => true,
    _AdminInboxFilter.critical =>
      item.severity == PriorityInboxSeverity.critical,
    _AdminInboxFilter.warning => item.severity == PriorityInboxSeverity.warning,
    _AdminInboxFilter.info => item.severity == PriorityInboxSeverity.info,
  };
}

class AdminInboxScreen extends ConsumerStatefulWidget {
  /// Items the dashboard already has in memory (the capped list).
  /// Used as the optimistic first paint while the uncapped fetch
  /// runs in the background.
  final List<PriorityInboxItem>? initialItems;

  /// Tap routing — invoked when the admin taps a row. Caller owns
  /// the deep-link switch (same one used by the dashboard card).
  final void Function(PriorityInboxItem item) onItemTap;

  /// Academic-year scope. Defaults to "current" on the backend when null.
  final int? academicYearId;

  const AdminInboxScreen({
    super.key,
    required this.onItemTap,
    this.initialItems,
    this.academicYearId,
  });

  @override
  ConsumerState<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends ConsumerState<AdminInboxScreen>
    with AdminAcademicYearReloadMixin<AdminInboxScreen> {
  _AdminInboxFilter _filter = _AdminInboxFilter.all;
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

  /// Reload when the dashboard AY picker flips. The optimistic
  /// `initialItems` snapshot is for the old year, so we wipe it back
  /// to "loading" so admin doesn't briefly see stale data.
  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    setState(() {
      _items = const [];
      _isLoading = true;
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    // Prefer the live `currentAcademicYearId` from the mixin over the
    // widget param so the inbox follows the dashboard's selection
    // after the screen has opened. Fall back to the widget param when
    // the global picker hasn't selected anything yet (cold start).
    final ayId = currentAcademicYearId ?? widget.academicYearId?.toString();
    final raw = await DashboardService.getAdminPriorityInboxAll(
      academicYearId: ayId,
    );
    if (!mounted) return;
    setState(() {
      _items = PriorityInboxItem.parseList(raw);
      _isLoading = false;
    });
  }

  Map<_AdminInboxFilter, int> _countsOf(List<PriorityInboxItem> visible) {
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
      _AdminInboxFilter.all: visible.length,
      _AdminInboxFilter.critical: crit,
      _AdminInboxFilter.warning: warn,
      _AdminInboxFilter.info: info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items;
    final filtered = visible.where(_filter.matches).toList(growable: false);
    final counts = _countsOf(visible);
    final total = counts[_AdminInboxFilter.all] ?? 0;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _load,
        color: ColorUtils.brandDarkBlue,
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
                    kicker: kDasInboxNoItems.tr,
                    title: _filter == _AdminInboxFilter.all
                        ? kDasAllClear.tr
                        : kDasInboxCleanForFilter.tr,
                    message: _filter == _AdminInboxFilter.all
                        ? kDasInboxAdminNoAttention.tr
                        : kDasInboxTryOtherCategory.tr,
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
                      child: _AdminInboxRow(
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
    return BrandPageHeader(
      role: 'admin',
      subtitle: 'BERANDA · ADMIN',
      title: 'Perlu Perhatian',
      bottomSlot: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              total > 0 ? '$total ${kDasInboxItemsNeedAction.tr}' : kDasInboxNoItems.tr,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(Map<_AdminInboxFilter, int> counts) {
    const entries = _AdminInboxFilter.values;
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
                color: selected ? ColorUtils.brandDarkBlue : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? ColorUtils.brandDarkBlue
                      : ColorUtils.slate200,
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

/// One row in the admin inbox. Severity drives the left border + chip
/// colour. The label / subtitle / relativeTime come from the model.
class _AdminInboxRow extends StatelessWidget {
  final PriorityInboxItem item;
  final VoidCallback onTap;

  const _AdminInboxRow({required this.item, required this.onTap});

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
