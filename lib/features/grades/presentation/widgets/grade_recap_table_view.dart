// Horizontally scrollable recap table with a frozen left column (student
// names) and a scrollable right section (chapter scores, UTS, UAS, Final,
// Skill, Predikat, Deskripsi).
//
// Renders inside GradeRecapPage detail view when `currentStep == 2`
// (table mode).
//
// Layout is delegated to the shared `FrozenColumnTable` scaffold in
// `lib/core/widgets/frozen_column_table.dart`. This widget is now only
// responsible for:
//   • Composing the chapter + summary columns for the right side
//   • Building the primary-colored "Siswa" left header and student rows
//   • Wiring the caller's cell builders (editable score cells) per column
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/frozen_column_table.dart';

class GradeRecapTableView extends StatelessWidget {
  final List<Map<String, dynamic>> tableData;
  final List<dynamic> chapters;
  final Map<String, TextEditingController> scoreControllers;
  final Map<String, TextEditingController> predikatControllers;
  final Map<String, TextEditingController> descriptionControllers;
  final Color primaryColor;
  final Map<String, String> labels;

  /// Builds an editable cell for a given type/chapter.
  /// Types: 'bab' (chapterIndex required), 'uts', 'uas', 'skill_score'.
  final Widget Function(String studentClassId, String type, int? chapterIndex)
  cellBuilder;

  /// Fires when a bab, UTS, or UAS header is tapped (bulk select).
  final void Function(String type, int? chapterIndex) onBulkSelect;

  /// Fires when a chapter delete (×) is tapped.
  final ValueChanged<int> onDeleteChapter;

  /// Fires when a chapter header is tapped — opens a rename dialog
  /// for that bab. Always available, including when the table only
  /// has a single chapter (in which case [onDeleteChapter] is hidden
  /// because deleting the last column would leave nothing to grade
  /// against).
  final ValueChanged<int> onEditChapter;

  /// Fires when a student's description cell is tapped.
  final void Function(String studentClassId, String studentName) onDeskripsiTap;

  const GradeRecapTableView({
    super.key,
    required this.tableData,
    required this.chapters,
    required this.scoreControllers,
    required this.predikatControllers,
    required this.descriptionControllers,
    required this.primaryColor,
    required this.labels,
    required this.cellBuilder,
    required this.onBulkSelect,
    required this.onDeleteChapter,
    required this.onEditChapter,
    required this.onDeskripsiTap,
  });

  // ── Layout constants ──────────────────────────────────────────────────────
  static const double _leftWidth = 150.0;
  static const double _headerHeight = 52.0;
  static const double _rowHeight = 44.0;

  static const double _gradeCellWidth = 90.0;
  static const double _finalScoreWidth = 60.0;
  static const double _predikatWidth = 56.0;
  static const double _deskripsiWidth = 160.0;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FrozenColumnTable(
      rowCount: tableData.length,
      leftColumns: [
        FrozenTableColumn(
          width: _leftWidth,
          header: _buildLeftHeader(),
          cellBuilder: _buildLeftCell,
        ),
      ],
      rightColumns: _buildRightColumns(),
      headerHeight: _headerHeight,
      rowHeight: _rowHeight,
      headerBackgroundColor: primaryColor,
      showLeftColumnShadow: true,
    );
  }

  // ── Left column ──────────────────────────────────────────────────────────

  /// Scaffold paints `headerBackgroundColor` across the entire header row,
  /// so this widget just contributes alignment + padding + text.
  Widget _buildLeftHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: const Text(
        'Siswa',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildLeftCell(int index) {
    final row = tableData[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          // Fixed, right-aligned index slot so single/double-digit numbers
          // line up cleanly.
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.slate400,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row['nama'] ?? '-',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate800,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Right columns ────────────────────────────────────────────────────────

  List<FrozenTableColumn> _buildRightColumns() {
    final cols = <FrozenTableColumn>[
      for (int i = 0; i < chapters.length; i++) _babColumn(i),
      _summaryColumn(
        label: 'UTS',
        width: _gradeCellWidth,
        onHeaderTap: () => onBulkSelect('uts', null),
        cellType: 'uts',
      ),
      _summaryColumn(
        label: 'UAS',
        width: _gradeCellWidth,
        onHeaderTap: () => onBulkSelect('uas', null),
        cellType: 'uas',
      ),
      // Final score — read-only, derived from stored value.
      FrozenTableColumn(
        width: _finalScoreWidth,
        header: _plainHeader(labels['finalLabel'] ?? 'Final'),
        cellBuilder: _buildFinalScoreCell,
      ),
      // Skill score — editable.
      FrozenTableColumn(
        width: _finalScoreWidth,
        header: _plainHeader(labels['skillLabel'] ?? 'Skill'),
        cellBuilder: (i) => cellBuilder(
          tableData[i]['student_class_id'] as String,
          'skill_score',
          null,
        ),
      ),
      // Predikat — text field.
      FrozenTableColumn(
        width: _predikatWidth,
        header: _plainHeader(labels['gradeLabel'] ?? 'Nilai'),
        cellBuilder: _buildPredikatCell,
      ),
      // Deskripsi — tap-to-edit.
      FrozenTableColumn(
        width: _deskripsiWidth,
        header: _plainHeader(labels['descLabel'] ?? 'Desk.'),
        cellBuilder: _buildDeskripsiCell,
      ),
    ];
    return cols;
  }

  FrozenTableColumn _babColumn(int chapterIndex) {
    return FrozenTableColumn(
      width: _gradeCellWidth,
      header: _babHeader(chapterIndex),
      cellBuilder: (i) => cellBuilder(
        tableData[i]['student_class_id'] as String,
        'bab',
        chapterIndex,
      ),
    );
  }

  FrozenTableColumn _summaryColumn({
    required String label,
    required double width,
    required VoidCallback onHeaderTap,
    required String cellType,
  }) {
    return FrozenTableColumn(
      width: width,
      header: _tappableHeader(label, onHeaderTap),
      cellBuilder: (i) => cellBuilder(
        tableData[i]['student_class_id'] as String,
        cellType,
        null,
      ),
    );
  }

  // ── Right-side header builders ───────────────────────────────────────────

  Widget _plainHeader(String label) {
    return Container(
      decoration: _headerBorderDecoration(),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tappableHeader(String label, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: _plainHeader(label));
  }

  Widget _babHeader(int i) {
    final title = _chapterTitle(i);
    final canDelete = chapters.length > 1;

    // Tapping the header itself renames the chapter — that's the
    // edit affordance. Delete remains a separate × icon top-right
    // and is only shown when there's more than one bab (deleting
    // the last column would leave the table with no grade slots).
    return InkWell(
      onTap: () => onEditChapter(i),
      child: Container(
        decoration: _headerBorderDecoration(),
        child: Stack(
          children: [
            Padding(
              // Reserve room on both sides for the edit pencil
              // (always shown, left) and the delete × (when >1, right).
              padding: EdgeInsets.only(
                left: 18,
                right: canDelete ? 18 : 6,
                top: 6,
                bottom: 6,
              ),
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Edit pencil — always visible, including when there's
            // only one bab (which is the case the user reported as
            // "no edit button at all"). Tapping it does the same
            // thing as tapping the header: opens the rename sheet.
            Positioned(
              top: 2,
              left: 2,
              child: InkResponse(
                radius: 14,
                onTap: () => onEditChapter(i),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            if (canDelete)
              Positioned(
                top: 2,
                right: 2,
                child: InkResponse(
                  radius: 14,
                  onTap: () => onDeleteChapter(i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _headerBorderDecoration() {
    return BoxDecoration(
      border: Border(
        right: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }

  String _chapterTitle(int i) {
    if (chapters.length <= i) {
      return 'Bab ${i + 1}';
    }
    return chapters[i]['judul_bab'] ??
        chapters[i]['judul'] ??
        chapters[i]['title'] ??
        'Bab ${i + 1}';
  }

  // ── Right-side cell builders ─────────────────────────────────────────────

  Widget _buildFinalScoreCell(int i) {
    final finalScore = (tableData[i]['final_score'] as num?)?.toDouble();
    return Container(
      alignment: Alignment.center,
      child: Text(
        finalScore != null ? finalScore.toStringAsFixed(0) : '-',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: finalScore != null
              ? _scoreColor(finalScore)
              : ColorUtils.slate300,
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  Widget _buildPredikatCell(int i) {
    final studentClassId = tableData[i]['student_class_id'] as String;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: ColorUtils.slate200),
    );
    return Container(
      alignment: Alignment.center,
      child: SizedBox(
        width: 48,
        child: TextField(
          controller: predikatControllers[studentClassId],
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            border: border,
            enabledBorder: border,
          ),
        ),
      ),
    );
  }

  Widget _buildDeskripsiCell(int i) {
    final row = tableData[i];
    final studentClassId = row['student_class_id'] as String;
    final studentName = row['nama']?.toString() ?? 'Siswa';
    final controller = descriptionControllers[studentClassId];
    final text = controller?.text ?? '';
    final hasText = text.isNotEmpty;

    return GestureDetector(
      onTap: () => onDeskripsiTap(studentClassId, studentName),
      child: Tooltip(
        message: text,
        preferBelow: true,
        triggerMode: TooltipTriggerMode.longPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          child: Text(
            hasText ? text : 'Ketuk untuk edit...',
            style: TextStyle(
              fontSize: 10,
              color: hasText ? ColorUtils.slate700 : ColorUtils.slate400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
