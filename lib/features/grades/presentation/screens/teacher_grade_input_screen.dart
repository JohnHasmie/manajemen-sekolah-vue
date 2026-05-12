import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/frozen_column_table.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';
import 'package:manajemensekolah/core/widgets/teacher_role_options.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_input_content_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_input_filter_dialog_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_book_screen.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';


class GradePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;

  /// Optional deep-link target — when both are set, the screen
  /// auto-opens the grade book for that (class, subject) tuple
  /// after the overview data loads. Used by the teacher dashboard
  /// priority-inbox "Buku Nilai belum dilengkapi" row.
  final String? initialClassId;
  final String? initialSubjectId;

  /// Optional column highlight. Not yet wired into GradeBookPage —
  /// see TODO in this file's `_maybeOpenInitialGradeBook` helper.
  final String? initialColumnId;

  const GradePage({
    super.key,
    required this.teacher,
    this.initialClassId,
    this.initialSubjectId,
    this.initialColumnId,
  });

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
  bool get isLoading => _isLoading;

  @override
  bool get isHomeroomView => _isHomeroomView;

  @override
  bool get isTableView => _isTableView;

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

  TextEditingController get searchController => _searchController;

  /// Resolve the teacher id with a riverpod fallback. The widget.teacher
  /// map sometimes arrives without `teacher_id` (e.g. when the screen is
  /// reached through a navigation that only had user data); falling
  /// through to teacherRiverpod keeps the grade-summary call from
  /// 500'ing with "teacher_id is required".
  @override
  String get teacherId {
    final fromWidget = (widget.teacher['teacher_id'] ?? widget.teacher['id'])
        ?.toString();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    return ref.read(teacherRiverpod).teacherId ?? '';
  }

  @override
  Color get primaryColor =>
      ColorUtils.getRoleColor(widget.teacher['role']?.toString() ?? 'guru');

  int getActiveFilterCount() =>
      (_filterClassId != null ? 1 : 0) + (_filterSubjectId != null ? 1 : 0);

  // `getAvailableClasses()` is no longer overridden — the filter
  // sheet now sources its chip set from `filterRosterRiverpod`
  // (see grade_input_filter_dialog_mixin). This screen only needs
  // to expose `isHomeroomView` (already done above) so the mixin
  // picks the right partition.

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
      onSubjectTap: openGradeBook,
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

      // ENSURE DEPENDENCIES ARE READY (Fix for race condition on cold start)
      // If the user navigates here immediately after app start (e.g. from
      // bottom nav tab before dashboard fully resolves), the providers might
      // still be empty or loading.
      final ayProvider = ref.read(academicYearRiverpod);
      if (ayProvider.selectedAcademicYear == null && ayProvider.isLoading) {
        // Wait for academic year to finish loading if it's already in progress
        int retries = 0;
        while (ref.read(academicYearRiverpod).selectedAcademicYear == null &&
            ref.read(academicYearRiverpod).isLoading &&
            mounted &&
            retries < 20) {
          await Future.delayed(const Duration(milliseconds: 500));
          retries++;
        }
      }

      final teacherProvider = ref.read(teacherRiverpod);
      if (teacherId.isEmpty || !teacherProvider.isLoaded) {
        await teacherProvider.ensureLoaded();
      }

      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      if (teacherId.isEmpty) {
        throw Exception('ID Guru tidak ditemukan. Silakan coba lagi.');
      }

      final data =
          await GradeService.getTeacherGradeSummary(
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
    final ayId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    final view = _isHomeroomView ? 'wali_kelas' : 'mengajar';
    return 'nilai_input_${teacherId}_${view}_$ayId';
  }

  @override
  Future<void> refresh() async => loadData(useCache: false);

  @override
  void openGradeBook(dynamic classData, dynamic subject) {
    final subj = Subject.fromJson(subject as Map<String, dynamic>);
    // Pushed as a Material page route (was a 95% modal bottom sheet)
    // so the BrandPageHeader gets its full SafeArea — no more clock /
    // back-button overlap, and ESC / system-back behaves predictably.
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => GradeBookPage(
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
        )
        .then((_) {
          // Force a fresh fetch on return — the teacher may have edited /
          // added / deleted grades, so the cached summary could be stale.
          // useCache: false skips the 1-hour local-cache flash and pulls
          // straight from the API (which itself has been invalidated
          // server-side by any grade write).
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
      loadData().then((_) {
        if (!mounted) return;
        _maybeOpenInitialGradeBook();
      });
    });
  }

  /// Auto-opens the grade book for a `(class_id, subject_id)` tuple
  /// supplied via constructor (deep-link from teacher dashboard
  /// priority inbox). Walks the already-loaded `_groupedData` to
  /// find the matching row, then reuses the same `openGradeBook`
  /// pathway as the user-tap. No-op if either id is null or no
  /// match is found.
  ///
  /// TODO(GG.5-followup): when [initialColumnId] is set, pass it
  /// through to GradeBookPage so the screen scrolls / highlights
  /// that column on open. Currently the column id is accepted but
  /// not yet plumbed into GradeBookPage's constructor.
  void _maybeOpenInitialGradeBook() {
    final cId = widget.initialClassId;
    final sId = widget.initialSubjectId;
    if (cId == null || cId.isEmpty || sId == null || sId.isEmpty) return;

    for (final group in _groupedData) {
      if (group is! Map) continue;
      if (group['class_id']?.toString() != cId) continue;
      final subjects = group['subjects'];
      if (subjects is! List) continue;
      for (final subject in subjects) {
        if (subject is! Map) continue;
        if (subject['id']?.toString() != sId) continue;
        openGradeBook(group, subject);
        return;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────
  //
  // Replaces the legacy `Column [TeacherPageHeader, Expanded(content)]`
  // shell with the same brand pattern Presensi / Kegiatan Kelas /
  // Rekap Nilai / RPP all use:
  //   • BrandPageHeader — cobalt gradient, kicker `Akademik · Buku
  //     Nilai`, title `Nilai Siswa`, action icons (filter + view
  //     toggle), and a BrandFilterChipStrip in the bottom slot
  //     showing Mengajar/Wali · Kelas · Mapel chip pills.
  //   • 4-cell KPI strip below the header — Lengkap / Belum / Rerata /
  //     < KKM. Pinned (no scroll-overlap effect) because the body
  //     `TeacherAsyncView` brings its own scrollable, and nesting
  //     it inside BrandPageLayout's ListView body throws "vertical
  //     viewport was given unbounded height".
  //   • Body: `Expanded(buildContent)` — the content mixin handles
  //     loading / error / empty states and renders either the new
  //     class+subject card list (Frame A) or the flat
  //     `_GradeSummaryTableView` table.
  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildBrandHeader(lp),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildBrandKpi(lp),
          ),
          Expanded(child: buildContent(lp)),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(LanguageProvider lp) {
    final activeCount = getActiveFilterCount();
    return BrandPageHeader(
      role: 'guru',
      title: lp.getTranslatedText({'en': 'Grades', 'id': 'Nilai Siswa'}),
      subtitle: lp.getTranslatedText({
        'en': 'Academic · Grade Book',
        'id': 'Akademik · Buku Nilai',
      }),
      isRealtimeFresh: true,
      // No KPI overlap — the KPI strip is rendered as a separate
      // pinned card below the header (see build()). TeacherAsyncView's
      // inner scrollable can't safely nest inside the layout's ListView.
      kpiOverlayHeight: 0,
      actionIcons: [
        BrandHeaderIconButton(
          icon: _isTableView
              ? Icons.view_agenda_rounded
              : Icons.table_chart_rounded,
          onTap: () {
            setState(() => _isTableView = !_isTableView);
            saveViewPreference();
          },
        ),
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: () => showFilterDialog(lp),
          badgeCount: activeCount > 0 ? activeCount : null,
          badgeBorderColor: ColorUtils.brandDarkBlue,
        ),
      ],
      // Mengajar / Wali Kelas role toggle — same shared widget that
      // Presensi / Kegiatan Kelas / Rekap Nilai use, with the multi-
      // wali option (one chip per homeroom class) when the teacher is
      // homeroom for more than one class. Hidden for non-homeroom
      // teachers (returns null).
      childSelector: _buildRoleSelector(lp),
      bottomSlot: BrandFilterChipStrip(chips: _buildHeaderChips(lp)),
    );
  }

  /// Mengajar / Wali Kelas role selector. Returns null for teachers
  /// without homeroom assignments — the chip row hides entirely.
  Widget? _buildRoleSelector(LanguageProvider lp) {
    final teacherState = ref.watch(teacherRiverpod);
    final homeroomClasses = teacherState.homeroomClasses;
    if (homeroomClasses.isEmpty) return null;
    final selectedId = _isHomeroomView && _filterClassId != null
        ? 'wali:$_filterClassId'
        : 'mengajar';
    return RoleToggleChipRow(
      roles: buildMultiWaliRoleOptions(
        homeroomClasses: homeroomClasses,
        lp: lp,
      ),
      selectedRoleId: selectedId,
      accentColor: ColorUtils.brandCobalt,
      onSelected: (id) {
        if (id == 'mengajar') {
          if (!_isHomeroomView &&
              _filterClassId == null &&
              _filterSubjectId == null) {
            return;
          }
          setState(() {
            _isHomeroomView = false;
            _filterClassId = null;
            _filterClassName = null;
            _filterSubjectId = null;
            _filterSubjectName = null;
          });
          loadData();
        } else if (id.startsWith('wali:')) {
          final classId = id.substring(5);
          // Resolve the picked homeroom class so we can stash its
          // human-readable name in the filter chip strip.
          Map<String, dynamic>? picked;
          for (final c in homeroomClasses) {
            if (c is Map && (c['id'] ?? '').toString() == classId) {
              picked = Map<String, dynamic>.from(c);
              break;
            }
          }
          final pickedName = (picked?['name'] ?? picked?['nama'] ?? '')
              .toString();
          if (_isHomeroomView && _filterClassId == classId) return;
          setState(() {
            _isHomeroomView = true;
            _filterClassId = classId;
            _filterClassName = pickedName;
            _filterSubjectId = null;
            _filterSubjectName = null;
          });
          loadData();
        }
      },
    );
  }

  /// Header chip strip — Kelas + Mapel filter chips. The legacy
  /// "Peran" chip is gone — the role toggle is a dedicated child
  /// selector above the chips now (matches Rekap Nilai / Presensi).
  List<BrandFilterChip> _buildHeaderChips(LanguageProvider lp) {
    void tap() => showFilterDialog(lp);
    return [
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
        value: _filterClassName,
        onTap: tap,
      ),
      BrandFilterChip(
        label: lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}),
        value: _filterSubjectName,
        onTap: tap,
      ),
    ];
  }

  /// 4-cell overlap KPI card — server data isn't ready yet, so we
  /// tally over the loaded summary list. Counts are accurate because
  /// the backend returns the FULL list (not paginated), unlike the
  /// RPP card.
  Widget _buildBrandKpi(LanguageProvider lp) {
    final stats = _resolveKpiStats();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        child: Row(
          children: [
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Complete', 'id': 'Lengkap'}),
              value: '${stats.complete}/${stats.totalGroups}',
              color: ColorUtils.success600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Pending', 'id': 'Belum'}),
              value: '${stats.pending}',
              color: ColorUtils.warning600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': 'Average', 'id': 'Rerata'}),
              value: stats.avg == null ? '—' : stats.avg!.toStringAsFixed(0),
              color: ColorUtils.info600,
            ),
            _kpiDivider(),
            _kpiCell(
              label: lp.getTranslatedText({'en': '< KKM', 'id': '< KKM'}),
              value: '${stats.belowKkm}',
              color: ColorUtils.error600,
              compact: stats.belowKkm > 99,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
    bool compact = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 16 : 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 28, color: ColorUtils.slate100);
  }

  /// Tally KPI stats over the loaded class+subject groups. Because
  /// `getTeacherGradeSummary` returns the FULL list (no pagination),
  /// these client-side counts match what the server has — no scroll
  /// drift like the RPP KPI bug.
  _BukuNilaiKpiStats _resolveKpiStats() {
    var totalGroups = 0;
    var completeGroups = 0;
    var pending = 0;
    var belowKkm = 0;
    var sumAvg = 0.0;
    var countAvg = 0;
    for (final g in _groupedData) {
      if (g is! Map) continue;
      final subjects = (g['subjects'] as List?) ?? const [];
      for (final s in subjects) {
        if (s is! Map) continue;
        totalGroups++;
        final assessments = (s['assessments'] as List?) ?? const [];
        final filledCount = assessments
            .where((a) => a is Map && a['avg'] is num)
            .length;
        if (assessments.isNotEmpty && filledCount == assessments.length) {
          completeGroups++;
        }
        // Rough "belum diisi" — number of assessments where avg is
        // still null. Doesn't try to expand to per-student × per-cell
        // (the summary endpoint doesn't carry that detail).
        pending += assessments.length - filledCount;

        final raw = s['avg_score'];
        if (raw is num) {
          sumAvg += raw.toDouble();
          countAvg++;
          if (raw < 75) belowKkm++;
        }
      }
    }
    return _BukuNilaiKpiStats(
      totalGroups: totalGroups,
      complete: completeGroups,
      pending: pending,
      avg: countAvg == 0 ? null : sumAvg / countAvg,
      belowKkm: belowKkm,
    );
  }
}

/// Simple POD struct for the overview KPI overlap card.
class _BukuNilaiKpiStats {
  final int totalGroups;
  final int complete;
  final int pending;
  final double? avg;
  final int belowKkm;
  const _BukuNilaiKpiStats({
    required this.totalGroups,
    required this.complete,
    required this.pending,
    required this.avg,
    required this.belowKkm,
  });
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
