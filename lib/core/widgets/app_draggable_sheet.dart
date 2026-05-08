// Shared draggable bottom-sheet helper for tall content surfaces
// (take/edit attendance, lesson detail, schedule detail, etc.).
//
// Use this when the body is rich enough that the user benefits from
// dragging the sheet up to read more without taking over the entire
// screen — the sheet caps at 96% of viewport height by default so the
// status bar still peeks through and "this is a sheet, not a screen"
// stays clear. For filter pickers keep using `AppFilterBottomSheet`;
// the draggable sheet is for detail / edit / form content only.
//
// Usage:
// ```dart
// await AppDraggableSheet.show<bool>(
//   context: context,
//   onClose: refreshList,
//   builder: (context, scrollController) => MyDetailWidget(
//     scrollController: scrollController,
//   ),
// );
// ```
//
// The widget passed to `builder` MUST drive its primary scrollable
// from the supplied `scrollController` (use it on the outermost
// scrollable inside the sheet — a `CustomScrollView`, `ListView`,
// `SingleChildScrollView`, etc.). Without that wiring the drag gesture
// fights with the inner scrollable and pulls don't smoothly extend
// the sheet.
import 'package:flutter/material.dart';

/// A modal bottom sheet that can be dragged taller (up to 96% of the
/// screen by default) but never goes fully full-screen. Drop-in
/// replacement for the bespoke `showModalBottomSheet` +
/// `DraggableScrollableSheet` blocks scattered across the codebase.
class AppDraggableSheet {
  AppDraggableSheet._();

  /// Default initial / min / max heights as a fraction of the viewport.
  /// Tuned to feel similar to the Ambil Presensi sheet:
  ///   • opens at 85% — enough to read header + KPI + several rows
  ///   • collapses to 50% — still useful when the user wants a peek
  ///   • caps at 96% — the brand bar/status bar still peeks above
  static const double defaultInitial = 0.85;
  static const double defaultMin = 0.5;
  static const double defaultMax = 0.96;

  /// Show the sheet.
  ///
  /// Returns the `Future` from `showModalBottomSheet` so callers can
  /// await dismissal and handle the optional pop value. If you don't
  /// need the value but still want a "refresh on close" callback, pass
  /// [onClose] — it fires once the sheet is dismissed regardless of
  /// the pop value.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(
      BuildContext context,
      ScrollController scrollController,
    )
    builder,
    double initialSize = defaultInitial,
    double minSize = defaultMin,
    double maxSize = defaultMax,
    bool isDismissible = true,
    bool enableDrag = true,
    VoidCallback? onClose,
    Color? barrierColor,
  }) {
    final future = showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      // Allow the sheet to expand all the way up to maxSize so drag
      // gestures aren't clipped at 50% of the screen.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxSize,
      ),
      barrierColor: barrierColor,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: initialSize,
        minChildSize: minSize,
        maxChildSize: maxSize,
        expand: false,
        builder: (innerContext, scrollController) =>
            builder(innerContext, scrollController),
      ),
    );
    if (onClose != null) {
      future.whenComplete(onClose);
    }
    return future;
  }
}
