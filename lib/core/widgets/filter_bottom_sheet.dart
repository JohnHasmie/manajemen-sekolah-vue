// Base scaffold for filter bottom sheets with header, scrollable content,
// and Apply/Reset footer buttons.
//
// Replaces the identical structure in 6+ dedicated filter sheet files
// and 10+ inline showModalBottomSheet filter calls.
//
// Now composes DragHandle + BottomSheetFooter primitives.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';

/// A reusable bottom sheet scaffold with a premium gradient header,
/// scrollable content area, and a consistent footer.
class AppFilterBottomSheet extends StatelessWidget {
  /// Title displayed in the header bar.
  final String title;

  /// Optional subtitle in the header.
  final String? headerSubtitle;

  /// Leading icon for the header.
  final IconData icon;

  /// The filter options content (chips, dropdowns, etc.).
  final Widget content;

  /// Called when the user taps "Apply".
  final VoidCallback onApply;

  /// Called when the user taps "Reset".
  final VoidCallback onReset;

  /// Accent color.
  final Color? primaryColor;

  /// Maximum height as a fraction of screen height. Default: 0.75.
  ///
  /// The sheet uses `mainAxisSize.min` internally so short filter lists
  /// shrink-wrap naturally — this cap only kicks in when the content is
  /// tall enough to want the full viewport. The default 0.75 keeps the
  /// scrim visible and the drag handle reachable on smaller phones.
  final double maxHeightFactor;

  /// Label for the apply button.
  final String applyLabel;

  /// Label for the cancel button.
  final String cancelLabel;

  /// Label for the reset button.
  final String resetLabel;

  const AppFilterBottomSheet({
    super.key,
    required this.title,
    this.headerSubtitle,
    this.icon = Icons.tune_rounded,
    required this.content,
    required this.onApply,
    required this.onReset,
    this.primaryColor,
    this.maxHeightFactor = 0.75,
    this.applyLabel = 'Terapkan Filter',
    this.cancelLabel = 'Batal',
    this.resetLabel = 'Reset',
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? ColorUtils.getRoleColor('guru');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // SafeArea is INSIDE the white-backgrounded Container so the home
      // indicator on iPhone sits over the sheet's own white background
      // (instead of a dark scrim strip below the sheet). The button row
      // is pushed up by `MediaQuery.padding.bottom` so it never lands
      // under the home indicator, but visually the area below the
      // buttons reads as part of the same white panel rather than as
      // wasted padding.
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(
              title: title,
              subtitle: headerSubtitle,
              icon: icon,
              primaryColor: color,
              trailing: _buildResetButton(context),
            ),

            // Scrollable content
            //
            // Only a small 12 px top inset below the gradient bar — enough
            // for breathing room without an awkward gap. `FilterSectionHeader`
            // no longer contributes its own top padding (see its file), so
            // this value IS the gap between the green bar and the first
            // section title. Inter-section spacing is handled by
            // [TeacherFilterContent] (sectionSpacing) or an explicit SizedBox
            // in raw-Column callers.
            //
            // Bottom inset = 20 px. The footer only adds an 8 px top pad +
            // 1 px divider, so without this the last chip row would sit
            // ~9 px from the Apply button — cramped, and users flagged it
            // (see screenshot in #135). 20 px here gives a comfortable
            // ~29 px visual gap between the last filter row and the button
            // row without re-introducing the "too much bottom margin"
            // problem that #133 fixed.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: content,
              ),
            ),

            // Footer
            BottomSheetFooter(
              primaryLabel: applyLabel,
              secondaryLabel: cancelLabel,
              primaryColor: color,
              onPrimary: onApply,
              onSecondary: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return TextButton(
      onPressed: onReset,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        resetLabel,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Shows an [AppFilterBottomSheet] as a modal bottom sheet.
///
/// Returns a [Future] that completes when the sheet is dismissed.
///
/// [maxHeightFactor] defaults to 0.75 to match [AppFilterBottomSheet]'s own
/// default. The sheet shrink-wraps to its content and only hits this cap
/// when the filter list would otherwise overflow the viewport.
Future<T?> showFilterSheet<T>({
  required BuildContext context,
  required String title,
  required Widget content,
  required VoidCallback onApply,
  required VoidCallback onReset,
  Color? primaryColor,
  double maxHeightFactor = 0.75,
  String applyLabel = 'Terapkan',
  String resetLabel = 'Reset',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Intentionally NOT using `useSafeArea: true`. That wraps the sheet
    // in a SafeArea which pushes the whole sheet up by the home-indicator
    // height (≈34 px on iPhone) and leaves a matching strip of dark
    // scrim beneath it — visually identical to the "too much bottom
    // padding" problem users have been flagging. Letting the sheet run
    // edge-to-edge keeps the white footer flush with the screen bottom;
    // the semi-transparent home indicator can sit over the footer's
    // background without obscuring the buttons.
    builder: (_) => AppFilterBottomSheet(
      title: title,
      content: content,
      onApply: onApply,
      onReset: onReset,
      primaryColor: primaryColor,
      maxHeightFactor: maxHeightFactor,
      applyLabel: applyLabel,
      resetLabel: resetLabel,
    ),
  );
}
