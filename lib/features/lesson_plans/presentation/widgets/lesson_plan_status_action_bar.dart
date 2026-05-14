// Status-driven affordances for the teacher RPP detail screen.
//
// Two pieces, used together on AiRppDetailScreen + ManualRppDetailScreen:
//
//   • [LessonPlanRevisionNoteBanner] — red-tinted note banner shown
//     at the top of the body when the RPP is Ditolak/Rejected AND the
//     admin left a `note_admin` / `catatan_admin` revision message.
//     Surfaces *what* needs fixing before the teacher resubmits.
//
//   • [LessonPlanStatusActionBar] — sticky bottom CTA that appears
//     only when the row is directional:
//       Draft   → "Ajukan untuk Ditinjau" → PATCH status = Menunggu
//       Ditolak → "Ajukan Ulang"           → PATCH status = Menunggu
//     For Menunggu / Disetujui the bar returns null so the screen
//     doesn't pass it to Scaffold.bottomNavigationBar (saves ~64 px).
//
// The PATCH uses the existing /rpp/{id}/status endpoint via
// [LessonPlanService.updateLessonPlanStatus] — no new backend route.
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

/// Canonical status keys the bar reacts to. Backend emits the
/// English forms; the Indonesian aliases come from older rows and
/// from the `_standardizeJson` mapper.
enum LessonPlanStatusKind { draft, pending, approved, rejected, unknown }

LessonPlanStatusKind classifyLessonPlanStatus(String raw) {
  final s = raw.toLowerCase().trim();
  if (s.isEmpty || s == 'draft' || s == 'draf') {
    return LessonPlanStatusKind.draft;
  }
  if (s == 'pending' || s == 'submitted' || s == 'menunggu') {
    return LessonPlanStatusKind.pending;
  }
  if (s == 'approved' || s == 'disetujui') {
    return LessonPlanStatusKind.approved;
  }
  if (s == 'rejected' || s == 'ditolak' || s == 'revision') {
    return LessonPlanStatusKind.rejected;
  }
  return LessonPlanStatusKind.unknown;
}

/// Red note banner. Render at the top of the detail body. Returns
/// `SizedBox.shrink()` when the status is not Rejected or the admin
/// note is empty so the caller can drop it in unconditionally.
class LessonPlanRevisionNoteBanner extends StatelessWidget {
  final String status;
  final String? adminNote;
  final EdgeInsetsGeometry margin;

  const LessonPlanRevisionNoteBanner({
    super.key,
    required this.status,
    required this.adminNote,
    this.margin = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    final kind = classifyLessonPlanStatus(status);
    final note = (adminNote ?? '').trim();
    if (kind != LessonPlanStatusKind.rejected || note.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: margin,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColorUtils.error600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.report_problem_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Catatan revisi dari admin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: ColorUtils.error600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: ColorUtils.slate800,
                      height: 1.45,
                    ),
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

/// Sticky bottom CTA. Use as `Scaffold.bottomNavigationBar` so the
/// system bottom safe-area is respected automatically.
///
/// [lessonPlanId] is required so the bar can issue the PATCH directly;
/// [onStatusChanged] is called after a successful resubmit so the
/// detail screen can update its KPI badge + local map without a refetch.
class LessonPlanStatusActionBar extends ConsumerStatefulWidget {
  final String lessonPlanId;
  final String status;
  final Color primaryColor;
  final void Function(String newStatus) onStatusChanged;

  const LessonPlanStatusActionBar({
    super.key,
    required this.lessonPlanId,
    required this.status,
    required this.primaryColor,
    required this.onStatusChanged,
  });

  /// Returns the widget when the status has a directional next step,
  /// otherwise null. Wire as
  /// `bottomNavigationBar: LessonPlanStatusActionBar.maybeBuild(...)`.
  static Widget? maybeBuild({
    Key? key,
    required String? lessonPlanId,
    required String status,
    required Color primaryColor,
    required void Function(String newStatus) onStatusChanged,
  }) {
    final kind = classifyLessonPlanStatus(status);
    if (kind != LessonPlanStatusKind.draft &&
        kind != LessonPlanStatusKind.rejected) {
      return null;
    }
    if (lessonPlanId == null) return null;
    return LessonPlanStatusActionBar(
      key: key,
      lessonPlanId: lessonPlanId,
      status: status,
      primaryColor: primaryColor,
      onStatusChanged: onStatusChanged,
    );
  }

  @override
  ConsumerState<LessonPlanStatusActionBar> createState() =>
      _LessonPlanStatusActionBarState();
}

class _LessonPlanStatusActionBarState
    extends ConsumerState<LessonPlanStatusActionBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final kind = classifyLessonPlanStatus(widget.status);
    final isRejected = kind == LessonPlanStatusKind.rejected;
    final label = isRejected ? 'Ajukan Ulang' : 'Ajukan untuk Ditinjau';
    final icon = isRejected ? Icons.refresh_rounded : Icons.send_rounded;
    final color = isRejected ? ColorUtils.error600 : widget.primaryColor;
    final hint = isRejected
        ? 'Status akan kembali ke Menunggu untuk ditinjau admin.'
        : 'Kirim RPP ke admin untuk ditinjau.';

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRejected ? 'Perlu revisi' : 'Belum diajukan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: ColorUtils.slate500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: color.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    : Icon(icon, size: 16),
                label: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final id = widget.lessonPlanId;
    final isRejected =
        classifyLessonPlanStatus(widget.status) ==
        LessonPlanStatusKind.rejected;
    final confirmed = await AppAlertDialog.show(
      context: context,
      title: isRejected ? 'Ajukan ulang untuk ditinjau?' : 'Ajukan RPP?',
      message: isRejected
          ? 'Status akan kembali ke Menunggu dan admin akan '
                'meninjau perubahanmu.'
          : 'Admin akan menerima permintaan tinjau untuk RPP ini.',
      icon: isRejected ? Icons.refresh_rounded : Icons.send_rounded,
      confirmText: isRejected ? 'Ajukan Ulang' : 'Ajukan',
      confirmColor: isRejected ? ColorUtils.error600 : widget.primaryColor,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      // Indonesian label — the backend's updateStatus maps it to
      // 'Pending' internally (see LessonPlanController::updateStatus).
      await LessonPlanService.updateLessonPlanStatus(id, 'Menunggu');
      if (!mounted) return;
      widget.onStatusChanged('Menunggu');
      // Force the dashboard's `priority_inbox` to refetch so the
      // "RPP butuh revisi" row drops out of "Perlu perhatian" on pop.
      // Disk cache was already cleared inside updateLessonPlanStatus,
      // but Riverpod's keepAlive state needs an explicit nudge.
      unawaited(ref.read(dashboardProvider.notifier).refreshStats());
      SnackBarUtils.showInfo(context, 'RPP diajukan untuk ditinjau.');
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
