import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_table_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_logic_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_helpers_mixin.dart';

mixin GradeTableUiMixin
    on State<GradeTableWidget>, GradeTableLogicMixin, GradeTableHelpersMixin {
  static const double headerH = 48;
  static const double rowH = 42;

  String? get editingKey;
  TextEditingController get editController;
  FocusNode get editFocus;
  String? get errorMessage;
  int get editingStudentIdx;
  int get editingColIdx;

  // Methods that must be provided by implementing class
  void startEditing(Student student, ColDef col, List<ColDef> cols);
  Future<void> finishAndMove(
    int nextStudentIdx,
    int nextColIdx,
    List<ColDef> cols,
  );

  // Access static constants from GradeTableLogicMixin
  double get cellW => GradeTableLogicMixin.cellW;
  double get nameW => GradeTableLogicMixin.nameW;

  /// Builds student name column on left side
  Widget nameColumn() {
    return Container(
      width: nameW,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Column(children: [buildNameColumnHeader(), ...buildNameRows()]),
    );
  }

  Widget buildNameColumnHeader() {
    return Container(
      height: headerH,
      width: nameW,
      padding: const EdgeInsets.only(left: 10),
      alignment: Alignment.centerLeft,
      color: widget.primaryColor,
      child: const Text(
        'Siswa',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Iterable<Widget> buildNameRows() {
    return widget.filteredStudentList.asMap().entries.map((e) {
      final i = e.key;
      return Container(
        height: rowH,
        width: nameW,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: i.isEven ? Colors.white : ColorUtils.slate50,
          border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
        ),
        child: buildNameRowContent(i, e.value.name),
      );
    });
  }

  Row buildNameRowContent(int index, String name) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate400,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Builds header row with assessment type labels and dates
  Widget headerRow(List<ColDef> cols, double contentWidth) {
    return Container(
      height: headerH,
      color: widget.primaryColor,
      child: Row(children: cols.map(buildHeaderCell).toList()),
    );
  }

  Widget buildHeaderCell(ColDef c) {
    if (c.isPlaceholder) {
      return buildPlaceholderHeaderCell(c);
    }
    return buildDataHeaderCell(c);
  }

  Widget buildPlaceholderHeaderCell(ColDef c) {
    final label = c.type.isNotEmpty ? short(c.type) : '';
    return Container(
      width: cellW,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: label.isNotEmpty
          ? Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }

  Widget buildDataHeaderCell(ColDef c) {
    final dFmt = formatHeaderDate(c.header['date'] as String);
    final label = '${short(c.type)} ${c.index + 1}';

    return InkWell(
      onTap: () => widget.onColumnTap(c.type, c.header),
      child: Container(
        width: cellW,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        child: buildHeaderCellContent(label, dFmt),
      ),
    );
  }

  String formatHeaderDate(String date) {
    final parts = date.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : date;
  }

  Column buildHeaderCellContent(String label, String dateFmt) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
        const SizedBox(height: 1),
        Text(
          dateFmt,
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Builds single data row for a student
  Widget dataRow(
    int index,
    Student student,
    List<ColDef> cols,
    double contentWidth,
  ) {
    return Container(
      height: rowH,
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(
        children: cols.map((c) {
          if (c.isPlaceholder) {
            return Container(
              width: cellW,
              decoration: BoxDecoration(
                color: ColorUtils.slate50.withValues(alpha: 0.3),
                border: Border(
                  right: BorderSide(
                    color: ColorUtils.slate100.withValues(alpha: 0.3),
                  ),
                ),
              ),
            );
          }

          final key = cellKey(student, c.type, c.index);
          final isEditing = editingKey == key;

          if (isEditing) {
            return editCell(cols);
          }

          final rec = getGrade(student, c.type, c.header);
          final hasVal = rec?.isNotEmpty == true;
          final score = hasVal ? (rec!['score'] as num?)?.toDouble() : null;
          final txt = hasVal ? fmt(rec!['score']) : '-';

          return GestureDetector(
            onTap: () => startEditing(student, c, cols),
            child: Container(
              width: cellW,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: ColorUtils.slate100.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Text(
                txt,
                style: TextStyle(
                  fontSize: hasVal ? 13 : 10,
                  fontWeight: hasVal ? FontWeight.w700 : FontWeight.w400,
                  color: score != null
                      ? scoreColor(score)
                      : ColorUtils.slate300,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Builds inline edit cell with error handling
  Widget editCell(List<ColDef> cols) {
    final hasError = errorMessage != null;
    final borderColor = hasError ? ColorUtils.error600 : widget.primaryColor;

    return Container(
      width: cellW,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: hasError
            ? ColorUtils.error600.withValues(alpha: 0.06)
            : widget.primaryColor.withValues(alpha: 0.06),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildEditTextField(cols, hasError),
          if (errorMessage != null) buildErrorMessage(),
        ],
      ),
    );
  }

  Widget buildEditTextField(List<ColDef> cols, bool hasError) {
    return SizedBox(
      height: hasError ? 22 : 30,
      child: TextField(
        controller: editController,
        focusNode: editFocus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: hasError ? ColorUtils.error600 : widget.primaryColor,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none,
        ),
        onSubmitted: (_) =>
            finishAndMove(editingStudentIdx + 1, editingColIdx, cols),
        onTapOutside: (_) => finishAndMove(-1, -1, cols),
      ),
    );
  }

  Widget buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(
        errorMessage!,
        style: TextStyle(
          fontSize: 6,
          color: ColorUtils.error600,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
