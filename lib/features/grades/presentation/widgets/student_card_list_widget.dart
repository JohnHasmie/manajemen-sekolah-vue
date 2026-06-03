import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Matches a v4/v7 UUID anywhere in a string. Used to detect and strip raw
/// UUIDs that some legacy seeded data accidentally stored inside assessment
/// titles (e.g. "UH - 019d9a76-337f-72f6-a298-74df9906ee3a"). Those titles
/// both look like garbage to teachers and blow past the row width.
final _uuidRegex = RegExp(
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
);

/// 1-2 character initials from a student name. Used as the avatar
/// content on the Frame B student cards. Picks the first letter of
/// the first two whitespace-separated tokens; falls back to the first
/// two letters of the trimmed name if there's only one word; falls
/// back to "?" for empty names.
String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  if (parts[0].length >= 2) {
    return parts[0].substring(0, 2).toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

/// Returns a display-safe assessment title.
///
/// Strips any embedded UUID and collapses leftover separators ("- ", " -"),
/// so "UH - 019d9a76-..." becomes "UH" and "Judul Asli - `<uuid>`" becomes
/// "Judul Asli". If the title collapses to an empty string (e.g. the title
/// was *just* a UUID), returns empty — callers fall back to the type label.
String _sanitizeTitle(String rawTitle) {
  final stripped = rawTitle.replaceAll(_uuidRegex, '').trim();
  // Drop trailing/leading " - " that's left behind after stripping.
  return stripped
      .replaceAll(RegExp(r'^[\s\-–—]+'), '')
      .replaceAll(RegExp(r'[\s\-–—]+$'), '')
      .trim();
}

/// Displays student list as expandable cards (mobile-friendly grade view).
/// Extracted from GradeBookPageState to reduce its size.
class StudentCardListWidget extends StatelessWidget {
  final List<Student> filteredStudentList;
  final List<Map<String, dynamic>> gradeList;
  final Set<String> expandedStudents;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final bool canEdit;
  final bool isReadOnly;
  final Function(Student, Map<String, dynamic>) onStudentGradeTap;
  final Function(String) onStudentToggled;
  final Color Function(double) scoreColor;
  final String Function(String) shortTypeLabel;
  final String Function(dynamic) formatScore;
  final String Function(String, LanguageProvider) getGradeTypeLabel;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;

  const StudentCardListWidget({
    super.key,
    required this.filteredStudentList,
    required this.gradeList,
    required this.expandedStudents,
    required this.primaryColor,
    required this.languageProvider,
    required this.canEdit,
    required this.isReadOnly,
    required this.onStudentGradeTap,
    required this.onStudentToggled,
    required this.scoreColor,
    required this.shortTypeLabel,
    required this.formatScore,
    required this.getGradeTypeLabel,
    required this.assessmentHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: filteredStudentList.length,
      itemBuilder: (context, index) {
        final student = filteredStudentList[index];
        final isExpanded = expandedStudents.contains(student.id);

        // Gather all grades for this student
        final studentGrades = gradeList.where((g) {
          final gStudentId =
              (g['siswa_id'] ?? g['student_id'] ?? g['student_class_id'])
                  ?.toString();
          return gStudentId == student.id ||
              gStudentId == student.studentClassId;
        }).toList();

        // Calculate average
        final scores = studentGrades
            .map((g) => g['score'])
            .whereType<num>()
            .toList();
        final avg = scores.isNotEmpty
            ? scores.reduce((a, b) => a + b) / scores.length
            : null;

        // Group by type for expanded view
        final byType = <String, List<Map<String, dynamic>>>{};
        for (final g in studentGrades) {
          final type = (g['jenis'] ?? g['type'] ?? '').toString();
          byType.putIfAbsent(type, () => []).add(g);
        }

        // Below-KKM count for the expanded meta-strip pill.
        final belowKkm = scores.where((s) => s.toDouble() < 75).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            // Frame A polish — cobalt-tinted 1.5dp border + soft
            // cobalt shadow when expanded so the open card visually
            // separates from neighbours. Collapsed cards stay quiet
            // on slate-100.
            border: Border.all(
              color: isExpanded
                  ? primaryColor.withValues(alpha: 0.22)
                  : ColorUtils.slate100,
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Student header — always visible. When expanded, gets
              // a subtle cobalt-04% top fade so the heading reads as
              // a card masthead.
              InkWell(
                onTap: () => onStudentToggled(student.id),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: isExpanded
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              primaryColor.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                        )
                      : null,
                  padding: EdgeInsets.fromLTRB(
                    14,
                    isExpanded ? 14 : 12,
                    14,
                    isExpanded ? 12 : 10,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Avatar — bigger when expanded.
                          Container(
                            width: isExpanded ? 44 : 32,
                            height: isExpanded ? 44 : 32,
                            decoration: BoxDecoration(
                              color: avg != null && avg < 75
                                  ? ColorUtils.error600.withValues(alpha: 0.10)
                                  : primaryColor.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials(student.name),
                              style: TextStyle(
                                fontSize: isExpanded ? 13 : 11,
                                fontWeight: FontWeight.w800,
                                color: avg != null && avg < 75
                                    ? ColorUtils.error600
                                    : primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: TextStyle(
                                    fontSize: isExpanded ? 14 : 13,
                                    fontWeight: FontWeight.w800,
                                    color: ColorUtils.slate900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (student.studentNumber.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      'NIS ${student.studentNumber}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtils.slate500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Frame A — circular rerata ring on the
                          // expanded card. Conic-gradient track shows
                          // the % filled, big colored number inside,
                          // "AVG" caption underneath. Collapsed cards
                          // keep the simple inline number + chevron.
                          if (isExpanded && avg != null)
                            _buildRerataRing(avg.toDouble())
                          else if (avg != null) ...[
                            Text(
                              avg.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: scoreColor(avg.toDouble()),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                              color: ColorUtils.slate400,
                            ),
                          ] else
                            Icon(
                              isExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 20,
                              color: ColorUtils.slate400,
                            ),
                        ],
                      ),
                      // Meta-strip pills (Frame A) — surfaces the
                      // assessment count, KKM warnings, and one extra
                      // status pill so the teacher gets at-a-glance
                      // context without expanding further.
                      if (isExpanded) ...[
                        const SizedBox(height: 10),
                        _buildMetaStrip(
                          assessmentCount: studentGrades.length,
                          belowKkm: belowKkm,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Frame B mini-scoreboard — fixed 4-cell horizontal
              // strip showing the latest 4 grades. Empty cells show
              // an "—" placeholder so the row stays balanced even
              // when the student has no scores yet. Replaces the
              // legacy horizontal chip strip — same data, more
              // scoreboard-like read.
              if (!isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: _buildMiniScoreboard(studentGrades),
                ),

              // Expanded: full breakdown by type
              if (isExpanded) ...[
                Divider(height: 1, color: ColorUtils.slate100),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...byType.entries.map((entry) {
                        final typeKey = entry.key;
                        final typeLabel = getGradeTypeLabel(
                          typeKey,
                          languageProvider,
                        );
                        final grades = entry.value;
                        // Per-type stats: count + avg, used by the
                        // type-group bar on the right side.
                        final typeScores = grades
                            .map((g) => g['score'])
                            .whereType<num>()
                            .toList();
                        final typeAvg = typeScores.isNotEmpty
                            ? typeScores
                                      .map((s) => s.toDouble())
                                      .reduce((a, b) => a + b) /
                                  typeScores.length
                            : null;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Frame A type-group bar — icon badge +
                            // uppercase label + count chip + per-type
                            // avg in the score color.
                            _buildTypeGroupBar(
                              typeKey: typeKey,
                              label: typeLabel,
                              count: grades.length,
                              avg: typeAvg,
                            ),
                            ...grades.asMap().entries.map((row) {
                              final isLast = row.key == grades.length - 1;
                              final g = row.value;
                              final score = g['score'];
                              final rawTitle = g['title']?.toString() ?? '';
                              // Strip embedded UUIDs from legacy bad
                              // data ("UH - 019d9a76-…") so the row
                              // reads as "UH" instead of a hex blob.
                              final cleanTitle = _sanitizeTitle(rawTitle);
                              final displayTitle = cleanTitle.isNotEmpty
                                  ? cleanTitle
                                  : typeLabel;
                              final date =
                                  g['tanggal']?.toString().split('T').first ??
                                  '';
                              final dateFormatted = date.length >= 10
                                  ? '${date.substring(8, 10)}/${date.substring(5, 7)}'
                                  : date;

                              return InkWell(
                                onTap: () {
                                  final assessmentId = g['assessment_id']
                                      ?.toString();
                                  final type = (g['jenis'] ?? g['type'] ?? '')
                                      .toString();
                                  final headers = assessmentHeaders[type] ?? [];
                                  final matchedHeader = headers.firstWhere(
                                    (h) => h['id']?.toString() == assessmentId,
                                    orElse: () => <String, dynamic>{
                                      'id': assessmentId,
                                      'date': date,
                                      // Keep the ORIGINAL (unsanitized)
                                      // title in the header payload so any
                                      // dialog that needs the raw value
                                      // still has it.
                                      'title': rawTitle,
                                    },
                                  );
                                  // Always attach `type` to the header so
                                  // openInputForm picks the right grade
                                  // type — without this, tapping a UTS
                                  // row silently opened as "uh" and
                                  // posted a new row instead of updating.
                                  final header = {
                                    ...matchedHeader,
                                    'type': type,
                                  };
                                  onStudentGradeTap(student, header);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    8,
                                    4,
                                    8,
                                  ),
                                  decoration: isLast
                                      ? null
                                      : BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: ColorUtils.slate100,
                                              width: 1,
                                              style: BorderStyle.solid,
                                            ),
                                          ),
                                        ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              displayTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: ColorUtils.slate900,
                                                height: 1.2,
                                              ),
                                            ),
                                            if (dateFormatted.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2,
                                                ),
                                                child: Text(
                                                  dateFormatted,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: ColorUtils.slate500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Frame A score chip — tappable,
                                      // tinted by score, edit pencil
                                      // embedded inside the chip.
                                      _buildScoreChip(
                                        score: score is num
                                            ? score.toDouble()
                                            : null,
                                        formatted: score != null
                                            ? formatScore(score)
                                            : '-',
                                        canEdit: canEdit && !isReadOnly,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                      if (studentGrades.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'No grades yet',
                              'id': 'Belum ada nilai',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Frame B 4-cell mini-scoreboard — fixed-grid summary of the
  /// student's most recent assessments. Empty cells show "—" so the
  /// row stays balanced when the student has fewer than 4 grades.
  /// Each cell tints by `scoreColor` for at-a-glance reading. Replaces
  /// the legacy horizontal-scroll chip strip.
  Widget _buildMiniScoreboard(List<Map<String, dynamic>> studentGrades) {
    // Most-recent first — assumes the API or accumulator returns
    // grades in chronological order. Fall back to the original order
    // if no `tanggal` field is present.
    final sorted = [...studentGrades];
    sorted.sort((a, b) {
      final ad = (a['tanggal'] ?? a['created_at'] ?? '').toString();
      final bd = (b['tanggal'] ?? b['created_at'] ?? '').toString();
      return bd.compareTo(ad); // newest first
    });
    final latest = sorted.take(4).toList();

    Widget cell(Map<String, dynamic>? g) {
      if (g == null) {
        // Placeholder cell — keeps the 4-column grid visually
        // balanced when the student has fewer than 4 assessments.
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '—',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate400,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '—',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate300,
                ),
              ),
            ],
          ),
        );
      }
      final score = g['score'];
      final type = shortTypeLabel((g['jenis'] ?? g['type'] ?? '').toString());
      final color = score is num
          ? scoreColor(score.toDouble())
          : ColorUtils.slate400;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate500,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              score == null ? '—' : formatScore(score),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(child: cell(i < latest.length ? latest[i] : null)),
              if (i < 3) Container(width: 1, color: ColorUtils.slate100),
            ],
          ],
        ),
      ),
    );
  }

  /// Frame A circular rerata ring — 56dp circle with conic-gradient
  /// track showing % filled, inner white disc with the score number
  /// in score-color and "AVG" caption below. Replaces the bare
  /// inline avg + chevron when the card is expanded.
  Widget _buildRerataRing(double avg) {
    final color = scoreColor(avg);
    final percent = (avg.clamp(0, 100)) / 100.0;
    return SizedBox(
      width: 56,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [color, ColorUtils.slate100],
            stops: [percent, percent],
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'AVG',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frame A meta-strip — slate / cobalt / red pills surfacing
  /// assessment count, KKM warnings, and a primary mapel chip. Sits
  /// just under the avatar+name row when the card is expanded.
  Widget _buildMetaStrip({
    required int assessmentCount,
    required int belowKkm,
    required Color primaryColor,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _metaPill(
          label: '$assessmentCount Asesmen',
          bg: primaryColor.withValues(alpha: 0.10),
          fg: primaryColor,
        ),
        if (belowKkm > 0)
          _metaPill(
            label: '$belowKkm× < KKM',
            bg: ColorUtils.error600.withValues(alpha: 0.10),
            fg: ColorUtils.error600,
          )
        else if (assessmentCount > 0)
          _metaPill(
            label: 'Lengkap',
            bg: ColorUtils.success600.withValues(alpha: 0.10),
            fg: ColorUtils.success600,
          ),
      ],
    );
  }

  Widget _metaPill({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Frame A type-group bar — small icon badge + uppercase label +
  /// count chip + per-type avg in score-color on the right. Replaces
  /// the bare cobalt section heading.
  Widget _buildTypeGroupBar({
    required String typeKey,
    required String label,
    required int count,
    required double? avg,
  }) {
    final tint = _typeTint(typeKey);
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ColorUtils.slate100, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: tint.bg,
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Icon(_typeIcon(typeKey), size: 11, color: tint.fg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '×$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (avg != null)
            Text(
              avg.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: scoreColor(avg),
                letterSpacing: -0.2,
              ),
            ),
        ],
      ),
    );
  }

  /// Frame A score chip — tinted by score, with embedded edit pencil
  /// when the row is editable. Replaces the score-text + separate
  /// pencil-icon pattern.
  Widget _buildScoreChip({
    required double? score,
    required String formatted,
    required bool canEdit,
  }) {
    if (score == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ColorUtils.slate200, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: ColorUtils.slate400,
                letterSpacing: -0.3,
              ),
            ),
            if (canEdit) ...[
              const SizedBox(width: 6),
              Icon(Icons.edit_rounded, size: 11, color: ColorUtils.slate400),
            ],
          ],
        ),
      );
    }
    final c = scoreColor(score);
    final bg = c.withValues(alpha: 0.10);
    final border = c.withValues(alpha: 0.30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatted,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: c,
              letterSpacing: -0.3,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 6),
            Icon(Icons.edit_rounded, size: 11, color: c),
          ],
        ],
      ),
    );
  }

  /// Type-specific icon for the type-group bar.
  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'tg':
      case 'tugas':
        return Icons.assignment_outlined;
      case 'uh':
        return Icons.fact_check_outlined;
      case 'uts':
        return Icons.calendar_today_outlined;
      case 'uas':
        return Icons.school_outlined;
      case 'pts':
        return Icons.timeline_outlined;
      case 'pas':
        return Icons.workspace_premium_outlined;
      case 'pr':
      case 'praktik':
        return Icons.science_outlined;
    }
    return Icons.label_outline_rounded;
  }

  /// Type-specific tint for the icon badge. Cobalt / violet / amber /
  /// emerald palette matches the type-pill colors used in the class
  /// overview cards.
  ({Color bg, Color fg}) _typeTint(String type) {
    switch (type.toLowerCase()) {
      case 'tg':
      case 'tugas':
        return (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF7C3AED));
      case 'uh':
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case 'uts':
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFD97706));
      case 'uas':
        return (bg: const Color(0xFFFFE4E6), fg: const Color(0xFFE11D48));
      case 'pr':
      case 'praktik':
        return (bg: const Color(0xFFD1FAE5), fg: const Color(0xFF047857));
    }
    return (bg: ColorUtils.slate100, fg: ColorUtils.slate600);
  }
}
