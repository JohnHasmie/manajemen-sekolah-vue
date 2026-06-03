// Admin-side action bar for the RPP detail sheet — 3 buttons:
// Setujui / Kembalikan / Tolak. Replaces the old 2-button bar
// (Setujui + Tolak via AlertDialog).
//
// Each button routes through a brand bottom-sheet:
//   - Setujui    → showLessonPlanAdminApproveSheet  (Frame A2)
//   - Kembalikan → showLessonPlanAdminSendBackSheet (Frame C2)
//   - Tolak      → showLessonPlanAdminRejectSheet   (Frame C1)
//
// PATCH endpoints:
//   - Setujui / Tolak → PUT /rpp/{id}/status (existing)
//   - Kembalikan      → PUT /rpp/{id}/send-back (new) — keeps status
//                       Pending, sets revision_requested_at + areas
//
// After success the bar invokes [onStatusChanged] so the admin sheet
// can flip its local KPI badge without a full re-fetch.
//
// NOTE — admin does NOT regen via AI nor edit the RPP content. Those
// are the guru's responsibilities on the teacher detail screen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_approve_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_reject_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_admin_send_back_sheet.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_status_action_bar.dart';

/// Sticky bottom bar with Setujui + Tolak buttons. Visibility rules:
///
///   Menunggu → both buttons shown
///   Disetujui → only "Tolak" shown (admin can change their mind)
///   Ditolak  → only "Setujui" shown (admin can change their mind)
///   Draft / unknown → bar returns null via [maybeBuild]
class LessonPlanAdminActionBar extends ConsumerStatefulWidget {
  final String lessonPlanId;
  final String status;
  final String? currentNote;
  final void Function(String newStatus, String? newNote) onStatusChanged;

  /// Display strings used to populate the Setujui/Tolak/Kembalikan
  /// sheet summary cards. The detail page already knows these from
  /// the LessonPlan model — we pass them in instead of re-fetching.
  final String title;
  final String format;
  final String formatLabel;
  final String subjectLabel;
  final String classLabel;
  final String teacherName;

  const LessonPlanAdminActionBar({
    super.key,
    required this.lessonPlanId,
    required this.status,
    required this.currentNote,
    required this.onStatusChanged,
    required this.title,
    required this.format,
    required this.formatLabel,
    required this.subjectLabel,
    required this.classLabel,
    required this.teacherName,
  });

  /// Returns the widget when the RPP is in an actionable state for the
  /// admin (anything except Draft / unknown). Returns null otherwise so
  /// the caller can use `Column(children: [body, bar ?? SizedBox()])`
  /// or pass directly as a Scaffold.bottomNavigationBar.
  static Widget? maybeBuild({
    Key? key,
    required String? lessonPlanId,
    required String status,
    required String? currentNote,
    required void Function(String newStatus, String? newNote) onStatusChanged,
    required String title,
    required String format,
    required String formatLabel,
    required String subjectLabel,
    required String classLabel,
    required String teacherName,
  }) {
    if (lessonPlanId == null) return null;
    final kind = classifyLessonPlanStatus(status);
    if (kind == LessonPlanStatusKind.draft ||
        kind == LessonPlanStatusKind.unknown) {
      return null;
    }
    return LessonPlanAdminActionBar(
      key: key,
      lessonPlanId: lessonPlanId,
      status: status,
      currentNote: currentNote,
      onStatusChanged: onStatusChanged,
      title: title,
      format: format,
      formatLabel: formatLabel,
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      teacherName: teacherName,
    );
  }

  @override
  ConsumerState<LessonPlanAdminActionBar> createState() =>
      _LessonPlanAdminActionBarState();
}

class _LessonPlanAdminActionBarState
    extends ConsumerState<LessonPlanAdminActionBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final kind = classifyLessonPlanStatus(widget.status);
    // Visibility rules:
    //  Menunggu  → all 3 (Tolak / Kembalikan / Setujui)
    //  Disetujui → only Tolak (admin can flip their decision)
    //  Ditolak   → only Setujui (admin can flip their decision); the
    //              "Kembalikan" path is meaningless on rejected rows
    //              since rejection is final by policy.
    final showApprove = kind != LessonPlanStatusKind.approved;
    final showReject = kind != LessonPlanStatusKind.rejected;
    final showSendBack = kind == LessonPlanStatusKind.pending;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate200)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            if (showReject) ...[
              Expanded(child: _buildRejectButton()),
              const SizedBox(width: 8),
            ],
            if (showSendBack) ...[
              Expanded(child: _buildSendBackButton()),
              const SizedBox(width: 8),
            ],
            if (showApprove) Expanded(child: _buildApproveButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildApproveButton() {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _busy ? null : _approve,
        style: ElevatedButton.styleFrom(
          // Mockup `.ab-btn.approve` uses Tailwind green-600 `#16A34A`.
          // `success600` is emerald-600 (#059669) which reads cooler;
          // use the on-brand `green600` token so the action bar
          // matches the design system primary green.
          backgroundColor: ColorUtils.green600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ColorUtils.green600.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 18),
        label: const Text('Setujui'),
      ),
    );
  }

  Widget _buildRejectButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _reject,
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorUtils.error600,
          side: BorderSide(color: ColorUtils.error600, width: 1.3),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.cancel_rounded, size: 17),
        label: const Text('Tolak'),
      ),
    );
  }

  Widget _buildSendBackButton() {
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _sendBack,
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorUtils.warningDark,
          backgroundColor: ColorUtils.warningLight,
          side: BorderSide(
            color: ColorUtils.warningDark.withValues(alpha: 0.6),
            width: 1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.reply_rounded, size: 17),
        label: const Text('Kembalikan'),
      ),
    );
  }

  Future<void> _approve() async {
    final result = await showLessonPlanAdminApproveSheet(
      context: context,
      title: widget.title,
      formatLabel: widget.formatLabel,
      subjectLabel: widget.subjectLabel,
      classLabel: widget.classLabel,
      teacherName: widget.teacherName,
    );
    if (result == null || !mounted) return;
    await _patch(status: 'Disetujui', catatan: result.note);
  }

  Future<void> _reject() async {
    final result = await showLessonPlanAdminRejectSheet(
      context: context,
      title: widget.title,
      formatLabel: widget.formatLabel,
      subjectLabel: widget.subjectLabel,
      classLabel: widget.classLabel,
      teacherName: widget.teacherName,
      initialNote: widget.currentNote,
    );
    if (result == null || !mounted) return;
    await _patch(status: 'Ditolak', catatan: result.note);
  }

  /// "Kembalikan ke guru" — routes through the dedicated send-back
  /// endpoint instead of the status PATCH. Status stays Pending but
  /// revision_requested_at + revision_areas are written so the guru
  /// gets a revision banner on their detail screen.
  Future<void> _sendBack() async {
    final result = await showLessonPlanAdminSendBackSheet(
      context: context,
      title: widget.title,
      format: widget.format,
      formatLabel: widget.formatLabel,
      subjectLabel: widget.subjectLabel,
      classLabel: widget.classLabel,
      teacherName: widget.teacherName,
      initialNote: widget.currentNote,
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await LessonPlanService.sendBackLessonPlan(
        widget.lessonPlanId,
        catatan: result.note,
        areas: result.areas.isEmpty ? null : result.areas,
      );
      if (!mounted) return;
      // Status stays Pending — only the note + revision flag changed.
      widget.onStatusChanged('Pending', result.note);
      unawaited(ref.read(dashboardProvider.notifier).refreshStats());
      SnackBarUtils.showSuccess(
        context,
        'RPP dikembalikan ke guru untuk direvisi.',
      );
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _patch({
    required String status,
    required String? catatan,
  }) async {
    setState(() => _busy = true);
    try {
      await LessonPlanService.updateLessonPlanStatus(
        widget.lessonPlanId,
        status,
        catatan: catatan,
      );
      if (!mounted) return;
      widget.onStatusChanged(status, catatan);
      // Refresh the admin dashboard's RPP review stats / priority
      // inbox so the freshly-decided row leaves "Perlu review" without
      // the admin having to pull-to-refresh.
      unawaited(ref.read(dashboardProvider.notifier).refreshStats());
      SnackBarUtils.showInfo(
        context,
        status == 'Disetujui' ? 'RPP disetujui.' : 'RPP ditolak.',
      );
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
