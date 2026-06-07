// Admin school-wide grade overview screen.
//
// Shows school-level KPI stats (total grades, avg, pass rate, distribution)
// and per-teacher summary cards with their subjects, scores, and assessment
// counts.
// Uses admin theme color (blue) instead of teacher theme color (green).
//
// Consumes: GET /grades/admin-overview?academic_year_id=...
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';

class AdminGradeOverviewScreen extends ConsumerStatefulWidget {
  const AdminGradeOverviewScreen({super.key});

  @override
  ConsumerState<AdminGradeOverviewScreen> createState() =>
      _AdminGradeOverviewScreenState();
}

class _AdminGradeOverviewScreenState
    extends ConsumerState<AdminGradeOverviewScreen> {
  static final Color _adminColor = ColorUtils.getRoleColor('admin');

  Map<String, dynamic> _schoolStats = {};
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _buildCacheKey() {
    final ayId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'admin_grade_overview_$ayId';
  }

  Future<void> _loadData({bool useCache = true}) async {
    try {
      final cacheKey = _buildCacheKey();

      // 1. Cache-first: show cached data instantly
      if (useCache) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(minutes: 5),
          );
          if (cached is Map<String, dynamic> && mounted) {
            setState(() {
              _schoolStats = Map<String, dynamic>.from(
                cached['school_stats'] ?? {},
              );
              _teachers = (cached['teachers'] as List?) ?? [];
              _isLoading = false;
            });
            // Don't return — continue fetching fresh data from API
          }
        } catch (_) {}
      }

      // Show skeleton only if no cache hit
      if (_teachers.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      // 2. Always fetch fresh data from API
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final data = await GradeService.getAdminOverview(academicYearId: ayId);

      if (mounted) {
        setState(() {
          _schoolStats = Map<String, dynamic>.from(data['school_stats'] ?? {});
          _teachers = (data['teachers'] as List?) ?? [];
          _isLoading = false;
          _errorMessage = null;
        });
        await LocalCacheService.save(cacheKey, data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  List<dynamic> get _filteredTeachers {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return _teachers;
    return _teachers.where((t) {
      final name = (t['teacher_name']?.toString() ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  void _openTeacherGrades(Map<String, dynamic> teacher) {
    final teacherData = {
      'id': teacher['teacher_id']?.toString() ?? '',
      'teacher_id': teacher['teacher_id']?.toString() ?? '',
      'nama': teacher['teacher_name']?.toString() ?? 'Guru',
      'role': 'admin',
    };
    AppNavigator.push(context, GradePage(teacher: teacherData));
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          BrandPageHeader(
            role: 'admin',
            subtitle: lp.getTranslatedText({
              'en': 'ACADEMIC',
              'id': 'AKADEMIK',
            }),
            title: lp.getTranslatedText({
              'en': 'Grades Overview',
              'id': 'Buku Nilai',
            }),
            bottomSlot: _buildSearchField(lp),
          ),
          Expanded(child: _buildContent(lp)),
        ],
      ),
    );
  }

  /// Compact white search bar that lives in the [BrandPageHeader.bottomSlot]
  /// — matches the v3 pattern where chips/filters or a search live inside
  /// the gradient hero rather than below it.
  Widget _buildSearchField(LanguageProvider lp) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: kGraSearchTeacher.tr,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LanguageProvider lp) {
    if (_isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: _errorMessage!,
        ),
      );
    }

    if (_teachers.isEmpty) {
      return EmptyState(
        icon: Icons.grade_outlined,
        title: kGraNoGradeData.tr,
        subtitle: kGraNoGradesRecorded.tr,
      );
    }

    final filtered = _filteredTeachers;
    return AppRefreshIndicator(
      onRefresh: () => _loadData(useCache: false),
      role: 'admin',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // KPI strip sits fully below the pinned header + search bar.
          //
          // This screen lays the header and body out in a plain Column
          // (not BrandPageLayout's Stack overlap), so there is no reserved
          // gradient free-zone for the card to overlap into. The old
          // negative Transform.translate(0, -22) dragged the card up
          // *behind* the floating "Cari guru…" search field, clipping its
          // top row (KPI numbers cut off under the navy header). This is
          // the Buku Nilai counterpart of the Rekap Nilai fix (c7d45bc2);
          // render it in normal flow with a small top gap instead.
          _buildKpiStrip(),
          // Dedicated "Sebaran Nilai" card pulled out of the old KPI
          // block — distribution gets to breathe instead of fighting
          // the KPI tiles for attention.
          _buildSebaranCard(),
          const SizedBox(height: 16),
          _buildSectionHeader(lp, filtered.length),
          const SizedBox(height: 10),
          ...filtered.map(_buildTeacherCard),
        ],
      ),
    );
  }

  // =====================================================================
  // Lightweight KPI strip (Fix-FF — replaces the heavy navy gradient
  // card that previously hosted both the KPIs AND the distribution bar
  // in one block). Matches the new Rekap Nilai screen and every other
  // brand surface that overlaps a 3-cell white KPI card onto the navy
  // header.
  // =====================================================================

  Widget _buildKpiStrip() {
    final total = (_schoolStats['total_grades'] as num?)?.toInt() ?? 0;
    final avg = (_schoolStats['avg_score'] as num?)?.toDouble() ?? 0.0;
    final passRate = (_schoolStats['pass_rate'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _kpiCell(value: '$total', label: 'NILAI', color: _adminColor),
            _kpiDivider(),
            _kpiCell(
              value: avg.toStringAsFixed(1),
              label: 'RATA-RATA',
              color: ColorUtils.slate800,
            ),
            _kpiDivider(),
            _kpiCell(
              value: '${passRate.toStringAsFixed(0)}%',
              label: 'LULUS ≥75',
              color: ColorUtils.success600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: ColorUtils.slate200,
    );
  }

  // =====================================================================
  // Sebaran Nilai — moves the distribusi bar + legend out of the KPI
  // block and gives each bucket its own tinted pill (green Tuntas, amber
  // Perlu Perhatian, red Remedial). Footer chip row carries "N guru · N
  // siswa · update timestamp" so the meta stays available but doesn't
  // shout.
  // =====================================================================

  Widget _buildSebaranCard() {
    final total = (_schoolStats['total_grades'] as num?)?.toInt() ?? 0;
    final dist = _schoolStats['distribution'] is Map
        ? Map<String, dynamic>.from(_schoolStats['distribution'])
        : <String, dynamic>{};
    final high = (dist['high'] as num?)?.toInt() ?? 0;
    final mid = (dist['mid'] as num?)?.toInt() ?? 0;
    final low = (dist['low'] as num?)?.toInt() ?? 0;
    final distTotal = high + mid + low;
    final totalTeachers =
        (_schoolStats['total_teachers'] as num?)?.toInt() ?? 0;
    final totalStudents =
        (_schoolStats['total_students'] as num?)?.toInt() ?? 0;

    String pct(int n) {
      if (distTotal == 0) return '0%';
      return '${((n / distTotal) * 100).round()}%';
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sebaran Nilai',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '$total nilai · KKM 75',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stacked bar — flat 10dp band so each segment reads.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: distTotal == 0
                  ? Container(color: ColorUtils.slate100)
                  : Row(
                      children: [
                        Expanded(
                          flex: high.clamp(0, 1 << 31).toInt() == 0 ? 0 : high,
                          child: Container(color: ColorUtils.success600),
                        ),
                        Expanded(
                          flex: mid.clamp(0, 1 << 31).toInt() == 0 ? 0 : mid,
                          child: Container(color: ColorUtils.warning600),
                        ),
                        Expanded(
                          flex: low.clamp(0, 1 << 31).toInt() == 0 ? 0 : low,
                          child: Container(color: ColorUtils.error600),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // 3 tinted pills.
          Row(
            children: [
              Expanded(
                child: _SebaranPill(
                  label: 'TUNTAS · ≥80',
                  value: '$high',
                  pct: pct(high),
                  tone: _SebaranTone.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SebaranPill(
                  label: 'PERLU · 60–79',
                  value: '$mid',
                  pct: pct(mid),
                  tone: _SebaranTone.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SebaranPill(
                  label: 'REMEDIAL · <60',
                  value: '$low',
                  pct: pct(low),
                  tone: _SebaranTone.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Footer chips: guru · siswa.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _MetaChip(
                icon: Icons.person_rounded,
                label: '$totalTeachers guru',
              ),
              _MetaChip(
                icon: Icons.school_rounded,
                label: '$totalStudents siswa',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // Section header — kicker style "PER GURU · N ORANG" with hairline
  // =====================================================================

  Widget _buildSectionHeader(LanguageProvider lp, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 13, color: ColorUtils.slate500),
          const SizedBox(width: 6),
          Text(
            lp.getTranslatedText({'en': 'PER TEACHER', 'id': 'PER GURU'}),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ColorUtils.slate500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count ORANG',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ColorUtils.slate300,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: ColorUtils.slate100)),
        ],
      ),
    );
  }

  // =====================================================================
  // Per-teacher card — v3 row pattern with 4-px score edge + initial avatar
  //
  // Mirrors the InvoiceRow shape used on Tagihan: a 4-px coloured left
  // edge (green/amber/red based on avg score) acts as a quick visual
  // skim cue, the navy-tinted initials avatar replaces the absent
  // photo, and the trailing "Avg" badge becomes a slim score pill
  // instead of the previous oversized 18pt block. The chevron sits
  // next to the badge on its own line so it never fights with the
  // amount.
  // =====================================================================

  Widget _buildTeacherCard(dynamic teacher) {
    final name = teacher['teacher_name']?.toString() ?? '-';
    final avgScore = teacher['avg_score'] is num
        ? (teacher['avg_score'] as num).toDouble()
        : null;
    final totalGrades = teacher['total_grades'] ?? 0;
    final subjectCount = teacher['subject_count'] ?? 0;
    final classCount = teacher['class_count'] ?? 0;
    final passed = teacher['passed'] ?? 0;
    final passRate = totalGrades > 0
        ? (passed / totalGrades * 100).roundToDouble()
        : 0.0;
    final subjects = (teacher['subjects'] as List?) ?? [];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final edgeColor = avgScore == null
        ? ColorUtils.slate300
        : _scoreColor(avgScore);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              _openTeacherGrades(Map<String, dynamic>.from(teacher as Map)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 4-px score edge
                  Container(width: 4, color: edgeColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: avatar + name + meta + avg pill + chevron
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _adminColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _adminColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$subjectCount mapel · '
                                      '$classCount kelas · $totalGrades nilai',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: ColorUtils.slate500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (avgScore != null) _AvgPill(value: avgScore),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: ColorUtils.slate400,
                              ),
                            ],
                          ),

                          // Row 2: Pass-rate progress bar
                          if (totalGrades > 0) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: passRate / 100,
                                      minHeight: 5,
                                      backgroundColor: ColorUtils.slate100,
                                      valueColor: AlwaysStoppedAnimation(
                                        passRate >= 75
                                            ? ColorUtils.success600
                                            : passRate >= 50
                                            ? ColorUtils.warning600
                                            : ColorUtils.error600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${passRate.toStringAsFixed(0)}% lulus',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Row 3: Subject mini-chips (max 5 + overflow)
                          if (subjects.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final s in subjects.take(5))
                                  _SubjectChip(
                                    name: s['subject_name']?.toString() ?? '-',
                                    avg: s['avg_score'] is num
                                        ? (s['avg_score'] as num).toDouble()
                                        : null,
                                    scoreColor: _scoreColor,
                                  ),
                                if (subjects.length > 5)
                                  _OverflowSubjectChip(
                                    extra: subjects.length - 5,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }
}

// =======================================================================
// Reusable pieces — kept private to this file so they can't be reached
// for from elsewhere. Each one is a thin presentational widget that the
// state class composes into the larger surface.
// =======================================================================

class _AvgPill extends StatelessWidget {
  final double value;
  const _AvgPill({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? ColorUtils.success600
        : value >= 60
        ? ColorUtils.warning600
        : ColorUtils.error600;
    final bg = value >= 80
        ? const Color(0xFFF0FDF4)
        : value >= 60
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFEF2F2);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'AVG',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String name;
  final double? avg;
  final Color Function(double) scoreColor;
  const _SubjectChip({
    required this.name,
    required this.avg,
    required this.scoreColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate700,
            ),
          ),
          if (avg != null) ...[
            const SizedBox(width: 6),
            Container(width: 1, height: 10, color: ColorUtils.slate200),
            const SizedBox(width: 6),
            Text(
              avg!.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: scoreColor(avg!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sebaran helpers (Fix-FF) ──────────────────────────────────────

enum _SebaranTone { green, amber, red }

class _SebaranPill extends StatelessWidget {
  final String label;
  final String value;
  final String pct;
  final _SebaranTone tone;

  const _SebaranPill({
    required this.label,
    required this.value,
    required this.pct,
    required this.tone,
  });

  ({Color bg, Color border, Color dot, Color value}) _palette() {
    switch (tone) {
      case _SebaranTone.green:
        return (
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFFBBF7D0),
          dot: ColorUtils.success600,
          value: ColorUtils.success700,
        );
      case _SebaranTone.amber:
        return (
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          dot: ColorUtils.warning600,
          value: ColorUtils.warning700,
        );
      case _SebaranTone.red:
        return (
          bg: const Color(0xFFFEF2F2),
          border: const Color(0xFFFECACA),
          dot: ColorUtils.error600,
          value: const Color(0xFFB91C1C),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: p.dot, shape: BoxShape.circle),
              ),
              const Spacer(),
              Text(
                pct,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: p.value,
              letterSpacing: -0.4,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: ColorUtils.slate500),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowSubjectChip extends StatelessWidget {
  final int extra;
  const _OverflowSubjectChip({required this.extra});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '+$extra mapel',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: ColorUtils.slate600,
        ),
      ),
    );
  }
}
