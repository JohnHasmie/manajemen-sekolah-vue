// Parent view of a child's attendance — Phase 3 brand-aligned redesign.
//
// The screen still composes its data layer from the existing six mixins
// (state / data / visibility / tour / filter / status) — that part hasn't
// moved. What changed is the presentation: instead of a custom gradient
// header + search bar + skeletal list, we now use the canonical
// Phase-3 stack of shared widgets:
//
//   • [BrandPageHeader] (role 'wali') — gradient hero with title, child
//     name in the subtitle, single filter icon, realtime pill, and a
//     [BrandFilterChipStrip] showing the active Bulan / Semester filters.
//   • [AttendanceRingKpi] — donut + 4-row legend KPI card driven by
//     `monthlySummary`.
//   • [AttendanceDayCard] — per-record list rows with status-tinted
//     date badge + status pill.
//
// The inline search input is gone (matches the Nilai/Tagihan pattern —
// parents don't type subject names; they tap chips). Filtering goes
// through the bottom sheet from [ParentAttendanceFilterMixin] and is
// surfaced in the chip strip.
//
// Pull-to-refresh wraps the body so the manual "refresh" overflow menu
// item from the old header is no longer needed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_day_card.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_ring_kpi.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_status.dart';
import 'package:manajemensekolah/core/widgets/brand_filter_chip_strip.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_filter_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_status_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_tour_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_visibility_mixin.dart';

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

  // Track when the cached/fresh data was last loaded so the realtime
  // pill can show "Terhubung realtime · HH:MM" or
  // "Terakhir diperbarui N menit lalu".
  DateTime _lastSync = DateTime.now();

  @override
  GlobalKey get monthlySummaryKey => _monthlySummaryKey;

  @override
  GlobalKey get attendanceListKey => _attendanceListKey;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.read(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(lang),
          Expanded(
            child: RefreshIndicator(
              color: ColorUtils.brandAzureDeep,
              onRefresh: () async {
                await forceRefresh();
                if (mounted) {
                  setState(() => _lastSync = DateTime.now());
                }
              },
              child: isLoading
                  ? SkeletonListLoading(
                      itemCount: 6,
                      infoTagCount: 2,
                      baseColor:
                          ColorUtils.brandAzure.withValues(alpha: 0.15),
                      highlightColor:
                          ColorUtils.brandAzure.withValues(alpha: 0.05),
                    )
                  : _buildBody(lang),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- header

  Widget _buildHeader(LanguageProvider lang) {
    final subtitleParts = <String>[];
    if (student?.name != null && student!.name.isNotEmpty) {
      subtitleParts.add(student!.name);
    }
    if (student?.className != null && student!.className!.isNotEmpty) {
      subtitleParts.add(student!.className!);
    }
    final subtitle = subtitleParts.isEmpty
        ? lang.getTranslatedText({
            'en': 'Academic · Child',
            'id': 'Akademik · Anak',
          })
        : subtitleParts.join(' · ');

    return BrandPageHeader(
      role: 'wali',
      subtitle: subtitle,
      title: lang.getTranslatedText({
        'en': 'Attendance',
        'id': 'Kehadiran',
      }),
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.tune_rounded,
          onTap: showFilterSheet,
          badgeCount: hasActiveFilter ? _activeFilterCount() : null,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
      ],
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      bottomSlot: BrandFilterChipStrip(
        chips: [
          BrandFilterChip(
            label: lang.getTranslatedText({'en': 'Month', 'id': 'Bulan'}),
            value: _monthChipValue(lang),
            onTap: showFilterSheet,
            width: 172,
          ),
          BrandFilterChip(
            label: lang.getTranslatedText({
              'en': 'Semester',
              'id': 'Semester',
            }),
            value: _semesterChipValue(lang),
            onTap: showFilterSheet,
          ),
        ],
      ),
    );
  }

  String? _monthChipValue(LanguageProvider lang) {
    if (selectedMonthFilter == null) return null;
    final months = getMonthsList();
    final match = months.firstWhere(
      (m) => m['val'] == selectedMonthFilter,
      orElse: () => const {},
    );
    if (match.isEmpty) return null;
    return lang.getTranslatedText({
      'en': match['en']!,
      'id': match['id']!,
    });
  }

  String? _semesterChipValue(LanguageProvider lang) {
    if (selectedSemesterFilter == null) return null;
    return lang.getTranslatedText({
      'en': 'Semester $selectedSemesterFilter',
      'id': 'Semester $selectedSemesterFilter',
    });
  }

  int _activeFilterCount() {
    var n = 0;
    if (selectedMonthFilter != null) n++;
    if (selectedSemesterFilter != null) n++;
    return n;
  }

  // ------------------------------------------------------------------ body

  Widget _buildBody(LanguageProvider lang) {
    final filtered = _filteredRecords();
    final totalDays = monthlySummary.values.fold<int>(0, (a, b) => a + b);
    final presentDays = (monthlySummary['hadir'] ?? 0) +
        (monthlySummary['terlambat'] ?? 0);
    final rate = totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;

    return ListView(
      // physics: ensures pull-to-refresh fires even when content fits.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        KeyedSubtree(
          key: _monthlySummaryKey,
          child: AttendanceRingKpi(
            rate: rate,
            presentDays: presentDays,
            excusedDays: monthlySummary['izin'] ?? 0,
            sickDays: monthlySummary['sakit'] ?? 0,
            alphaDays: monthlySummary['alpha'] ?? 0,
            schoolDays: totalDays,
            periodLabel: hasActiveFilter
                ? lang.getTranslatedText({
                    'en': 'Selected period',
                    'id': 'Periode terpilih',
                  })
                : lang.getTranslatedText({
                    'en': 'This month',
                    'id': 'Bulan ini',
                  }),
            brandColor: ColorUtils.brandAzureDeep,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
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
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate500,
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
            // TODO(parent-kehadiran): wire up the full-month calendar
            // screen once it lands. The shared
            // `AttendanceCalendarGrid` widget is already in place.
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
            hasActiveFilter
                ? lang.getTranslatedText({
                    'en': 'Try adjusting the active filters.',
                    'id': 'Coba sesuaikan filter yang aktif.',
                  })
                : lang.getTranslatedText({
                    'en':
                        'No records yet for the selected academic year.',
                    'id': 'Belum ada catatan untuk tahun ajaran ini.',
                  }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- filters

  /// Apply the current month + semester filters (and the never-set
  /// search query — kept for back-compat with the data mixin) to the
  /// raw `attendanceData` list and return the result newest-first.
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
      if (query.isNotEmpty) {
        final subject = (record.subjectName ?? '').toLowerCase();
        final status = record.status.toLowerCase();
        if (!subject.contains(query) && !status.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }
}

/// Wraps an [AttendanceDayCard] so the mark-as-read hook fires the
/// instant the card mounts (i.e. when the parent first sees it).
class _DayCardForRecord extends StatefulWidget {
  final Attendance record;
  final void Function(Attendance record) onItemVisible;

  const _DayCardForRecord({
    required this.record,
    required this.onItemVisible,
  });

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
    secondaryParts
        .add(DateFormat('EEEE, d MMM yyyy', 'id_ID').format(widget.record.date));
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
            border: Border.all(
              color: const Color(0xFFBAE6FD),
              width: 1,
            ),
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
