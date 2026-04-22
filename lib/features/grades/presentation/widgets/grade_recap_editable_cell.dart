import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Compact editable score cell matching Buku Nilai style.
/// Shows score-colored text + small history icon for grade selection.
///
/// Supports keyboard navigation between rows:
/// - **Enter** / **NumpadEnter** → commit value, jump to the cell directly
///   below (same column). On mobile this is wired to the IME's "Next" button.
/// - **ArrowDown** → jump to the cell directly below.
/// - **ArrowUp** → jump to the cell directly above.
///
/// Intercepting arrow keys also sidesteps a Flutter assertion
/// (`VerticalCaretMovementRun.moveNext` → `isValid`) that fires when the
/// framework's default vertical-caret-movement action runs against a
/// single-line [TextField].
class GradeRecapEditableCell extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<double> onChanged;
  final VoidCallback onHistoryTap;

  /// Focus node for this cell's [TextField]. Optional — when null, the
  /// cell still renders but keyboard navigation is disabled.
  final FocusNode? focusNode;

  /// Invoked on Enter / ArrowDown. The parent looks up the cell directly
  /// below (same column, next row) and calls `requestFocus` on it. `null`
  /// when this is the last row.
  final VoidCallback? onMoveDown;

  /// Invoked on ArrowUp. `null` when this is the first row.
  final VoidCallback? onMoveUp;

  const GradeRecapEditableCell({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onHistoryTap,
    this.focusNode,
    this.onMoveDown,
    this.onMoveUp,
  });

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  /// Intercepts vertical-movement keys BEFORE Flutter's default text-editing
  /// actions run. Returning [KeyEventResult.handled] stops the framework
  /// from invoking `VerticalCaretMovementRun.moveNext`, which asserts on
  /// single-line fields.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      onMoveDown?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      onMoveUp?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the controller text changes so the color + icon
    // opacity reflect the current value.
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasValue = controller.text.trim().isNotEmpty;
        final score = double.tryParse(controller.text) ?? 0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: Focus(
                // `onKeyEvent` on the Focus ancestor runs BEFORE the
                // EditableText's own handler, so our arrow-down/up
                // interception wins the race against the framework's
                // default vertical-caret-movement action.
                onKeyEvent: _handleKey,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_ScoreRangeFormatter()],
                  // IME "Next" button on soft keyboards jumps to the row
                  // below. Fires `onSubmitted`, which we forward to
                  // [onMoveDown].
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: hasValue
                        ? _scoreColor(score)
                        : ColorUtils.slate300,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none,
                    hintText: '–',
                    hintStyle: TextStyle(
                      color: ColorUtils.slate300,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  onChanged: (val) =>
                      onChanged(double.tryParse(val) ?? 0.0),
                  onSubmitted: (_) => onMoveDown?.call(),
                ),
              ),
            ),
            // History / bulk-select affordance. Kept very subtle when the
            // cell is empty so the table doesn't look busy with `- ▾` noise
            // across every row.
            InkResponse(
              onTap: onHistoryTap,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: hasValue
                      ? ColorUtils.slate500
                      : ColorUtils.slate200,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Keeps score input inside the 0–100 band.
///
/// Rejects the pending edit (returns [oldValue]) if the text parses to a
/// number greater than 100 or less than 0. Empty strings, lone `.` and
/// partial decimals like `9.` are allowed so the teacher can keep typing.
class _ScoreRangeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Allow in-progress decimals ("9.", ".5") — we can't parse them yet
    // but they'll reach a valid state on the next keystroke.
    if (text == '.' || text.endsWith('.')) return newValue;

    final parsed = double.tryParse(text);
    if (parsed == null) return oldValue; // non-numeric — reject
    if (parsed < 0 || parsed > 100) return oldValue;

    return newValue;
  }
}
