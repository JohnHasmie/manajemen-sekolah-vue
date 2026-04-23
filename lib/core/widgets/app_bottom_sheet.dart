// Full-featured bottom sheet scaffold that composes DragHandle,
// BottomSheetHeader, scrollable content, and BottomSheetFooter.
//
// Replaces 40+ showModalBottomSheet boilerplate patterns by providing
// a single, consistent entry point for building bottom sheets.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/widgets/drag_handle.dart';

/// A fully composed bottom sheet with gradient header, scrollable
/// content area, and optional footer buttons.
///
/// Use the static [show] helper for the most common case:
/// ```dart
/// AppBottomSheet.show(
///   context: context,
///   title: 'Select Activity Type',
///   subtitle: 'Choose what you want to create',
///   icon: Icons.add_task_rounded,
///   primaryColor: Colors.blue,
///   content: MyContentWidget(),
/// );
/// ```
///
/// For sheets that need footer buttons:
/// ```dart
/// AppBottomSheet.show(
///   context: context,
///   title: 'Filter Attendance',
///   icon: Icons.filter_list,
///   primaryColor: Colors.teal,
///   content: FilterChipsWidget(),
///   footer: BottomSheetFooter(
///     primaryLabel: 'Terapkan',
///     secondaryLabel: 'Reset',
///     primaryColor: Colors.teal,
///     onPrimary: () => _apply(),
///     onSecondary: () => _reset(),
///   ),
/// );
/// ```
class AppBottomSheet extends StatelessWidget {
  /// Title displayed in the gradient header.
  final String title;

  /// Optional subtitle below the title.
  final String? subtitle;

  /// Header icon.
  final IconData icon;

  /// Gradient base color for the header.
  final Color primaryColor;

  /// The scrollable body content.
  final Widget content;

  /// Optional footer widget (typically a [BottomSheetFooter]).
  /// When null, no footer is shown.
  final Widget? footer;

  /// Optional trailing widget for the header (e.g., a Reset button).
  final Widget? headerTrailing;

  /// Maximum height as a fraction of screen height. Default: 0.85.
  final double maxHeightFactor;

  /// Border radius for the top corners. Default: 24.
  final double borderRadius;

  /// Whether the content area is scrollable. Default: true.
  final bool scrollable;

  /// Padding around the content area.
  final EdgeInsetsGeometry contentPadding;

  /// Whether to use a simple header (drag handle + plain title)
  /// instead of the gradient header. Default: false.
  final bool simpleHeader;

  const AppBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.primaryColor,
    required this.content,
    this.footer,
    this.headerTrailing,
    this.maxHeightFactor = 0.85,
    this.borderRadius = 24,
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(20),
    this.simpleHeader = false,
  });

  /// Shows this bottom sheet as a modal.
  ///
  /// Returns a [Future] that completes when the sheet is dismissed.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color primaryColor,
    required Widget content,
    Widget? footer,
    Widget? headerTrailing,
    double maxHeightFactor = 0.85,
    double borderRadius = 24,
    bool scrollable = true,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.all(20),
    bool simpleHeader = false,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (_) => AppBottomSheet(
        title: title,
        subtitle: subtitle,
        icon: icon,
        primaryColor: primaryColor,
        content: content,
        footer: footer,
        headerTrailing: headerTrailing,
        maxHeightFactor: maxHeightFactor,
        borderRadius: borderRadius,
        scrollable: scrollable,
        contentPadding: contentPadding,
        simpleHeader: simpleHeader,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius)),
      ),
      // SafeArea lives INSIDE the white-backgrounded Container so the
      // iPhone home indicator sits over the sheet's own white background
      // (not a dark scrim strip below the sheet). The footer row is
      // pushed up out of the home-indicator zone, but visually reads as
      // part of the same white panel rather than as wasted padding.
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_header(context), _body(), _footerOrSafeArea(context)],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    if (simpleHeader) {
      return _SimpleSheetHeader(
        title: title,
        onClose: () => Navigator.pop(context),
      );
    }
    return BottomSheetHeader(
      title: title,
      subtitle: subtitle,
      icon: icon,
      primaryColor: primaryColor,
      borderRadius: borderRadius,
      trailing: headerTrailing,
    );
  }

  Widget _body() {
    if (scrollable) {
      return Flexible(
        child: SingleChildScrollView(padding: contentPadding, child: content),
      );
    }
    return Flexible(
      child: Padding(padding: contentPadding, child: content),
    );
  }

  Widget _footerOrSafeArea(BuildContext context) {
    if (footer != null) return footer!;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).padding.bottom > 0 ? 0 : 12,
      ),
    );
  }
}

/// Simple header: drag handle + title + close button.
class _SimpleSheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _SimpleSheetHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DragHandle(),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _closeButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _closeButton() {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
      ),
    );
  }
}
