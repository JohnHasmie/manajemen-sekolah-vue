import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/widgets/active_filter_chips.dart';
import 'package:manajemensekolah/core/widgets/frozen_column_table.dart';
import 'package:manajemensekolah/core/widgets/teacher_page_header.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_input_content_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_input_filter_dialog_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';

class GradePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  const GradePage({super.key, required this.teacher});
  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends ConsumerState<GradePage>
    with GradeInputFilterDialogMixin, GradeInputContentMixin {
  List<dynamic> _groupedData = [];
  bool _isLoading = true;
  bool _isHomeroomView = false;
  bool _isTableView = false;
  final _searchController = TextEditingController();

  String? _filterClassId;
  String? _filterClassName;
  String? _filterSubjectId;
  String? _filterSubjectName;

  @override
  List<dynamic> get groupedData => _groupedData;

  @override
  set groupedData(List<dynamic> value) {
    _groupedData = value;
  }

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) {
    _isLoading = value;
  }

  @override
  bool get isHomeroomView => _isHomeroomView;

  @override
  set isHomeroomView(bool value) {
    _isHomeroomView = value;
  }

  @override
  bool get isTableView => _isTableView;

  @override
  set isTableView(bool value) {
    _isTableView = value;
  }

  @override
  String? get filterClassId => _filterClassId;

  @override
  set filterClassId(String? value) {
    _filterClassId = value;
  }

  @override
  String? get filterClassName => _filterClassName;

  @override
  set filterClassName(String? value) {
    _filterClassName = value;
  }

  @override
  String? get filterSubjectId => _filterSubjectId;

  @override
  set filterSubjectId(String? value) {
    _filterSubjectId = value;
  }

  @override
  String? get filterSubjectName => _filterSubjectName;

  @override
  set filterSubjectName(String? value) {
    _filterSubjectName = value;
  }

  @override
  TextEditingController get searchController => _searchController;

  String get teacherId =>
      (widget.teacher['teacher_id'] ?? widget.teacher['id'])?.toString() ?? '';

  @override
  Color get primaryColor =>
      ColorUtils.getRoleColor(widget.teacher['role']?.toString() ?? 'guru');

  int getActiveFilterCount() =>
      (_filterClassId != null ? 1 : 0) + (_filterSubjectId != null ? 1 : 0);

  @override
  List<Map<String, String>> getAvailableClasses() {
    final seen = <String>{};
    return _groupedData
        .where((g) {
          final id = g['class_id']?.toString() ?? '';
          if (seen.contains(id)) return false;
          seen.add(id);
          return true;
        })
        .map(
          (g) => {
            'id': g['class_id']?.toString() ?? '',
            'name': g['class_name']?.toString() ?? '-',
          },
        )
        .toList();
  }

  void saveViewPreference() {
    LocalCacheService.save('nilai_view_preference', {
      'is_table_view': _isTableView,
    });
  }

  void loadViewPreference() {
    try {
      LocalCacheService.load('nilai_view_preference').then((cached) {
        if (cached is Map && mounted) {
          setState(() => _isTableView = cached['is_table_view'] ?? false);
        }
      });
    } catch (e) {
      // Silently fail
    }
  }

  @override
  List<dynamic> getFilteredData() {
    final query = _searchController.text.toLowerCase();
    return _groupedData.where((g) {
      final cn = g['class_name']?.toString().toLowerCase() ?? '';
      final subs = (g['subjects'] as List?) ?? [];
      final matchSub = subs.any(
        (s) => (s['name']?.toString().toLowerCase() ?? '').contains(query),
      );
      final matchClass =
          _filterClassId == null || g['class_id']?.toString() == _filterClassId;
      final matchSubject =
          _filterSubjectId == null ||
          subs.any((s) => s['id']?.toString() == _filterSubjectId);
      return (query.isEmpty || cn.contains(query) || matchSub) &&
          matchClass &&
          matchSubject;
    }).toList();
  }

  @override
  Map<String, dynamic> safeMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  @override
  Widget buildTableView(List<dynamic> data) {
    return _GradeSummaryTableView(
      data: data,
      primaryColor: primaryColor,
      onSubjectTap: (classData, subject) => openGradeBook(classData, subject),
    );
  }

  String? _gradeErrorMessage;

  @override
  String? get gradeErrorMessage => _gradeErrorMessage;

  @override
  Future<void> loadData({bool useCache = true}) async {
    try {
      final cacheKey = _buildGradeCacheKey();

      // 1. Cache-first: show cached data instantly (no skeleton flash)
      if (useCache) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 1),
          );
          if (cached is List && cached.isNotEmpty && mounted) {
            setState(() {
              _groupedData = cached;
              _isLoading = false;
            });
            // Don't return — continue fetching fresh data from API
          }
        } catch (_) {}
      }

      // Show skeleton only if no cache hit (list is still empty)
      if (_groupedData.isEmpty && mounted) {
        setState(() => _isLoading = true);
      }

      // 2. Always fetch fresh data from API.
      //
      // We wrap the request in an explicit 20s timeout as a belt-and-suspenders
      // safeguard on top of Dio's own 30s receive/connect timeouts. This screen's
      // backend endpoint (/grades/teacher-summary) does heavy aggregation and
      // has occasionally hung the simulator on a cold cache, leaving the user
      // staring at an infinite skeleton that looks like a crash. With this
      // guard, a stuck request converts to a TimeoutException → caught below →
      // friendly "Koneksi terlalu lambat" error screen with a retry button.
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
      final data = await GradeService.getTeacherGradeSummary(
        teacherId: teacherId,
        academicYearId: ayId,
        view: _isHomeroomView ? 'wali_kelas' : 'mengajar',
        classId: _filterClassId,
        subjectId: _filterSubjectId,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Permintaan ke server melebihi batas waktu (20 detik).',
        ),
      );
      if (mounted) {
        // Silently update UI with fresh data
        setState(() {
          _groupedData = data;
          _isLoading = false;
          _gradeErrorMessage = null;
        });
        await LocalCacheService.save(cacheKey, data);
      }
    } catch (e) {
      AppLogger.error('loadData failed for GradePage', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _gradeErrorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  String _buildGradeCacheKey() {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString() ?? 'default';
    final view = _isHomeroomView ? 'wali_kelas' : 'mengajar';
    return 'nilai_input_${teacherId}_${view}_$ayId';
  }

  @override
  Future<void> refresh() async => loadData(useCache: false);

  @override
  void openGradeBook(dynamic classData, dynamic subject) {
    final subj = Subject.fromJson(subject as Map<String, dynamic>);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.95,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: GradeBookPage(
            teacher: widget.teacher,
            subject: {
              'id': subj.id,
              'nama': subj.name,
              'name': subj.name,
              'kode': subj.code,
              'code': subj.code,
            },
            classData: {
              'id': classData['class_id'],
              'nama': classData['class_name'],
              'name': classData['class_name'],
              'grade_level': classData['grade_level'],
            },
          ),
        ),
      ),
    ).then((_) {
      // Force a fresh fetch when returning from the grade book — the user
      // may have edited/added/deleted grades, so the cached summary could be
      // stale. useCache: false skips the 1-hour local-cache flash and pulls
      // straight from the API (which itself has been invalidated server-side
      // by any grade write).
      return loadData(useCache: false);
    });
  }

  @override
  void initState() {
    super.initState();
    // Defer both async kick-offs to AFTER the first frame is committed.
    //
    // Why: calling loadData() directly from initState races the very first
    // build. If loadData's cache-hit branch fires synchronously (cache load
    // resolves on the same microtask) it can call setState before the initial
    // frame is mounted, which Flutter tolerates but on iOS simulator has been
    // associated with the app being backgrounded by the OS during heavy
    // first-frame work. addPostFrameCallback guarantees the widget is on
    // screen before we touch SharedPreferences or fire the network call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      loadViewPreference();
      loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    final isHomeroomTeacher = ref.watch(teacherRiverpod).isHomeroomTeacher;
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          TeacherPageHeader(
            title: lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai'}),
            subtitle: lp.getTranslatedText({
              'en': 'Manage student grades',
              'id': 'Kelola nilai siswa',
            }),
            primaryColor: primaryColor,
            showRoleToggle: isHomeroomTeacher,
            isHomeroomView: _isHomeroomView,
            onRoleChanged: _handleRoleChange,
            showSearchFilter: true,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            onFilterTap: () => showFilterDialog(lp),
            hasActiveFilter: getActiveFilterCount() > 0,
            activeFilters: _buildActiveFilters(),
            onClearAllFilters: _clearAllFilters,
            trailing: _buildViewToggle(),
          ),
          Expanded(child: buildContent(lp)),
        ],
      ),
    );
  }

  void _handleRoleChange(bool isHomeroom) {
    setState(() {
      _isHomeroomView = isHomeroom;
      _filterClassId = null;
      _filterClassName = null;
      _filterSubjectId = null;
      _filterSubjectName = null;
    });
    loadData();
  }

  void _clearAllFilters() {
    setState(() {
      _filterClassId = null;
      _filterClassName = null;
      _filterSubjectId = null;
      _filterSubjectName = null;
    });
    loadData();
  }

  List<ActiveFilter> _buildActiveFilters() {
    final filters = <ActiveFilter>[];
    if (_filterClassName != null) {
      filters.add(
        ActiveFilter(
          label: _filterClassName!,
          onRemove: () {
            setState(() {
              _filterClassId = null;
              _filterClassName = null;
            });
            loadData();
          },
        ),
      );
    }
    if (_filterSubjectName != null) {
      filters.add(
        ActiveFilter(
          label: _filterSubjectName!,
          onRemove: () {
            setState(() {
              _filterSubjectId = null;
              _filterSubjectName = null;
            });
            loadData();
          },
        ),
      );
    }
    return filters;
  }

  Widget _buildViewToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _isTableView = !_isTableView);
        saveViewPreference();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _isTableView ? Icons.view_agenda_rounded : Icons.table_chart_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary table view: flat rows of class × subject with per-assessment avg
// columns. Uses the shared FrozenColumnTable scaffold so the Nilai overview
// reads visually identical to Grade Recap, Finance per-class report, and
// Raport overview.
//
// Layout:
//   • Frozen left block: Kelas (56w) + Mapel (80w) — two independently
//     sized frozen columns, thanks to FrozenColumnTable's leftColumns API.
//   • Scrollable right: one column per assessment label (50w each), plus
//     a summary Avg column (48w), plus a chevron affordance (24w).
//   • Solid-green header painted by the scaffold via headerBackgroundColor.
//   • Row tap -> onSubjectTap(classRow, subjectMap).
// ─────────────────────────────────────────────────────────────────────────────

class _GradeSummaryTableView extends StatelessWidget {
  final List<dynamic> data;
  final Color primaryColor;
  final void Function(dynamic classData, dynamic subject) onSubjectTap;

  const _GradeSummaryTableView({
    required this.data,
    required this.primaryColor,
    required this.onSubjectTap,
  });

  // ── Layout constants ────────────────────────────────────────────────────
  static const double _kelasWidth = 56.0;
  static const double _mapelWidth = 80.0;
  static const double _cellWidth = 50.0;
  static const double _avgWidth = 48.0;
  static const double _chevronWidth = 24.0;
  static const double _headerHeight = 40.0;
  static const double _rowHeight = 44.0;

  static const _headerStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    // Flatten class × subject into rows.
    final rows = <Map<String, dynamic>>[];
    for (final g in data) {
      for (final s in (g['subjects'] as List? ?? [])) {
        rows.add({...Map<String, dynamic>.from(g as Map), 'subject': s});
      }
    }

    // Collect all unique assessment labels in insertion order.
    final allLabels = <String>[];
    for (final r in rows) {
      for (final a in ((r['subject']?['assessments'] as List?) ?? [])) {
        final l = a['label']?.toString() ?? '';
        if (l.isNotEmpty && !allLabels.contains(l)) allLabels.add(l);
      }
    }

    // Wrap in a vertical SingleChildScrollView so the parent screen's
    // RefreshIndicator still has a scrollable descendant. FrozenColumnTable
    // is a fixed-height Row internally.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: FrozenColumnTable(
          rowCount: rows.length,
          headerHeight: _headerHeight,
          rowHeight: _rowHeight,
          headerBackgroundColor: primaryColor,
          showLeftColumnShadow: true,
          onRowTap: (i) => onSubjectTap(rows[i], rows[i]['subject']),
          leftColumns: [
            // Kelas — class name, bold slate.
            FrozenTableColumn(
              width: _kelasWidth,
              header: _leftHeaderCell(
                'Kelas',
                alignment: Alignment.centerLeft,
                leftPadding: 12,
              ),
              cellBuilder: (i) => _buildKelasCell(rows[i]),
            ),
            // Mapel — subject name, primary-colored medium.
            FrozenTableColumn(
              width: _mapelWidth,
              header: _leftHeaderCell('Mapel'),
              cellBuilder: (i) => _buildMapelCell(rows[i]),
            ),
          ],
          rightColumns: [
            for (final label in allLabels)
              FrozenTableColumn(
                width: _cellWidth,
                header: _centerHeaderCell(label),
                cellBuilder: (i) => _buildAssessmentCell(rows[i], label),
              ),
            FrozenTableColumn(
              width: _avgWidth,
              header: _centerHeaderCell('Avg'),
              cellBuilder: (i) => _buildAvgCell(rows[i]),
            ),
            FrozenTableColumn(
              width: _chevronWidth,
              header: const SizedBox.shrink(),
              cellBuilder: (_) => Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: ColorUtils.slate300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header cells ─────────────────────────────────────────────────────────

  /// Left-side header cell. Scaffold paints the green background; this cell
  /// only contributes alignment + padding + text.
  Widget _leftHeaderCell(
    String label, {
    Alignment alignment = Alignment.centerLeft,
    double leftPadding = 0,
  }) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(left: leftPadding),
      child: Text(label, style: _headerStyle),
    );
  }

  Widget _centerHeaderCell(String label) {
    return Container(
      alignment: Alignment.center,
      child: Text(label, style: _headerStyle, textAlign: TextAlign.center),
    );
  }

  // ── Left cells ───────────────────────────────────────────────────────────

  Widget _buildKelasCell(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          r['class_name']?.toString() ?? '-',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildMapelCell(Map<String, dynamic> r) {
    final sub = r['subject'];
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          sub?['name']?.toString() ?? '-',
          style: TextStyle(
            fontSize: 11,
            color: primaryColor,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Right cells ──────────────────────────────────────────────────────────

  Widget _buildAssessmentCell(Map<String, dynamic> r, String label) {
    final sub = r['subject'];
    final aList = (sub?['assessments'] as List?) ?? const [];
    double? value;
    for (final a in aList) {
      if (a['label']?.toString() == label && a['avg'] is num) {
        value = (a['avg'] as num).toDouble();
        break;
      }
    }
    return Center(
      child: Text(
        value != null ? value.toStringAsFixed(0) : '-',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: value != null ? FontWeight.w700 : FontWeight.w400,
          color: value != null ? _scoreColor(value) : ColorUtils.slate300,
        ),
      ),
    );
  }

  Widget _buildAvgCell(Map<String, dynamic> r) {
    final raw = r['subject']?['avg_score'];
    final avg = raw is num ? raw.toDouble() : null;
    if (avg == null) {
      return Center(
        child: Text(
          '-',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate300),
        ),
      );
    }
    return Center(
      child: Text(
        avg.toStringAsFixed(0),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _scoreColor(avg),
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
