// Sticky bottom Save bar for the grade recap screen.
//
// Why this exists
// ---------------
// The recap screen needs a single, full-width primary action when
// the table is in edit mode (step 2 of the wizard). Export lives in
// the header and the `+` FAB owns add-chapter, leaving the bottom
// bar free to present a single Simpan affordance with an inline
// "unsaved changes" indicator.
//
// The widget is purely presentational — it takes the current saving
// flag, the unsaved-changes flag, the localizer, the primary tap
// handler, and a [GlobalKey] so the parent screen can anchor a
// product tour to it.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class GradeRecapSaveBar extends StatelessWidget {
  /// Tour anchor — the recap tour helper highlights this box when
  /// guiding a teacher to the Simpan button.
  final Key? saveKey;

  /// True while the network round-trip is in flight. Disables the
  /// button and swaps the icon for a spinner.
  final bool isSaving;

  /// True when the table has dirty state. Drives the small white
  /// dot next to the label.
  final bool hasUnsavedChanges;

  /// Tap handler. Ignored while [isSaving] is true.
  final VoidCallback onSave;

  final LanguageProvider lp;

  const GradeRecapSaveBar({
    super.key,
    this.saveKey,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.onSave,
    required this.lp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        key: saveKey,
        height: 52,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorUtils.success600,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorUtils.slate300,
            elevation: 2,
            shadowColor: ColorUtils.success600.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSaving
                    ? lp.getTranslatedText({
                        'en': 'Saving...',
                        'id': 'Menyimpan...',
                      })
                    : lp.getTranslatedText({'en': 'Save', 'id': 'Simpan'}),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              // Inline unsaved-changes indicator — small white dot next
              // to the label when there are pending changes.
              if (hasUnsavedChanges && !isSaving) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
