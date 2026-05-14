// Parent view of student grades — Phase 3 brand-aligned redesign.
//
// Read-only view of a child's grades with multi-anak chip selector,
// auto-marking grades as read when scrolled into view, and caching.
// In Laravel terms: `GradeController@parentIndex`.
//
// The data layer (5 mixins: read tracking / data loading / tour /
// detail / UI builder) is unchanged; only the screen's build()
// composition moved over to the canonical Phase-3 stack
// (BrandPageHeader + ChildSelectorChipRow + RefreshIndicator).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_data_loading_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_detail_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_filter_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_ui_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/shell/shell_tab.dart';

/// Parent's read-only view of student grades.
///
/// Props: optional [academicYearId].
class ParentGradeScreen extends ConsumerStatefulWidget {
  final String? academicYearId;

  const ParentGradeScreen({super.key, this.academicYearId});

  @override
  ParentGradeScreenState createState() => ParentGradeScreenState();
}

/// State for [ParentGradeScreen].
///
/// Main state holder with all mixins for functionality.
class ParentGradeScreenState extends ConsumerState<ParentGradeScreen>
    with
        PaginationMixin<ParentGradeScreen>,
        ParentGradeReadTrackingMixin,
        ParentGradeDataLoadingMixin,
        ParentGradeDetailMixin,
        ParentGradeFilterMixin,
        ParentGradeUiMixin {
  List<dynamic> _gradeList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  bool _isLoading = true;

  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _gradeListKey = GlobalKey();

  // Grade type color map. `tugas` uses the brand azure so the parent
  // grade chip stays inside the wali palette rather than borrowing the
  // legacy corporate-blue swatch.
  final Map<String, Color> _gradeTypeColorMap = {
    'tugas': ColorUtils.brandAzure,
    'uh': ColorUtils.success600,
    'uts': ColorUtils.warning600,
    'uas': ColorUtils.error600,
  };

  @override
  void initState() {
    super.initState();
    initPagination();
    loadUserData();
  }

  @override
  void dispose() {
    disposePagination();
    disposeReadTracking();
    super.dispose();
  }

  // Mixin-required property getters for data
  @override
  List<dynamic> get gradeList => _gradeList;
  @override
  set gradeList(List<dynamic> value) {
    _gradeList = value;
  }

  @override
  List<dynamic> get studentList => _studentList;
  @override
  set studentList(List<dynamic> value) {
    _studentList = value;
  }

  @override
  String? get selectedStudentId => _selectedStudentId;
  @override
  set selectedStudentId(String? value) {
    _selectedStudentId = value;
  }

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) {
    _isLoading = value;
  }

  @override
  String? get academicYearId => widget.academicYearId;

  @override
  GlobalKey get studentSelectorKey => _studentSelectorKey;

  @override
  GlobalKey get gradeListKey => _gradeListKey;

  @override
  Map<String, Color> get gradeTypeColorMap => _gradeTypeColorMap;

  @override
  Color Function() get getPrimaryColor =>
      () => ColorUtils.getRoleColor('wali');

  @override
  LinearGradient Function() get getCardGradient =>
      () => ColorUtils.brandGradient('wali');

  @override
  void Function(String?) get onStudentChanged => (value) {
    setState(() {
      _selectedStudentId = value;
      _gradeList = [];
    });
    loadGrades();
  };

  @override
  String Function(String) get getGradeTypeLabel => _getGradeTypeLabel;

  String _getGradeTypeLabel(String type) {
    switch (type) {
      case 'tugas':
        return 'Tugas';
      case 'uh':
        return 'UH';
      case 'uts':
        return 'UTS';
      case 'uas':
        return 'UAS';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Future<void> onRefreshRequested() => forceRefresh();

  // Drives the realtime pill — bumped after every successful refresh.
  DateTime _lastSync = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final kpi = _gradeList.isNotEmpty ? _buildKpiWidget(lang) : null;
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        header: _buildHeader(lang),
        kpiCard: kpi,
        role: 'wali',
        onRefresh: () async {
          await onRefreshRequested();
          if (mounted) setState(() => _lastSync = DateTime.now());
        },
        bodyChildren: [_buildGradesBody(lang)],
      ),
    );
  }

  /// Renders the body of the grade screen per
  /// `Parent_Phase3_Nilai_Mockup.svg`:
  ///   - 3-column KPI strip (Penilaian / Rata-rata / Rentang)
  ///   - Subject sections — each with a 'MATEMATIKA · BU SARI' style
  ///     header pill (subject name + average pill on the right) and
  ///     the grade cards for that subject.
  /// Falls back to the loading skeleton or empty state via the
  /// existing `buildGradeList()` mixin call when there's no data.
  // Cached aggregates recomputed when grade list changes.
  ({int scored, int pending, double avg, double min, double max})
  _gradeAggregates() {
    final scores = _gradeList
        .map((g) => double.tryParse((g as Map)['score']?.toString() ?? ''))
        .whereType<double>()
        .toList();
    return (
      scored: scores.length,
      pending: _gradeList.length - scores.length,
      avg: scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length,
      min: scores.isEmpty ? 0.0 : scores.reduce((a, b) => a < b ? a : b),
      max: scores.isEmpty ? 0.0 : scores.reduce((a, b) => a > b ? a : b),
    );
  }

  Widget _buildKpiWidget(LanguageProvider lang) {
    final s = _gradeAggregates();
    return _buildKpiStrip(lang, s.scored, s.pending, s.avg, s.min, s.max);
  }

  Widget _buildGradesBody(LanguageProvider lang) {
    if (_gradeList.isEmpty) {
      return buildGradeList(); // mixin handles loading + empty state
    }

    final groups = <String, List<dynamic>>{};
    for (final g in _gradeList) {
      final m = g as Map;
      final subject =
          (m['subject_name'] ??
                  m['mata_pelajaran'] ??
                  AppLocalizations.subject.tr)
              .toString();
      groups.putIfAbsent(subject, () => <dynamic>[]).add(g);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final entry in groups.entries) ...[
          _GradeSubjectHeader(
            subject: entry.key,
            average: _averageOf(entry.value),
          ),
          // Reuse the existing per-card rendering by passing this
          // subject's grades through `buildGradeList()` would mean
          // overriding the gradeList field temporarily — too fragile.
          // Inline a lighter card row instead.
          for (final g in entry.value)
            _GradeCardRow(
              grade: g as Map<String, dynamic>,
              onTap: () => showGradeDetail(g),
              onVisible: () => onItemVisible(g),
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  double _averageOf(List<dynamic> grades) {
    final scores = grades
        .map((g) => double.tryParse((g as Map)['score']?.toString() ?? ''))
        .whereType<double>()
        .toList();
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  Widget _buildKpiStrip(
    LanguageProvider lang,
    int scored,
    int pending,
    double avg,
    double minScore,
    double maxScore,
  ) {
    String fmtScore(double v) {
      if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
      return v.toStringAsFixed(1).replaceAll('.', ',');
    }

    String avgLabel() {
      if (avg >= 85) return 'Sangat Baik';
      if (avg >= 75) return 'Baik';
      if (avg >= 65) return 'Cukup';
      return 'Perlu perbaikan';
    }

    Color avgColor() {
      if (avg >= 85) return const Color(0xFF15803D);
      if (avg >= 75) return const Color(0xFF1D4ED8);
      if (avg >= 65) return const Color(0xFFB45309);
      return const Color(0xFF991B1B);
    }

    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: lang.getTranslatedText({
            'en': 'Assessments',
            'id': 'Penilaian',
          }),
          value: '${_gradeList.length}',
          sub: '$scored sudah · $pending menunggu',
        ),
        BrandKpiColumn(
          label: lang.getTranslatedText({'en': 'Average', 'id': 'Rata-rata'}),
          value: fmtScore(avg),
          badge: avgLabel(),
          badgeColor: avgColor(),
        ),
        BrandKpiColumn(
          label: lang.getTranslatedText({'en': 'Range', 'id': 'Rentang'}),
          value: '${fmtScore(minScore)} — ${fmtScore(maxScore)}',
        ),
      ],
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    final summaries = _studentList
        .map<ChildSummary>((raw) {
          final model = Student.fromJson(raw as Map<String, dynamic>);
          return ChildSummary(
            id: model.id,
            shortName: model.name.isEmpty ? '?' : model.name,
            klass: model.className.isEmpty ? '-' : 'Kelas ${model.className}',
          );
        })
        .toList(growable: false);

    return BrandPageHeader(
      role: 'wali',
      kpiOverlayHeight: BrandKpiStrip.defaultOverlap,
      showBackButton: true,
      onBackPressed: () => AppNavigator.pop(context),
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: showFilterSheet,
          badgeCount: hasActiveFilter ? 1 : 0,
          badgeBorderColor: ColorUtils.brandAzure,
        ),
      ],
      isRealtimeFresh: !isLoading,
      childSelector: summaries.length < 2
          ? null
          : ChildSelectorChipRow(
              key: _studentSelectorKey,
              children: summaries,
              selectedChildId: _selectedStudentId ?? summaries.first.id,
              onSelected: onStudentChanged,
              accentColor: ColorUtils.brandAzureDeep,
            ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lang.getTranslatedText({
              'en': 'Grade Type',
              'id': 'Tipe Nilai',
            }),
            value: selectedGradeTypeFilter != null
                ? getGradeTypeLabel(selectedGradeTypeFilter!)
                : null,
            onTap: showFilterSheet,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Body widgets per Parent_Phase3_Nilai_Mockup.svg
// ===========================================================================

/// Per-subject section header — subject name + average pill on the
/// right ('A · 91' style). Renders above each subject's grade rows.
class _GradeSubjectHeader extends StatelessWidget {
  final String subject;
  final double average;

  const _GradeSubjectHeader({required this.subject, required this.average});

  String _letter() {
    if (average >= 85) return 'A';
    if (average >= 75) return 'B';
    if (average >= 65) return 'C';
    if (average >= 55) return 'D';
    return 'E';
  }

  Color _bg() {
    if (average >= 85) return const Color(0xFFDCFCE7);
    if (average >= 75) return const Color(0xFFDBEAFE);
    if (average >= 65) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  Color _fg() {
    if (average >= 85) return const Color(0xFF15803D);
    if (average >= 75) return const Color(0xFF1D4ED8);
    if (average >= 65) return const Color(0xFFB45309);
    return const Color(0xFF991B1B);
  }

  @override
  Widget build(BuildContext context) {
    final avgInt = average.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          if (average > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _bg(),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                '${_letter()} · $avgInt',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _fg(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One grade card row in the per-subject list. Letter-grade badge on
/// the left, title + type/date in the middle, score + KKM on the
/// right — matches the mockup's grade-row layout.
class _GradeCardRow extends StatefulWidget {
  final Map<String, dynamic> grade;
  final VoidCallback onTap;
  final VoidCallback onVisible;

  const _GradeCardRow({
    required this.grade,
    required this.onTap,
    required this.onVisible,
  });

  @override
  State<_GradeCardRow> createState() => _GradeCardRowState();
}

class _GradeCardRowState extends State<_GradeCardRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  String _letter(double s) {
    if (s >= 85) return 'A';
    if (s >= 75) return 'B';
    if (s >= 65) return 'C';
    if (s >= 55) return 'D';
    return 'E';
  }

  Color _bg(double s) {
    if (s >= 85) return const Color(0xFFDCFCE7);
    if (s >= 75) return const Color(0xFFDBEAFE);
    if (s >= 65) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  Color _fg(double s) {
    if (s >= 85) return const Color(0xFF15803D);
    if (s >= 75) return const Color(0xFF1D4ED8);
    if (s >= 65) return const Color(0xFFB45309);
    return const Color(0xFF991B1B);
  }

  String _typeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'tugas':
        return 'Tugas';
      case 'uh':
        return 'UH';
      case 'uts':
        return 'UTS';
      case 'uas':
        return 'UAS';
      default:
        return raw.toUpperCase();
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    final s = d.toString();
    if (s.isEmpty || s == 'null') return '';
    try {
      final dt = DateTime.parse(s);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.grade;
    final score = double.tryParse(g['score']?.toString() ?? '');
    final hasScore = score != null;
    final type = g['type']?.toString() ?? 'tugas';
    final title = g['title']?.toString() ?? '';
    final date = _formatDate(g['date']);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: hasScore ? ColorUtils.slate200 : ColorUtils.slate200,
                width: 0.75,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Row(
              children: [
                // Letter-grade badge (left)
                Container(
                  width: 44,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hasScore ? _bg(score) : const Color(0xFFF1F5F9),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Text(
                    hasScore ? _letter(score) : '—',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: hasScore ? _fg(score) : ColorUtils.slate400,
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
                        title.isEmpty ? '${_typeLabel(type)}' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_typeLabel(type)} · ${date.isEmpty ? "—" : date}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasScore ? score.toStringAsFixed(0) : '—',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KKM 75',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: ColorUtils.slate500,
                      ),
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
}
