// Editable grade input cell for the recap table (step 2 of the wizard).
// Like a Vue `<GradeCell>` component — a number TextField with a history icon
// that lets teachers pick from past grades without touching parent state directly.
//
// Extracted from `_buildEditableGradeCell` in `teacher_grade_recap_screen.dart`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single editable number cell in the grade recap spreadsheet.
///
/// Wraps a [TextField] for manual numeric input and adds a history-icon button
/// that triggers [onHistoryTap] so the parent can show a grade-selection dialog.
/// The [onChanged] callback fires with the parsed double whenever the user types,
/// allowing the parent to update its data model and recalculate the final score.
///
/// In Laravel terms: one editable cell inside `GradeRecapController@index` view.
class GradeRecapEditableCell extends StatelessWidget {
  /// The [TextEditingController] owned by the parent state (keyed by
  /// `'$studentClassId|$type|${chapterIndex ?? "null"}'`).
  final TextEditingController controller;

  /// Called with the parsed [double] value each time the text changes.
  /// The parent uses this to update its table data and recalculate row totals.
  final ValueChanged<double> onChanged;

  /// Called when the user taps the history icon button.
  /// The parent should show a grade-selection dialog at this point.
  final VoidCallback onHistoryTap;

  const GradeRecapEditableCell({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          border: OutlineInputBorder(),
          // History icon lets the teacher pick from previous grade entries.
          // Like a Vue slot that opens a modal on click.
          suffixIcon: InkWell(
            onTap: onHistoryTap,
            child: Icon(Icons.history, size: 14, color: ColorUtils.slate400),
          ),
          suffixIconConstraints: BoxConstraints(minWidth: 24, minHeight: 24),
        ),
        onChanged: (val) {
          // Parse to double; default to 0.0 for non-numeric input.
          // Like a Vue computed setter that coerces user input.
          onChanged(double.tryParse(val) ?? 0.0);
        },
      ),
    );
  }
}
