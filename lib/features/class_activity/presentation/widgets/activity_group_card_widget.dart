import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ActivityGroupCardWidget extends StatelessWidget {
  final dynamic group;
  final Color primaryColor;
  final VoidCallback onTap;

  /// When true (wali-kelas tab) the card surfaces the authoring teacher so
  /// the homeroom teacher can see which colleague recorded each group.
  final bool isHomeroomView;

  const ActivityGroupCardWidget({
    super.key,
    required this.group,
    required this.primaryColor,
    required this.onTap,
    this.isHomeroomView = false,
  });

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
    final cn = group['class_name']?.toString() ?? '-';
    final sn = group['subject_name']?.toString() ?? '-';
    final total = group['total_count'] ?? 0;
    final latest = (group['latest_activities'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
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
                _buildHeader(cn, sn, total),
                if (isHomeroomView) ...[
                  const SizedBox(height: 6),
                  _buildTeacherRow(group),
                ],
                if (latest.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildLatestActivities(latest),
                ],
                const SizedBox(height: 8),
                _buildFooter(group),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String className, String subjectName, int total) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.school_outlined, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelas: $className',
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
                subjectName,
                style: TextStyle(
                  fontSize: 12,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildCountBadge(total),
      ],
    );
  }

  Widget _buildCountBadge(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$total',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'kegiatan',
            style: TextStyle(
              fontSize: 10,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestActivities(List<dynamic> latest) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: latest.asMap().entries.map((e) {
          final a = e.value;
          final isAssignment =
              a['type'] == 'assignment' || a['type'] == 'tugas';
          return Padding(
            padding: EdgeInsets.only(top: e.key > 0 ? 6 : 0),
            child: Row(
              children: [
                Icon(
                  isAssignment
                      ? Icons.assignment_outlined
                      : Icons.menu_book_outlined,
                  size: 14,
                  color: isAssignment
                      ? ColorUtils.warning600
                      : ColorUtils.success600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    a['title']?.toString() ?? '-',
                    style: TextStyle(
                      fontSize: 12,
                      color: ColorUtils.slate700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(a['date']?.toString()),
                  style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Teacher name row shown in wali-kelas mode, aligned under
  /// the 40px leading icon to keep the visual hierarchy tidy.
  Widget _buildTeacherRow(dynamic group) {
    final raw =
        group['teacher_name'] ??
        group['guru_nama'] ??
        group['teacher']?['name'];
    final name = raw?.toString().trim() ?? '';
    if (name.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 13, color: ColorUtils.slate400),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
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
    );
  }

  Widget _buildFooter(dynamic group) {
    return Row(
      children: [
        Icon(Icons.update_rounded, size: 14, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Terbaru: '
            '${_formatDate(group['latest_date']?.toString())}',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 11,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 14, color: primaryColor),
            ],
          ),
        ),
      ],
    );
  }
}
