// Sticky bottom Save bar for the grade recap screen.
//
// Why this exists
// ---------------
// The recap screen needs a primary action and a secondary "add bab"
// action while the table is in edit mode (step 2 of the wizard).
// Export lives in the header.
//
// SS4-HH change: previously the add-bab action was a floating
// FloatingActionButton anchored at the bottom-right that covered the
// rightmost cells of the matrix table. Teachers couldn't see / tap the
// last student row without scrolling. The FAB is gone; this bar now
// hosts both actions side-by-side, so the table stays unobscured.
//
// The widget is purely presentational — it takes the current saving
// flag, the unsaved-changes flag, the localizer, the primary tap
// handler, an `onAddChapter` callback, and two [GlobalKey]s so the
// parent screen can anchor product tours to each button.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class GradeRecapSaveBar extends StatelessWidget {
  /// Tour anchor — the recap tour helper highlights this box when
  /// guiding a teacher to the Simpan button.
  final Key? saveKey;

  /// Tour anchor for the add-bab button (left side of the bar).
  final Key? addChapterKey;

  /// True while the network round-trip is in flight. Disables the
  /// button and swaps the icon for a spinner.
  final bool isSaving;

  /// True when the table has dirty state. Drives the small white
  /// dot next to the label.
  final bool hasUnsavedChanges;

  /// Tap handler. Ignored while [isSaving] is true.
  final VoidCallback onSave;

  /// Tap handler for the inline add-bab button. When null, the button
  /// is hidden and Simpan stretches full-width (back-compat).
  final VoidCallback? onAddChapter;

  final LanguageProvider lp;

  const GradeRecapSaveBar({
    super.key,
    this.saveKey,
    this.addChapterKey,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.onSave,
    this.onAddChapter,
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
      child: Row(
        children: [
          if (onAddChapter != null) ...[
            _AddBabButton(
              tourKey: addChapterKey,
              onPressed: isSaving ? null : onAddChapter,
              lp: lp,
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: _buildSaveButton()),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      key: saveKey,
      height: 52,
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
              isSaving ? kGraSaving.tr : kSave.tr,
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
    );
  }
}

/// Solid-cobalt "Tambah Bab" button rendered to the left of the
/// Simpan action. Square-ish 52×52 so it visually pairs with the Save
/// button height without crowding the bar. Filled background + white
/// icon matches the original FAB the bar replaced, so the action
/// reads as primary even though Simpan takes the bigger slot.
class _AddBabButton extends StatelessWidget {
  final Key? tourKey;
  final VoidCallback? onPressed;
  final LanguageProvider lp;

  const _AddBabButton({
    required this.tourKey,
    required this.onPressed,
    required this.lp,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final tooltip = kGraAddChapter.tr;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        key: tourKey,
        width: 56,
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: cobalt,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorUtils.slate300,
            elevation: 2,
            shadowColor: cobalt.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Icon(Icons.add_rounded, size: 26),
        ),
      ),
    );
  }
}
