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
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
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

    // Header is now icon-free. The two affordances that used to be
    // jammed into the chip (edit pencil + delete ×) lived in a
    // ~90px-wide cell along with two-line wrapped text and read as
    // visual noise — and the × in particular collided with the
    // AppBar's close-screen X right above it.
    //
    // Short-tap stays wired to onBulkSelect (the bulk-grade dialog
    // is still TODO upstream but the wire stays for when it lands).
    // Long-press opens the action menu with rename + (when >1) delete.
    //
    // The Builder wraps the InkWell so the long-press handler has a
    // descendant BuildContext for `showModalBottomSheet` — the cell
    // sits deep inside FrozenColumnTable's internal scrollers so we
    // can't reach for the host screen's context here.
    return Builder(
      builder: (cellContext) {
        return InkWell(
          onTap: () => onBulkSelect('bab', i),
          onLongPress: () => _showChapterActionSheet(cellContext, i),
          child: Container(
            decoration: _headerBorderDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            alignment: Alignment.center,
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
        );
      },
    );
  }

  /// Opens the action menu for chapter [i]. "Edit bab" is always
  /// present; "Hapus bab" only when there's more than one chapter,
  /// since deleting the only column would leave the table with no
  /// grade slots.
  ///
  /// Uses the shared [AppBottomSheet] shell so the surface matches the
  /// brand pattern every other action sheet in the app uses (cobalt
  /// gradient header + icon + title + subtitle + close X). The body
  /// renders two large tap targets — a primary "Edit bab" card with
  /// cobalt accent and a destructive "Hapus bab" card with error
  /// accent — instead of two plain `ListTile`s, so the affordances
  /// read as primary actions rather than menu items.
  void _showChapterActionSheet(BuildContext context, int i) {
    final canDelete = chapters.length > 1;
    final cobalt = ColorUtils.brandCobalt;

    AppBottomSheet.show(
      context: context,
      title: 'Aksi Bab',
      subtitle: _chapterTitle(i),
      icon: Icons.view_column_rounded,
      primaryColor: cobalt,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      content: Builder(
        builder: (sheetCtx) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChapterActionCard(
                icon: Icons.edit_rounded,
                label: 'Edit bab',
                description: 'Ubah nama, materi, dan nilai per siswa',
                accent: cobalt,
                onTap: () {
                  // SS3-HH — long-press surfaces the SAME full editor
                  // the "+" add button uses (showBulkDialog).
                  Navigator.of(sheetCtx).pop();
                  onBulkSelect('bab', i);
                },
              ),
              if (canDelete) ...[
                const SizedBox(height: 10),
                _ChapterActionCard(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus bab',
                  description: 'Hapus kolom ini beserta semua nilainya',
                  accent: ColorUtils.error600,
                  destructive: true,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onDeleteChapter(i);
                  },
                ),
              ],
            ],
          );
        },
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

/// Action card rendered inside the bab long-press sheet. Replaces the
/// plain `ListTile` rows so each affordance reads as a primary action
/// with a tinted icon badge, a short description, and a chevron — the
/// same shape `activity_quick_actions_sheet.dart` and the parent
/// rekomendasi sheets use.
class _ChapterActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color accent;
  final bool destructive;
  final VoidCallback onTap;

  const _ChapterActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.accent,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? ColorUtils.error600 : ColorUtils.slate900;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: destructive
                ? ColorUtils.error600.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: destructive
                  ? ColorUtils.error600.withValues(alpha: 0.20)
                  : ColorUtils.slate200,
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: destructive
                            ? ColorUtils.error600.withValues(alpha: 0.75)
                            : ColorUtils.slate500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
