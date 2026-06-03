// Schedule-driven Ambil Presensi sheet — replaces the legacy chip
// picker (Pilih Kelas + Pilih Mapel) with a list of today's actual
// teaching sessions sourced from `/attendance/teacher-calendar`.
//
// Mirrors `_design/teacher_attendance_input_sheet_redesign.html`:
//   • Brand-cobalt header (kicker + title + today's date pill)
//   • Segmented tabs · "Jadwal hari ini" | "Atur sendiri"
//   • Sesi-sekarang banner pinned above the list when current time
//     falls inside a scheduled slot
//   • Schedule cards: time-rail · subject + class pill · siswa count
//     · status pill (Sudah / Sedang / Belum)
//   • Manual fallback tab keeps date + lesson-hour + class + subject
//     pickers for off-schedule input
//   • Empty state when there is no schedule today (Sundays/holidays)
//
// ── Structure ──
// This file is the orchestrator: the public `AmbilPresensiPick` data
// class, the `showAmbilPresensiSheet` entry point, and the
// `_AmbilPresensiSheetState` state + data flow + `build`. The view
// sections live in `part` files (extensions on the State class) so
// each stays a focused unit while sharing the State's private fields:
//   • attendance_input_picker_header.dart        — cobalt header + tabs
//   • attendance_input_picker_schedule_body.dart — "Jadwal hari ini"
//   • attendance_input_picker_manual_body.dart   — "Atur sendiri"
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';

part 'attendance_input_picker_header.dart';
part 'attendance_input_picker_schedule_body.dart';
part 'attendance_input_picker_manual_body.dart';

class AmbilPresensiPick {
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;

  /// Optional — when the picked source is a scheduled session.
  final String? lessonHourId;
  final String? lessonHourName;
  final String? startTime;
  final String? endTime;

  /// ISO `YYYY-MM-DD` — defaults to today when manual mode picked it.
  final String date;

  const AmbilPresensiPick({
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.date,
    this.lessonHourId,
    this.lessonHourName,
    this.startTime,
    this.endTime,
  });
}

/// Open the redesigned Ambil Presensi sheet. Returns the picked
/// session (class · subject · lesson_hour · date) or null on cancel.
///
/// [classList] is the list of classes the teacher teaches — used by
/// the manual-mode tab as the chip source. [teacherId] drives the
/// `/attendance/teacher-calendar` lookup that builds the schedule
/// cards in default mode.
///
/// Uses the shared `AppDraggableSheet` primitive so the chrome
/// (modal bottom sheet wrapping + drag handle behavior + height
/// presets) stays consistent with the rest of the app.
Future<AmbilPresensiPick?> showAmbilPresensiSheet({
  required BuildContext context,
  required LanguageProvider lp,
  required String teacherId,
  required List<dynamic> classList,
  String? academicYearId,
}) {
  return AppDraggableSheet.show<AmbilPresensiPick>(
    context: context,
    builder: (ctx, scrollController) => _AmbilPresensiSheet(
      lp: lp,
      teacherId: teacherId,
      classList: classList,
      academicYearId: academicYearId,
      scrollController: scrollController,
    ),
  );
}

class _AmbilPresensiSheet extends StatefulWidget {
  final LanguageProvider lp;
  final String teacherId;
  final List<dynamic> classList;
  final String? academicYearId;
  final ScrollController scrollController;

  const _AmbilPresensiSheet({
    required this.lp,
    required this.teacherId,
    required this.classList,
    required this.academicYearId,
    required this.scrollController,
  });

  @override
  State<_AmbilPresensiSheet> createState() => _AmbilPresensiSheetState();
}

class _AmbilPresensiSheetState extends State<_AmbilPresensiSheet> {
  bool _scheduleTab = true;
  bool _loadingSchedule = true;
  String? _scheduleError;
  List<Map<String, dynamic>> _sessions = const [];

  // Manual-mode state
  DateTime _manualDate = DateTime.now();
  String? _manualClassId;
  String? _manualClassName;
  String? _manualSubjectId;
  String? _manualSubjectName;
  List<dynamic> _manualSubjectList = const [];
  bool _loadingSubjects = false;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    try {
      final res = await AttendanceService.getTeacherCalendar(
        teacherId: widget.teacherId,
        academicYearId: widget.academicYearId,
      );
      final raw = res['sessions_today'];
      final sessions = raw is List
          ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loadingSchedule = false;
        _scheduleError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSchedule = false;
        _scheduleError = '$e';
      });
    }
  }

  Future<void> _fetchManualSubjects(String classId) async {
    setState(() => _loadingSubjects = true);
    try {
      final r = await dioClient.get(
        '/teacher/${widget.teacherId}/subjects',
        queryParameters: {'class_id': classId},
      );
      final raw = r.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : const []);
      if (!mounted) return;
      setState(() {
        _manualSubjectList = list;
        _loadingSubjects = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSubjects = false);
    }
  }

  /// Returns the index in `_sessions` whose [start, end] window
  /// contains the current wall-clock time, or null when nothing is
  /// live. Drives the "Sesi sekarang" pinned banner.
  int? get _liveIndex {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (var i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      final start = _parseHm((s['start_time'] ?? '').toString());
      final end = _parseHm((s['end_time'] ?? '').toString());
      if (start != null &&
          end != null &&
          nowMinutes >= start &&
          nowMinutes < end) {
        return i;
      }
    }
    return null;
  }

  int? _parseHm(String hm) {
    if (hm.isEmpty) return null;
    final parts = hm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  void _confirm(AmbilPresensiPick pick) => Navigator.of(context).pop(pick);

  void _selectScheduleSession(Map<String, dynamic> s) {
    _confirm(
      AmbilPresensiPick(
        classId: (s['class_id'] ?? '').toString(),
        className: (s['class_name'] ?? '').toString(),
        subjectId: (s['subject_id'] ?? '').toString(),
        subjectName: (s['subject_name'] ?? '').toString(),
        lessonHourId: (s['lesson_hour_id'] ?? '').toString().isEmpty
            ? null
            : s['lesson_hour_id'].toString(),
        lessonHourName: s['lesson_hour_name']?.toString(),
        startTime: s['start_time']?.toString(),
        endTime: s['end_time']?.toString(),
        date: (s['date'] ?? '').toString().isEmpty
            ? DateFormat('yyyy-MM-dd').format(DateTime.now())
            : s['date'].toString(),
      ),
    );
  }

  void _applyManual() {
    if (_manualClassId == null || _manualSubjectId == null) return;
    _confirm(
      AmbilPresensiPick(
        classId: _manualClassId!,
        className: _manualClassName ?? '',
        subjectId: _manualSubjectId!,
        subjectName: _manualSubjectName ?? '',
        date: DateFormat('yyyy-MM-dd').format(_manualDate),
      ),
    );
  }

  // ── setState wrappers ──
  // The view sections live in `part` extensions (header / schedule body
  // / manual body), and extensions can't call the protected `setState`.
  // These tiny mutators keep the `setState` calls on the state class so
  // the parts can drive UI transitions without the
  // `invalid_use_of_protected_member` lint. Bodies are unchanged from
  // the original inline `setState` blocks.

  void _setScheduleTab(bool schedule) =>
      setState(() => _scheduleTab = schedule);

  void _setManualDate(DateTime date) => setState(() => _manualDate = date);

  void _selectManualClass(String cid, String cname) {
    setState(() {
      _manualClassId = cid;
      _manualClassName = cname;
      _manualSubjectId = null;
      _manualSubjectName = null;
      _manualSubjectList = const [];
    });
  }

  void _selectManualSubject(String sid, String sname) {
    setState(() {
      _manualSubjectId = sid;
      _manualSubjectName = sname;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: Column(
          children: [
            _header(),
            Expanded(child: _scheduleTab ? _scheduleBody() : _manualBody()),
            if (!_scheduleTab) _manualFooter(),
          ],
        ),
      ),
    );
  }

  String _clipTime(String s) {
    if (s.length >= 5) return s.substring(0, 5).replaceAll(':', '.');
    return s.replaceAll(':', '.');
  }
}
