// Perlu Perhatian — full-screen "Lihat Semua" inbox for the
// teacher dashboard (Phase 2 / GG.7).
//
// Reached from the "Lihat semua" link on the teacher dashboard's
// Perlu Perhatian card. Lists every priority-inbox row the
// backend would otherwise cap at 5, grouped by date and filterable
// by severity.
//
// Key design choices (deltas vs the parent inbox screen):
//   • Filter chips are SEVERITY buckets (Semua / Kritis /
//     Peringatan / Info) — the teacher's actionable items are
//     dominated by severity, not type, so this is the more useful
//     dimension to slice on.
//   • Date groups: HARI INI / KEMARIN / MINGGU INI / LEBIH LAMA.
//     Matches the parent inbox's groupings so brand language stays
//     consistent.
//   • Cobalt brand colour (matches the dashboard's teacher tokens)
//     not azure (parent) or dark-blue (admin).
//   • Navigation: this screen does NOT contain the per-route push
//     logic. The caller passes `onItemTap` which the dashboard
//     hooks into `_navigateToInboxTarget` so we don't duplicate
//     getIt/ref.read/teacherPayload lookups across two screens.
//
// Backend: GET /api/dashboard/teacher-priority-inbox
// Returns `{ success, data: [PriorityInboxItem...] }` — full list
// (no top-5 cap; see `TeacherPriorityInboxService::uncapped()`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/features/dashboard/data/dashboard_service.dart';
import 'package:manajemensekolah/features/dashboard/data/priority_inbox_snooze_store.dart';
import 'package:manajemensekolah/features/dashboard/domain/models/priority_inbox_item.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/priority_inbox_snooze_sheet.dart';

/// Filter buckets the screen exposes. Maps 1:1 onto
/// [PriorityInboxSeverity] with an `all` shortcut.
enum _InboxFilter { all, critical, warning, info }

extension on _InboxFilter {
  String get label => switch (this) {
    _InboxFilter.all => 'Semua',
    _InboxFilter.critical => 'Kritis',
    _InboxFilter.warning => 'Peringatan',
    _InboxFilter.info => 'Info',
  };

  bool matches(PriorityInboxItem item) => switch (this) {
    _InboxFilter.all => true,
    _InboxFilter.critical => item.severity == PriorityInboxSeverity.critical,
    _InboxFilter.warning => item.severity == PriorityInboxSeverity.warning,
    _InboxFilter.info => item.severity == PriorityInboxSeverity.info,
  };
}

class TeacherInboxScreen extends ConsumerStatefulWidget {
  /// Optional initial items — if the dashboard already has the
  /// (capped) priority_inbox in memory it can pass them here so the
  /// screen renders instantly instead of flashing the spinner. The
  /// uncapped fetch still runs in the background and replaces the
  /// list when it lands.
  final List<PriorityInboxItem>? initialItems;

  /// Navigation handler — invoked when the teacher taps a row.
  /// Same closed enum as the dashboard's `_navigateToInboxTarget`.
  /// Caller is responsible for the per-route push + mark-as-seen
  /// fire-and-forget.
  final void Function(PriorityInboxItem item) onItemTap;

  /// Academic-year scope. Defaults to "current" on the backend
  /// when null.
  final int? academicYearId;

  const TeacherInboxScreen({
    super.key,
    required this.onItemTap,
    this.initialItems,
    this.academicYearId,
  });

  @override
  ConsumerState<TeacherInboxScreen> createState() => _TeacherInboxScreenState();
}

class _TeacherInboxScreenState extends ConsumerState<TeacherInboxScreen> {
  _InboxFilter _filter = _InboxFilter.all;
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
    final raw = await DashboardService.getTeacherPriorityInbox(
      academicYearId: widget.academicYearId?.toString(),
    );
    if (!mounted) return;
    setState(() {
      _items = PriorityInboxItem.parseList(raw);
      _isLoading = false;
    });
  }

  /// GG.9 — long-press handler. Opens the snooze sheet; on confirm
  /// the store hides the row and we [setState] to re-run the
  /// snooze filter at the top of [build]. The fetch isn't re-run
  /// — the row is purely a render-time decision.
  Future<void> _snooze(PriorityInboxItem item) async {
    final didSnooze = await showPriorityInboxSnoozeSheet(
      context: context,
      item: item,
    );
    if (didSnooze == true && mounted) {
      setState(() {});
    }
  }

  /// Per-severity counts driving the filter-chip badges. Computed
  /// off the visible (post-snooze, pre-filter-chip) list so chip
  /// badges stay stable as the user toggles severity filters but
  /// shrink when they snooze a row.
  Map<_InboxFilter, int> _countsOf(List<PriorityInboxItem> visible) {
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
      _InboxFilter.all: visible.length,
      _InboxFilter.critical: crit,
      _InboxFilter.warning: warn,
      _InboxFilter.info: info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = PriorityInboxSnoozeStore.instance;
    final now = DateTime.now();
    final visible = _items
        .where((it) => !store.isSnoozed(it.id, now: now))
        .toList(growable: false);
    final filtered = visible.where(_filter.matches).toList(growable: false);
    final groups = _groupByDate(filtered);
    final counts = _countsOf(visible);
    final total = counts[_InboxFilter.all] ?? 0;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: AppRefreshIndicator(
        onRefresh: _load,
        color: ColorUtils.brandCobalt,
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
                    title: _filter == _InboxFilter.all
                        ? 'Semua aman 🎉'
                        : 'Bersih untuk filter ini',
                    message: _filter == _InboxFilter.all
                        ? 'Tidak ada hal yang perlu perhatian Anda saat ini.'
                        : 'Coba kategori lain untuk melihat item lainnya.',
                  ),
                ),
              )
            else
              ..._buildSliverGroups(groups),
            const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
      ),
    );
  }

  // ─────────────── pieces ───────────────

  Widget _buildHero(int total) {
    final statusBar = MediaQuery.of(context).viewPadding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandDarkBlue, ColorUtils.brandAzure],
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
          Row(
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
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Beranda · Guru',
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

  Widget _buildFilterChips(Map<_InboxFilter, int> counts) {
    final entries = _InboxFilter.values;
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
        itemBuilder: (_, i) {
          final f = entries[i];
          return _FilterChip(
            label: f.label,
            count: counts[f] ?? 0,
            active: f == _filter,
            onTap: () {
              if (f == _filter) return;
              setState(() => _filter = f);
            },
          );
        },
      ),
    );
  }

  /// Group items into HARI INI / KEMARIN / MINGGU INI / LEBIH LAMA
  /// using `occurredAt`. Empty buckets are dropped so the UI doesn't
  /// render dead headers.
  Map<String, List<PriorityInboxItem>> _groupByDate(
    List<PriorityInboxItem> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 7));

    final groups = <String, List<PriorityInboxItem>>{
      'HARI INI': [],
      'KEMARIN': [],
      'MINGGU INI': [],
      'LEBIH LAMA': [],
    };

    for (final item in items) {
      final d = DateTime(
        item.occurredAt.year,
        item.occurredAt.month,
        item.occurredAt.day,
      );
      if (d == today) {
        groups['HARI INI']!.add(item);
      } else if (d == yesterday) {
        groups['KEMARIN']!.add(item);
      } else if (d.isAfter(weekStart)) {
        groups['MINGGU INI']!.add(item);
      } else {
        groups['LEBIH LAMA']!.add(item);
      }
    }

    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  List<Widget> _buildSliverGroups(Map<String, List<PriorityInboxItem>> groups) {
    final out = <Widget>[];
    final now = DateTime.now();
    groups.forEach((label, items) {
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate500,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      );
      out.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _InboxRow(
                item: items[i],
                now: now,
                onTap: () => widget.onItemTap(items[i]),
                onLongPress: () => _snooze(items[i]),
              ),
            ),
            childCount: items.length,
          ),
        ),
      );
    });
    return out;
  }
}

// ════════════════════════════════════════════════════════════════════
//  Row + chip
// ════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? ColorUtils.brandCobalt : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: active
                ? null
                : Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : ColorUtils.slate600,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white.withValues(alpha: 0.7)
                        : ColorUtils.slate400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final PriorityInboxItem item;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _InboxRow({
    required this.item,
    required this.now,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = item.severity.color;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.severity == PriorityInboxSeverity.critical
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFE2E8F0),
              width: item.severity == PriorityInboxSeverity.critical ? 1 : 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity dot — mirrors the dashboard card row so
              // the affordance reads as "same thing, more of it".
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5, right: 12, left: 2),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.relativeTime(now),
                    style: TextStyle(fontSize: 9.5, color: ColorUtils.slate400),
                  ),
                  if (item.count > 1) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '·${item.count}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
