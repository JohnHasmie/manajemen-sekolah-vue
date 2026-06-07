// Shared rich-text Quill editor component with custom-designed toolbar.
// Professional UI with a branded compact toolbar and styled editor area.
// Used by: recommendation edit, RPP section editor, and any future rich-text
// needs.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A polished, reusable Quill rich-text editor with a custom toolbar.
///
/// The toolbar uses our design system instead of the default Quill toolbar.
/// Accent color tints the active formatting buttons and can be customized
/// per context (e.g. priority color, section color).
class AppQuillEditor extends StatefulWidget {
  /// The Quill controller that manages the document and selection.
  final quill.QuillController controller;

  /// Accent color used for active toolbar button highlights.
  final Color? accentColor;

  /// Placeholder text shown when the editor is empty.
  final String placeholder;

  /// Minimum height of the editor area (excluding toolbar).
  final double minHeight;

  /// Maximum height of the editor area (excluding toolbar).
  final double maxHeight;

  /// Whether to show the toolbar. Defaults to true.
  final bool showToolbar;

  /// Whether the editor is read-only. Defaults to false.
  final bool readOnly;

  /// Optional border radius override for the outer container.
  final double borderRadius;

  const AppQuillEditor({
    super.key,
    required this.controller,
    this.accentColor,
    this.placeholder = 'Tulis konten...',
    this.minHeight = 120,
    this.maxHeight = 200,
    this.showToolbar = true,
    this.readOnly = false,
    this.borderRadius = 10,
  });

  @override
  State<AppQuillEditor> createState() => _AppQuillEditorState();
}

class _AppQuillEditorState extends State<AppQuillEditor> {
  Color get _accent => widget.accentColor ?? ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    // Rebuild to update toolbar active states
    if (mounted) setState(() {});
  }

  bool _isFormatActive(quill.Attribute attribute) {
    final attrs = widget.controller.getSelectionStyle().attributes;
    if (attribute.key == quill.Attribute.list.key) {
      return attrs[attribute.key]?.value == attribute.value;
    }
    return attrs.containsKey(attribute.key);
  }

  void _toggleFormat(quill.Attribute attribute) {
    if (_isFormatActive(attribute)) {
      widget.controller.formatSelection(quill.Attribute.clone(attribute, null));
    } else {
      widget.controller.formatSelection(attribute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(widget.borderRadius)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [if (widget.showToolbar) _buildToolbar(), _buildEditor()],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Row(
        children: [
          // Undo / Redo
          _buildToolbarButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onTap: () => widget.controller.undo(),
            isActive: false,
          ),
          _buildToolbarButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo',
            onTap: () => widget.controller.redo(),
            isActive: false,
          ),

          _toolbarDivider(),

          // Text formatting
          _buildToolbarButton(
            icon: Icons.format_bold_rounded,
            tooltip: 'Bold',
            onTap: () => _toggleFormat(quill.Attribute.bold),
            isActive: _isFormatActive(quill.Attribute.bold),
          ),
          _buildToolbarButton(
            icon: Icons.format_italic_rounded,
            tooltip: 'Italic',
            onTap: () => _toggleFormat(quill.Attribute.italic),
            isActive: _isFormatActive(quill.Attribute.italic),
          ),
          _buildToolbarButton(
            icon: Icons.format_underlined_rounded,
            tooltip: 'Underline',
            onTap: () => _toggleFormat(quill.Attribute.underline),
            isActive: _isFormatActive(quill.Attribute.underline),
          ),

          _toolbarDivider(),

          // Lists
          _buildToolbarButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: 'Bullet List',
            onTap: () => _toggleFormat(quill.Attribute.ul),
            isActive: _isFormatActive(quill.Attribute.ul),
          ),
          _buildToolbarButton(
            icon: Icons.format_list_numbered_rounded,
            tooltip: 'Numbered List',
            onTap: () => _toggleFormat(quill.Attribute.ol),
            isActive: _isFormatActive(quill.Attribute.ol),
          ),

          _toolbarDivider(),

          // Clear format
          _buildToolbarButton(
            icon: Icons.format_clear_rounded,
            tooltip: kCorWidClearFormat.tr,
            onTap: () {
              final selection = widget.controller.selection;
              if (!selection.isCollapsed) {
                // Remove all inline styles
                for (final attr in [
                  quill.Attribute.bold,
                  quill.Attribute.italic,
                  quill.Attribute.underline,
                ]) {
                  widget.controller.formatSelection(
                    quill.Attribute.clone(attr, null),
                  );
                }
              }
            },
            isActive: false,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isActive
                  ? _accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? _accent : ColorUtils.slate500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbarDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: ColorUtils.slate200,
    );
  }

  Widget _buildEditor() {
    return Container(
      constraints: BoxConstraints(
        minHeight: widget.minHeight,
        maxHeight: widget.maxHeight,
      ),
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: quill.QuillEditor.basic(
        controller: widget.controller,
        config: quill.QuillEditorConfig(
          placeholder: widget.placeholder,
          padding: EdgeInsets.zero,
          showCursor: !widget.readOnly,
          customStyles: quill.DefaultStyles(
            paragraph: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: 13.5,
                color: ColorUtils.slate700,
                height: 1.6,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 4),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
            placeHolder: quill.DefaultTextBlockStyle(
              TextStyle(
                fontSize: 13.5,
                color: ColorUtils.slate400,
                fontStyle: FontStyle.italic,
              ),
              const quill.HorizontalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              const quill.VerticalSpacing(0, 0),
              null,
            ),
          ),
        ),
      ),
    );
  }
}
