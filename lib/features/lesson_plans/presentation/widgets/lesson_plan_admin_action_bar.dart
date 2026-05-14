// Admin-side Setujui / Tolak action bar for the RPP detail sheet.
//
// Surfaces the two primary admin actions as visible buttons at the
// bottom of the detail sheet instead of burying them behind a 3-dot
// popup menu. The popup menu stays as a redundant entry point so the
// existing screenshots / muscle memory keep working — this bar is the
// new default.
//
// Approve flow:  one-tap confirm → PATCH status = 'Disetujui'
// Reject  flow:  required catatan dialog → PATCH status = 'Ditolak'
//                + catatan. The catatan lands in `note_admin` and
//                surfaces back to the teacher via the revision-note
//                banner on AiRppDetailScreen / ManualRppDetailScreen.
//
// Both call [LessonPlanService.updateLessonPlanStatus] (PUT /rpp/{id}/
// status) — no new endpoint needed. After success the bar invokes
// [onStatusChanged] so the admin sheet can flip its local KPI badge
// without a full re-fetch.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_alert_dialog.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';
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

  const LessonPlanAdminActionBar({
    super.key,
    required this.lessonPlanId,
    required this.status,
    required this.currentNote,
    required this.onStatusChanged,
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
    final showApprove = kind != LessonPlanStatusKind.approved;
    final showReject = kind != LessonPlanStatusKind.rejected;

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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            if (showReject) ...[
              Expanded(child: _buildRejectButton()),
              if (showApprove) const SizedBox(width: 10),
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
          backgroundColor: ColorUtils.success600,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ColorUtils.success600.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(Icons.cancel_rounded, size: 18),
        label: const Text('Tolak'),
      ),
    );
  }

  Future<void> _approve() async {
    final confirmed = await AppAlertDialog.show(
      context: context,
      title: 'Setujui RPP?',
      message:
          'Status RPP akan berubah menjadi Disetujui dan guru akan '
              'mendapat pemberitahuan.',
      icon: Icons.check_circle_rounded,
      confirmText: 'Setujui',
      confirmColor: ColorUtils.success600,
    );
    if (confirmed != true || !mounted) return;
    await _patch(status: 'Disetujui', catatan: null);
  }

  Future<void> _reject() async {
    final note = await _showRejectNoteDialog();
    if (note == null || !mounted) return;
    await _patch(status: 'Ditolak', catatan: note);
  }

  /// Custom reject dialog with a required catatan field. The note is
  /// what the teacher reads from the revision-note banner, so we
  /// gate-keep emptiness here rather than letting an empty rejection
  /// slip through.
  Future<String?> _showRejectNoteDialog() async {
    final ctrl = TextEditingController(text: widget.currentNote ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final text = ctrl.text.trim();
            final canSubmit = text.isNotEmpty;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ColorUtils.error600.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.cancel_rounded,
                      color: ColorUtils.error600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Tolak RPP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catatan revisi (wajib)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    maxLines: 4,
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Apa yang perlu diperbaiki guru?',
                      hintStyle: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ColorUtils.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ColorUtils.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: ColorUtils.error600,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Catatan akan ditampilkan ke guru sebagai instruksi '
                    'perbaikan sebelum mereka mengajukan ulang.',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(null),
                  child: Text(
                    'Batal',
                    style: TextStyle(color: ColorUtils.slate600),
                  ),
                ),
                ElevatedButton(
                  onPressed: canSubmit
                      ? () => Navigator.of(dialogCtx).pop(text)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.error600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ColorUtils.error600.withValues(
                      alpha: 0.4,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Tolak RPP',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    ctrl.dispose();
    return result;
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
