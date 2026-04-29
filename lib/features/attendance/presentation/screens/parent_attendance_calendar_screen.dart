// Parent full-month attendance calendar.
//
// Phase-3 mockup: `Parent_Phase3_Kehadiran_Calendar_Mockup.svg`.
//
//   • Brand-azure gradient hero with month name as the title, child
//     name in the subtitle, prev / next chevrons for month
//     navigation, and a row of 4 mini KPI tiles (Hadir / Izin / Sakit
//     / Alpha) showing per-month counts.
//   • Body: a single white card containing the 7-column SEN-MIN
//     `AttendanceCalendarGrid` for the visible month.
//   • Below the calendar: an inline detail panel for the currently
//     selected day, listing each class-period record with status
//     pill + subject + lesson-hour.
//
// The screen consumes attendance data passed in from the parent
// `ParentAttendanceScreen` rather than refetching — the parent
// already has the year's records loaded so no extra network round
// trip is needed.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:intl/intl.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_calendar_grid.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_status.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';

/// Full-month calendar view of a child's attendance.
class ParentAttendanceCalendarScreen extends ConsumerStatefulWidget {
  /// Display name shown in the hero subtitle ("Kehadiran · {name}").
  final String studentName;

  /// Already-loaded year's attendance — the calendar filters this
  /// down to the visible month and aggregates per-day status.
  final List<Attendance> attendanceData;

  /// Initial month to display (year/month parts only). Defaults to
  /// the current calendar month.
  final DateTime? initialMonth;

  const ParentAttendanceCalendarScreen({
    super.key,
    required this.studentName,
    required this.attendanceData,
    this.initialMonth,
  });

  @override
  ConsumerState<ParentAttendanceCalendarScreen> createState() =>
      _ParentAttendanceCalendarScreenState();
}

class _ParentAttendanceCalendarScreenState
    extends ConsumerState<ParentAttendanceCalendarScreen> {
  late DateTime _viewMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _viewMonth = DateTime(
      widget.initialMonth?.year ?? now.year,
      widget.initialMonth?.month ?? now.month,
    );
  }

  // ---------- Per-month aggregation ------------------------------------

  /// Records that fall inside [_viewMonth].
  Iterable<Attendance> get _monthRecords => widget.attendanceData.where(
    (r) => r.date.year == _viewMonth.year && r.date.month == _viewMonth.month,
  );

  /// One AttendanceStatus per calendar day in the visible month.
  /// Aggregation rule: the WORST status of the day wins (alpha >
  /// sick > excused > late > present > none) so a single missed
  /// class doesn't get hidden by a bunch of "hadir" records on the
  /// same date.
  Map<DateTime, AttendanceStatus> get _dayStatuses {
    final result = <DateTime, AttendanceStatus>{};
    for (final r in _monthRecords) {
      final key = DateTime(r.date.year, r.date.month, r.date.day);
      final status = parseAttendanceStatus(r.status);
      final existing = result[key];
      if (existing == null ||
          _statusSeverity(status) > _statusSeverity(existing)) {
        result[key] = status;
      }
    }
    return result;
  }

  /// Higher = worse. Used by [_dayStatuses] for "worst wins"
  /// per-day aggregation.
  int _statusSeverity(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.alpha:
        return 5;
      case AttendanceStatus.sick:
        return 4;
      case AttendanceStatus.excused:
        return 3;
      case AttendanceStatus.late:
        return 2;
      case AttendanceStatus.present:
        return 1;
      case AttendanceStatus.none:
        return 0;
    }
  }

  /// Per-month per-status counts driving the 4 mini KPI tiles.
  ({int present, int excused, int sick, int alpha}) get _counts {
    var p = 0, e = 0, s = 0, a = 0;
    for (final entry in _dayStatuses.values) {
      switch (entry) {
        case AttendanceStatus.present:
        case AttendanceStatus.late:
          p++;
        case AttendanceStatus.excused:
          e++;
        case AttendanceStatus.sick:
          s++;
        case AttendanceStatus.alpha:
          a++;
        case AttendanceStatus.none:
          break;
      }
    }
    return (present: p, excused: e, sick: s, alpha: a);
  }

  // ---------- Build ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(lang)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                0,
              ),
              child: AttendanceCalendarGrid(
                month: _viewMonth,
                dayStatuses: _dayStatuses,
                selectedDate: _selectedDay,
                onDaySelected: (day) => setState(() => _selectedDay = day),
              ),
            ),
          ),
          if (_selectedDay != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                child: _buildDetailPanel(lang),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    final monthLabel = DateFormat('MMMM y', 'id_ID').format(_viewMonth);
    final c = _counts;
    return BrandPageHeader(
      role: 'wali',
      subtitle:
          '${lang.getTranslatedText({'en': 'Attendance', 'id': 'Kehadiran'})} · ${widget.studentName}',
      title: monthLabel,
      actionIcons: [
        BrandHeaderIconButton(
          icon: Icons.chevron_left_rounded,
          onTap: _goToPrevMonth,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
        BrandHeaderIconButton(
          icon: Icons.chevron_right_rounded,
          onTap: _goToNextMonth,
          badgeBorderColor: ColorUtils.brandAzureDeep,
        ),
      ],
      bottomSlot: Row(
        children: [
          Expanded(
            child: _MiniKpi(
              label: lang.getTranslatedText({'en': 'Present', 'id': 'Hadir'}),
              count: c.present,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniKpi(
              label: lang.getTranslatedText({'en': 'Permission', 'id': 'Izin'}),
              count: c.excused,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniKpi(
              label: lang.getTranslatedText({'en': 'Sick', 'id': 'Sakit'}),
              count: c.sick,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MiniKpi(
              label: lang.getTranslatedText({'en': 'Alpha', 'id': 'Alpha'}),
              count: c.alpha,
            ),
          ),
        ],
      ),
    );
  }

  void _goToPrevMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _goToNextMonth() {
    setState(() {
      _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
      _selectedDay = null;
    });
  }

  // ---------- Selected-day detail panel --------------------------------

  Widget _buildDetailPanel(LanguageProvider lang) {
    final selected = _selectedDay!;
    final records =
        widget.attendanceData
            .where(
              (r) =>
                  r.date.year == selected.year &&
                  r.date.month == selected.month &&
                  r.date.day == selected.day,
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final dayLabel = DateFormat('EEEE · d MMM', 'id_ID').format(selected);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${lang.getTranslatedText({'en': 'DETAIL', 'id': 'DETAIL'})} ${dayLabel.toUpperCase()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (records.isEmpty)
            Text(
              lang.getTranslatedText({
                'en': 'No attendance recorded for this day.',
                'id': 'Belum ada catatan kehadiran untuk hari ini.',
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: ColorUtils.slate700,
              ),
            )
          else
            for (var i = 0; i < records.length; i++) ...[
              if (i > 0) const Divider(height: 16, color: Color(0xFFF1F5F9)),
              _buildRecordRow(records[i]),
            ],
        ],
      ),
    );
  }

  Widget _buildRecordRow(Attendance record) {
    final status = parseAttendanceStatus(record.status);
    final palette = statusPalette(status);
    final subject = (record.subjectName ?? '').trim();
    final lesson = (record.lessonHourName ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: const BorderRadius.all(Radius.circular(11)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.dot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                palette.label.isEmpty ? record.status : palette.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (subject.isNotEmpty)
          Text(
            subject,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate900,
            ),
          ),
        if (lesson.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            lesson,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate600,
            ),
          ),
        ],
      ],
    );
  }
}

/// One of the 4 mini KPI tiles in the calendar hero. White-tinted
/// pill with a small label, big count, and a "hari" caption.
class _MiniKpi extends StatelessWidget {
  final String label;
  final int count;

  const _MiniKpi({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF), // 18% white solid
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'hari',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
