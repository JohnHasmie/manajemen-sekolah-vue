// Parent view of a child's attendance — Phase 3 brand-aligned redesign.
//
// Layout shape
// ------------
// Single scroll surface (CustomScrollView). The brand-azure gradient
// hero + the KPI ring card are the *first sliver* — they scroll up
// off-screen with the body, matching the dashboard's hero idiom (not
// pinned). The KPI overlaps the bottom edge of the gradient by 18 px
// so the gradient "bleeds" into the card.
//
// What's special on this screen
// -----------------------------
//   • In-place sibling switching. Tapping a different chip in the
//     `ChildSelectorChipRow` doesn't navigate — it bumps a state
//     override (`_overrideStudentId`) and re-runs `loadData`. The
//     data mixin reads from `currentStudentId` (a getter on the
//     state mixin) so cache keys swap to the new child cleanly.
//   • Auto-current-month. `selectedMonthFilter` is seeded to the
//     current calendar month so the KPI lands on "Bulan ini" by
//     default. Semester is *derived* from the month (Jul-Dec =
//     Ganjil, Jan-Jun = Genap) — there's no longer a separate
//     semester filter UI.
//   • Combined Periode chip showing "Bulan YYYY · Genap/Ganjil".
//   • Status chip filters the day list to a single
//     [AttendanceStatus] (Hadir / Terlambat / Izin / Sakit / Alpha).
//   • `vs Bulan lalu` trend chip: deltaPct = current month rate −
//     previous month rate. Hides when prev month has no records.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_day_card.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_ring_kpi.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_status.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_filter_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_status_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_tour_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_visibility_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_calendar_screen.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Parent's read-only view of a child's attendance.
class ParentAttendanceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> parent;
  final String studentId;
  final String? academicYearId;

  const ParentAttendanceScreen({
    super.key,
    required this.parent,
    required this.studentId,
    this.academicYearId,
  });

  @override
  ParentAttendanceScreenState createState() => ParentAttendanceScreenState();
}

class ParentAttendanceScreenState extends ConsumerState<ParentAttendanceScreen>
    with
        ParentAttendanceStateMixin,
        ParentAttendanceDataMixin,
        ParentAttendanceVisibilityMixin,
        ParentAttendanceTourMixin,
        ParentAttendanceFilterMixin,
        ParentAttendanceStatusMixin {
  final GlobalKey _monthlySummaryKey = GlobalKey();
  final GlobalKey _attendanceListKey = GlobalKey();

  /// Runtime override for the active student id. `null` means we
  /// keep showing whatever `widget.studentId` was constructed with
  /// (the initial child the screen was opened for). Set this via
  /// `_switchChild` to swap siblings without pushReplacement.
  String? _overrideStudentId;

  /// All siblings linked to this parent. Drives the
  /// [ChildSelectorChipRow]; loaded once on init and refreshed on
  /// pull-to-refresh.
  List<Student> _siblings = const [];

  /// Track when the cached/fresh data was last loaded so the realtime
  /// pill can show "Terhubung realtime · HH:MM" or
  /// "Terakhir diperbarui N menit lalu".
  DateTime _lastSync = DateTime.now();

  // ------- Data-mixin overrides for in-place child switching ------

  @override
  String get currentStudentId => _overrideStudentId ?? widget.studentId;

  // ----------------------------------------------------------------

  @override
  GlobalKey get monthlySummaryKey => _monthlySummaryKey;

  @override
  GlobalKey get attendanceListKey => _attendanceListKey;

  @override
  void initState() {
    super.initState();
    // Auto-select the current month so the KPI lands on "Bulan ini"
    // by default. `_isExplicitFilter` excludes this default from the
    // badge counter and the "adjust filters" empty-state copy.
    selectedMonthFilter = DateTime.now().month.toString();
    loadData();
    _loadSiblings();
  }

  /// Loads the parent's full sibling list for the chip selector.
  Future<void> _loadSiblings() async {
    try {
      final raw = PreferencesService().getString('user');
      final userData = raw == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(json.decode(raw) as Map);
      final email = (userData['email'] ?? widget.parent['email'] ?? '')
          .toString();
      final userId = (userData['id'] ?? widget.parent['id'] ?? '').toString();
      if (email.isEmpty && userId.isEmpty) return;

      final allStudents = await getIt<ApiStudentService>().getStudent(
        userId: userId.isNotEmpty ? userId : null,
        guardianEmail: email.isNotEmpty ? email : null,
      );
      if (!mounted) return;
      setState(() {
        _siblings = allStudents
            .map((m) => Student.fromJson(m as Map<String, dynamic>))
            .toList(growable: false);
      });
    } catch (_) {
      // Sibling list is a UX nicety; if it fails the chip row simply
      // hides itself and the rest of the screen still works.
    }
  }

  /// True only when the user has explicitly narrowed filters beyond
  /// the auto-selected current month. Drives the filter icon's
  /// badge counter and the "Periode terpilih" KPI label.
  bool get _isExplicitFilter {
    final currentMonth = DateTime.now().month.toString();
    return (selectedMonthFilter != null &&
            selectedMonthFilter != currentMonth) ||
        selectedStatusFilter != null;
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: RefreshIndicator(
        color: ColorUtils.brandAzureDeep,
        onRefresh: () async {
          await forceRefresh();
          await _loadSiblings();
          if (mounted) setState(() => _lastSync = DateTime.now());
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(lang)),
            for (final widget in _buildScrollChildren(lang))
              SliverToBoxAdapter(child: widget),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildScrollChildren(LanguageProvider lang) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: KeyedSubtree(
          key: _monthlySummaryKey,
          child: _buildKpiCard(lang),
        ),
      ),
      if (isLoading)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SkeletonListLoading(
            itemCount: 6,
            infoTagCount: 2,
            shrinkWrap: true,
            baseColor: ColorUtils.brandAzure.withValues(alpha: 0.15),
            highlightColor: ColorUtils.brandAzure.withValues(alpha: 0.05),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: _buildBodyColumn(lang),
        ),
    ];
  }

  // ----------------------------------------------------- KPI card

  Widget _buildKpiCard(LanguageProvider lang) {
    final totalDays = monthlySummary.values.fold<int>(0, (a, b) => a + b);
    final presentDays =
        (monthlySummary['hadir'] ?? 0) + (monthlySummary['terlambat'] ?? 0);
    final rate = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;
    return AttendanceRingKpi(
      rate: rate,
      presentDays: presentDays,
      excusedDays: monthlySummary['izin'] ?? 0,
      sickDays: monthlySummary['sakit'] ?? 0,
      alphaDays: monthlySummary['alpha'] ?? 0,
      schoolDays: totalDays,
      periodLabel: _isExplicitFilter
          ? lang.getTranslatedText({
              'en': 'Selected period',
              'id': 'Periode terpilih',
            })
          : lang.getTranslatedText({'en': 'This month', 'id': 'Bulan ini'}),
      deltaPct: _computeDeltaPct(),
      brandColor: ColorUtils.brandAzureDeep,
    );
  }

  /// Computes the attendance-rate delta between the currently-shown
  /// month and the month before it. Returns null when the previous
  /// month has no recorded attendance.
  double? _computeDeltaPct() {
    final monthInt = int.tryParse(selectedMonthFilter ?? '');
    if (monthInt == null) return null;
    final now = DateTime.now();
    final shownYear = now.year;
    final prevMonth = monthInt == 1 ? 12 : monthInt - 1;
    final prevYear = monthInt == 1 ? shownYear - 1 : shownYear;

    double rateOf(int year, int month) {
      final records = attendanceData
          .where((r) => r.date.year == year && r.date.month == month)
          .toList();
      if (records.isEmpty) return double.nan;
      final present = records.where((r) {
        final s = parseAttendanceStatus(r.status);
        return s == AttendanceStatus.present || s == AttendanceStatus.late;
      }).length;
      return (present / records.length) * 100;
    }

    final prev = rateOf(prevYear, prevMonth);
    if (prev.isNaN) return null;
    final cur = rateOf(shownYear, monthInt);
    if (cur.isNaN) return null;
    return cur - prev;
  }

  // ---------------------------------------------------------------- header

  Widget _buildHeader(LanguageProvider lang) {
    final children = _buildChildSummaries();
    return BrandPageHeader(
      role: 'wali',
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({'en': 'Attendance', 'id': 'Kehadiran'}),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: showFilterSheet,
          badgeCount: _isExplicitFilter ? _activeFilterCount() : null,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
      ],
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      childSelector: children.length < 2
          ? null
          : ChildSelectorChipRow(
              children: children,
              selectedChildId: currentStudentId,
              onSelected: _switchChild,
              accentColor: ColorUtils.brandAzureDeep,
            ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lang.getTranslatedText({'en': 'Period', 'id': 'Periode'}),
            value: _periodChipValue(lang),
            onTap: showFilterSheet,
            width: 220,
          ),
          BrandFilterChip(
            label: lang.getTranslatedText({'en': 'Status', 'id': 'Status'}),
            value: _statusChipValue(lang),
            onTap: showFilterSheet,
          ),
        ],
      ),
    );
  }

  List<ChildSummary> _buildChildSummaries() {
    return _siblings
        .map(
          (s) => ChildSummary(
            id: s.id,
            shortName: s.name.isEmpty ? '?' : s.name,
            klass: s.className.isEmpty ? '-' : 'Kelas ${s.className}',
          ),
        )
        .toList(growable: false);
  }

  /// Switches the active child without re-pushing the route. Bumps
  /// the override and re-runs the data load — the data mixin reads
  /// `currentStudentId` so the cache key naturally updates.
  void _switchChild(String newStudentId) {
    if (newStudentId == currentStudentId) return;
    setState(() {
      _overrideStudentId = newStudentId;
      // Reset the visible body so the skeleton shows during the
      // refetch instead of stale rows from the previous child.
      attendanceData = [];
      monthlySummary.updateAll((_, _) => 0);
      isLoading = true;
    });
    loadData();
  }

  /// Periode chip value combining month + year + derived semester,
  /// e.g. "April 2026 · Genap". Returns null when the parent has
  /// somehow cleared the month filter (in practice never, since we
  /// auto-seed it).
  String? _periodChipValue(LanguageProvider lang) {
    final monthInt = int.tryParse(selectedMonthFilter ?? '');
    if (monthInt == null) return null;
    final months = getMonthsList();
    final match = months.firstWhere(
      (m) => m['val'] == selectedMonthFilter,
      orElse: () => const {},
    );
    if (match.isEmpty) return null;
    final monthLabel = lang.getTranslatedText({
      'en': match['en']!,
      'id': match['id']!,
    });
    // Year — same calendar year as today; users only navigate
    // backwards within the active academic year so this matches
    // expectations for the typical "browse last few months" flow.
    final year = DateTime.now().year;
    // Semester — derived. ID semester convention: Ganjil = Jul-Dec,
    // Genap = Jan-Jun.
    final semester = monthInt >= 7
        ? lang.getTranslatedText({'en': 'Odd', 'id': 'Ganjil'})
        : lang.getTranslatedText({'en': 'Even', 'id': 'Genap'});
    return '$monthLabel $year · $semester';
  }

  String? _statusChipValue(LanguageProvider lang) {
    if (selectedStatusFilter == null) return null;
    final list = getStatusList();
    final match = list.firstWhere(
      (s) => s['val'] == selectedStatusFilter,
      orElse: () => const {},
    );
    if (match.isEmpty) return null;
    return lang.getTranslatedText({'en': match['en']!, 'id': match['id']!});
  }

  int _activeFilterCount() {
    var n = 0;
    final currentMonth = DateTime.now().month.toString();
    if (selectedMonthFilter != null && selectedMonthFilter != currentMonth) {
      n++;
    }
    if (selectedStatusFilter != null) n++;
    return n;
  }

  // ------------------------------------------------------------------ body

  Widget _buildBodyColumn(LanguageProvider lang) {
    final filtered = _filteredRecords();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang.getTranslatedText({
                'en': 'Daily history',
                'id': 'Riwayat harian',
              }),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
            Text(
              lang.getTranslatedText({
                'en': 'Pull to refresh ↓',
                'id': 'Tarik untuk segarkan ↓',
              }),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        KeyedSubtree(
          key: _attendanceListKey,
          child: filtered.isEmpty
              ? _buildEmpty(lang)
              : Column(
                  children: [
                    for (final record in filtered) ...[
                      _DayCardForRecord(
                        record: record,
                        onItemVisible: onItemVisible,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _CalendarCta(
          label: lang.getTranslatedText({
            'en': 'Open full calendar →',
            'id': 'Lihat kalender penuh →',
          }),
          onTap: () {
            final monthInt = int.tryParse(selectedMonthFilter ?? '');
            final initial = monthInt == null
                ? null
                : DateTime(DateTime.now().year, monthInt);
            AppNavigator.push(
              context,
              ParentAttendanceCalendarScreen(
                studentName: student?.name ?? '',
                attendanceData: attendanceData,
                initialMonth: initial,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmpty(LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 26,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            lang.getTranslatedText({
              'en': 'No attendance records',
              'id': 'Belum ada data kehadiran',
            }),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isExplicitFilter
                ? lang.getTranslatedText({
                    'en': 'Try adjusting the active filters.',
                    'id': 'Coba sesuaikan filter yang aktif.',
                  })
                : lang.getTranslatedText({
                    'en': 'No records yet for this month.',
                    'id': 'Belum ada catatan untuk bulan ini.',
                  }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate700,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- filters

  /// Apply the current month + status filters to `attendanceData`.
  /// `selectedMonthFilter` and `selectedSemesterFilter` are also
  /// applied by the data mixin's `calculateMonthlySummary`, which
  /// keeps the KPI counts in sync with the visible day list.
  List<Attendance> _filteredRecords() {
    final query = searchController.text.toLowerCase();
    final filtered = attendanceData.where((record) {
      final date = record.date;
      if (selectedMonthFilter != null &&
          date.month.toString() != selectedMonthFilter) {
        return false;
      }
      if (selectedSemesterFilter != null) {
        final sem = date.month >= 7 ? '1' : '2';
        if (sem != selectedSemesterFilter) return false;
      }
      if (selectedStatusFilter != null) {
        final normalized = normalizeStatus(record.status);
        if (normalized != selectedStatusFilter) return false;
      }
      if (query.isNotEmpty) {
        final subject = (record.subjectName ?? '').toLowerCase();
        final status = record.status.toLowerCase();
        if (!subject.contains(query) && !status.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }
}

/// Wraps an [AttendanceDayCard] so the mark-as-read hook fires the
/// instant the card mounts (i.e. when the parent first sees it).
class _DayCardForRecord extends StatefulWidget {
  final Attendance record;
  final void Function(Attendance record) onItemVisible;

  const _DayCardForRecord({required this.record, required this.onItemVisible});

  @override
  State<_DayCardForRecord> createState() => _DayCardForRecordState();
}

class _DayCardForRecordState extends State<_DayCardForRecord> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onItemVisible(widget.record);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = parseAttendanceStatus(widget.record.status);
    final palette = statusPalette(status);
    final headlineParts = <String>[
      palette.label.isEmpty ? widget.record.status : palette.label,
    ];
    final subjectName = widget.record.subjectName?.trim();
    if (subjectName != null && subjectName.isNotEmpty) {
      headlineParts.add(subjectName);
    }
    final headline = headlineParts.join(' · ');

    final secondaryParts = <String>[];
    final lessonHourName = widget.record.lessonHourName?.trim();
    if (lessonHourName != null && lessonHourName.isNotEmpty) {
      secondaryParts.add(lessonHourName);
    }
    secondaryParts.add(
      DateFormat('EEEE, d MMM yyyy', 'id_ID').format(widget.record.date),
    );
    final secondary = secondaryParts.join(' · ');

    return AttendanceDayCard(
      date: widget.record.date,
      status: status,
      headline: headline,
      secondary: secondary,
    );
  }
}

/// Bottom CTA leading to the full-month calendar view.
class _CalendarCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CalendarCta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F9FF),
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: ColorUtils.brandAzureDeep,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
