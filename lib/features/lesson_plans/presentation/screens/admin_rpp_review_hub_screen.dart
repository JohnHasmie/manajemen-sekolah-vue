// Admin RPP review hub — Mockup #09 with shared brand components.
//
// Uses BrandPageHeader + BrandPageLayout (same pattern as parent role
// screens) so the hero, pull-to-refresh, and KPI overlay are
// consistent across all admin surfaces.
//
// Layout:
//   1. BrandPageHeader with kicker "Akademik · Pembelajaran", title
//      "RPP", filter chips in bottomSlot.
//   2. KPI overlay: 3 QueueCountTiles (Perlu Review / Disetujui /
//      Ditolak) overlapping the hero gradient.
//   3. Body: ReviewQueueColumn with tier sections.
//   4. Pull-to-refresh via BrandPageLayout.onRefresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_lesson_plan_components.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/lesson_plans/data/admin_lesson_plan_queue_service.dart';

class AdminRppReviewHubScreen extends ConsumerStatefulWidget {
  const AdminRppReviewHubScreen({super.key});

  @override
  ConsumerState<AdminRppReviewHubScreen> createState() =>
      _AdminRppReviewHubScreenState();
}

class _AdminRppReviewHubScreenState
    extends ConsumerState<AdminRppReviewHubScreen> {
  /// Active status filter — null = show all.
  String? _statusFilter;

  Future<void> _refresh() async {
    ref.invalidate(adminLessonPlanQueueProvider);
    // Wait for the provider to settle so the refresh
    // indicator finishes only after data arrives.
    await ref.read(adminLessonPlanQueueProvider.future);
  }

  void _setStatusFilter(String? key) {
    setState(() {
      _statusFilter = (_statusFilter == key) ? null : key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminLessonPlanQueueProvider);
    final queue = async.maybeWhen(data: (q) => q, orElse: () => null);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: _refresh,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: 'Akademik · Pembelajaran',
          title: 'RPP',
          // Matches the rule baked into BrandPageLayout — header
          // reserves overlap space below the chip strip so the KPI's
          // overlap zone tucks into navy instead of covering chips.
          kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
          actionIcons: [
            BrandHeaderIconButton(
              icon: Icons.tune_rounded,
              onTap: () => _showStatusSheet(context),
              badgeCount: _statusFilter != null ? 1 : null,
            ),
          ],
          // Filter chip strip — matches parent role pattern
          // (parent_billing_screen): one BrandFilterChip whose `value`
          // reflects the active status. Tapping the chip OR the tune
          // icon opens the same status sheet.
          bottomSlot: BrandFilterChipStrip(
            chips: [
              BrandFilterChip(
                label: 'Status',
                value: _statusFilter == null
                    ? null
                    : _filterLabel(_statusFilter!),
                onTap: () => _showStatusSheet(context),
              ),
            ],
          ),
        ),
        kpiCard: _buildKpiStrip(queue),
        bodyChildren: [
          const SizedBox(height: AppSpacing.md),
          _buildBody(context, async),
          SizedBox(
            height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  // ── KPI strip (white card, same as parent role) ──

  Widget _buildKpiStrip(AdminLessonPlanQueue? q) {
    final pending = q?.tierByKey('pending');
    final approved = q?.tierByKey('approved');
    final rejected = q?.tierByKey('rejected');

    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: 'Perlu Review',
          value: '${pending?.totalCount ?? 0}',
          valueColor: const Color(0xFFF59E0B),
          sub: pending?.deltaLabel,
        ),
        BrandKpiColumn(
          label: 'Disetujui',
          value: '${approved?.totalCount ?? 0}',
          valueColor: const Color(0xFF10B981),
          sub: approved?.deltaLabel,
        ),
        BrandKpiColumn(
          label: 'Ditolak',
          value: '${rejected?.totalCount ?? 0}',
          valueColor: const Color(0xFFDC2626),
          sub: rejected?.deltaLabel,
        ),
      ],
    );
  }

  // ── Body ──

  Widget _buildBody(
    BuildContext context,
    AsyncValue<AdminLessonPlanQueue> async,
  ) {
    return async.when(
      data: (q) => _buildQueue(context, q),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(
              'Gagal memuat: $e',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _refresh, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }

  Widget _buildQueue(BuildContext context, AdminLessonPlanQueue queue) {
    // Filter tiers by status if a filter is active.
    var tiers = queue.tiers;
    if (_statusFilter != null) {
      tiers = tiers.where((t) => t.key == _statusFilter).toList();
    }

    if (tiers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            _statusFilter != null
                ? 'Tidak ada RPP dengan status '
                      '"${_filterLabel(_statusFilter!)}"'
                : 'Belum ada RPP.',
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
          ),
        ),
      );
    }

    final rendered = tiers.map((t) {
      final cards = t.items.take(t.key == 'approved' ? 3 : 5).map((item) {
        return SwipeableQueueCard(
          subtitle: item.subtitle,
          title: item.title,
          tone: t.tone,
          rejectionReason: item.rejectionReason,
          meta: [
            _StatusPill(label: item.status, tone: t.tone),
            if (item.updatedAtHuman != null)
              Text(
                item.updatedAtHuman!,
                style: TextStyle(fontSize: 10.5, color: ColorUtils.slate500),
              ),
          ],
          footer: item.teacherName,
          onTap: () => SnackBarUtils.showInfo(
            context,
            'Detail RPP akan tersedia '
            'di rilis berikutnya.',
          ),
          onApprove: t.key == 'pending'
              ? () => _handleApprove(context, item.id)
              : null,
          actionsRow: t.key == 'rejected'
              ? [
                  _ActionButton(
                    label: '\u27F3 Regen via AI',
                    primary: true,
                    onTap: () => SnackBarUtils.showInfo(
                      context,
                      'Regen via AI akan tersedia '
                      'di rilis berikutnya.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Edit manual',
                    primary: false,
                    onTap: () => SnackBarUtils.showInfo(
                      context,
                      'Edit manual akan tersedia '
                      'di rilis berikutnya.',
                    ),
                  ),
                ]
              : null,
        );
      }).toList();

      return ReviewTier(
        key: t.key,
        label: t.label,
        totalCount: t.totalCount,
        tone: t.tone,
        cards: cards,
        collapsed: t.key == 'approved' && t.items.length > 3,
        onSeeAll: t.key == 'approved'
            ? () => SnackBarUtils.showInfo(
                context,
                'Daftar lengkap akan tersedia '
                'di rilis berikutnya.',
              )
            : null,
      );
    }).toList();

    return ReviewQueueColumn(tiers: rendered);
  }

  // ── Actions ──

  Future<void> _handleApprove(BuildContext context, String id) async {
    try {
      await ref
          .read(adminLessonPlanQueueServiceProvider)
          .updateStatus(id, 'Approved');
      ref.invalidate(adminLessonPlanQueueProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'RPP disetujui');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal: $e');
      }
    }
  }

  // ── Status filter sheet ──

  String _filterLabel(String key) => switch (key) {
    'pending' => 'Perlu Review',
    'approved' => 'Disetujui',
    'rejected' => 'Ditolak',
    _ => key,
  };

  void _showStatusSheet(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Filter Status',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate900,
              ),
            ),
            const SizedBox(height: 12),
            for (final key in ['pending', 'approved', 'rejected'])
              ListTile(
                title: Text(
                  _filterLabel(key),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _statusFilter == key
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: _statusFilter == key ? navy : ColorUtils.slate700,
                  ),
                ),
                trailing: _statusFilter == key
                    ? Icon(Icons.check_rounded, color: navy, size: 18)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatusFilter(key);
                },
              ),
            if (_statusFilter != null)
              ListTile(
                title: const Text(
                  'Hapus filter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStatusFilter(null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Private widgets
// ═════════════════════════════════════════════════════════════════════

class _StatusPill extends StatelessWidget {
  final String label;
  final QueueTone tone;
  const _StatusPill({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      QueueTone.warn => (const Color(0xFFFFFBEB), const Color(0xFF92400E)),
      QueueTone.good => (const Color(0xFFF0FDF4), const Color(0xFF166534)),
      QueueTone.bad => (const Color(0xFFFEF2F2), const Color(0xFF991B1B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final bg = primary ? navy : Colors.white;
    final fg = primary ? Colors.white : ColorUtils.slate700;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: primary
                ? null
                : Border.all(color: ColorUtils.slate300, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
