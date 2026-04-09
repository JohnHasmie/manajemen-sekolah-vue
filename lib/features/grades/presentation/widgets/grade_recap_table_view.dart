// Frozen-column spreadsheet table for the grade recap wizard step 2.
// Like a Vue <GradeRecapTable> component — purely presentational, all state
// mutations (resize, add/delete chapter, open dialogs) flow through callbacks.

import 'package:flutter/material.dart';

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

  static const double _gradeCellWidth = 90;
  static const double _finalScoreWidth = 60;
  static const double _predikatWidth = 56;
  static const double _deskripsiWidth = 160;

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SkeletonListLoading(itemCount: 5, infoTagCount: 3, showActions: false);
    }

    final int numChapters = chapters.isNotEmpty ? chapters.length : 1;
    final double leftWidth = 120;

    final double rightSideWidth =
        (numChapters * _gradeCellWidth) +
        (_gradeCellWidth * 2) +
        (_finalScoreWidth * 2) +
        _predikatWidth +
        _deskripsiWidth;

    return Column(children: [
      // Action bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.white,
        child: Row(children: [
          Text(labels['gradeData'] ?? 'Data Nilai', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
          const Spacer(),
          GestureDetector(
            key: addChapterKey,
            onTap: onAddChapter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 14, color: primaryColor),
                const SizedBox(width: 4),
                Text(labels['addBab'] ?? 'Tambah Bab', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
      // Table
      Expanded(child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildLeftColumn(leftWidth),
          Expanded(child: _buildRightSide(rightSideWidth, numChapters)),
        ])),
      )),
    ]);
  }

  // ── Frozen left column ──

  Widget _buildLeftColumn(double leftWidth) {
    return Container(
      width: leftWidth,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: ColorUtils.slate200))),
      child: Column(children: [
        // Header
        Container(
          height: 52, width: leftWidth,
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          color: primaryColor,
          child: const Text('Siswa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.white)),
        ),
        // Student rows
        ...tableData.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Container(
            height: 44, width: leftWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : ColorUtils.slate50,
              border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(children: [
              SizedBox(width: 18, child: Text('${i + 1}', style: TextStyle(fontSize: 10, color: ColorUtils.slate400, fontWeight: FontWeight.w600))),
              Expanded(child: Text(row['nama'] ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ColorUtils.slate800), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          );
        }),
      ]),
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

  // ── Header row (green, matching Buku Nilai) ──

  Widget _buildHeaderRow(int numChapters) {
    return Container(
      height: 52,
      color: primaryColor,
      child: Row(children: [
        for (int i = 0; i < numChapters; i++) _buildBabHeader(i),
        _buildColHeader('UTS', _gradeCellWidth, onTap: () => onBulkSelect('uts', null)),
        _buildColHeader('UAS', _gradeCellWidth, onTap: () => onBulkSelect('uas', null)),
        _buildColHeader(labels['finalLabel'] ?? 'Final', _finalScoreWidth),
        _buildColHeader(labels['skillLabel'] ?? 'Skill', _finalScoreWidth),
        _buildColHeader(labels['gradeLabel'] ?? 'Nilai', _predikatWidth),
        _buildColHeader(labels['descLabel'] ?? 'Desk.', _deskripsiWidth),
      ]),
    );
  }

  Widget _buildColHeader(String label, double width, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.12)))),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ),
    );
  }

  Widget _buildBabHeader(int i) {
    final title = chapters.length > i ? (chapters[i]['judul_bab'] ?? chapters[i]['judul'] ?? chapters[i]['title'] ?? 'Bab ${i + 1}') : 'Bab ${i + 1}';
    return InkWell(
      onTap: () => onBulkSelect('bab', i),
      child: Container(
        width: _gradeCellWidth,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.12)))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis)),
            GestureDetector(onTap: () => onDeleteChapter(i), child: Icon(Icons.close, size: 12, color: Colors.white.withValues(alpha: 0.5))),
          ]),
        ]),
      ),
    );
  }

  // ── Data rows (compact, matching Buku Nilai) ──

  List<Widget> _buildDataRows(int numChapters) {
    return tableData.asMap().entries.map((e) {
      final i = e.key;
      final row = e.value;
      final String studentClassId = row['student_class_id'] as String;
      final finalScore = (row['final_score'] as num?)?.toDouble();

      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: i.isEven ? Colors.white : ColorUtils.slate50,
          border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
        ),
        child: Row(children: [
          // Bab cells
          for (int j = 0; j < numChapters; j++)
            SizedBox(width: _gradeCellWidth, child: cellBuilder(studentClassId, 'bab', j)),
          // UTS
          SizedBox(width: _gradeCellWidth, child: cellBuilder(studentClassId, 'uts', null)),
          // UAS
          SizedBox(width: _gradeCellWidth, child: cellBuilder(studentClassId, 'uas', null)),
          // Final (read-only)
          Container(
            width: _finalScoreWidth, alignment: Alignment.center,
            child: Text(
              finalScore != null ? finalScore.toStringAsFixed(0) : '-',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: finalScore != null ? _scoreColor(finalScore) : ColorUtils.slate300),
            ),
          ),
          // Skill
          SizedBox(width: _finalScoreWidth, child: cellBuilder(studentClassId, 'skill_score', null)),
          // Predikat
          Container(
            width: _predikatWidth, alignment: Alignment.center,
            child: SizedBox(width: 48, child: TextField(
              controller: predikatControllers[studentClassId],
              style: const TextStyle(fontSize: 11), textAlign: TextAlign.center,
              decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: ColorUtils.slate200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: ColorUtils.slate200)),
              ),
            )),
          ),
          // Deskripsi
          GestureDetector(
            onTap: () => onDeskripsiTap(studentClassId, row['nama']?.toString() ?? 'Siswa'),
            child: Tooltip(
              message: descriptionControllers[studentClassId]?.text ?? '',
              preferBelow: true,
              triggerMode: TooltipTriggerMode.longPress,
              child: Container(
                width: _deskripsiWidth, padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  descriptionControllers[studentClassId]?.text.isNotEmpty == true ? descriptionControllers[studentClassId]!.text : 'Ketuk untuk edit...',
                  style: TextStyle(fontSize: 10, color: descriptionControllers[studentClassId]?.text.isNotEmpty == true ? ColorUtils.slate700 : ColorUtils.slate400),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ]),
      );
    }).toList();
  }
}
