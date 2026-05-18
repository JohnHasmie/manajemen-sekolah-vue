// Admin school-wide grade overview screen.
//
// Shows school-level KPI stats (total grades, avg, pass rate, distribution)
// and per-teacher summary cards with their subjects, scores, and assessment counts.
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
                hintText: lp.getTranslatedText({
                  'en': 'Search teacher...',
                  'id': 'Cari guru...',
                }),
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
        title: lp.getTranslatedText({
          'en': 'No Grade Data',
          'id': 'Belum Ada Data Nilai',
        }),
        subtitle: lp.getTranslatedText({
          'en': 'No grades have been recorded yet',
          'id': 'Belum ada nilai yang dicatat',
        }),
      );
    }

    final filtered = _filteredTeachers;
    return AppRefreshIndicator(
      onRefresh: () => _loadData(useCache: false),
      role: 'admin',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          _buildSchoolStatsCard(),
          const SizedBox(height: 18),
          _buildSectionHeader(lp, filtered.length),
          const SizedBox(height: 10),
          ...filtered.map(_buildTeacherCard),
        ],
      ),
    );
  }

  // =====================================================================
  // School-wide KPI hero card
  //
  // Replaces the prior lopsided layout (two small badges left + one giant
  // "550" floating right) with a balanced 3-up tile strip in the same
  // visual language as `MoneyFlowStrip` on Keuangan: each tile holds an
  // uppercase kicker, a heavy value, and a faint footer caption. The
  // distribution bar moves *underneath* the strip with a flat 1px legend
  // row instead of competing with the strip for real estate. The "X guru
  // · Y siswa" meta stays as a faint footer line so it doesn't dominate.
  // =====================================================================

  Widget _buildSchoolStatsCard() {
    final total = _schoolStats['total_grades'] ?? 0;
    final avg = _schoolStats['avg_score'] ?? 0;
    final passRate = _schoolStats['pass_rate'] ?? 0;
    final totalTeachers = _schoolStats['total_teachers'] ?? 0;
    final totalStudents = _schoolStats['total_students'] ?? 0;
    final dist = _schoolStats['distribution'] is Map
        ? Map<String, dynamic>.from(_schoolStats['distribution'])
        : <String, dynamic>{};
    final high = (dist['high'] as num?)?.toInt() ?? 0;
    final mid = (dist['mid'] as num?)?.toInt() ?? 0;
    final low = (dist['low'] as num?)?.toInt() ?? 0;
    final distTotal = high + mid + low;

    return Container(
      decoration: BoxDecoration(
        gradient: ColorUtils.headerFadeGradient(
          _adminColor,
          endOpacity: 0.82,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _adminColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-up KPI tile strip
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  kicker: 'TOTAL',
                  value: '$total',
                  caption: 'Nilai',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  kicker: 'RATA-RATA',
                  value: (avg as num).toStringAsFixed(1),
                  caption: 'dari 100',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  kicker: 'LULUS',
                  value: '${(passRate as num).toStringAsFixed(1)}%',
                  caption: 'KKM ≥ 75',
                ),
              ),
            ],
          ),

          // Distribution band — only if we actually have data
          if (distTotal > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  Icons.donut_small_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  'DISTRIBUSI',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· $distTotal NILAI',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  _buildDistBar(high / distTotal, ColorUtils.success600),
                  _buildDistBar(mid / distTotal, ColorUtils.warning600),
                  _buildDistBar(low / distTotal, ColorUtils.error600),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DistLegend(
                    range: '≥80',
                    count: high,
                    color: ColorUtils.success600,
                  ),
                ),
                Expanded(
                  child: _DistLegend(
                    range: '60–79',
                    count: mid,
                    color: ColorUtils.warning600,
                  ),
                ),
                Expanded(
                  child: _DistLegend(
                    range: '<60',
                    count: low,
                    color: ColorUtils.error600,
                  ),
                ),
              ],
            ),
          ],

          // Hairline + footer counts
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                '$totalTeachers guru',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.school_rounded,
                size: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 5),
              Text(
                '$totalStudents siswa',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistBar(double fraction, Color color) {
    return Expanded(
      flex: (fraction * 100).round().clamp(1, 100),
      child: Container(height: 6, color: color),
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
                                      '$subjectCount mapel · $classCount kelas · $totalGrades nilai',
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

class _StatTile extends StatelessWidget {
  final String kicker;
  final String value;
  final String caption;
  const _StatTile({
    required this.kicker,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kicker,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistLegend extends StatelessWidget {
  final String range;
  final int count;
  final Color color;
  const _DistLegend({
    required this.range,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '$range · $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

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
