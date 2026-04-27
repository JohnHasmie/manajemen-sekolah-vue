import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ActivityTimelineCardWidget extends StatelessWidget {
  final dynamic activity;
  final Color primaryColor;
  final VoidCallback onTap;

  /// Wali-kelas mode — surfaces the authoring teacher name so the homeroom
  /// teacher can see who recorded each entry in the combined timeline.
  final bool isHomeroomView;

  const ActivityTimelineCardWidget({
    super.key,
    required this.activity,
    required this.primaryColor,
    required this.onTap,
    this.isHomeroomView = false,
  });

  String? _authorName() {
    final raw =
        activity['guru_nama'] ??
        activity['teacher_name'] ??
        activity['teacher']?['name'];
    final str = raw?.toString().trim();
    if (str == null || str.isEmpty) return null;
    return str;
  }

  String _formatDate(String? d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = activity['title']?.toString() ?? '-';
    final classObj = activity['class'];
    final subjectObj = activity['subject'];
    final cn =
        activity['class_name']?.toString() ??
        activity['kelas_nama']?.toString() ??
        (classObj is Map ? classObj['name']?.toString() : null) ??
        '-';
    final sn =
        activity['subject_name']?.toString() ??
        activity['mata_pelajaran_nama']?.toString() ??
        (subjectObj is Map ? subjectObj['name']?.toString() : null) ??
        '-';
    final type =
        activity['type']?.toString() ?? activity['jenis']?.toString() ?? '';
    final isAssignment = type == 'assignment' || type == 'tugas';
    final dateStr = _formatDate(activity['date']?.toString());
    final description = (activity['deskripsi'] ?? activity['description'])
        ?.toString();
    final hasDesc = description != null && description.isNotEmpty;
    final accentColor = isAssignment
        ? ColorUtils.warning600
        : ColorUtils.success600;
    final typeLabel = isAssignment ? 'Tugas' : 'Materi';
    final authorName = isHomeroomView ? _authorName() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildMetaRow(cn, sn, dateStr, typeLabel, accentColor),
                      if (authorName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 13,
                              color: ColorUtils.slate400,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                authorName,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: ColorUtils.slate500,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasDesc) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(
    String className,
    String subjectName,
    String dateStr,
    String typeLabel,
    Color accentColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$className · $subjectName',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.calendar_today_rounded,
          size: 10,
          color: ColorUtils.slate400,
        ),
        const SizedBox(width: 3),
        Text(
          dateStr,
          style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            typeLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
      ],
    );
  }
}
