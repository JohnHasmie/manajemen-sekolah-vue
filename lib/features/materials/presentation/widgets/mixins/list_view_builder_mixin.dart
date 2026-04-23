import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

mixin ListViewBuilderMixin {
  Color get primaryColor;
  bool get isHomeroomView;
  void Function(String, String, String, String) get onOpenChapter;

  Color pctColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }

  Widget buildSubjectHeader(
    String name,
    int chapters,
    int classCount,
    Color p,
  ) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: p.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.menu_book_outlined, color: p, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              Text(
                '$chapters bab · $classCount kelas',
                style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildClassRow(dynamic g, String subjectName, Color p) {
    final cn = g['class_name']?.toString() ?? '-';
    final classId = g['class_id']?.toString() ?? '';
    final subjectId = g['subject_id']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpenChapter(classId, cn, subjectId, subjectName),
        child: classRowBody(g, cn, p),
      ),
    );
  }

  Widget classRowBody(dynamic g, String cn, Color p) {
    final pct = (g['progress_pct'] ?? 0).toDouble();
    final color = pctColor(pct);
    final teacherName = isHomeroomView
        ? (g['teacher_name'] ?? '').toString()
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              classBadge(cn, p),
              const SizedBox(width: 10),
              progressBar(pct, color),
              const SizedBox(width: 8),
              pctLabel(pct, color),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 16, color: ColorUtils.slate400),
            ],
          ),
          if (teacherName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 4),
                Icon(Icons.person_rounded, size: 12, color: ColorUtils.slate500),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    teacherName,
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget classBadge(String cn, Color p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        cn,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p),
      ),
    );
  }

  Widget progressBar(double pct, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct / 100,
          minHeight: 6,
          backgroundColor: ColorUtils.slate200,
          color: color,
        ),
      ),
    );
  }

  Widget pctLabel(double pct, Color color) {
    return Text(
      '${pct.toStringAsFixed(0)}%',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    );
  }
}
