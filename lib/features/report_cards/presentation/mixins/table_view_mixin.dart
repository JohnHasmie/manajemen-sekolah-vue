// Table-view presentation for the Raport (report card) overview.
//
// Previously built ad-hoc with Expanded columns inside a ListView. Now
// delegates row/column layout to the shared `FrozenColumnTable` scaffold
// (same widget used by Buku Nilai and the Finance per-class report) so
// the three features read visually identical.
//
// Mixes in on `ConsumerState<ReportCardOverviewPage>` to share the
// subclass's `openClassReport` handler and its Riverpod ref.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/frozen_column_table.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';

mixin TableViewMixin on ConsumerState<ReportCardOverviewPage> {
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  void openClassReport(dynamic classItem);

  // ── Layout constants ────────────────────────────────────────────────────
  static const double _leftWidth = 140.0;
  static const double _progressWidth = 180.0;
  static const double _countWidth = 60.0;
  static const double _headerHeight = 40.0;
  static const double _rowHeight = 56.0;

  Widget buildTableView(List<dynamic> data) {
    // Wrap in a vertical scroll view so the parent RefreshIndicator still
    // has a scrollable descendant. FrozenColumnTable itself is a fixed-
    // height Row(...) — without this wrapper, tall datasets would overflow
    // and pull-to-refresh would break.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FrozenColumnTable(
          rowCount: data.length,
          leftColumns: [
            FrozenTableColumn(
              width: _leftWidth,
              header: _buildHeaderCell(
                'Kelas',
                alignment: Alignment.centerLeft,
              ),
              cellBuilder: (i) => _buildClassCell(data[i]),
            ),
          ],
          rightColumns: [
            FrozenTableColumn(
              width: _progressWidth,
              header: _buildHeaderCell(
                'Progress',
                alignment: Alignment.centerLeft,
              ),
              cellBuilder: (i) => _buildProgressCell(data[i]),
            ),
            FrozenTableColumn(
              width: _countWidth,
              header: _buildHeaderCell('Draft'),
              cellBuilder: (i) => _buildDraftCell(data[i]),
            ),
            FrozenTableColumn(
              width: _countWidth,
              header: _buildHeaderCell('Final'),
              cellBuilder: (i) => _buildFinalCell(data[i]),
            ),
          ],
          headerHeight: _headerHeight,
          rowHeight: _rowHeight,
          // Solid-green header matches Grade Recap and Nilai Overview so
          // the three teacher tables read identically across the app.
          headerBackgroundColor: primaryColor,
          rowDecorationBuilder: _rowDecoration,
          showLeftColumnShadow: false,
          onRowTap: (i) => openClassReport(data[i]),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  /// Scaffold paints `headerBackgroundColor` (solid primary) across the
  /// header row, so this cell only contributes alignment + padding + text.
  /// White text for legibility on the filled green background.
  Widget _buildHeaderCell(
    String label, {
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── Cells ────────────────────────────────────────────────────────────────

  Widget _buildClassCell(dynamic classData) {
    final className = classData['class_name']?.toString() ?? '-';
    final totalRaports = classData['total_raports'] ?? 0;
    final studentCount = classData['student_count'] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            className,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$totalRaports/$studentCount siswa',
            style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCell(dynamic classData) {
    final totalRaports = classData['total_raports'] ?? 0;
    final studentCount = classData['student_count'] ?? 0;
    final pctVal = _calculateProgress(totalRaports, studentCount);
    final pctColor = _progressColor(pctVal);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${pctVal.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: pctColor,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: pctVal / 100,
                backgroundColor: ColorUtils.slate100,
                color: pctColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCell(dynamic classData) {
    final draftCount = classData['draft_count'] ?? 0;
    return Center(
      child: Text(
        '$draftCount',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: draftCount > 0 ? ColorUtils.warning600 : ColorUtils.slate300,
        ),
      ),
    );
  }

  Widget _buildFinalCell(dynamic classData) {
    final finalCount = classData['final_count'] ?? 0;
    final publishedCount = classData['published_count'] ?? 0;
    final total = finalCount + publishedCount;
    return Center(
      child: Text(
        '$total',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: total > 0 ? ColorUtils.success600 : ColorUtils.slate300,
        ),
      ),
    );
  }

  // ── Row decoration ───────────────────────────────────────────────────────

  BoxDecoration _rowDecoration(int rowIndex) {
    return BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _calculateProgress(int totalRaports, int studentCount) {
    return studentCount > 0 ? (totalRaports / studentCount * 100) : 0.0;
  }

  Color _progressColor(double pctVal) {
    if (pctVal >= 80) return ColorUtils.success600;
    if (pctVal >= 40) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }
}
