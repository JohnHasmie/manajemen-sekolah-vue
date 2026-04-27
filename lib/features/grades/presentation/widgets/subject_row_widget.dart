import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

class SubjectRowWidget extends StatelessWidget {
  final dynamic classData;
  final dynamic subject;
  final Color primaryColor;
  final VoidCallback onTap;

  /// When true (homeroom / wali-kelas view), the row shows the subject
  /// teacher's name under the subject title. Hidden in the teacher's own
  /// mengajar view since it would always be their own name — redundant.
  final bool isHomeroomView;

  const SubjectRowWidget({
    super.key,
    required this.classData,
    required this.subject,
    required this.primaryColor,
    required this.onTap,
    this.isHomeroomView = false,
  });

  @override
  Widget build(BuildContext context) {
    final subjectModel = Subject.fromJson(subject as Map<String, dynamic>);
    final sn = subjectModel.name;
    final rawAvg = subject['avg_score'];
    final avg = rawAvg is num ? rawAvg.toDouble() : null;
    final total = subject['total_grades'] ?? 0;
    final maxScore = subject['max_score'] is num
        ? (subject['max_score'] as num).toDouble()
        : null;
    final minScore = subject['min_score'] is num
        ? (subject['min_score'] as num).toDouble()
        : null;

    final dist = _safeMap(subject['distribution']);
    final high = dist['high'] is num ? (dist['high'] as num).toInt() : 0;
    final mid = dist['mid'] is num ? (dist['mid'] as num).toInt() : 0;
    final low = dist['low'] is num ? (dist['low'] as num).toInt() : 0;
    final distTotal = high + mid + low;
    final assessments = (subject['assessments'] as List?) ?? [];

    // Only surface the subject teacher name in wali-kelas view — on the
    // mengajar view the teacher is always looking at their own subjects so
    // showing their own name on every tile would be noise.
    final teacherName = isHomeroomView ? _teacherName() : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(sn, teacherName, avg),
              if (total > 0) ...[
                const SizedBox(height: 6),
                _buildAssessments(assessments),
                if (minScore != null && maxScore != null) ...[
                  const SizedBox(height: 6),
                  _buildScoreRange(minScore, maxScore),
                ],
                if (distTotal > 0) ...[
                  const SizedBox(height: 6),
                  _buildDistributionBar(high, mid, low),
                ],
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Belum ada nilai',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reads the subject teacher's name from the backend payload. Supports both
  /// English (`teacher_name`, `teacher.name`) and Indonesian (`guru_nama`,
  /// `guru.nama`) field aliases to match the shape the schedule endpoint uses.
  String? _teacherName() {
    if (subject is! Map) return null;
    final s = subject as Map;
    final flat = s['teacher_name'] ?? s['guru_nama'];
    if (flat is String && flat.trim().isNotEmpty) return flat.trim();
    final nested = s['teacher'] ?? s['guru'];
    if (nested is Map) {
      final nm = nested['name'] ?? nested['nama'];
      if (nm is String && nm.trim().isNotEmpty) return nm.trim();
    }
    return null;
  }

  Widget _buildHeader(String name, String? teacherName, double? avg) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              if (teacherName != null && teacherName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 12,
                      color: ColorUtils.slate400,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        teacherName,
                        style: TextStyle(
                          fontSize: 10.5,
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
            ],
          ),
        ),
        if (avg != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _scoreColor(avg).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _scoreColor(avg),
                  ),
                ),
                Text(
                  'Rata-rata',
                  style: TextStyle(
                    fontSize: 7,
                    color: _scoreColor(avg).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right_rounded, size: 16, color: ColorUtils.slate300),
      ],
    );
  }

  Widget _buildAssessments(List<dynamic> assessments) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...assessments.map((a) {
          final label = a['label']?.toString() ?? '';
          final aAvg = a['avg'] is num ? (a['avg'] as num).toDouble() : null;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label ',
                  style: TextStyle(fontSize: 9, color: ColorUtils.slate400),
                ),
                Text(
                  aAvg != null ? aAvg.toStringAsFixed(0) : '-',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: aAvg != null
                        ? _scoreColor(aAvg)
                        : ColorUtils.slate300,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildScoreRange(double minScore, double maxScore) {
    return Row(
      children: [
        Icon(
          Icons.arrow_downward_rounded,
          size: 10,
          color: ColorUtils.error600,
        ),
        const SizedBox(width: 2),
        Text(
          'Terendah ',
          style: TextStyle(fontSize: 9, color: ColorUtils.slate400),
        ),
        Text(
          minScore.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorUtils.error600,
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.arrow_upward_rounded,
          size: 10,
          color: ColorUtils.success600,
        ),
        const SizedBox(width: 2),
        Text(
          'Tertinggi ',
          style: TextStyle(fontSize: 9, color: ColorUtils.slate400),
        ),
        Text(
          maxScore.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ColorUtils.success600,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionBar(int high, int mid, int low) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Row(
          children: [
            if (high > 0)
              Expanded(
                flex: high,
                child: Container(color: ColorUtils.success600),
              ),
            if (mid > 0)
              Expanded(
                flex: mid,
                child: Container(color: ColorUtils.warning600),
              ),
            if (low > 0)
              Expanded(
                flex: low,
                child: Container(color: ColorUtils.error600),
              ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }
}
