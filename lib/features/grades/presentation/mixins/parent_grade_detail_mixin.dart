import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';

/// Mixin for grade detail bottom sheet and related UI building.
///
/// Migrated from `showDialog(Dialog(...))` to [AppBottomSheet.show] so the
/// surface participates in the shared sheet design system — gradient header
/// from `primaryColor` (wali violet), drag handle, header close X, brand
/// shadow, and Samsung-safe footer padding. The bespoke gradient header
/// and Tutup footer button are gone; the score badge moved into the body
/// as a hero card so the parent sees the grade prominently as soon as the
/// sheet opens.
mixin ParentGradeDetailMixin on ConsumerState<ParentGradeScreen> {
  // Expected from state
  Color Function() get getPrimaryColor;
  Map<String, Color> get gradeTypeColorMap;

  /// Show detailed view of a single grade in a bottom sheet.
  void showGradeDetail(Map<String, dynamic> grade) {
    final primaryColor = getPrimaryColor();
    final type = grade['type']?.toString().toLowerCase() ?? 'tugas';
    final typeColor = gradeTypeColorMap[type] ?? ColorUtils.brandAzure;

    AppBottomSheet.show(
      context: context,
      title: 'Detail Nilai',
      subtitle:
          grade['subject_name'] ??
          grade['mata_pelajaran'] ??
          AppLocalizations.subject.tr,
      icon: Icons.grade_rounded,
      primaryColor: primaryColor,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      content: _DetailContent(
        grade: grade,
        type: type,
        typeColor: typeColor,
        primaryColor: primaryColor,
        formatDate: formatDate,
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

/// Sheet body: score hero card + detail rows.
///
/// Pulled out into its own widget so the sheet builder closure stays small
/// and the score hero composition reads top-to-bottom in one place.
class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.grade,
    required this.type,
    required this.typeColor,
    required this.primaryColor,
    required this.formatDate,
  });

  final Map<String, dynamic> grade;
  final String type;
  final Color typeColor;
  final Color primaryColor;
  final String Function(dynamic) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _scoreHero(),
        const SizedBox(height: AppSpacing.lg),
        ..._buildDetailRows(),
      ],
    );
  }

  /// Score hero card — the score badge that used to live in the dialog
  /// header. Now sits at the top of the sheet body so it remains the
  /// visual anchor of the detail view.
  Widget _scoreHero() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: ColorUtils.headerFadeGradient(typeColor, endOpacity: 0.78),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
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
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  grade['subject_name'] ??
                      grade['mata_pelajaran'] ??
                      AppLocalizations.subject.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (grade['title'] != null &&
                    grade['title'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      grade['title'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailRows() {
    final rows = <Widget>[
      _detailRow(
        Icons.person_rounded,
        AppLocalizations.teacher.tr,
        grade['teacher_name'] ?? 'Tidak Diketahui',
      ),
      _detailRow(
        Icons.calendar_today_rounded,
        'Tanggal Penilaian',
        formatDate(grade['date']),
      ),
      _detailRow(
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
        _detailRow(
          Icons.notes_rounded,
          'Catatan Guru',
          grade['notes'].toString(),
        ),
      );
    }

    return rows;
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    final c = iconColor ?? primaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(icon, size: 18, color: c),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
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
          ),
        ],
      ),
    );
  }
}
