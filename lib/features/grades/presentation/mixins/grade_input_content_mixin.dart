import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/teacher_async_view.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';

mixin GradeInputContentMixin on ConsumerState<GradePage> {
  bool get isLoading;
  bool get isHomeroomView;
  bool get isTableView;
  String? get gradeErrorMessage => null;

  List<dynamic> getFilteredData();

  Future<void> refresh();

  Map<String, dynamic> safeMap(dynamic raw);

  /// Open the grade book for a `(classData, subject)` tuple.
  ///
  /// [columnId] is an optional assessment-column deep link forwarded to
  /// [GradeBookPage.initialColumnId]. When non-null, the grade book opens
  /// directly in edit mode for that column — used by the teacher
  /// dashboard's "Buku Nilai belum dilengkapi" inbox row so each row
  /// lands the teacher on the specific column they tapped.
  void openGradeBook(dynamic classData, dynamic subject, {String? columnId});

  Color get primaryColor;

  Widget buildContent(LanguageProvider lp) {
    return TeacherAsyncView(
      isLoading: isLoading,
      errorMessage: gradeErrorMessage,
      isEmpty: getFilteredData().isEmpty,
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
      emptySubtitle: isHomeroomView
          ? lp.getTranslatedText({
              'en': 'You are not assigned as homeroom teacher',
              'id': 'Anda tidak ditugaskan sebagai wali kelas',
            })
          : lp.getTranslatedText({
              'en': 'No teaching assignments found',
              'id': 'Tidak ada jadwal mengajar ditemukan',
            }),
      emptyIcon: isHomeroomView ? Icons.class_outlined : Icons.grade_outlined,
      childBuilder: () => isTableView
          ? buildTableView(getFilteredData())
          : _buildListView(getFilteredData()),
    );
  }

  /// Frame A list view — flatten the class-grouped data into one card
  /// per (class × subject) combo. Each card shows class kicker + mapel
  /// name, big avg, 3-cell meta (siswa / asesmen / nilai), assessment
  /// type pills, and a per-assessment progress strip.
  Widget _buildListView(List<dynamic> data) {
    final pairs = <(Map<String, dynamic>, Map<String, dynamic>)>[];
    for (final g in data) {
      if (g is! Map) continue;
      final classData = Map<String, dynamic>.from(g);
      final subjects = (g['subjects'] as List?) ?? const [];
      if (subjects.isEmpty) {
        // Class with no subjects → still render a card so the teacher
        // sees the row exists (rare, but happens for fresh class
        // assignments).
        pairs.add((classData, <String, dynamic>{}));
        continue;
      }
      for (final s in subjects) {
        if (s is! Map) continue;
        pairs.add((classData, Map<String, dynamic>.from(s)));
      }
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: pairs.length,
      itemBuilder: (_, i) {
        final p = pairs[i];
        return _buildClassSubjectCard(p.$1, p.$2);
      },
    );
  }

  Widget buildTableView(List<dynamic> data);

  /// Frame A — single (class × subject) card. Replaces the legacy
  /// class-grouped card with stacked subject rows. Cleaner read,
  /// faster tap, no nested-divider noise.
  Widget _buildClassSubjectCard(
    Map<String, dynamic> classData,
    Map<String, dynamic> subject,
  ) {
    final className = classData['class_name']?.toString() ?? '-';
    final studentCount = classData['student_count'] is int
        ? classData['student_count'] as int
        : int.tryParse('${classData['student_count'] ?? 0}') ?? 0;
    final subjectName = subject['name']?.toString() ?? '-';
    final assessments = (subject['assessments'] as List?) ?? const [];
    final filledCount = assessments
        .where((a) => a is Map && a['avg'] is num)
        .length;
    final totalNilai = subject['total_nilai'] is num
        ? (subject['total_nilai'] as num).toInt()
        : null;
    final avgRaw = subject['avg_score'];
    final avg = avgRaw is num ? avgRaw.toDouble() : null;

    final hasAssessments = assessments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: subject.isEmpty
              ? null
              : () => openGradeBook(classData, subject),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row — icon + class kicker + mapel + avg.
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.school_rounded,
                        size: 18,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'KELAS ${className.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subjectName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate900,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasAssessments)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            avg == null ? '—' : avg.toStringAsFixed(0),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: avg == null
                                  ? ColorUtils.slate400
                                  : scoreColor(avg),
                              height: 1,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AVG',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'BELUM',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate400,
                          letterSpacing: 0.6,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Meta row — Siswa / Asesmen / Nilai. Each cell is a
                // slate-50 mini box.
                Row(
                  children: [
                    Expanded(child: _metaCell('$studentCount', 'Siswa')),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _metaCell(
                        '${assessments.length}',
                        'Asesmen',
                        emphasize: assessments.isEmpty
                            ? _MetaEmphasis.muted
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _metaCell(
                        totalNilai == null
                            ? (filledCount == 0 ? '0' : '$filledCount')
                            : '$totalNilai',
                        'Nilai',
                        emphasize: filledCount == 0
                            ? _MetaEmphasis.muted
                            : (filledCount < assessments.length
                                  ? _MetaEmphasis.warning
                                  : null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Foot — type pills + Buka CTA.
                Container(
                  padding: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: ColorUtils.slate100, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _buildTypePills(assessments),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subject.isEmpty ? '+ Mulai' : 'Buka',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: subject.isEmpty
                                  ? const Color(0xFF7C3AED)
                                  : primaryColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            subject.isEmpty
                                ? Icons.add_rounded
                                : Icons.chevron_right_rounded,
                            size: 14,
                            color: subject.isEmpty
                                ? const Color(0xFF7C3AED)
                                : primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Per-assessment progress strip — one bar per
                // assessment, color-coded by avg presence. Hidden
                // when no assessments exist yet.
                if (hasAssessments) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final a in assessments)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate200,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: a is Map && a['avg'] is num
                                  ? 1.0
                                  : 0.08,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _progressColor(a),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaCell(String value, String label, {_MetaEmphasis? emphasize}) {
    final v = emphasize == _MetaEmphasis.muted
        ? ColorUtils.slate400
        : (emphasize == _MetaEmphasis.warning
              ? ColorUtils.warning600
              : ColorUtils.slate900);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: v,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the assessment type pills (e.g. UH ×4, TG ×3, UTS ×1) —
  /// counts grouped by the legacy "type" field (uh / tg / uts / uas /
  /// pr) which the summary endpoint sets per assessment.
  List<Widget> _buildTypePills(List<dynamic> assessments) {
    if (assessments.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: ColorUtils.slate100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Belum ada asesmen',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ];
    }
    final groups = <String, int>{};
    for (final a in assessments) {
      if (a is! Map) continue;
      final t = (a['type'] ?? a['kind'] ?? 'lain').toString().toLowerCase();
      groups[t] = (groups[t] ?? 0) + 1;
    }
    return [
      for (final entry in groups.entries) _typePill(entry.key, entry.value),
    ];
  }

  Widget _typePill(String type, int count) {
    final spec = _typeStyle(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${spec.label} ×$count',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: spec.fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  ({String label, Color bg, Color fg}) _typeStyle(String type) {
    switch (type) {
      case 'uh':
        return (
          label: 'UH',
          bg: const Color(0xFFDBEAFE),
          fg: const Color(0xFF1D4ED8),
        );
      case 'tg':
      case 'tugas':
        return (
          label: 'TG',
          bg: const Color(0xFFEDE9FE),
          fg: const Color(0xFF7C3AED),
        );
      case 'uts':
        return (
          label: 'UTS',
          bg: const Color(0xFFFEF3C7),
          fg: const Color(0xFFD97706),
        );
      case 'uas':
        return (
          label: 'UAS',
          bg: const Color(0xFFFFE4E6),
          fg: const Color(0xFFE11D48),
        );
      case 'pr':
      case 'praktik':
        return (
          label: 'PR',
          bg: const Color(0xFFD1FAE5),
          fg: const Color(0xFF047857),
        );
    }
    return (
      label: type.toUpperCase(),
      bg: ColorUtils.slate100,
      fg: ColorUtils.slate700,
    );
  }

  Color _progressColor(dynamic a) {
    if (a is Map && a['avg'] is num) {
      final v = (a['avg'] as num).toDouble();
      return scoreColor(v);
    }
    return ColorUtils.slate300;
  }

  Color scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }
}

/// Local enum used by `_metaCell` to tint the value in muted /
/// warning states without exposing a public type.
enum _MetaEmphasis { muted, warning }
