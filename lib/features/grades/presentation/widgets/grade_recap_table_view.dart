// Frozen-column spreadsheet table for the grade recap wizard step 2.
// Like a Vue <GradeRecapTable> component — purely presentational, all state
// mutations (resize, add/delete chapter, open dialogs) flow through callbacks.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';

/// Spreadsheet-style grade table for the recap screen.
///
/// Renders a frozen left column (student info) and a horizontally-scrollable
/// right side (bab/UTS/UAS/predikat/deskripsi columns).
/// Like a Vue data-table component: receives [tableData] as rows and emits
/// callback events back to the parent StatefulWidget for all mutations.
///
/// Layout mirrors a Laravel Blade `@foreach` loop over students with
/// dynamic chapter columns built from [chapters].
class GradeRecapTableView extends StatelessWidget {
  // ── Data ──────────────────────────────────────────────────────────────────

  /// Each entry is a student row map: keys include 'student_class_id',
  /// 'nama', 'nis', 'final_score', 'bab_scores', etc.
  final List<Map<String, dynamic>> tableData;

  /// Active chapter (bab) list. Length determines how many Bab columns appear.
  final List<dynamic> chapters;

  /// Whether the parent is still loading data (shows skeleton when true).
  final bool isLoading;

  // ── Layout ─────────────────────────────────────────────────────────────────

  /// Current width of the frozen left column, controlled by the parent.
  final double studentInfoWidth;

  /// Primary brand colour used for action buttons and final score text.
  final Color primaryColor;

  // ── GlobalKeys (for tour highlighting) ────────────────────────────────────

  /// Key placed on the "Add Bab" button so the onboarding tour can highlight it.
  final GlobalKey addChapterKey;

  // ── Translations ───────────────────────────────────────────────────────────

  /// Translated label strings keyed by their semantic name.
  /// Expected keys: 'studentInfo', 'finalLabel', 'skillLabel',
  /// 'gradeLabel', 'descLabel', 'gradeData', 'addBab'.
  final Map<String, String> labels;

  // ── Controllers (owned by parent) ─────────────────────────────────────────

  /// Map of studentClassId → predikat TextField controller.
  final Map<String, TextEditingController> predikatControllers;

  /// Map of studentClassId → description TextField controller.
  final Map<String, TextEditingController> descriptionControllers;

  // ── Cell builder ──────────────────────────────────────────────────────────

  /// Factory that produces the editable score cell widget.
  /// Signature: (studentClassId, type, chapterIndex) → Widget.
  /// Kept in the parent because it needs access to the score controller map.
  final Widget Function(String studentClassId, String type, int? chapterIndex)
  cellBuilder;

  // ── Callbacks ─────────────────────────────────────────────────────────────

  /// Called when the user drags the left-column resize handle.
  /// Parent should clamp the value (min 100, max 350) and call setState.
  final ValueChanged<double> onWidthChanged;

  /// Called when the user taps a column header to open the bulk-select dialog.
  /// [type] is 'bab', 'uts', or 'uas'. [chapterIndex] is non-null only for bab.
  final void Function(String type, int? chapterIndex) onBulkSelect;

  /// Called when the user taps the × icon on a bab column header.
  final ValueChanged<int> onDeleteChapter;

  /// Called when the user taps "Add Bab" in the action bar.
  final VoidCallback onAddChapter;

  /// Called when the user taps the description field of a student row.
  final void Function(String studentClassId, String studentName)
  onDeskripsiTap;

  const GradeRecapTableView({
    super.key,
    required this.tableData,
    required this.chapters,
    required this.isLoading,
    required this.studentInfoWidth,
    required this.primaryColor,
    required this.addChapterKey,
    required this.labels,
    required this.predikatControllers,
    required this.descriptionControllers,
    required this.cellBuilder,
    required this.onWidthChanged,
    required this.onBulkSelect,
    required this.onDeleteChapter,
    required this.onAddChapter,
    required this.onDeskripsiTap,
  });

  // ── Constants ──────────────────────────────────────────────────────────────

  static const double _gradeCellWidth = 110;
  static const double _finalScoreWidth = 80;
  static const double _predikatWidth = 80;
  static const double _deskripsiWidth = 280;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SkeletonListLoading(
        itemCount: 5,
        infoTagCount: 3,
        showActions: false,
      );
    }

    final int numChapters = chapters.isNotEmpty ? chapters.length : 1;
    final double leftWidth = studentInfoWidth;

    final double rightSideWidth =
        (numChapters * _gradeCellWidth) +
        (_gradeCellWidth * 2) + // UTS + UAS
        (_finalScoreWidth * 2) + // Final + Skill
        _predikatWidth +
        _deskripsiWidth +
        60; // extra safety margin

    final leftSide = _buildLeftColumn(leftWidth);
    final rightSide = _buildRightSide(rightSideWidth, numChapters);

    return Column(
      children: [
        _buildActionBar(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: ColorUtils.corporateShadow(),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftSide,
                      Expanded(child: rightSide),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Action bar (top: "Grade Data" label + "Add Bab" button) ───────────────

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            labels['gradeData'] ?? 'Grade Data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate700,
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            key: addChapterKey,
            onPressed: onAddChapter,
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              labels['addBab'] ?? 'Add Bab',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            ),
          ),
        ],
      ),
    );
  }

  // ── Frozen left column (student name + NIS) ────────────────────────────────

  Widget _buildLeftColumn(double leftWidth) {
    return Container(
      width: leftWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: ColorUtils.slate200, width: 2),
        ),
      ),
      child: Column(
        children: [
          // Header with drag-to-resize handle
          Stack(
            children: [
              Container(
                height: 60,
                width: leftWidth,
                padding: const EdgeInsets.only(left: 16, right: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Text(
                  labels['studentInfo'] ?? 'STUDENT INFO',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ColorUtils.slate700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Drag handle — parent rebuilds with new width via onWidthChanged
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      onWidthChanged(leftWidth + details.delta.dx),
                  child: Container(
                    width: 10,
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 20,
                        decoration: BoxDecoration(
                          color: ColorUtils.slate300,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Student rows (frozen, only name + NIS visible here)
          ...tableData.map(
            (row) => Container(
              height: 75,
              width: leftWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: ColorUtils.slate200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    row['nama'] ?? '-',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'NIS: ${row['nis'] ?? '-'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scrollable right side (all score columns) ──────────────────────────────

  Widget _buildRightSide(double rightSideWidth, int numChapters) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: rightSideWidth,
        child: Column(
          children: [
            _buildHeaderRow(numChapters),
            ..._buildDataRows(numChapters),
          ],
        ),
      ),
    );
  }

  // ── Header row ─────────────────────────────────────────────────────────────

  Widget _buildHeaderRow(int numChapters) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
      ),
      child: Row(
        children: [
          // Dynamic Bab column headers
          for (int i = 0; i < numChapters; i++)
            _buildBabHeader(i),

          // PTS/UTS header
          _buildFixedHeader(
            label: 'PTS/UTS',
            onTap: () => onBulkSelect('uts', null),
          ),

          // PAS/UAS header
          _buildFixedHeader(
            label: 'PAS/UAS',
            onTap: () => onBulkSelect('uas', null),
          ),

          // Final score (read-only label)
          _buildLabelHeader(labels['finalLabel'] ?? 'Final', _finalScoreWidth),

          // Skill score (read-only label)
          _buildLabelHeader(
            labels['skillLabel'] ?? 'Skill',
            _finalScoreWidth,
          ),

          // Predikat (read-only label)
          _buildLabelHeader(
            labels['gradeLabel'] ?? 'Grade',
            _predikatWidth,
          ),

          // Deskripsi (read-only label, left-aligned)
          Container(
            width: _deskripsiWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              labels['descLabel'] ?? 'Description',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBabHeader(int i) {
    final chapterTitle = chapters.length > i
        ? (chapters[i]['judul_bab'] ??
              chapters[i]['judul'] ??
              chapters[i]['title'] ??
              'Bab ${i + 1}')
        : 'Bab ${i + 1}';

    return Container(
      width: _gradeCellWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onBulkSelect('bab', i),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      chapterTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate700,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.edit_outlined,
                    size: 12,
                    color: ColorUtils.slate400,
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => onDeleteChapter(i),
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Icon(
                Icons.close,
                size: 14,
                color: Colors.red.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedHeader({
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      width: _gradeCellWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.edit_outlined, size: 12, color: ColorUtils.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelHeader(String label, double width) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: ColorUtils.slate700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Data rows ──────────────────────────────────────────────────────────────

  List<Widget> _buildDataRows(int numChapters) {
    return tableData.map((row) {
      final String studentClassId = row['student_class_id'] as String;
      return Container(
        height: 75,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
        ),
        child: Row(
          children: [
            // Bab score cells
            for (int i = 0; i < numChapters; i++)
              Container(
                width: _gradeCellWidth,
                alignment: Alignment.center,
                child: cellBuilder(studentClassId, 'bab', i),
              ),

            // UTS cell
            Container(
              width: _gradeCellWidth,
              alignment: Alignment.center,
              child: cellBuilder(studentClassId, 'uts', null),
            ),

            // UAS cell
            Container(
              width: _gradeCellWidth,
              alignment: Alignment.center,
              child: cellBuilder(studentClassId, 'uas', null),
            ),

            // Final score (read-only display)
            Container(
              width: _finalScoreWidth,
              alignment: Alignment.center,
              child: Text(
                row['final_score']?.toStringAsFixed(1) ?? '0.0',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 14,
                ),
              ),
            ),

            // Skill score cell
            Container(
              width: _finalScoreWidth,
              alignment: Alignment.center,
              child: cellBuilder(studentClassId, 'skill_score', null),
            ),

            // Predikat (editable text field)
            Container(
              width: _predikatWidth,
              alignment: Alignment.center,
              child: SizedBox(
                width: 60,
                child: TextField(
                  controller: predikatControllers[studentClassId],
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ColorUtils.slate200),
                    ),
                  ),
                ),
              ),
            ),

            // Deskripsi (read-only, opens full-editor dialog on tap)
            Container(
              width: _deskripsiWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: descriptionControllers[studentClassId],
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
                readOnly: true,
                onTap: () => onDeskripsiTap(
                  studentClassId,
                  row['nama']?.toString() ?? 'Siswa',
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  fillColor: ColorUtils.slate50,
                  filled: true,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
