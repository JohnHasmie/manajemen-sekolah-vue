// Admin school-wide Rekap Nilai overview screen — Fix-FF Frame C.
//
// Per kelas × mapel completeness rows. Each row surfaces:
//   • progress %         — how much of the recap (bab + UTS + UAS) is filled
//   • avg final score    — among students with final_score set
//   • lulus %            — % final_score >= 75 in this slice
//   • status chips       — "N/N bab", "UTS ✓|belum", "UAS ✓|belum"
//
// Tapping a row drills into the existing GradeRecapPage scoped to that
// (class, subject) so the admin can see / edit the teacher's recap
// table directly. The screen follows BrandPageLayout's overlap pattern
// (white KPI card overlapping the navy header) — same chrome as the
// redesigned Buku Nilai screen.
//
// Consumes: GET /grades/admin-recap-overview?academic_year_id=...
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_screen.dart';

class AdminGradeRecapOverviewScreen extends ConsumerStatefulWidget {
  const AdminGradeRecapOverviewScreen({super.key});

  @override
  ConsumerState<AdminGradeRecapOverviewScreen> createState() =>
      _AdminGradeRecapOverviewScreenState();
}

class _AdminGradeRecapOverviewScreenState
    extends ConsumerState<AdminGradeRecapOverviewScreen> {
  static final Color _adminColor = ColorUtils.getRoleColor('admin');

  Map<String, dynamic> _summary = {};
  List<dynamic> _rows = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  bool _onlyIncomplete = false;

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
    return 'admin_grade_recap_overview_$ayId';
  }

  Future<void> _loadData({bool useCache = true}) async {
    try {
      final cacheKey = _buildCacheKey();

      // Cache-first for instant display.
      if (useCache) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(minutes: 5),
          );
          if (cached is Map<String, dynamic> && mounted) {
            setState(() {
              _summary = Map<String, dynamic>.from(cached['summary'] ?? {});
              _rows = (cached['rows'] as List?) ?? [];
              _isLoading = false;
            });
          }
        } catch (_) {
          // Cache miss is non-fatal — we'll fetch below.
        }
      }

      if (_rows.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final data = await GradeService.getAdminRecapOverview(
        academicYearId: ayId,
      );

      if (mounted) {
        setState(() {
          _summary = Map<String, dynamic>.from(data['summary'] ?? {});
          _rows = (data['rows'] as List?) ?? [];
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

  List<dynamic> get _filteredRows {
    final q = _searchController.text.toLowerCase().trim();
    return _rows.where((r) {
      if (r is! Map) return false;
      if (_onlyIncomplete && (r['is_complete'] == true)) return false;
      if (q.isEmpty) return true;
      final cn = (r['class_name'] ?? '').toString().toLowerCase();
      final sn = (r['subject_name'] ?? '').toString().toLowerCase();
      final tn = (r['teacher_name'] ?? '').toString().toLowerCase();
      return cn.contains(q) || sn.contains(q) || tn.contains(q);
    }).toList();
  }

  void _openSlice(Map<String, dynamic> row) {
    final teacherId = row['teacher_id']?.toString() ?? '';
    final teacherName = row['teacher_name']?.toString() ?? 'Guru';
    if (teacherId.isEmpty) return;
    final teacher = {
      'id': teacherId,
      'teacher_id': teacherId,
      'name': teacherName,
      'nama': teacherName,
      'role': 'admin',
    };
    final initialClass = {
      'id': row['class_id']?.toString() ?? '',
      'class_id': row['class_id']?.toString() ?? '',
      'name': row['class_name']?.toString() ?? '',
    };
    final initialSubject = {
      'id': row['subject_id']?.toString() ?? '',
      'name': row['subject_name']?.toString() ?? '',
    };
    AppNavigator.push(
      context,
      GradeRecapPage(
        teacher: teacher,
        initialClass: initialClass,
        initialSubject: initialSubject,
      ),
    );
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
              'en': 'Grade Recap',
              'id': 'Rekap Nilai',
            }),
            bottomSlot: _buildSearchField(lp),
          ),
          Expanded(child: _buildContent(lp)),
        ],
      ),
    );
  }

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
          Icon(Icons.search_rounded, size: 18, color: ColorUtils.slate400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: lp.getTranslatedText({
                  'en': 'Search class, subject, or teacher...',
                  'id': 'Cari kelas, mapel, atau guru...',
                }),
                hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LanguageProvider lp) {
    if (_isLoading && _rows.isEmpty) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
    }

    if (_errorMessage != null && _rows.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline,
          title: 'Error',
          subtitle: _errorMessage!,
        ),
      );
    }

    if (_rows.isEmpty) {
      return EmptyState(
        icon: Icons.assessment_outlined,
        title: lp.getTranslatedText({
          'en': 'No Recap Data Yet',
          'id': 'Belum Ada Rekap Nilai',
        }),
        subtitle: lp.getTranslatedText({
          'en':
              'Recap rows are created when teachers start filling the bab/UTS/UAS table.',
          'id':
              'Rekap muncul saat guru mulai mengisi tabel bab/UTS/UAS untuk kelas + mapel.',
        }),
      );
    }

    final filtered = _filteredRows;
    return AppRefreshIndicator(
      onRefresh: () => _loadData(useCache: false),
      role: 'admin',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        children: [
          // KPI strip overlaps the header (overlay offset).
          Transform.translate(
            offset: const Offset(0, -22),
            child: _buildKpiStrip(),
          ),
          _buildFilterChipsRow(lp),
          const SizedBox(height: 12),
          _buildSectionHeader(lp, filtered.length),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: EmptyState(
                icon: Icons.filter_alt_off_rounded,
                title: lp.getTranslatedText({
                  'en': 'No matching slices',
                  'id': 'Tidak ada slice yang cocok',
                }),
                subtitle: lp.getTranslatedText({
                  'en': 'Try clearing the filter or search query.',
                  'id': 'Coba hapus filter atau kata kunci pencarian.',
                }),
              ),
            )
          else
            ...filtered.map((r) => _buildSliceCard(r as Map<String, dynamic>)),
        ],
      ),
    );
  }

  // ── KPI strip — 3 cells (Slice / Sudah Isi / Final ✓) ──

  Widget _buildKpiStrip() {
    final totalSlice = (_summary['total_slice'] as num?)?.toInt() ?? 0;
    final completed = (_summary['completed_slice'] as num?)?.toInt() ?? 0;
    final avgProgress = (_summary['avg_progress'] as num?)?.toDouble() ?? 0.0;

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
            _kpiCell(value: '$totalSlice', label: 'SLICE', color: _adminColor),
            _kpiDivider(),
            _kpiCell(
              value: '${avgProgress.toStringAsFixed(0)}%',
              label: 'PROGRESS',
              color: ColorUtils.slate800,
            ),
            _kpiDivider(),
            _kpiCell(
              value: '$completed',
              label: 'FINAL ✓',
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

  // ── Filter chip row (incomplete-only toggle) ──

  Widget _buildFilterChipsRow(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _filterChip(
            label: lp.getTranslatedText({
              'en': 'Incomplete only',
              'id': 'Belum lengkap',
            }),
            selected: _onlyIncomplete,
            onTap: () => setState(() => _onlyIncomplete = !_onlyIncomplete),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _adminColor.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? _adminColor.withValues(alpha: 0.30)
                : ColorUtils.slate200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: _adminColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? _adminColor : ColorUtils.slate700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section header ──

  Widget _buildSectionHeader(LanguageProvider lp, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.assessment_outlined, size: 13, color: ColorUtils.slate500),
          const SizedBox(width: 6),
          Text(
            lp.getTranslatedText({'en': 'PER SLICE', 'id': 'PER SLICE'}),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ColorUtils.slate500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '· $count SLICE',
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

  // ── Per-slice card ──

  Widget _buildSliceCard(Map<String, dynamic> row) {
    final className = row['class_name']?.toString() ?? '-';
    final subjectName = row['subject_name']?.toString() ?? '-';
    final teacherName = row['teacher_name']?.toString();
    final progressPct = (row['progress_pct'] as num?)?.toDouble() ?? 0.0;
    final avgFinal = (row['avg_final_score'] as num?)?.toDouble();
    final passRate = (row['pass_rate'] as num?)?.toDouble() ?? 0.0;
    final babTotal = (row['bab_total'] as num?)?.toInt() ?? 0;
    final babFilled = (row['bab_filled'] as num?)?.toInt() ?? 0;
    final studentsTotal = (row['students_total'] as num?)?.toInt() ?? 0;
    final utsDone = (row['uts_done'] as num?)?.toInt() ?? 0;
    final uasDone = (row['uas_done'] as num?)?.toInt() ?? 0;

    final bucket = _bucketColor(progressPct);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openSlice(row),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row: class pill + subject name + chevron
                Row(
                  children: [
                    _classPill(className, bucket),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: ColorUtils.slate400,
                    ),
                  ],
                ),
                if (teacherName != null && teacherName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 38),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_rounded,
                          size: 11,
                          color: ColorUtils.slate500,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // 3 stats row: progress / rerata / lulus
                Row(
                  children: [
                    _sliceStat(
                      label: 'PROGRESS',
                      value: '${progressPct.toStringAsFixed(0)}%',
                      color: bucket,
                    ),
                    Expanded(child: _verticalDivider()),
                    _sliceStat(
                      label: 'RATA-RATA',
                      value: avgFinal == null
                          ? '—'
                          : avgFinal.toStringAsFixed(1),
                      color: ColorUtils.slate800,
                    ),
                    Expanded(child: _verticalDivider()),
                    _sliceStat(
                      label: 'LULUS',
                      value: '${passRate.toStringAsFixed(0)}%',
                      color: _passColor(passRate),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Slim progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 5,
                    color: ColorUtils.slate100,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (progressPct / 100).clamp(0.0, 1.0),
                      child: Container(color: bucket),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Status chips: bab / UTS / UAS
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statusChip(
                      label: studentsTotal > 0 && babTotal > 0
                          ? '${(babFilled / studentsTotal).floor()}/$babTotal bab'
                          : '0/$babTotal bab',
                      done:
                          studentsTotal > 0 &&
                          babTotal > 0 &&
                          babFilled >= (studentsTotal * babTotal),
                    ),
                    _statusChip(
                      label: utsDone >= studentsTotal && studentsTotal > 0
                          ? 'UTS ✓'
                          : 'UTS belum',
                      done: utsDone >= studentsTotal && studentsTotal > 0,
                    ),
                    _statusChip(
                      label: uasDone >= studentsTotal && studentsTotal > 0
                          ? 'UAS ✓'
                          : 'UAS belum',
                      done: uasDone >= studentsTotal && studentsTotal > 0,
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

  Widget _classPill(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _sliceStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: ColorUtils.slate100,
    );
  }

  Widget _statusChip({required String label, required bool done}) {
    final fg = done ? ColorUtils.success700 : ColorUtils.warning700;
    final bg = done ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB);
    final border = done
        ? const Color(0xFFBBF7D0)
        : ColorUtils.warning600.withValues(alpha: 0.30);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: done ? ColorUtils.success600 : ColorUtils.warning600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bucket helpers ──

  Color _bucketColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 40) return _adminColor;
    if (pct >= 1) return ColorUtils.warning600;
    return ColorUtils.slate500;
  }

  Color _passColor(double pct) {
    if (pct >= 80) return ColorUtils.success700;
    if (pct >= 60) return ColorUtils.warning700;
    return ColorUtils.error600;
  }
}
