// Admin RPP review hub — Mockup #09 applied.
//
// Hero with 3 QueueCountTiles + period pill, then a ReviewQueueColumn
// with 3 tiers (Pending → Rejected → Approved teaser). Each pending
// card has an inline approve action; rejected cards expose Regen +
// Edit manual buttons (snackbar placeholder until #134 regen flow is
// generalised for admin).
//
// Existing AdminLessonPlanScreen left untouched — the new hub is a
// dedicated drill-in with a different shape (review queue vs. CRUD
// list). Future work can swap entry points or merge them.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_lesson_plan_components.dart';
import 'package:manajemensekolah/features/lesson_plans/data/admin_lesson_plan_queue_service.dart';

class AdminRppReviewHubScreen extends ConsumerWidget {
  const AdminRppReviewHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navy = ColorUtils.getRoleColor('admin');
    final async = ref.watch(adminLessonPlanQueueProvider);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(navy: navy, queue: async.maybeWhen(
            data: (q) => q,
            orElse: () => null,
          )),
          const SizedBox(height: AppSpacing.lg),
          async.when(
            data: (q) => _buildBody(context, ref, q),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Gagal memuat: $e',
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ),
          SizedBox(
            height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AdminLessonPlanQueue queue,
  ) {
    final tiers = queue.tiers.map((t) {
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
                style: TextStyle(
                  fontSize: 10.5,
                  color: ColorUtils.slate500,
                ),
              ),
          ],
          footer: '${item.teacherName}',
          onTap: () => SnackBarUtils.showInfo(
            context,
            'Detail RPP akan tersedia di rilis berikutnya.',
          ),
          onApprove: t.key == 'pending'
              ? () => _handleApprove(context, ref, item.id)
              : null,
          actionsRow: t.key == 'rejected'
              ? [
                  _ActionButton(
                    label: '⟳ Regen via AI',
                    primary: true,
                    onTap: () => SnackBarUtils.showInfo(
                      context,
                      'Regen via AI akan tersedia di rilis berikutnya.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Edit manual',
                    primary: false,
                    onTap: () => SnackBarUtils.showInfo(
                      context,
                      'Edit manual akan tersedia di rilis berikutnya.',
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
        collapsed:
            t.key == 'approved' && t.items.length > 3,
        onSeeAll: t.key == 'approved'
            ? () => SnackBarUtils.showInfo(
                  context,
                  'Daftar lengkap akan tersedia di rilis berikutnya.',
                )
            : null,
      );
    }).toList();

    return ReviewQueueColumn(tiers: tiers);
  }

  Future<void> _handleApprove(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await ref
          .read(adminLessonPlanQueueServiceProvider)
          .updateStatus(id, 'Approved');
      // Re-fetch the queue so the approved card moves to the
      // approved tier teaser.
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
}

class _Hero extends StatelessWidget {
  final Color navy;
  final AdminLessonPlanQueue? queue;
  const _Hero({required this.navy, this.queue});

  QueueTier? _byKey(String key) => queue?.tierByKey(key);

  @override
  Widget build(BuildContext context) {
    final pending = _byKey('pending');
    final approved = _byKey('approved');
    final rejected = _byKey('rejected');

    return Container(
      decoration: BoxDecoration(gradient: ColorUtils.brandGradient('admin')),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => AppNavigator.pop(context),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Akademik · Pembelajaran',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'RPP',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: QueueCountTile(
                      label: 'PERLU REVIEW',
                      count: pending?.totalCount ?? 0,
                      tone: QueueTone.warn,
                      deltaLabel: pending?.deltaLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QueueCountTile(
                      label: 'DISETUJUI',
                      count: approved?.totalCount ?? 0,
                      tone: QueueTone.good,
                      deltaLabel: approved?.deltaLabel,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: QueueCountTile(
                      label: 'DITOLAK',
                      count: rejected?.totalCount ?? 0,
                      tone: QueueTone.bad,
                      deltaLabel: rejected?.deltaLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

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
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
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
