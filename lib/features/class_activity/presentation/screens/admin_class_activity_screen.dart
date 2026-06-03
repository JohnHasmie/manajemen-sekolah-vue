// Admin Kegiatan Kelas hub (AK.3 — full rewrite).
//
// Drops the legacy Guru → Mapel → Kegiatan drill-down (3 taps to reach
// any activity, no overview signal) in favour of a single recent-first
// hub modelled after the brand pattern admins already use on Jadwal /
// Rekap Nilai / Kehadiran:
//
//   * BrandPageLayout — owns the gradient header overlap + pull-to-refresh
//   * BrandPageHeader — single filter icon in the action rail (no Print)
//   * BrandFilterChipStrip — Kelas / Mapel / Guru / Tipe / Periode
//   * BrandKpiStrip — Total · Minggu Ini · Belum Submit
//   * Pill-style type tabs — Semua / Tugas / PR / Ulangan / Lainnya
//   * Recent-first activity cards grouped by date (Hari Ini / Senin /
//     Pekan Lalu ...) with submission progress bars
//
// State management uses the shared AdminAcademicYearReloadMixin — when
// the global AY picker flips, the hub re-loads cleanly. The legacy
// drill-down state fields (showTeacherList / showSubjectList /
// selectedTeacherId / selectedSubjectId) are GONE; the supporting
// loader mixins are no longer wired (and the screen no longer mixes
// them in).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/filter_options_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_kpi_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/domain/models/admin_activity_summary.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_empty_state.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_filter_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_quick_action_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_activity_detail_screen.dart';

/// Admin hub for monitoring every kegiatan kelas in the school.
///
/// Read-only — admins observe, they do not author. Activities are
/// authored by teachers via the teacher hub.
class AdminClassActivityScreen extends ConsumerStatefulWidget {
  const AdminClassActivityScreen({super.key});

  @override
  ConsumerState<AdminClassActivityScreen> createState() =>
      _AdminClassActivityScreenState();
}

class _AdminClassActivityScreenState
    extends ConsumerState<AdminClassActivityScreen>
    with AdminAcademicYearReloadMixin<AdminClassActivityScreen> {
  // ── Data ───────────────────────────────────────────────────────────
  AdminActivitySummaryPage _page = const AdminActivitySummaryPage(
    items: [],
    kpi: AdminActivityKpi(),
  );
  bool _isLoading = true;
  String? _errorMessage;

  // ── Filter state ───────────────────────────────────────────────────
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  AdminActivityType? _selectedType;
  AdminActivityPeriod _selectedPeriod = AdminActivityPeriod.sevenDays;

  // Filter reference lists — loaded lazily when the filter sheet opens
  // so the hub's first paint stays light.
  List<Map<String, dynamic>>? _availableClasses;
  List<Map<String, dynamic>>? _availableSubjects;
  List<Map<String, dynamic>>? _availableTeachers;

  // ── Lifecycle ──────────────────────────────────────────────────────
  final ApiClassActivityService _service = ApiClassActivityService();

  @override
  void initState() {
    super.initState();
    _hydrateFromCacheThenLoad();
  }

  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    // Reset every filter that's AY-scoped — teacher/class/subject IDs
    // wouldn't survive a year flip — then nuke the cached slice and
    // refetch from the server.
    setState(() {
      _selectedClassId = null;
      _selectedClassName = null;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _selectedType = null;
      _availableClasses = null;
      _availableSubjects = null;
      _availableTeachers = null;
    });
    unawaited(ApiClassActivityService.clearAdminSummaryCache());
    _hydrateFromCacheThenLoad();
  }

  /// Cache-first paint: show last-known slice instantly, then hit the
  /// API. The cache only stores the unfiltered page-1 slice; once the
  /// admin applies any chip, we go straight to the network.
  Future<void> _hydrateFromCacheThenLoad() async {
    final cached = await ApiClassActivityService.loadCachedAdminActivitySummary(
      academicYearId: currentAcademicYearId,
      period: _selectedPeriod.apiValue,
    );
    if (cached != null && mounted) {
      setState(() {
        _page = AdminActivitySummaryPage.fromJson(cached);
        _isLoading = false;
      });
    }
    await _loadData();
  }

  Future<void> _loadData({bool resetPage = true}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final result = await _service.getAdminActivitySummary(
        classId: _selectedClassId,
        subjectId: _selectedSubjectId,
        teacherId: _selectedTeacherId,
        type: _selectedType?.apiValue,
        period: _selectedPeriod.apiValue,
        academicYearId: currentAcademicYearId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _page = AdminActivitySummaryPage.fromJson(result);
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('admin_class_activity', 'load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '$e';
      });
    }
  }

  Future<void> _onRefresh() async {
    await ApiClassActivityService.clearAdminSummaryCache();
    await _loadData();
  }

  // ── Filter actions ────────────────────────────────────────────────
  bool get _hasActiveFilter =>
      _selectedClassId != null ||
      _selectedSubjectId != null ||
      _selectedTeacherId != null ||
      _selectedType != null ||
      _selectedPeriod != AdminActivityPeriod.sevenDays;

  Future<void> _openFilterSheet() async {
    // Lazy-load the filter option lists once per AY change. We hit
    // the consolidated `/filter-options?role=admin` endpoint (cached
    // 6h) instead of the legacy per-feature variant that 404s.
    if (_availableClasses == null ||
        _availableSubjects == null ||
        _availableTeachers == null) {
      try {
        final opts = await FilterOptionsService.getFilterOptions(
          role: 'admin',
          academicYearId: currentAcademicYearId,
        );
        if (opts.isNotEmpty) {
          List<Map<String, dynamic>> pluck(String key) =>
              (opts[key] as List?)
                  ?.whereType<Map>()
                  .map(Map<String, dynamic>.from)
                  .toList() ??
              const [];
          _availableClasses = pluck('classes');
          _availableSubjects = pluck('subjects');
          _availableTeachers = pluck('teachers');
        }
      } catch (e) {
        AppLogger.warning('admin_class_activity', 'filter options: $e');
      }
    }

    if (!mounted) return;
    await AdminActivityFilterSheet.show(
      context: context,
      availableClasses: _availableClasses ?? const [],
      availableSubjects: _availableSubjects ?? const [],
      availableTeachers: _availableTeachers ?? const [],
      initialClassId: _selectedClassId,
      initialSubjectId: _selectedSubjectId,
      initialTeacherId: _selectedTeacherId,
      initialType: _selectedType,
      initialPeriod: _selectedPeriod,
      previewCount: _page.totalItems,
      onApply:
          ({
            required String? classId,
            required String? className,
            required String? subjectId,
            required String? subjectName,
            required String? teacherId,
            required String? teacherName,
            required AdminActivityType? type,
            required AdminActivityPeriod period,
          }) {
            setState(() {
              _selectedClassId = classId;
              _selectedClassName = className;
              _selectedSubjectId = subjectId;
              _selectedSubjectName = subjectName;
              _selectedTeacherId = teacherId;
              _selectedTeacherName = teacherName;
              _selectedType = type;
              _selectedPeriod = period;
            });
            _loadData();
          },
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedClassId = null;
      _selectedClassName = null;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _selectedType = null;
      _selectedPeriod = AdminActivityPeriod.sevenDays;
    });
    _loadData();
  }

  // ── Type tab actions ──────────────────────────────────────────────
  void _selectType(AdminActivityType? type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
    _loadData();
  }

  // ── Card actions ──────────────────────────────────────────────────
  void _onActivityTap(AdminActivitySummary a) {
    AppNavigator.push(
      context,
      AdminActivityDetailScreen(activityId: a.id, summary: a),
    );
  }

  Future<void> _onActivityKebab(AdminActivitySummary a) async {
    await AdminActivityQuickActionSheet.show(
      context: context,
      activity: a,
      onViewDetail: () => _onActivityTap(a),
      onFilterByTeacher: () {
        setState(() {
          _selectedTeacherId = a.teacherId;
          _selectedTeacherName = a.teacherName;
        });
        _loadData();
      },
      onFilterBySubject: () {
        setState(() {
          _selectedSubjectId = a.subjectId;
          _selectedSubjectName = a.subjectName;
        });
        _loadData();
      },
      onFilterByClass: () {
        setState(() {
          _selectedClassId = a.classId;
          _selectedClassName = a.className;
        });
        _loadData();
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'admin',
        onRefresh: _onRefresh,
        header: BrandPageHeader(
          role: 'admin',
          subtitle: lang.getTranslatedText(const {
            'en': 'DATA MANAGEMENT',
            'id': 'MANAJEMEN DATA',
          }),
          title: lang.getTranslatedText(const {
            'en': 'Class Activities',
            'id': 'Kegiatan Kelas',
          }),
          isRealtimeFresh: !_isLoading && _errorMessage == null,
          kpiOverlayHeight: BrandPageLayout.kpiOverlapHeight,
          actionIcons: [
            // Single icon — Filter only (no Print, per user direction).
            BrandHeaderIconButton(
              icon: _hasActiveFilter
                  ? Icons.filter_alt_rounded
                  : Icons.tune_rounded,
              onTap: _openFilterSheet,
              badgeCount: _hasActiveFilter ? 1 : null,
              badgeBorderColor: ColorUtils.brandDarkBlue,
            ),
          ],
          bottomSlot: _buildFilterChipStrip(lang),
        ),
        kpiCard: _buildKpiCard(lang),
        bodyChildren: [_buildBody(lang)],
      ),
    );
  }

  Widget _buildFilterChipStrip(LanguageProvider lang) {
    final chips = <BrandFilterChip>[
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Period', 'id': 'Periode'}),
        value: _selectedPeriod.labelId,
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Class', 'id': 'Kelas'}),
        value: _selectedClassName,
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Subject', 'id': 'Mapel'}),
        value: _selectedSubjectName,
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Teacher', 'id': 'Guru'}),
        value: _selectedTeacherName,
        onTap: _openFilterSheet,
      ),
      BrandFilterChip(
        label: lang.getTranslatedText(const {'en': 'Type', 'id': 'Tipe'}),
        value: _selectedType?.labelId,
        onTap: _openFilterSheet,
      ),
    ];
    return BrandFilterChipStrip(chips: chips);
  }

  Widget _buildKpiCard(LanguageProvider lang) {
    return BrandKpiStrip(
      columns: [
        BrandKpiColumn(
          label: lang.getTranslatedText(const {'en': 'Total', 'id': 'Total'}),
          value: '${_page.kpi.total}',
        ),
        BrandKpiColumn(
          label: lang.getTranslatedText(const {
            'en': 'This week',
            'id': 'Minggu Ini',
          }),
          value: '${_page.kpi.thisWeek}',
          valueColor: ColorUtils.brandCobalt,
        ),
        BrandKpiColumn(
          label: lang.getTranslatedText(const {
            'en': 'Pending',
            'id': 'Belum Submit',
          }),
          value: '${_page.kpi.pendingSubmissions}',
          valueColor: _page.kpi.pendingSubmissions > 0
              ? const Color(0xFFB45309) // amber-600
              : null,
        ),
      ],
    );
  }

  Widget _buildBody(LanguageProvider lang) {
    final academicYear = ref.watch(academicYearRiverpod);
    final isReadOnly = academicYear.isReadOnly;

    // Type tab counts derive from the visible page — server already
    // applies the type filter when one is active. Counts are accurate
    // for the "Semua" baseline; specific tabs show the live total once
    // selected.
    final tabCounts = <AdminActivityType?, int>{
      null: _page.totalItems,
      for (final t in AdminActivityType.values) t: -1,
    };
    for (final a in _page.items) {
      tabCounts[a.type] = (tabCounts[a.type] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeTabStrip(
            selected: _selectedType,
            tabCounts: tabCounts,
            onSelect: _selectType,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoading && _page.items.isEmpty)
            const _LoadingSkeleton()
          else if (_errorMessage != null && _page.items.isEmpty)
            _ErrorRetry(message: _errorMessage!, onRetry: _loadData)
          else if (_page.items.isEmpty)
            AdminActivityEmptyState(
              isReadOnly: isReadOnly,
              hasFilters: _hasActiveFilter,
              onClearFilters: _clearAllFilters,
            )
          else
            _buildGroupedList(lang),
        ],
      ),
    );
  }

  Widget _buildGroupedList(LanguageProvider lang) {
    // Group items under a date label — Hari Ini / Kemarin / weekday /
    // older. Backend already sorts items by date desc, so we just
    // walk linearly and emit a divider whenever the bucket flips.
    final groups = <_DateGroup>[];
    String? currentBucket;
    final today = DateTime.now();
    String bucketKey(DateTime? d) {
      if (d == null) return 'unknown';
      final delta = today.difference(d).inDays;
      if (delta <= 0 && _sameDay(d, today)) return 'today';
      if (delta == 1) return 'yesterday';
      if (delta <= 7) return 'this_week';
      if (delta <= 14) return 'last_week';
      return 'older';
    }

    String bucketLabel(String key) {
      switch (key) {
        case 'today':
          return lang.getTranslatedText(const {
            'en': 'Today',
            'id': 'Hari Ini',
          });
        case 'yesterday':
          return lang.getTranslatedText(const {
            'en': 'Yesterday',
            'id': 'Kemarin',
          });
        case 'this_week':
          return lang.getTranslatedText(const {
            'en': 'This week',
            'id': 'Pekan Ini',
          });
        case 'last_week':
          return lang.getTranslatedText(const {
            'en': 'Last week',
            'id': 'Pekan Lalu',
          });
        case 'older':
          return lang.getTranslatedText(const {
            'en': 'Older',
            'id': 'Lebih Lampau',
          });
        default:
          return lang.getTranslatedText(const {
            'en': 'Undated',
            'id': 'Tanpa Tanggal',
          });
      }
    }

    for (final a in _page.items) {
      final key = bucketKey(a.date);
      if (key != currentBucket) {
        currentBucket = key;
        groups.add(_DateGroup(label: bucketLabel(key), items: [a]));
      } else {
        groups.last.items.add(a);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in groups) ...[
          _DateDivider(label: g.label),
          for (final a in g.items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AdminActivityCard(
                activity: a,
                onTap: () => _onActivityTap(a),
                onKebabTap: () => _onActivityKebab(a),
              ),
            ),
        ],
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────
// Type tab strip — pill row at the top of the body. The active tab
// uses brand-dark fill + a soft count pill; inactive ones stay
// outlined.
class _TypeTabStrip extends StatelessWidget {
  const _TypeTabStrip({
    required this.selected,
    required this.tabCounts,
    required this.onSelect,
  });

  final AdminActivityType? selected;
  final Map<AdminActivityType?, int> tabCounts;
  final void Function(AdminActivityType?) onSelect;

  @override
  Widget build(BuildContext context) {
    final tabs = <_TabSpec>[
      const _TabSpec(value: null, label: 'Semua'),
      ...AdminActivityType.values.map(
        (t) => _TabSpec(value: t, label: t.labelId),
      ),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isActive = selected == tab.value;
          final count = tabCounts[tab.value] ?? 0;
          final showCount = tab.value == null || count > 0;
          return Material(
            color: isActive ? ColorUtils.brandDarkBlue : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(
                color: isActive
                    ? ColorUtils.brandDarkBlue
                    : ColorUtils.slate200,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelect(tab.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isActive ? Colors.white : ColorUtils.slate700,
                      ),
                    ),
                    if (showCount && tab.value == null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withValues(alpha: 0.22)
                              : ColorUtils.slate100,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? Colors.white
                                : ColorUtils.slate600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabSpec {
  final AdminActivityType? value;
  final String label;
  const _TabSpec({required this.value, required this.label});
}

class _DateGroup {
  final String label;
  final List<AdminActivitySummary> items;
  _DateGroup({required this.label, required this.items});
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: ColorUtils.slate200)),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
            ),
          ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 32, color: ColorUtils.slate500),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: ColorUtils.slate600),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Muat ulang'),
          ),
        ],
      ),
    );
  }
}
