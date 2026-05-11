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
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';

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
          ? raw
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
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
            : (s['date']).toString(),
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

  // ── Header ──

  /// Drag handle, drawn on the cobalt header in white-with-alpha so
  /// there's no slate-50 strip between the parent screen and the
  /// header (the previous layout had the handle on a slate-50 band
  /// above the gradient, which read as a white seam).
  Widget _handleOnCobalt() => Container(
    margin: const EdgeInsets.only(top: 8, bottom: 4),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(999),
    ),
  );

  Widget _header() {
    final today = DateFormat('EEE, d MMM', 'id_ID').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandDarkBlue, ColorUtils.brandCobalt],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: _handleOnCobalt()),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.lp.getTranslatedText({
                        'en': 'Academic · Attendance',
                        'id': 'Akademik · Presensi',
                      }).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.72),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.lp.getTranslatedText({
                        'en': 'Take Attendance',
                        'id': 'Ambil Presensi',
                      }),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  today,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _segmentTabs(),
        ],
      ),
    );
  }

  Widget _segmentTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _tab(
            label: widget.lp.getTranslatedText({
              'en': "Today's schedule",
              'id': 'Jadwal hari ini',
            }),
            icon: Icons.schedule_rounded,
            active: _scheduleTab,
            onTap: () => setState(() => _scheduleTab = true),
          ),
          _tab(
            label: widget.lp.getTranslatedText({
              'en': 'Manual',
              'id': 'Atur sendiri',
            }),
            icon: Icons.tune_rounded,
            active: !_scheduleTab,
            onTap: () => setState(() => _scheduleTab = false),
          ),
        ],
      ),
    );
  }

  Widget _tab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: active
                    ? ColorUtils.brandCobalt
                    : Colors.white.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? ColorUtils.brandCobalt
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Schedule tab body ──

  Widget _scheduleBody() {
    if (_loadingSchedule) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_scheduleError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Gagal memuat jadwal: $_scheduleError',
          style: TextStyle(color: ColorUtils.error600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_sessions.isEmpty) {
      return _emptyState();
    }
    final liveIdx = _liveIndex;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      children: [
        if (liveIdx != null) _nowBanner(_sessions[liveIdx]),
        _sectionHead(
          title: widget.lp.getTranslatedText({
            'en': "Today's schedule",
            'id': 'Jadwal hari ini',
          }),
          tail: '${_sessions.length} sesi',
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < _sessions.length; i++)
          _scheduleCard(_sessions[i], live: i == liveIdx),
      ],
    );
  }

  Widget _nowBanner(Map<String, dynamic> s) {
    final cobalt = ColorUtils.brandCobalt;
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            cobalt.withValues(alpha: 0.10),
            ColorUtils.info600.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cobalt.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ColorUtils.success600,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ColorUtils.success600.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.lp.getTranslatedText({
                        'en': 'Live now',
                        'id': 'Sesi sekarang',
                      }) +
                      ' · ${s['lesson_hour_name'] ?? ''} · ${s['class_name'] ?? ''} · ${s['subject_name'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_clipTime((s['start_time'] ?? '').toString())} – '
                  '${_clipTime((s['end_time'] ?? '').toString())} · '
                  '${s['student_count'] ?? 0} siswa',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _selectScheduleSession(s),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cobalt,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: cobalt.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.lp.getTranslatedText({'en': 'Start', 'id': 'Mulai'}),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHead({required String title, required String tail}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            tail,
            style: TextStyle(
              fontSize: 10.5,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(Map<String, dynamic> s, {required bool live}) {
    final status = (s['status'] ?? 'pending').toString();
    final startTime = _clipTime((s['start_time'] ?? '').toString());
    final endTime = _clipTime((s['end_time'] ?? '').toString());
    final lessonHourName = (s['lesson_hour_name'] ?? '')
        .toString()
        .toUpperCase();
    final subjectName = (s['subject_name'] ?? '-').toString();
    final className = (s['class_name'] ?? '-').toString();
    final studentCount = ((s['student_count'] ?? 0) as num).toInt();
    final recordedCount = ((s['recorded_count'] ?? 0) as num).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _selectScheduleSession(s),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: live ? ColorUtils.brandCobalt : ColorUtils.slate200,
                width: live ? 1.5 : 1,
              ),
              boxShadow: live
                  ? [
                      BoxShadow(
                        color: ColorUtils.brandCobalt.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _timeRail(lessonHourName, startTime, endTime),
                const SizedBox(width: 10),
                Expanded(
                  child: _scheduleCardBody(
                    subjectName: subjectName,
                    className: className,
                    studentCount: studentCount,
                    status: status,
                    recordedCount: recordedCount,
                    live: live,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorUtils.slate300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeRail(String jam, String start, String end) {
    return Container(
      width: 56,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            jam,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.brandCobalt,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            start.isEmpty ? '–' : start,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ColorUtils.slate900,
              letterSpacing: -0.4,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            end.isEmpty ? '' : end,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCardBody({
    required String subjectName,
    required String className,
    required int studentCount,
    required String status,
    required int recordedCount,
    required bool live,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                subjectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: ColorUtils.info600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                className,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.info600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.people_alt_rounded,
              size: 11,
              color: ColorUtils.slate400,
            ),
            const SizedBox(width: 4),
            Text(
              '$studentCount siswa',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _statusPill(status, recordedCount, live),
      ],
    );
  }

  Widget _statusPill(String status, int recordedCount, bool live) {
    String label;
    Color tint;
    Color fg;
    IconData icon;
    if (live) {
      label = widget.lp.getTranslatedText({
        'en': 'Live now',
        'id': 'Sedang berlangsung',
      });
      tint = ColorUtils.brandCobalt;
      fg = Colors.white;
      icon = Icons.radio_button_checked;
    } else if (status == 'recorded') {
      label =
          widget.lp.getTranslatedText({'en': 'Done', 'id': 'Sudah'}) +
          ' · $recordedCount hadir';
      tint = ColorUtils.success600.withValues(alpha: 0.14);
      fg = ColorUtils.success600;
      icon = Icons.check_circle_rounded;
    } else {
      label = widget.lp.getTranslatedText({
        'en': 'Not yet',
        'id': 'Belum diabsen',
      });
      tint = ColorUtils.warning600.withValues(alpha: 0.14);
      fg = ColorUtils.warning600;
      icon = Icons.error_outline_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: ColorUtils.slate300,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorUtils.info600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.event_busy_rounded,
                    color: ColorUtils.info600,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.lp.getTranslatedText({
                    'en': 'No schedule today',
                    'id': 'Tidak ada jadwal hari ini',
                  }),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.lp.getTranslatedText({
                    'en':
                        "It's not a teaching day. You can still record attendance manually.",
                    'id':
                        'Tidak ada sesi mengajar terjadwal. Anda masih bisa mencatat presensi manual.',
                  }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ColorUtils.slate500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => setState(() => _scheduleTab = false),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: ColorUtils.brandCobalt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.lp.getTranslatedText({
                        'en': 'Manual',
                        'id': 'Atur sendiri',
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual tab body ──

  Widget _manualBody() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      children: [
        _fieldGroup(
          label: widget.lp.getTranslatedText({'en': 'Date', 'id': 'Tanggal'}),
          child: _datePicker(),
        ),
        _fieldGroup(
          label: widget.lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
          child: _classChips(),
        ),
        _fieldGroup(
          label: widget.lp.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          child: _subjectChips(),
        ),
      ],
    );
  }

  Widget _fieldGroup({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _manualDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) setState(() => _manualDate = picked);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          border: Border.all(color: ColorUtils.slate200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: ColorUtils.slate400,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('EEE, d MMM yyyy', 'id_ID').format(_manualDate),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: ColorUtils.slate400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _classChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in widget.classList)
          if (c is Map)
            _chip(
              label: (c['name'] ?? c['nama'] ?? '-').toString(),
              selected: _manualClassId == (c['id'] ?? '').toString(),
              onTap: () {
                final cid = (c['id'] ?? '').toString();
                final cname = (c['name'] ?? c['nama'] ?? '').toString();
                setState(() {
                  _manualClassId = cid;
                  _manualClassName = cname;
                  _manualSubjectId = null;
                  _manualSubjectName = null;
                  _manualSubjectList = const [];
                });
                _fetchManualSubjects(cid);
              },
            ),
      ],
    );
  }

  Widget _subjectChips() {
    if (_manualClassId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.lp.getTranslatedText({
            'en': 'Pick a class first.',
            'id': 'Pilih kelas terlebih dulu.',
          }),
          style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
        ),
      );
    }
    if (_loadingSubjects) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.lp.getTranslatedText({
            'en': 'Loading subjects…',
            'id': 'Memuat mapel…',
          }),
          style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
        ),
      );
    }
    if (_manualSubjectList.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          widget.lp.getTranslatedText({
            'en': 'No subjects assigned for this class.',
            'id': 'Tidak ada mapel untuk kelas ini.',
          }),
          style: TextStyle(fontSize: 11.5, color: ColorUtils.slate400),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in _manualSubjectList)
          if (s is Map)
            _chip(
              label: (s['name'] ?? s['nama'] ?? '-').toString(),
              selected: _manualSubjectId == (s['id'] ?? '').toString(),
              onTap: () {
                setState(() {
                  _manualSubjectId = (s['id'] ?? '').toString();
                  _manualSubjectName = (s['name'] ?? s['nama'] ?? '')
                      .toString();
                });
              },
            ),
      ],
    );
  }

  /// Compact chip — sized to its label, not greedy. Earlier the chips
  /// rendered as full-width pills because the AnimatedContainer used
  /// `alignment: Alignment.center` which makes Container expand to the
  /// parent's intrinsic width. Replaced with a Material+InkWell wrap
  /// around `Padding > Text` so the chip hugs its content and Wrap
  /// can lay multiple chips per row.
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? ColorUtils.brandCobalt.withValues(alpha: 0.10)
                : ColorUtils.slate50,
            border: Border.all(
              color: selected ? ColorUtils.brandCobalt : ColorUtils.slate200,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? ColorUtils.brandCobalt : ColorUtils.slate700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _manualFooter() {
    final canApply = _manualClassId != null && _manualSubjectId != null;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorUtils.slate700,
                    side: BorderSide(color: ColorUtils.slate200),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: Text(
                    widget.lp.getTranslatedText({
                      'en': 'Cancel',
                      'id': 'Batal',
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: canApply ? _applyManual : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  label: Text(
                    widget.lp.getTranslatedText({
                      'en': 'Start',
                      'id': 'Mulai Absen',
                    }),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.brandCobalt,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ColorUtils.slate200,
                    disabledForegroundColor: ColorUtils.slate500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
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
