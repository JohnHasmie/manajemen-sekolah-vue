// Parent report card list — Phase 3 brand-aligned redesign.
//
// Layout (per Parent_Phase3_RingkasanRapor_Mockup.svg):
//   ┌───────────────────────────────────────────────┐
//   │  ⊙   Rania Putri · Kelas 8B                   │  ← caption row
//   │      ┌─────────┬─────────┐                    │
//   │      │ 87,4    │ 96%     │  ← KPI mini-strip
//   │      │ Rata-rata│Kehadiran│
//   │      └─────────┴─────────┘
//   │      Mapel teratas:                           │  ← per-subject preview
//   │      • Matematika    A · 93                   │
//   │      • B. Indonesia  A · 90                   │
//   │      • IPA Terpadu   B · 85                   │
//   │      ───────────────────────────              │
//   │      Lihat rapor lengkap (10 mapel) →         │  ← CTA
//   └───────────────────────────────────────────────┘
//
// The card derives Rata-rata (mean of (knowledge_score+skill_score)/2
// across raport_subjects) and Kehadiran (1 - (sick+permit+absent)/100)
// client-side from the existing /parent/raports payload, so no backend
// change is required. The peringkat (rank) field isn't in the parent
// payload — we surface attendance + average instead, both of which
// the backend already computes.
//
// The screen-level header (BrandPageHeader, semester chip strip) is
// owned by ParentReportCardScreen — this mixin only owns
// `buildContentArea()` and the card visuals so the screen stays a
// thin shell.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/'
    'presentation/screens/'
    'parent_report_card_detail_screen.dart';
import 'package:manajemensekolah/features/report_cards/'
    'presentation/widgets/'
    'parent_report_card_detail_widgets.dart';

/// Mixin for UI builder methods (header, filter, content states).
mixin ReportCardUIBuilderMixin<T extends StatefulWidget> on State<T> {
  // State fields (from implementation state)
  bool get isLoading;
  String get errorMessage;
  List<dynamic> get studentsData;
  Map<String, dynamic> get parentData;
  String get selectedTermId;
  set selectedTermId(String value);

  // Data access methods (from ReportCardDataMixin)
  Color getPrimaryColor();
  LinearGradient getCardGradient();
  Future<void> loadData({bool useCache = true});
  Future<void> forceRefresh();

  /// Legacy header — kept for tests and any consumer that still calls
  /// `buildHeader()` directly. New screen wires `BrandPageHeader` at
  /// the screen level instead.
  Widget buildHeader() => const SizedBox.shrink();

  /// Legacy filter section. Same retention reason as `buildHeader()`.
  Widget buildFilterSection() => const SizedBox.shrink();

  Widget buildContentArea({List<dynamic>? filteredData}) {
    if (isLoading) {
      return const SkeletonListLoading(shrinkWrap: true);
    }

    if (errorMessage.isNotEmpty && studentsData.isEmpty) {
      return _buildErrorState();
    }

    final data = filteredData ?? studentsData;
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return _buildStudentsList(data);
  }

  Widget _buildErrorState() {
    return BrandEmptyState(
      icon: Icons.cloud_off_rounded,
      tone: BrandEmptyStateTone.danger,
      kicker: 'Sambungan bermasalah',
      title: 'Tidak dapat memuat rapor',
      message: errorMessage.isEmpty
          ? 'Periksa koneksi internet, lalu coba muat ulang.'
          : errorMessage,
      primaryAction: BrandEmptyStateAction(
        label: AppLocalizations.tryAgain.tr,
        icon: Icons.refresh_rounded,
        onTap: loadData,
      ),
    );
  }

  Widget _buildEmptyState() {
    return BrandEmptyState(
      icon: Icons.description_outlined,
      tone: BrandEmptyStateTone.info,
      kicker: 'Belum ada data',
      title: 'Belum ada rapor terbit',
      message:
          'Belum ada E-Raport yang dipublikasikan pada semester ini. '
          'Periksa kembali setelah sekolah menerbitkannya.',
      secondaryAction: BrandEmptyStateAction(
        label: 'Muat ulang',
        icon: Icons.refresh_rounded,
        onTap: loadData,
      ),
    );
  }

  Widget _buildStudentsList(List<dynamic> data) {
    // The screen pre-filters to a single selected child (via the child
    // selector chips in the header). When that filter resolves to one
    // entry, we render the full inline rapor — KPI strip, section
    // header, per-subject cards, and the "Lihat rapor lengkap" CTA —
    // matching Parent_Phase3_RingkasanRapor_Mockup.svg.
    //
    // When the filter happens to return more than one (unlikely; only
    // if siblings happen to share a published rapor in the same
    // request), we fall back to the legacy summary-card stack so we
    // never crash on an unexpected payload shape.
    final published = data.where((s) {
      final rc = (s as Map)['reportCard'];
      return rc != null && rc['status'] == 'published';
    }).toList();

    if (published.isEmpty) {
      return _buildEmptyState();
    }

    if (published.length == 1) {
      final entry = published.first as Map<String, dynamic>;
      return _buildInlineRapor(
        entry,
        entry['reportCard'] as Map<String, dynamic>,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: published.length,
      itemBuilder: (context, index) {
        final entry = published[index] as Map<String, dynamic>;
        return _buildStudentCard(
          entry,
          entry['reportCard'] as Map<String, dynamic>,
        );
      },
    );
  }

  /// Inline rapor body for a single child — KPI strip + per-subject
  /// score cards + "Lihat rapor lengkap" CTA. Matches the list-screen
  /// mockup intent: one child shown at a time, switch via header chips.
  Widget _buildInlineRapor(
    Map<String, dynamic> student,
    Map<String, dynamic> reportCard,
  ) {
    // Backend rename: `raport_subjects` → `report_card_subjects`.
    final subjects =
        (reportCard['reportCardSubjects'] ??
                reportCard['report_card_subjects'] ??
                reportCard['raportSubjects'] ??
                reportCard['raport_subjects'] ??
                const [])
            as List<dynamic>;
    final average = _averageScore(subjects);
    final attendance = _attendancePct(reportCard);
    final subjectCount = subjects.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: ColorUtils.slate200, width: 0.75),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: _kpiStrip(average, attendance, subjectCount),
          ),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Nilai per mata pelajaran',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
                Text(
                  '$subjectCount mapel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
          if (subjects.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: ColorUtils.slate200, width: 0.75),
              ),
              child: Text(
                'Belum ada nilai mata pelajaran.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate500,
                ),
              ),
            ),
          ...subjects.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubjectMiniCard(
                subject: s as Map,
                onTap: () => showParentRaporDeskripsiSheet(context, subject: s),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // CTA → opens the detail screen with the same payload.
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openDetail(student, reportCard),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: ColorUtils.brandAzureDeep,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lihat rapor lengkap ($subjectCount mapel)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.brandAzureDeep,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: ColorUtils.brandAzureDeep,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(
    Map<String, dynamic> student,
    Map<String, dynamic> reportCard,
  ) {
    final studentInfo = (student['student'] as Map?) ?? const {};
    final studentName = (studentInfo['name'] ?? 'Siswa').toString();
    final klass =
        (studentInfo['class_name'] ??
                studentInfo['class'] ??
                student['class_name'] ??
                '')
            .toString();
    final initials = _initials(studentName);
    final palette = _avatarPalette(studentName);

    // Backend rename: `raport_subjects` → `report_card_subjects`.
    final subjects =
        (reportCard['reportCardSubjects'] ??
                reportCard['report_card_subjects'] ??
                reportCard['raportSubjects'] ??
                reportCard['raport_subjects'] ??
                const [])
            as List<dynamic>;
    final subjectCount = subjects.length;
    final average = _averageScore(subjects);
    final attendance = _attendancePct(reportCard);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(student, reportCard),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: ColorUtils.slate200, width: 0.75),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: avatar + name/class + chevron.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: palette.bg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: palette.fg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate900,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (klass.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              klass.startsWith('Kelas')
                                  ? klass
                                  : 'Kelas $klass',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 11,
                            color: Color(0xFF15803D),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Terbit',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // KPI mini-strip: Rata-rata · Kehadiran · Mapel.
                _kpiStrip(average, attendance, subjectCount),
                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(height: 1, color: ColorUtils.slate100),
                  const SizedBox(height: 10),
                  Text(
                    'MAPEL TERATAS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate400,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._topSubjectsPreview(subjects),
                ],
                const SizedBox(height: 12),
                Container(height: 1, color: ColorUtils.slate100),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: ColorUtils.brandAzureDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lihat rapor lengkap',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.brandAzureDeep,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: ColorUtils.brandAzureDeep,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(
    Map<String, dynamic> student,
    Map<String, dynamic> reportCard,
  ) {
    final studentInfo = (student['student'] as Map?) ?? const {};
    final name = (studentInfo['name'] ?? 'Siswa').toString();
    AppNavigator.push(
      context,
      ParentReportCardDetailScreen(
        reportCardData: Map<String, dynamic>.from(reportCard),
        studentName: name,
        userRole: 'wali',
        studentData: Map<String, dynamic>.from(studentInfo),
      ),
    );
  }

  Widget _kpiStrip(double? average, double? attendance, int subjectCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _kpiCell(
              label: 'Rata-rata',
              value: average == null
                  ? '–'
                  : average.toStringAsFixed(1).replaceAll('.', ','),
              accent: _averageAccent(average),
            ),
          ),
          Container(width: 1, height: 36, color: ColorUtils.slate200),
          Expanded(
            child: _kpiCell(
              label: 'Kehadiran',
              value: attendance == null
                  ? '–'
                  : '${attendance.toStringAsFixed(0)}%',
              accent: _attendanceAccent(attendance),
            ),
          ),
          Container(width: 1, height: 36, color: ColorUtils.slate200),
          Expanded(
            child: _kpiCell(
              label: 'Mapel',
              value: subjectCount.toString(),
              accent: const Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.1,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate500,
          ),
        ),
      ],
    );
  }

  /// Top 3 subjects ranked by knowledge score, presented as compact rows.
  List<Widget> _topSubjectsPreview(List<dynamic> subjects) {
    // Build rows with score then sort desc.
    final rows = subjects.map((raw) {
      final s = raw as Map;
      final subject = (s['subject'] is Map)
          ? (s['subject'] as Map)['name']?.toString() ?? '-'
          : '-';
      final score = _toDouble(
        s['knowledge_score'] ?? s['knowledgeScore'] ?? s['skill_score'],
      );
      return _SubjectRow(subject: subject, score: score);
    }).toList()..sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));

    return rows.take(3).map((row) {
      final letter = _scoreLetter(row.score);
      final palette = _letterPalette(letter);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: palette.bg,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: palette.fg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                row.subject,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              row.score == null ? '–' : row.score!.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate900,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  /// Stable per-name accent so siblings get distinguishable avatars.
  ({Color bg, Color fg}) _avatarPalette(String name) {
    const palettes = [
      (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8)),
      (bg: Color(0xFFDCFCE7), fg: Color(0xFF15803D)),
      (bg: Color(0xFFFEF3C7), fg: Color(0xFFB45309)),
      (bg: Color(0xFFEDE9FE), fg: Color(0xFF6D28D9)),
      (bg: Color(0xFFFCE7F3), fg: Color(0xFFBE185D)),
    ];
    if (name.isEmpty) return palettes.first;
    final idx = name.codeUnits.fold<int>(0, (a, b) => a + b) % palettes.length;
    return palettes[idx];
  }

  double? _averageScore(List<dynamic> subjects) {
    if (subjects.isEmpty) return null;
    var sum = 0.0;
    var count = 0;
    for (final raw in subjects) {
      final s = raw as Map;
      final k = _toDouble(s['knowledge_score'] ?? s['knowledgeScore']);
      final sk = _toDouble(s['skill_score'] ?? s['skillScore']);
      if (k != null && sk != null) {
        sum += (k + sk) / 2;
        count++;
      } else if (k != null) {
        sum += k;
        count++;
      } else if (sk != null) {
        sum += sk;
        count++;
      }
    }
    if (count == 0) return null;
    return sum / count;
  }

  double? _attendancePct(Map<String, dynamic> raport) {
    final sick = _toInt(raport['attendance_sick']);
    final permit = _toInt(raport['attendance_permit']);
    final absent = _toInt(raport['attendance_absent']);
    final present = _toInt(raport['attendance_present']);
    final total = _toInt(raport['attendance_total']);

    // Prefer explicit total when the backend provides it; otherwise
    // fall back to sick+permit+absent+present (best-effort).
    final denom =
        total ?? ((sick ?? 0) + (permit ?? 0) + (absent ?? 0) + (present ?? 0));
    if (denom == 0) return null;
    final missed = (sick ?? 0) + (permit ?? 0) + (absent ?? 0);
    return ((denom - missed) / denom) * 100;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _scoreLetter(double? score) {
    if (score == null) return '–';
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'E';
  }

  ({Color bg, Color fg}) _letterPalette(String letter) {
    switch (letter) {
      case 'A':
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
      case 'B':
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case 'C':
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
      case 'D':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
      default:
        return (bg: ColorUtils.slate100, fg: ColorUtils.slate500);
    }
  }

  Color _averageAccent(double? avg) {
    if (avg == null) return ColorUtils.slate500;
    if (avg >= 85) return const Color(0xFF15803D);
    if (avg >= 75) return const Color(0xFF1D4ED8);
    if (avg >= 65) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  Color _attendanceAccent(double? pct) {
    if (pct == null) return ColorUtils.slate500;
    if (pct >= 95) return const Color(0xFF15803D);
    if (pct >= 85) return const Color(0xFF1D4ED8);
    if (pct >= 75) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }
}

class _SubjectRow {
  const _SubjectRow({required this.subject, required this.score});

  final String subject;
  final double? score;
}

/// Per-subject mini card for the inline rapor body — Option C layout
/// from `_design/parent_raport_inline_summary_dual_score_redesign.html`.
///
/// One-row card: letter badge (40dp) + subject name + meta line +
/// two compact KI badges side-by-side at the right (KI 3 cobalt,
/// KI 4 violet, each with a small tag label and a 15pt bold value).
/// Failing cell (score < KKM) shifts to red tone. Empty (no score
/// yet) renders "–" in slate-300.
///
/// Tap opens the per-mapel Deskripsi Capaian sheet (KI 3 + KI 4
/// narration) so the parent can read context without leaving the
/// summary screen. Tap target is the entire card (~64dp tall).
class _SubjectMiniCard extends StatelessWidget {
  const _SubjectMiniCard({required this.subject, this.onTap});

  final Map subject;
  final VoidCallback? onTap;

  // ── Brand tokens (mirrored from parent_report_card_detail_widgets.dart)
  static const Color _kKi3 = Color(0xFF1B6FB8); // brandCobalt
  static const Color _kKi4 = Color(0xFF7C3AED); // violet600
  static const Color _kFailFg = Color(0xFFB91C1C);

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _bandLetter(double v) {
    if (v >= 90) return 'A';
    if (v >= 80) return 'B';
    if (v >= 70) return 'C';
    if (v >= 60) return 'D';
    return 'E';
  }

  ({Color bg, Color fg}) _letterPalette(String letter) {
    switch (letter) {
      case 'A':
        return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
      case 'B':
        return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
      case 'C':
        return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
      case 'D':
        return (bg: const Color(0xFFFEE2E2), fg: const Color(0xFFB91C1C));
      default:
        return (bg: ColorUtils.slate100, fg: ColorUtils.slate500);
    }
  }

  String _friendlyPredikat(String knowledgeRaw, String skillRaw) {
    String label(String letter) {
      switch (letter) {
        case 'A':
          return 'Sangat Baik';
        case 'B':
          return 'Baik';
        case 'C':
          return 'Cukup';
        case 'D':
        case 'E':
          return 'Perlu dukungan';
        default:
          return letter;
      }
    }

    final k = knowledgeRaw.trim();
    final s = skillRaw.trim();
    if (k.isEmpty && s.isEmpty) return '';
    if (k == s) return label(k);
    if (k.isNotEmpty && s.isNotEmpty) {
      return '${label(k)} / ${label(s)}';
    }
    return label(k.isEmpty ? s : k);
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = (subject['subject'] is Map)
        ? ((subject['subject'] as Map)['name']?.toString() ?? 'Mata Pelajaran')
        : 'Mata Pelajaran';
    final teacher =
        (subject['teacher_name'] ??
                (subject['subject'] is Map
                    ? (subject['subject'] as Map)['teacher_name']
                    : null) ??
                '')
            .toString();
    final knowledge = _toDouble(subject['knowledge_score']);
    final skill = _toDouble(subject['skill_score']);
    final kkm = _toDouble(subject['kkm']) ?? 75;

    // Predikat: prefer backend-stored letter, else derive from score.
    final kPredStored = (subject['knowledge_predicate'] ?? '')
        .toString()
        .trim();
    final sPredStored = (subject['skill_predicate'] ?? '').toString().trim();
    final kPredLetter = kPredStored.isNotEmpty && kPredStored != '–'
        ? kPredStored
        : (knowledge != null ? _bandLetter(knowledge) : '');
    final sPredLetter = sPredStored.isNotEmpty && sPredStored != '–'
        ? sPredStored
        : (skill != null ? _bandLetter(skill) : '');

    // Letter badge: derived from the average of whatever scores exist.
    final hasAnyScore = knowledge != null || skill != null;
    final avg = (knowledge != null && skill != null)
        ? (knowledge + skill) / 2
        : (knowledge ?? skill);
    final letter = avg == null ? '–' : _bandLetter(avg);
    final letterPalette = letter == '–'
        ? (bg: ColorUtils.slate100, fg: ColorUtils.slate400)
        : _letterPalette(letter);

    final knowledgeFailing = knowledge != null && knowledge < kkm;
    final skillFailing = skill != null && skill < kkm;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Letter badge (left)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: letterPalette.bg,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Text(
              letter,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: letterPalette.fg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Subject name + meta (center)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  _composeMeta(
                    teacher: teacher,
                    knowledgePred: kPredLetter,
                    skillPred: sPredLetter,
                    hasAnyScore: hasAnyScore,
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Two compact KI badges side-by-side (right)
          _kiBadge(
            tag: 'KI 3',
            accent: _kKi3,
            score: knowledge,
            failing: knowledgeFailing,
          ),
          const SizedBox(width: 5),
          _kiBadge(
            tag: 'KI 4',
            accent: _kKi4,
            score: skill,
            failing: skillFailing,
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: card,
      ),
    );
  }

  String _composeMeta({
    required String teacher,
    required String knowledgePred,
    required String skillPred,
    required bool hasAnyScore,
  }) {
    final parts = <String>[];
    if (teacher.isNotEmpty) parts.add(teacher);
    final friendly = _friendlyPredikat(knowledgePred, skillPred);
    if (friendly.isNotEmpty) {
      parts.add(friendly);
    } else if (!hasAnyScore) {
      parts.add('Belum dinilai');
    }
    return parts.join(' · ');
  }

  Widget _kiBadge({
    required String tag,
    required Color accent,
    required double? score,
    required bool failing,
  }) {
    final effectiveAccent = failing ? _kFailFg : accent;
    final hasScore = score != null;
    final valueColor = !hasScore
        ? ColorUtils.slate300
        : (failing ? _kFailFg : ColorUtils.slate900);
    return Container(
      constraints: const BoxConstraints(minWidth: 50),
      padding: const EdgeInsets.fromLTRB(9, 5, 9, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [effectiveAccent.withValues(alpha: 0.08), Colors.white],
          stops: const [0.0, 0.70],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(
          color: effectiveAccent.withValues(alpha: failing ? 0.25 : 0.20),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            tag,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: effectiveAccent,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            hasScore ? score.toStringAsFixed(0) : '–',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.0,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
