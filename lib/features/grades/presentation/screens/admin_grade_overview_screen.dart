// Admin school-wide grade overview screen.
//
// Shows school-level KPI stats (total grades, avg, pass rate, distribution)
// and per-teacher summary cards with their subjects, scores, and assessment counts.
// Uses admin theme color (blue) instead of teacher theme color (green).
//
// Consumes: GET /grades/admin-overview?academic_year_id=...
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
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
          const SizedBox(height: 16),
          _buildSectionTitle(lp),
          const SizedBox(height: 8),
          ...filtered.map((t) => _buildTeacherCard(t)),
        ],
      ),
    );
  }

  // ── School-wide KPI stats card ──

  Widget _buildSchoolStatsCard() {
    final total = _schoolStats['total_grades'] ?? 0;
    final avg = _schoolStats['avg_score'] ?? 0;
    final passRate = _schoolStats['pass_rate'] ?? 0;
    final totalTeachers = _schoolStats['total_teachers'] ?? 0;
    final totalStudents = _schoolStats['total_students'] ?? 0;
    final dist = _schoolStats['distribution'] is Map
        ? Map<String, dynamic>.from(_schoolStats['distribution'])
        : <String, dynamic>{};
    final high = dist['high'] ?? 0;
    final mid = dist['mid'] ?? 0;
    final low = dist['low'] ?? 0;
    final distTotal = high + mid + low;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_adminColor, _adminColor.withValues(alpha: 0.85)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _adminColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avg score + pass rate
          Row(
            children: [
              _buildStatBadge(
                '${(avg as num).toStringAsFixed(1)}',
                'Rata-rata',
                Colors.white,
              ),
              const SizedBox(width: 12),
              _buildStatBadge(
                '${(passRate as num).toStringAsFixed(1)}%',
                'Lulus (≥75)',
                Colors.white,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Total Nilai',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 2: Distribution bar
          if (distTotal > 0) ...[
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
            const SizedBox(height: 6),
            Row(
              children: [
                _buildDistLabel('≥80', high, ColorUtils.success600),
                const SizedBox(width: 12),
                _buildDistLabel('60-79', mid, ColorUtils.warning600),
                const SizedBox(width: 12),
                _buildDistLabel('<60', low, ColorUtils.error600),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Row 3: Teachers + students count
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '$totalTeachers guru',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.school_outlined,
                size: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                '$totalStudents siswa',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
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

  Widget _buildDistLabel(String range, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$range: $count',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ── Section title ──

  Widget _buildSectionTitle(LanguageProvider lp) {
    return Text(
      lp.getTranslatedText({'en': 'Per Teacher', 'id': 'Per Guru'}),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: ColorUtils.slate700,
      ),
    );
  }

  // ── Per-teacher card ──

  Widget _buildTeacherCard(dynamic teacher) {
    final name = teacher['teacher_name']?.toString() ?? '-';
    final avgScore = teacher['avg_score'] is num
        ? (teacher['avg_score'] as num).toDouble()
        : null;
    final totalGrades = teacher['total_grades'] ?? 0;
    final subjectCount = teacher['subject_count'] ?? 0;
    final classCount = teacher['class_count'] ?? 0;
    final passed = teacher['passed'] ?? 0;
    final failed = teacher['failed'] ?? 0;
    final passRate = totalGrades > 0
        ? (passed / totalGrades * 100).roundToDouble()
        : 0.0;
    final subjects = (teacher['subjects'] as List?) ?? [];
    final dist = teacher['distribution'] is Map
        ? Map<String, dynamic>.from(teacher['distribution'])
        : <String, dynamic>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () =>
              _openTeacherGrades(Map<String, dynamic>.from(teacher as Map)),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Teacher name + avg badge + chevron
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$subjectCount mapel · $classCount kelas · $totalGrades nilai',
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (avgScore != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _scoreColor(avgScore).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              avgScore.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _scoreColor(avgScore),
                              ),
                            ),
                            Text(
                              'Avg',
                              style: TextStyle(
                                fontSize: 8,
                                color: _scoreColor(
                                  avgScore,
                                ).withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: ColorUtils.slate300,
                    ),
                  ],
                ),

                // Row 2: Pass rate bar
                if (totalGrades > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: passRate / 100,
                            minHeight: 4,
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
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Row 3: Subject mini-chips
                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: subjects.take(5).map<Widget>((s) {
                      final sName = s['subject_name']?.toString() ?? '-';
                      final sAvg = s['avg_score'] is num
                          ? (s['avg_score'] as num).toDouble()
                          : null;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _adminColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _adminColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              sName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: ColorUtils.slate700,
                              ),
                            ),
                            if (sAvg != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                sAvg.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _scoreColor(sAvg),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  if (subjects.length > 5)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${subjects.length - 5} mapel lainnya',
                        style: TextStyle(
                          fontSize: 10,
                          color: ColorUtils.slate400,
                        ),
                      ),
                    ),
                ],
              ],
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
