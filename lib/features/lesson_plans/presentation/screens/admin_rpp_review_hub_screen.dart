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
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_lesson_plan_components.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/lesson_plans/data/admin_lesson_plan_queue_service.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_approve_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_filter_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_reject_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_send_back_sheet.dart';

class AdminRppReviewHubScreen extends ConsumerStatefulWidget {
  const AdminRppReviewHubScreen({super.key});

  @override
  ConsumerState<AdminRppReviewHubScreen> createState() =>
      _AdminRppReviewHubScreenState();
}

class _AdminRppReviewHubScreenState
    extends ConsumerState<AdminRppReviewHubScreen>
    with AdminAcademicYearReloadMixin<AdminRppReviewHubScreen> {
  /// Full filter (status / format / mapel / kelas / guru / periode).
  ///
  /// The `status` field also acts as the bottom-slot chip's display
  /// label — but the other dimensions get pushed into the query and
  /// surfaced as an "+N filter aktif" pill instead of cluttering the
  /// chip strip with 6 chips on a narrow phone.
  LessonPlanAdminFilter _filter = const LessonPlanAdminFilter.empty();

  /// Reload the RPP queue when the dashboard AY picker flips. The
  /// queue provider reads the AY scope internally, so invalidating
  /// it triggers a refresh with the new year.
  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    _refresh();
  }

  Future<void> _refresh() async {
    ref.invalidate(adminLessonPlanQueueProvider);
    // Wait for the provider to settle so the refresh
    // indicator finishes only after data arrives.
    await ref.read(adminLessonPlanQueueProvider.future);
  }

  /// Push the non-status filter dimensions into the queue params
  /// provider so any change flips the FutureProvider into the loading
  /// state and refetches. Status stays purely client-side — the
  /// backend doesn't have a status query param on /admin-queue and
  /// the queue is already grouped by tier.
  void _syncQueryParams() {
    ref.read(adminLessonPlanQueueParamsProvider.notifier).state =
        AdminLessonPlanQueueParams(
          format: _filter.format,
          subjectId: _filter.subjectId,
          classId: _filter.classId,
          teacherId: _filter.teacherId,
          period: _filter.period,
        );
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
              onTap: () => _openFilterSheet(context),
              badgeCount: _filter.isEmpty ? null : _filter.activeCount,
            ),
          ],
          // Filter chip strip — mockup shows 4 chips ("Semua / Mapel
          // · X / Kelas · Y / Guru · 4") so the strip looks balanced
          // and the admin can see active filters at a glance. We
          // populate Status + Format always (the two most-used
          // dimensions) and replace the placeholder labels with the
          // active value when a filter is applied. Tapping any chip
          // opens the same full filter sheet.
          bottomSlot: BrandFilterChipStrip(
            chips: [
              BrandFilterChip(
                label: 'Status',
                value: _filter.status == null
                    ? null
                    : _statusLabel(_filter.status!),
                onTap: () => _openFilterSheet(context),
              ),
              BrandFilterChip(
                label: 'Format',
                value: _filter.format == null
                    ? null
                    : LessonPlanFormat.fromValue(_filter.format!).shortLabel,
                onTap: () => _openFilterSheet(context),
              ),
              BrandFilterChip(
                label: 'Periode',
                value: _filter.period == null
                    ? null
                    : _periodLabel(_filter.period!),
                onTap: () => _openFilterSheet(context),
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

    // Mockup uses Tailwind 700-weight tints for the KPI numerals so
    // they read as text — not loud 500-weight accents — against the
    // white strip. See `.kpi-num.amber/.green/.red` in the mockup.
    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: 'Perlu Review',
          value: '${pending?.totalCount ?? 0}',
          valueColor: ColorUtils.warning700,
          sub: pending?.deltaLabel,
        ),
        BrandKpiColumn(
          label: 'Disetujui',
          value: '${approved?.totalCount ?? 0}',
          valueColor: ColorUtils.success700,
          sub: approved?.deltaLabel,
        ),
        BrandKpiColumn(
          label: 'Ditolak',
          value: '${rejected?.totalCount ?? 0}',
          valueColor: ColorUtils.error700,
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
    // Filter tiers by status if the filter sheet's status field is
    // active. The other filter dimensions are server-side (already
    // applied at /admin-queue?format=…&class_id=…) so we don't
    // re-filter them here.
    final tierKeyFromStatus = switch (_filter.status) {
      'Pending' => 'pending',
      'Approved' => 'approved',
      'Rejected' => 'rejected',
      _ => null,
    };

    var tiers = queue.tiers;
    if (tierKeyFromStatus != null) {
      tiers = tiers.where((t) => t.key == tierKeyFromStatus).toList();
    }

    if (tiers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            _filter.status != null
                ? 'Tidak ada RPP dengan status '
                      '"${_statusLabel(_filter.status!)}"'
                : 'Belum ada RPP.',
            style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
          ),
        ),
      );
    }

    final rendered = tiers.map((t) {
      final cards = t.items.take(t.key == 'approved' ? 3 : 5).map((item) {
        final fmt = LessonPlanFormat.fromValue(item.format);
        return SwipeableQueueCard(
          subtitle: item.subtitle,
          title: item.title,
          tone: t.tone,
          rejectionReason: item.rejectionReason,
          // Format pill (K13 / Modul Ajar / 1 HAL / FILE) on the
          // left, then status pill, then relative time \u2014 matches
          // mockup `.rpp-card .row1`.
          formatBadge: _FormatPill(format: fmt),
          meta: [
            _StatusPill(label: item.status, tone: t.tone),
            if (item.updatedAtHuman != null)
              Text(
                item.updatedAtHuman!,
                style: TextStyle(fontSize: 10.5, color: ColorUtils.slate500),
              ),
          ],
          footer: item.teacherName,
          avatarInitials: _initialsFor(item.teacherName),
          // Tap \u2192 open the admin detail sheet. The detail page hydrates
          // its own state via /rpp/{id}, so we only pass the minimum
          // identifier + display strings the sheet can show before the
          // refresh lands.
          onTap: () => _openDetail(context, item),
          // 3 quick actions \u2014 only on Pending rows. Approved/Rejected
          // rows stay read-only (no per-card action; admin flips via
          // the detail action bar if they really need to).
          onApprove: t.key == 'pending'
              ? () => _handleApprove(context, item)
              : null,
          onSendBack: t.key == 'pending'
              ? () => _handleSendBack(context, item)
              : null,
          onReject: t.key == 'pending'
              ? () => _handleReject(context, item)
              : null,
          // Rejected rows used to surface "Regen via AI" / "Edit
          // manual" CTAs targeting the guru's job. Per the new admin
          // policy, admin doesn't regen or edit on the guru's behalf \u2014
          // the row stays read-only here. The guru sees their own
          // edit/regen affordances on the teacher detail screen.
          actionsRow: null,
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
            ? () => _openFullList(context, 'approved')
            : null,
      );
    }).toList();

    return ReviewQueueColumn(tiers: rendered);
  }

  // ── Actions ──

  /// Quick-approve flow from the row's ✓ button. Shows the confirmation
  /// sheet (Frame A2) so the admin sees a summary + can attach an
  /// optional catatan before the PATCH. Falls back to a friendly error
  /// snackbar on network failure.
  Future<void> _handleApprove(BuildContext context, QueueItem item) async {
    // Parse the "Mapel · Kelas X" subtitle that the backend pre-formats
    // — we display the same shape inside the confirmation summary.
    final parts = item.subtitle.split('·').map((e) => e.trim()).toList();
    final subjectLabel = parts.isNotEmpty ? parts.first : '';
    final classLabel = parts.length > 1 ? parts[1] : '';

    final result = await showLessonPlanAdminApproveSheet(
      context: context,
      title: item.title,
      formatLabel: 'RPP',
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      teacherName: item.teacherName,
    );
    if (result == null) return;
    if (!context.mounted) return;

    try {
      await LessonPlanService.updateLessonPlanStatus(
        item.id,
        'Disetujui',
        catatan: result.note,
      );
      ref.invalidate(adminLessonPlanQueueProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'RPP disetujui.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal menyetujui RPP: $e');
      }
    }
  }

  /// Quick-reject from the row's ✗ button. Opens the same reject sheet
  /// the detail page uses (Frame C1) so admin sees the same chip
  /// reasons + required catatan flow without having to navigate first.
  Future<void> _handleReject(BuildContext context, QueueItem item) async {
    final parts = item.subtitle.split('·').map((e) => e.trim()).toList();
    final subjectLabel = parts.isNotEmpty ? parts.first : '';
    final classLabel = parts.length > 1 ? parts[1] : '';

    final result = await showLessonPlanAdminRejectSheet(
      context: context,
      title: item.title,
      formatLabel: LessonPlanFormat.fromValue(item.format).shortLabel,
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      teacherName: item.teacherName,
      initialNote: item.rejectionReason,
    );
    if (result == null || !context.mounted) return;

    try {
      await LessonPlanService.updateLessonPlanStatus(
        item.id,
        'Ditolak',
        catatan: result.note,
      );
      ref.invalidate(adminLessonPlanQueueProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(context, 'RPP ditolak.');
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal menolak RPP: $e');
      }
    }
  }

  /// Quick-send-back from the row's ⤺ button. Opens the same send-back
  /// sheet (Frame C2) the detail page uses. Status stays Pending but
  /// revision_requested_at + revision_areas are set on the backend.
  Future<void> _handleSendBack(BuildContext context, QueueItem item) async {
    final parts = item.subtitle.split('·').map((e) => e.trim()).toList();
    final subjectLabel = parts.isNotEmpty ? parts.first : '';
    final classLabel = parts.length > 1 ? parts[1] : '';

    final result = await showLessonPlanAdminSendBackSheet(
      context: context,
      title: item.title,
      format: item.format,
      formatLabel: LessonPlanFormat.fromValue(item.format).shortLabel,
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      teacherName: item.teacherName,
      initialNote: item.rejectionReason,
    );
    if (result == null || !context.mounted) return;

    try {
      await LessonPlanService.sendBackLessonPlan(
        item.id,
        catatan: result.note,
        areas: result.areas.isEmpty ? null : result.areas,
      );
      ref.invalidate(adminLessonPlanQueueProvider);
      if (context.mounted) {
        SnackBarUtils.showSuccess(
          context,
          'RPP dikembalikan ke guru untuk direvisi.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, 'Gagal mengembalikan RPP: $e');
      }
    }
  }

  /// Open the admin detail sheet for [item]. We pass a thin map so
  /// LessonPlanAdminDetailPage can render a header immediately; the
  /// sheet's own initState() re-fetches the full record via
  /// LessonPlanService.getLessonPlanById to populate format-specific
  /// sections and the attachment card.
  Future<void> _openDetail(BuildContext context, QueueItem item) async {
    final seed = <String, dynamic>{
      'id': item.id,
      'title': item.title,
      'status': item.status,
      'teacher_name': item.teacherName,
      'subject_name': item.subtitle.split('·').first.trim(),
      if (item.rejectionReason != null) 'note_admin': item.rejectionReason,
    };
    await LessonPlanAdminDetailPage.show(
      context: context,
      lessonPlan: seed,
    );
    // Always refresh — admin may have acted on the row inside the sheet.
    ref.invalidate(adminLessonPlanQueueProvider);
  }

  /// "Lihat semua Disetujui" — defers to the full admin RPP list screen
  /// with the status pre-filtered. The list screen handles pagination,
  /// search, and the per-card kebab while the hub keeps the top-N
  /// teaser collapsed.
  void _openFullList(BuildContext context, String statusKey) {
    SnackBarUtils.showInfo(
      context,
      'Buka tab "Manajemen RPP" untuk daftar lengkap.',
    );
    // TODO(admin-rpp): when AdminLessonPlanScreen gains a public route
    // we can wire AppNavigator.push here. For now the inbox tile +
    // bottom nav already cover this path.
  }

  // ── Filter sheet ──

  /// Human label for a backend status key. Used both by the
  /// bottom-slot chip and the empty-state copy.
  String _statusLabel(String backendKey) => switch (backendKey) {
    'Pending' => 'Perlu Review',
    'Approved' => 'Disetujui',
    'Rejected' => 'Ditolak',
    _ => backendKey,
  };

  /// Short label for the periode chip on the header strip. Matches
  /// the strings the filter sheet uses for its single-select chips.
  String _periodLabel(String backendKey) => switch (backendKey) {
    'week' => 'Minggu ini',
    'month' => 'Bulan ini',
    'semester' => 'Semester',
    'all' => 'Semua',
    _ => backendKey,
  };

  /// First-two-character initials for the teacher avatar. Mirrors
  /// the helper inside CardBuildersMixin so the list card avatar
  /// renders the same letters as the detail-page hero avatar.
  String _initialsFor(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final updated = await showLessonPlanAdminFilterSheet(
      context: context,
      initial: _filter,
      role: 'admin',
      // TODO(admin-rpp): pass the currently-selected academic_year_id
      // once the dashboard exposes it via Riverpod. For now the
      // FilterOptionsService falls back to "current" which is the
      // only year the admin queue surfaces anyway.
    );
    if (updated == null) return;
    setState(() => _filter = updated);
    _syncQueryParams();
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
    // Tailwind-50 / -700 pairs, mirrored from the mockup
    // `.status-pill.menunggu/.disetujui/.ditolak` palette.
    final (bg, fg) = switch (tone) {
      QueueTone.warn => (const Color(0xFFFEF3C7), ColorUtils.warning700),
      QueueTone.good => (const Color(0xFFDCFCE7), ColorUtils.success700),
      QueueTone.bad => (const Color(0xFFFEE2E2), ColorUtils.error700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// Note: _ActionButton (Regen/Edit CTAs on rejected rows) was retired
// when the admin role lost regen + edit responsibilities. Kept as a
// comment marker so a future "I swear we used to have those buttons"
// search lands here and the rationale is one git log away.

/// Format pill used by SwipeableQueueCard's `formatBadge` slot — shows
/// K13 / 1 HAL / MODUL AJAR / FILE with the same tinted-50/700 palette
/// as the detail-page hero. Keeps list ↔ detail visual continuity.
class _FormatPill extends StatelessWidget {
  final LessonPlanFormat format;
  const _FormatPill({required this.format});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (format) {
      LessonPlanFormat.k13 => (const Color(0xFFDBEAFE), const Color(0xFF1E40AF)),
      LessonPlanFormat.modulAjar => (
            const Color(0xFFEDE9FE),
            const Color(0xFF6D28D9),
          ),
      LessonPlanFormat.rpp1Halaman => (
            const Color(0xFFCCFBF1),
            const Color(0xFF0F766E),
          ),
      LessonPlanFormat.file => (ColorUtils.slate100, ColorUtils.slate700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        format.shortLabel,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
