// Frame E from the parent Rekomendasi mockup — the "Tandai Selesai"
// confirmation sheet shown when a parent confirms a rec is applied
// at home.
//
// Built on AppBottomSheet + BottomSheetFooter so the chrome matches
// every other sheet. Green primary (success colour) because this is
// a positive confirmation, not a destructive action. Body has:
//   • a green confirmation banner with copy explaining what happens
//   • optional Catatan textarea ("Anak sudah mengerjakan…") that
//     gets stored on `recommendation_share_recipients.parent_completion_note`
//   • a "Kirim notifikasi ke wali kelas" toggle (default on) — when
//     on, the action also flips the rec's status to `completed` so
//     the wali kelas's hub counts it
//
// Pops with a [ParentCompletionResult] on confirm, or null on cancel.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Result returned from the Tandai Selesai sheet. The caller forwards
/// this to `markRecommendationCompletedByParent`.
class ParentCompletionResult {
  /// Optional free-text note left by the parent.
  final String? note;

  /// Whether to also flip the rec's `status='completed'` (notifies the
  /// wali kelas's hub). Defaults to true in the sheet UI.
  final bool notifyTeacher;

  const ParentCompletionResult({this.note, required this.notifyTeacher});
}

/// Static helper — opens the sheet and returns a [ParentCompletionResult]
/// on confirm, null on cancel.
Future<ParentCompletionResult?> showParentRecommendationCompleteSheet({
  required BuildContext context,
  required String recommendationTitle,
  String? dueLabel,
}) {
  return AppBottomSheet.show<ParentCompletionResult>(
    context: context,
    title: 'Tandai Selesai',
    subtitle: dueLabel == null
        ? recommendationTitle
        : '$recommendationTitle · $dueLabel',
    icon: Icons.check_circle_rounded,
    primaryColor: ColorUtils.success600,
    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    content: const _CompleteSheetBody(),
  );
}

class _CompleteSheetBody extends StatefulWidget {
  const _CompleteSheetBody();

  @override
  State<_CompleteSheetBody> createState() => _CompleteSheetBodyState();
}

class _CompleteSheetBodyState extends State<_CompleteSheetBody> {
  final TextEditingController _noteCtrl = TextEditingController();
  bool _notifyTeacher = true;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    AppNavigator.pop(
      context,
      ParentCompletionResult(
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        notifyTeacher: _notifyTeacher,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = ColorUtils.success600;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Green confirmation banner ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: green.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: green),
                    const SizedBox(width: 8),
                    Text(
                      'SUDAH SELESAI DIKERJAKAN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: green,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Wali kelas akan menerima konfirmasi bahwa rekomendasi ini '
                  'sudah diterapkan di rumah.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Label('Catatan untuk wali kelas', trailing: '· opsional'),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 4,
            minLines: 3,
            style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
            decoration: InputDecoration(
              hintText: 'mis. "Sudah saya damping selama 10 hari…"',
              hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
              filled: true,
              fillColor: ColorUtils.slate50,
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
                borderSide: BorderSide(color: green, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),
          // ── Notify-teacher toggle row ──
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _notifyTeacher = !_notifyTeacher),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  // Visual toggle pill — switch widget would be heavier
                  // and adds platform-conditional spacing we don't need.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _notifyTeacher ? green : ColorUtils.slate300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 160),
                          alignment: _notifyTeacher
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Kirim notifikasi ke wali kelas',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Wali kelas akan diberi tahu bahwa anak '
                          'sudah selesai',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          BottomSheetFooter(
            primaryLabel: 'Tandai Selesai',
            secondaryLabel: 'Batal',
            primaryColor: green,
            onPrimary: _confirm,
            onSecondary: () => AppNavigator.pop(context, null),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? trailing;

  const _Label(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: text.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate700,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null)
            TextSpan(
              text: ' $trailing',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate400,
              ),
            ),
        ],
      ),
    );
  }
}
