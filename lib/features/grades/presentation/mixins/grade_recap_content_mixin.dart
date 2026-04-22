import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_overview.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_stats_hero.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_progress_ring.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

mixin GradeRecapContentMixin on ConsumerState<GradeRecapOverviewPage> {
  String? get recapErrorMessage;

  Widget buildContent(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: recapErrorMessage,
      isEmpty: filteredData.isEmpty,
      onRefresh: refresh,
      role: 'guru',
      emptyTitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'No Homeroom Class',
              'id': 'Bukan Wali Kelas',
            })
          : lp.getTranslatedText({
              'en': 'No Classes Found',
              'id': 'Tidak Ada Kelas',
            }),
      emptySubtitle: lp.getTranslatedText({
        'en': 'No teaching assignments found',
        'id': 'Tidak ada jadwal mengajar',
      }),
      emptyIcon: isHomeroomView ? Icons.class_outlined : Icons.assessment_outlined,
      childBuilder: () {
        final data = filteredData;
        return isListView ? _buildListView(data) : _buildCardView(data);
      },
    );
  }

  // ── Aggregate stats used by the hero card ──
  //
  // Primary source is the backend-computed `summary` block — it stays
  // accurate regardless of client-side pagination or search filtering.
  // As a fallback (e.g. a legacy cached response with no summary, or a
  // transient error), we recompute from whatever class rows we have.

  _HeroStats _computeHeroStatsFallback(List<dynamic> data) {
    int totalStudents = 0;
    int totalEntries = 0;
    int totalRecaps = 0;
    double scoreSum = 0;
    int scoreCount = 0;

    for (final g in data) {
      totalStudents += ((g['student_count'] ?? 0) as num).toInt();
      final subjects = (g['subjects'] as List?) ?? [];
      for (final sub in subjects) {
        totalEntries += ((sub['total_students'] ?? 0) as num).toInt();
        totalRecaps += ((sub['recap_count'] ?? 0) as num).toInt();
        final avg = sub['avg_final_score'];
        if (avg is num) {
          scoreSum += avg.toDouble();
          scoreCount++;
        }
      }
    }

    final overallPct = totalEntries > 0
        ? (totalRecaps / totalEntries) * 100.0
        : 0.0;
    final overallAvg = scoreCount > 0 ? scoreSum / scoreCount : null;

    return _HeroStats(
      classCount: data.length,
      totalStudents: totalStudents,
      completionPct: overallPct,
      avgScore: overallAvg,
    );
  }

  _HeroStats _resolveHeroStats(List<dynamic> data) {
    final summary = recapSummary;
    if (summary.isNotEmpty) {
      return _HeroStats(
        classCount: (summary['total_classes'] as num?)?.toInt() ?? data.length,
        totalStudents: (summary['total_students'] as num?)?.toInt() ?? 0,
        completionPct:
            (summary['overall_completion_pct'] as num?)?.toDouble() ?? 0.0,
        avgScore: (summary['overall_avg_score'] as num?)?.toDouble(),
      );
    }
    return _computeHeroStatsFallback(data);
  }

  Widget _buildHero(List<dynamic> data) {
    final stats = _resolveHeroStats(data);
    return GradeRecapStatsHero(
      primaryColor: primaryColor,
      classCount: stats.classCount,
      studentCount: stats.totalStudents,
      completionPct: stats.completionPct,
      avgScore: stats.avgScore,
      isHomeroomView: isHomeroomView,
    );
  }

  // ── Card View (grouped by class) ──

  Widget _buildCardView(List<dynamic> data) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: data.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildHero(data);
        return buildClassCard(data[i - 1]);
      },
    );
  }

  Widget buildClassCard(dynamic g) {
    final cn = g['class_name']?.toString() ?? '-';
    final subjects = (g['subjects'] as List?) ?? [];
    final studentCount = ((g['student_count'] ?? 0) as num).toInt();

    // Class-level completion — mean of per-subject completion_pct
    double classCompletion = 0;
    if (subjects.isNotEmpty) {
      final sum = subjects.fold<double>(
        0,
        (a, s) => a + ((s['completion_pct'] ?? 0) as num).toDouble(),
      );
      classCompletion = sum / subjects.length;
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        children: [
          // Class header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor,
                        primaryColor.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.class_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cn,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$studentCount siswa · ${subjects.length} mapel',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                GradeRecapProgressRing(
                  value: classCompletion / 100,
                  size: 34,
                  strokeWidth: 3,
                  activeColor: _getProgressColor(classCompletion),
                  trackColor: ColorUtils.slate100,
                  label: '${classCompletion.round()}%',
                  labelStyle: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _getProgressColor(classCompletion),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: ColorUtils.slate100),
          ...subjects.asMap().entries.map((e) {
            final sub = e.value;
            final isLast = e.key == subjects.length - 1;
            return Column(
              children: [
                buildSubjectRow(g, sub),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 60, right: 14),
                    child: Container(height: 1, color: ColorUtils.slate100),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ── List View (flat subject rows) ──

  Widget _buildListView(List<dynamic> data) {
    final flatItems = <_FlatRecapItem>[];
    for (final g in data) {
      final cn = g['class_name']?.toString() ?? '-';
      final subjects = (g['subjects'] as List?) ?? [];
      for (final sub in subjects) {
        flatItems.add(_FlatRecapItem(
          classData: g,
          subject: sub,
          className: cn,
        ));
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: flatItems.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildHero(data);
        return _buildListItem(flatItems[i - 1]);
      },
    );
  }

  Widget _buildListItem(_FlatRecapItem item) {
    final sn = Subject.fromJson(item.subject as Map<String, dynamic>).name;
    final recapCount = ((item.subject['recap_count'] ?? 0) as num).toInt();
    final totalStudents =
        ((item.subject['total_students'] ?? 0) as num).toInt();
    final completionPct =
        ((item.subject['completion_pct'] ?? 0) as num).toDouble();
    final avgScore = item.subject['avg_final_score'] is num
        ? (item.subject['avg_final_score'] as num).toDouble()
        : null;
    final babCount = ((item.subject['bab_count'] ?? 0) as num).toInt();
    final teacherName = isHomeroomView ? _subjectTeacherName(item.subject) : null;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openRecapTable(item.classData, item.subject),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GradeRecapProgressRing(
                  value: completionPct / 100,
                  size: 44,
                  strokeWidth: 4,
                  activeColor: _getProgressColor(completionPct),
                  trackColor: ColorUtils.slate100,
                  label: '${completionPct.round()}%',
                  labelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _getProgressColor(completionPct),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sn,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.className,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (teacherName != null) ...[
                        const SizedBox(height: 3),
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
                                teacherName,
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
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _infoBadge(
                            '$recapCount/$totalStudents',
                            Icons.people_outline,
                          ),
                          if (babCount > 0)
                            _infoBadge(
                              '$babCount bab',
                              Icons.bookmark_outline,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (avgScore != null) ...[
                  const SizedBox(width: 8),
                  _scoreBadge(avgScore),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorUtils.slate300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate500),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(double score) {
    final color = _getScoreColor(score);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'avg',
            style: TextStyle(
              fontSize: 7,
              color: color.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Subject row (used in card view) ──

  Widget buildSubjectRow(dynamic classData, dynamic subject) {
    final sn = Subject.fromJson(subject as Map<String, dynamic>).name;
    final recapCount = ((subject['recap_count'] ?? 0) as num).toInt();
    final totalStudents = ((subject['total_students'] ?? 0) as num).toInt();
    final completionPct =
        ((subject['completion_pct'] ?? 0) as num).toDouble();
    final avgScore = subject['avg_final_score'] is num
        ? (subject['avg_final_score'] as num).toDouble()
        : null;
    final babCount = ((subject['bab_count'] ?? 0) as num).toInt();
    // Wali-kelas only — surfaces the subject teacher name under the mapel
    // label so the homeroom teacher can see who owns each subject's recap.
    final teacherName = isHomeroomView ? _subjectTeacherName(subject) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openRecapTable(classData, subject),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GradeRecapProgressRing(
                value: completionPct / 100,
                size: 36,
                strokeWidth: 3.5,
                activeColor: _getProgressColor(completionPct),
                trackColor: ColorUtils.slate100,
                label: '${completionPct.round()}%',
                labelStyle: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _getProgressColor(completionPct),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sn,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (teacherName != null) ...[
                      const SizedBox(height: 3),
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
                              teacherName,
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
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          '$recapCount/$totalStudents siswa',
                          style: TextStyle(
                            fontSize: 10,
                            color: ColorUtils.slate500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (babCount > 0)
                          Text(
                            '· $babCount bab',
                            style: TextStyle(
                              fontSize: 10,
                              color: ColorUtils.slate500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (avgScore != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getScoreColor(avgScore).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    avgScore.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _getScoreColor(avgScore),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorUtils.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Extract the subject teacher's name from a subject payload. Backend emits
  /// `teacher_name` in wali-kelas view; fall back to common aliases in case
  /// the response is served from an older cached entry or a different shape.
  String? _subjectTeacherName(dynamic subject) {
    final raw = subject['teacher_name'] ??
        subject['guru_nama'] ??
        (subject['teacher'] is Map ? subject['teacher']['name'] : null);
    final str = raw?.toString().trim();
    if (str == null || str.isEmpty || str == '-') return null;
    return str;
  }

  Color _getScoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  Color _getProgressColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }

  // Exposed state/methods needed
  late bool isLoading;
  late bool isHomeroomView;
  late bool isListView;
  late Color primaryColor;
  List<dynamic> get filteredData;
  // Backend-computed hero totals. Left abstract so the real field from
  // GradeRecapDataMixin wins linearization (same pattern we use for
  // availableClasses — shadowing with a `late` field here silently
  // uninitialized would zero the hero card).
  Map<String, dynamic> get recapSummary;
  Future<void> refresh();
  void openRecapTable(dynamic classData, dynamic subject);
  void toggleViewMode();
}

/// Helper class for flattened list view items.
class _FlatRecapItem {
  final dynamic classData;
  final dynamic subject;
  final String className;

  _FlatRecapItem({
    required this.classData,
    required this.subject,
    required this.className,
  });
}

class _HeroStats {
  final int classCount;
  final int totalStudents;
  final double completionPct;
  final double? avgScore;

  _HeroStats({
    required this.classCount,
    required this.totalStudents,
    required this.completionPct,
    required this.avgScore,
  });
}
