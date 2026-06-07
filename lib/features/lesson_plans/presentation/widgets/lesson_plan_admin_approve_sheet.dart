// Admin "Setujui RPP?" confirmation sheet — Mockup Frame A2.
//
// Surfaces a short summary card + optional catatan textarea before
// flipping the lesson plan to Approved. Wired from two places:
//
//   1. Quick-approve checkmark on the admin RPP list card
//      (admin_rpp_review_hub_screen → SwipeableQueueCard.onApprove).
//   2. "Setujui" action-bar button on the admin detail page
//      (LessonPlanAdminActionBar — replaces the old AppAlertDialog).
//
// Returns a [LessonPlanApproveResult] when the admin confirms, or
// null on cancel. The caller does the actual PATCH and refresh.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Payload returned when the admin confirms Setujui. [note] is the
/// optional catatan to attach as `note_admin`.
class LessonPlanApproveResult {
  final String? note;
  const LessonPlanApproveResult({this.note});
}

/// Opens the Setujui confirmation sheet. Returns null when the admin
/// dismisses or taps Batal; returns a [LessonPlanApproveResult]
/// (possibly with an empty note) when they tap Setujui.
Future<LessonPlanApproveResult?> showLessonPlanAdminApproveSheet({
  required BuildContext context,
  required String title,
  required String formatLabel,
  required String subjectLabel,
  required String classLabel,
  required String teacherName,
  String? initialNote,
}) {
  return AppBottomSheet.show<LessonPlanApproveResult>(
    context: context,
    title: kLesPlaApproveConfirm.tr,
    subtitle: kLesPlaApproveSubtitle.tr,
    icon: Icons.check_circle_rounded,
    primaryColor: ColorUtils.green600,
    content: _ApproveSheetBody(
      title: title,
      formatLabel: formatLabel,
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      teacherName: teacherName,
      initialNote: initialNote,
    ),
  );
}

class _ApproveSheetBody extends StatefulWidget {
  final String title;
  final String formatLabel;
  final String subjectLabel;
  final String classLabel;
  final String teacherName;
  final String? initialNote;

  const _ApproveSheetBody({
    required this.title,
    required this.formatLabel,
    required this.subjectLabel,
    required this.classLabel,
    required this.teacherName,
    this.initialNote,
  });

  @override
  State<_ApproveSheetBody> createState() => _ApproveSheetBodyState();
}

class _ApproveSheetBodyState extends State<_ApproveSheetBody> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryCard(),
        const SizedBox(height: 14),
        _noteField(),
        const SizedBox(height: 14),
        BottomSheetFooter(
          primaryLabel: 'Setujui',
          secondaryLabel: 'Batal',
          primaryColor: ColorUtils.green600,
          onPrimary: () => Navigator.of(context).pop(
            LessonPlanApproveResult(
              note: _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim(),
            ),
          ),
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.formatLabel.toUpperCase()} · ${widget.subjectLabel}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.classLabel} · ${widget.teacherName}',
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Catatan untuk guru',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'OPSIONAL',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          maxLines: 3,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Bagus, alur kegiatan sudah runtut…',
            hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 12),
            filled: true,
            fillColor: ColorUtils.slate50,
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
              borderSide: BorderSide(color: ColorUtils.green600, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
