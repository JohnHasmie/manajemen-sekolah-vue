// Lesson plan regeneration prompt sheets.
//
// Replaces the previous `showDialog(AlertDialog)` implementation in
// `lesson_plan_regen_dialogs.dart` with the canonical
// drag-handle → gradient header → scrollable body → Samsung-safe footer
// bottom-sheet shell provided by [AppBottomSheet] + [BottomSheetFooter].
//
// Two static entry points are exposed so callers can keep passing these
// methods as tear-offs to the regeneration mixin without changing call
// sites:
//
//   • [LessonPlanRegenSheet.getAdditionalInstructions] — single-field
//     prompt. Returns the (possibly empty) additional-instructions text
//     when the user confirms, or null when the sheet is dismissed.
//   • [LessonPlanRegenSheet.showRegenAllDialog] — regenerate-all prompt.
//     Returns `true` when the user confirms, or null on dismissal.
//
// The previously-unused `showRegenFieldDialog` (returning Future<bool?>)
// was removed; grep for its name confirmed no callers.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// Bottom-sheet prompts for lesson-plan AI regeneration.
class LessonPlanRegenSheet {
  const LessonPlanRegenSheet._();

  /// Prompts the user for optional additional instructions before
  /// regenerating a single RPP field.
  ///
  /// Signature is kept positional (not named) so the method can be passed
  /// as a tear-off matching the mixin contract:
  /// `Future<String?> Function(BuildContext, String, int, int, Color)`.
  static Future<String?> getAdditionalInstructions(
    BuildContext context,
    String fieldLabel,
    int remaining,
    int maxAttempts,
    Color primaryColor,
  ) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RegenFieldSheet(
        fieldLabel: fieldLabel,
        remaining: remaining,
        maxAttempts: maxAttempts,
        primaryColor: primaryColor,
      ),
    );
  }

  /// Prompts the user to confirm regenerating every RPP field at once.
  ///
  /// Signature is kept positional so the method can be passed as a
  /// tear-off matching the mixin contract:
  /// `Future<bool?> Function(BuildContext, Color)`.
  static Future<bool?> showRegenAllDialog(
    BuildContext context,
    Color primaryColor,
  ) {
    return showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RegenAllSheet(primaryColor: primaryColor),
    );
  }
}

/// Sheet body for the single-field regeneration prompt.
///
/// Stateful so the [TextEditingController] can be disposed when the
/// sheet is popped, and so the footer action has access to the current
/// text value.
class _RegenFieldSheet extends StatefulWidget {
  final String fieldLabel;
  final int remaining;
  final int maxAttempts;
  final Color primaryColor;

  const _RegenFieldSheet({
    required this.fieldLabel,
    required this.remaining,
    required this.maxAttempts,
    required this.primaryColor,
  });

  @override
  State<_RegenFieldSheet> createState() => _RegenFieldSheetState();
}

class _RegenFieldSheetState extends State<_RegenFieldSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: '${kRegenerate.tr} ${widget.fieldLabel}',
      subtitle:
          '${kLesPlaRemainingRegens.tr} ${widget.remaining} dari ${widget.maxAttempts}',
      icon: Icons.auto_awesome_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.7,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kLesPlaAddInstructionsPrompt.tr,
            style: TextStyle(
              fontSize: 13,
              color: ColorUtils.slate500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InstructionField(
            controller: _controller,
            primaryColor: widget.primaryColor,
            hint: 'Mis. "Gunakan contoh konkret untuk kelas 5 SD"',
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: AppLocalizations.regenerate.tr,
        secondaryLabel: AppLocalizations.cancel.tr,
        primaryColor: widget.primaryColor,
        onPrimary: () => AppNavigator.pop<String>(context, _controller.text),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

/// Sheet body for the regenerate-all prompt.
class _RegenAllSheet extends StatefulWidget {
  final Color primaryColor;

  const _RegenAllSheet({required this.primaryColor});

  @override
  State<_RegenAllSheet> createState() => _RegenAllSheetState();
}

class _RegenAllSheetState extends State<_RegenAllSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: kLesPlaRegenerateAllFields.tr,
      subtitle: kLesPlaRegenerateAllSubtitle.tr,
      icon: Icons.auto_awesome_rounded,
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.7,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.primaryColor.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: widget.primaryColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    kLesPlaRegenerateAllWarning.tr,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: ColorUtils.slate700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InstructionField(
            controller: _controller,
            primaryColor: widget.primaryColor,
            hint: 'Instruksi untuk seluruh RPP (opsional)',
          ),
        ],
      ),
      footer: BottomSheetFooter(
        primaryLabel: AppLocalizations.regenerateAll.tr,
        secondaryLabel: AppLocalizations.cancel.tr,
        primaryColor: widget.primaryColor,
        // The existing mixin only checks `confirmed == true` before kicking
        // off regeneration, so we signal confirmation with `true`. The
        // optional instructions typed here are currently not threaded
        // through `regenerateAllFields`; a future pass can forward them.
        onPrimary: () => AppNavigator.pop<bool>(context, true),
        onSecondary: () => AppNavigator.pop(context),
      ),
    );
  }
}

/// Shared multiline text field with the regen sheets' styling.
class _InstructionField extends StatelessWidget {
  final TextEditingController controller;
  final Color primaryColor;
  final String hint;

  const _InstructionField({
    required this.controller,
    required this.primaryColor,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 3,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }
}
