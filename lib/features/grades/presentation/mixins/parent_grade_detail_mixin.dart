import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';

/// Mixin for grade detail dialog and related UI building.
///
/// Handles display of full grade details in a modal dialog.
mixin ParentGradeDetailMixin on ConsumerState<ParentGradeScreen> {
  // Expected from state
  Color Function() get getPrimaryColor;
  Map<String, Color> get gradeTypeColorMap;

  /// Show detailed view of a single grade in a dialog.
  void showGradeDetail(Map<String, dynamic> grade) {
    final primaryColor = getPrimaryColor();
    final type = grade['type']?.toString().toLowerCase() ?? 'tugas';
    final typeColor = gradeTypeColorMap[type] ?? ColorUtils.corporateBlue600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailHeader(grade, primaryColor, type),
            _buildDetailContent(grade, type, typeColor),
            _buildDetailFooter(),
          ],
        ),
      ),
    );
  }

  /// Build detail dialog header with score and subject.
  Widget _buildDetailHeader(
    Map<String, dynamic> grade,
    Color primaryColor,
    String type,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
        ),
      ),
      child: Row(
        children: [
          _buildScoreBadge(grade),
          const SizedBox(width: 14),
          _buildHeaderText(grade, type),
        ],
      ),
    );
  }

  /// Build score badge in header.
  Widget _buildScoreBadge(Map<String, dynamic> grade) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          grade['score']?.toString() ?? '0',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Build header text section.
  Widget _buildHeaderText(Map<String, dynamic> grade, String type) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            grade['subject_name'] ??
                grade['mata_pelajaran'] ??
                AppLocalizations.subject.tr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (grade['title'] != null && grade['title'].toString().isNotEmpty)
            _buildTitleText(grade),
        ],
      ),
    );
  }

  /// Build title text in header.
  Widget _buildTitleText(Map<String, dynamic> grade) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(
          grade['title'],
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Build detail content section.
  Widget _buildDetailContent(
    Map<String, dynamic> grade,
    String type,
    Color typeColor,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 350),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildDetailRows(grade, type, typeColor),
        ),
      ),
    );
  }

  /// Build all detail rows for grade content.
  List<Widget> _buildDetailRows(
    Map<String, dynamic> grade,
    String type,
    Color typeColor,
  ) {
    final rows = <Widget>[
      _buildDetailRow(
        Icons.person_rounded,
        AppLocalizations.teacher.tr,
        grade['teacher_name'] ?? 'Tidak Diketahui',
      ),
      _buildDetailRow(
        Icons.calendar_today_rounded,
        'Tanggal Penilaian',
        formatDate(grade['date']),
      ),
      _buildDetailRow(
        Icons.category_rounded,
        'Penilaian',
        type.toUpperCase(),
        iconColor: typeColor,
      ),
    ];

    if (grade['notes'] != null &&
        grade['notes'].toString().isNotEmpty &&
        grade['notes'] != 'null') {
      rows.add(
        _buildDetailRow(
          Icons.notes_rounded,
          'Catatan Guru',
          grade['notes'].toString(),
        ),
      );
    }

    return rows;
  }

  /// Build detail footer with close button.
  Widget _buildDetailFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => AppNavigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: ColorUtils.slate300),
            foregroundColor: ColorUtils.slate700,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          child: Text(
            AppLocalizations.close.tr,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  /// Build a detail row (icon + label + value).
  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    final c = iconColor ?? getPrimaryColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRowIcon(icon, c),
          const SizedBox(width: AppSpacing.md),
          _buildRowContent(label, value),
        ],
      ),
    );
  }

  /// Build icon container for detail row.
  Widget _buildRowIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  /// Build text content for detail row.
  Widget _buildRowContent(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate800,
            ),
          ),
        ],
      ),
    );
  }

  /// Format date for display.
  String formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = AppDateUtils.parseApiDate(date);
      if (dt == null) return date.toString();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }
}
