// RPP inline text editor view. Extracted from lesson_plan_detail_screen.dart.
// Shows a formatting toolbar and a full-screen text field for editing RPP content.
// Like the `<Editor>` component in a Vue SPA — receives content + emits changes.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Full-screen RPP text editor with a formatting toolbar.
///
/// Constructor params (like Vue props):
/// - [content]    — the current RPP text being edited
/// - [primaryColor] — brand colour for focus borders / shadows
/// - [onChanged]  — callback fired whenever the text changes (replaces setState in parent)
class RppEditorView extends StatelessWidget {
  final String content;
  final Color primaryColor;
  final ValueChanged<String> onChanged;

  const RppEditorView({
    super.key,
    required this.content,
    required this.primaryColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Formatting toolbar (buttons are stubs — formatting is plain text for now)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: ColorUtils.slate900.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _formatButton('B', Icons.format_bold),
                _formatButton('I', Icons.format_italic),
                _formatButton('U', Icons.format_underlined),
                _formatButton('H1', Icons.title),
                _formatButton('Table', Icons.table_chart),
                _formatButton('List', Icons.list),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: TextEditingController(text: content),
                onChanged: onChanged,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(AppSpacing.lg),
                  hintText: 'Ketik RPP disini...',
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Courier',
                  height: 1.5,
                  color: ColorUtils.slate800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Toolbar button stub — formatting is not yet wired to the text field.
  Widget _formatButton(String tooltip, IconData icon) {
    return IconButton(
      icon: Icon(icon, size: 20, color: ColorUtils.slate600),
      onPressed: () {},
      tooltip: tooltip,
    );
  }
}
