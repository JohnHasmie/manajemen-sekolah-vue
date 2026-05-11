// Frame D from the parent Rekomendasi mockup — the "Balas Wali Kelas"
// sheet shown when a parent taps Balas on a rec card or detail screen.
//
// Built on AppBottomSheet + BottomSheetFooter so the chrome matches
// every other sheet in the app (gradient header, drag handle, sticky
// footer with safe-area). Body is a quick-reply chip strip + a free-
// form Pesan textarea so the parent can either tap a canned reply or
// type their own.
//
// Pops with the trimmed reply text on Send; null when the parent
// cancels or backs out.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Static helper — opens the reply sheet and returns the parent's
/// trimmed reply text on confirm, or `null` on cancel / backdrop tap.
Future<String?> showParentRecommendationReplySheet({
  required BuildContext context,
  required String teacherName,
  String? subjectName,
  String? initialText,
}) {
  return AppBottomSheet.show<String>(
    context: context,
    title: 'Balas Wali Kelas',
    subtitle: subjectName == null ? teacherName : '$teacherName · $subjectName',
    icon: Icons.chat_bubble_rounded,
    primaryColor: ColorUtils.brandAzure,
    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    content: _ReplySheetBody(initialText: initialText ?? ''),
  );
}

class _ReplySheetBody extends StatefulWidget {
  final String initialText;

  const _ReplySheetBody({required this.initialText});

  @override
  State<_ReplySheetBody> createState() => _ReplySheetBodyState();
}

class _ReplySheetBodyState extends State<_ReplySheetBody> {
  late final TextEditingController _ctrl;

  /// Quick-reply chips — same set as the mockup's Frame D. Tapping a
  /// chip *appends* (or replaces if the box is empty) so the parent
  /// can stack canned replies + a personal touch.
  static const _quickReplies = <String>[
    '🙏 Terima kasih',
    '✅ Akan saya coba',
    '❓ Butuh penjelasan lebih',
    '🗓️ Bisa kapan saja',
    '⏰ Mungkin minggu depan',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSend => _ctrl.text.trim().isNotEmpty;

  void _applyQuickReply(String text) {
    final existing = _ctrl.text.trim();
    final next = existing.isEmpty ? text : '$existing\n$text';
    _ctrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final azure = ColorUtils.brandAzure;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Balasan cepat', trailing: '· tap untuk pakai'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in _quickReplies)
                _QuickReplyChip(
                  label: q,
                  color: azure,
                  onTap: () => _applyQuickReply(q),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Label('Pesan'),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
            decoration: InputDecoration(
              hintText: 'Tulis balasan untuk wali kelas…',
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
                borderSide: BorderSide(color: azure, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),
          BottomSheetFooter(
            primaryLabel: 'Kirim Balasan',
            secondaryLabel: 'Batal',
            primaryColor: azure,
            primaryEnabled: _canSend,
            onPrimary: _canSend
                ? () => AppNavigator.pop(context, _ctrl.text.trim())
                : () {},
            onSecondary: () => AppNavigator.pop(context, null),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickReplyChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.30), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
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
