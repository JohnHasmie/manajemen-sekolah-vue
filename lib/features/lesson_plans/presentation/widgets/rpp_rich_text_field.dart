// A Quill rich-text editor card for one RPP content section.
// Like a Vue <QuillEditor> wrapper — takes a QuillController prop
// and renders a toolbar + editor without touching parent state.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Decorated Quill editor card (toolbar + 200px editor area).
///
/// [controller] is the QuillController owned by the parent screen —
/// like passing a `v-model` reference down to a Vue child component.
class RppRichTextField extends StatelessWidget {
  final quill.QuillController controller;

  const RppRichTextField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Toolbar clipped so it respects the card's rounded top corners
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showInlineCode: false,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: false,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
              ),
            ),
          ),
          Divider(height: 1, color: ColorUtils.slate200),
          Container(
            height: 200,
            padding: EdgeInsets.all(AppSpacing.lg),
            child: quill.QuillEditor.basic(
              controller: controller,
              config: const quill.QuillEditorConfig(),
            ),
          ),
        ],
      ),
    );
  }
}
