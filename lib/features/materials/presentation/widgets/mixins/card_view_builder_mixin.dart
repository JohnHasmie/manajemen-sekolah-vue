import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

mixin CardViewBuilderMixin {
  Color get primaryColor;
  LanguageProvider get lp;
  bool get isHomeroomView;
  void Function(String, String, String, String) get onOpenChapter;

  Color progressColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }

  Widget buildCard(BuildContext context, dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final sn = g['subject_name']?.toString() ?? '-';
    final classId = g['class_id']?.toString() ?? '';
    final subjectId = g['subject_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onOpenChapter(classId, cn, subjectId, sn),
          child: cardBody(g, cn, sn),
        ),
      ),
    );
  }

  Widget cardBody(dynamic g, String cn, String sn) {
    final pct = (g['progress_pct'] ?? 0).toDouble();
    final pctColor = progressColor(pct);
    final p = primaryColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerRow(cn, sn, pct, pctColor, g['total_chapters'] ?? 0, p),
          if (isHomeroomView && (g['teacher_name'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            _teacherRow(g['teacher_name'].toString(), p),
          ],
          const SizedBox(height: 10),
          statsRow(
            g['total_sub_chapters'] ?? 0,
            g['checked'] ?? 0,
            g['generated'] ?? 0,
            p,
          ),
        ],
      ),
    );
  }

  Widget headerRow(
    String cn,
    String sn,
    double pct,
    Color pctColor,
    int totalChapters,
    Color p,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 4,
                  backgroundColor: ColorUtils.slate100,
                  color: pctColor,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: pctColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelas: $cn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sn,
                style: TextStyle(
                  fontSize: 12,
                  color: p,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: p.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$totalChapters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: p,
                ),
              ),
              Text(
                'bab',
                style: TextStyle(
                  fontSize: 8,
                  color: p,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget statsRow(int totalSubs, int checked, int generated, Color p) {
    return Row(
      children: [
        statChip(Icons.list_rounded, '$totalSubs sub-bab', ColorUtils.slate600),
        const SizedBox(width: 10),
        statChip(
          Icons.check_circle_outline,
          '$checked selesai',
          ColorUtils.success600,
        ),
        const SizedBox(width: 10),
        statChip(
          Icons.auto_awesome_outlined,
          '$generated AI',
          ColorUtils.violet500,
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: p.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lp.getTranslatedText({'en': 'View', 'id': 'Lihat Bab'}),
                style: TextStyle(
                  fontSize: 11,
                  color: p,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 14, color: p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _teacherRow(String teacherName, Color p) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 13, color: ColorUtils.slate500),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              teacherName,
              style: TextStyle(
                fontSize: 11.5,
                color: ColorUtils.slate600,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
