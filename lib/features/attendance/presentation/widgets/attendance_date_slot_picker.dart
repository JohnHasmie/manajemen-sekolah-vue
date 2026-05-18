// Date & slot picker — Frame D from
// `_design/teacher_attendance_detail_mockup.html`.
//
// Bottom sheet that shows:
//   • A month calendar grid with green dots on dates that already
//     have at least one attendance record for the teacher.
//   • A list of today's scheduled sessions joined with attendance
//     status (recorded vs pending).
//
// Picking a date returns the YYYY-MM-DD string; picking a session
// returns the full session map so the caller can navigate to the
// attendance detail screen for that specific (class, subject, lesson
// hour) tuple. Caller decides what to do with the result.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';

/// Result of the picker — caller handles navigation/refresh.
class DateSlotPickerResult {
  final DateTime? date;
  final Map<String, dynamic>? session;
  const DateSlotPickerResult({this.date, this.session});
}

Future<DateSlotPickerResult?> showAttendanceDateSlotPicker({
  required BuildContext context,
  String? teacherId,
  String? classId,
  String? academicYearId,
  DateTime? initialMonth,
}) {
  return showModalBottomSheet<DateSlotPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DateSlotPickerBody(
      teacherId: teacherId,
      classId: classId,
      academicYearId: academicYearId,
      initialMonth: initialMonth ?? DateTime.now(),
    ),
  );
}

class _DateSlotPickerBody extends StatefulWidget {
  final String? teacherId;
  final String? classId;
  final String? academicYearId;
  final DateTime initialMonth;

  const _DateSlotPickerBody({
    required this.teacherId,
    required this.classId,
    required this.academicYearId,
    required this.initialMonth,
  });

  @override
  State<_DateSlotPickerBody> createState() => _DateSlotPickerBodyState();
}

class _DateSlotPickerBodyState extends State<_DateSlotPickerBody> {
  late DateTime _month;
  Set<String> _datesWithRecords = const {};
  List<Map<String, dynamic>> _todaysSessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final monthStr = DateFormat('yyyy-MM').format(_month);
    try {
      final res = await AttendanceService.getTeacherCalendar(
        teacherId: widget.teacherId,
        classId: widget.classId,
        academicYearId: widget.academicYearId,
        month: monthStr,
      );
      if (!mounted) return;
      setState(() {
        _datesWithRecords = ((res['dates_with_records'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet();
        _todaysSessions = ((res['sessions_today'] as List?) ?? const [])
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _handle(),
              const SizedBox(height: 4),
              _title(),
              _subtitle(),
              const SizedBox(height: 6),
              _monthHeader(),
              _weekdayLabels(),
              _calendarGrid(),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(child: _sessionsList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.only(top: 12),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: ColorUtils.slate300,
      borderRadius: BorderRadius.circular(999),
    ),
  );

  Widget _title() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Pilih waktu & sesi',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: ColorUtils.slate900,
        ),
      ),
    ),
  );

  Widget _subtitle() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Tanggal hijau = sudah ada presensi tersimpan. Pilih satu '
        'untuk dilihat / diedit, atau pilih sesi hari ini untuk '
        'membuat / membuka.',
        style: TextStyle(fontSize: 11, color: ColorUtils.slate500, height: 1.4),
      ),
    ),
  );

  Widget _monthHeader() {
    final label = DateFormat('MMMM yyyy', 'id_ID').format(_month);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _loading ? null : () => _shiftMonth(-1),
            icon: Icon(Icons.chevron_left_rounded, color: ColorUtils.slate700),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate900,
              ),
            ),
          ),
          IconButton(
            onPressed: _loading ? null : () => _shiftMonth(1),
            icon: Icon(Icons.chevron_right_rounded, color: ColorUtils.slate700),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _weekdayLabels() {
    const labels = ['S', 'S', 'R', 'K', 'J', 'S', 'M']; // Sen..Min
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: labels
            .map(
              (l) => Expanded(
                child: SizedBox(
                  height: 22,
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate400,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _calendarGrid() {
    // Build a 6-row grid starting on Monday (ISO).
    final firstDay = DateTime(_month.year, _month.month, 1);
    final lead = (firstDay.weekday + 6) % 7; // Mon=0
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final today = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(_month.year, _month.month, d);
      final iso = DateFormat('yyyy-MM-dd').format(date);
      final hasRecord = _datesWithRecords.contains(iso);
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      cells.add(_dayCell(date, d, hasRecord: hasRecord, isToday: isToday));
    }
    // Pad to a multiple of 7 for clean rows.
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 7,
        childAspectRatio: 1.05,
        children: cells,
      ),
    );
  }

  Widget _dayCell(
    DateTime date,
    int day, {
    required bool hasRecord,
    required bool isToday,
  }) {
    final fg = isToday
        ? Colors.white
        : (hasRecord ? ColorUtils.success600 : ColorUtils.slate800);
    final bg = isToday
        ? ColorUtils.brandCobalt
        : (hasRecord
              ? ColorUtils.success600.withValues(alpha: 0.12)
              : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.pop(context, DateSlotPickerResult(date: date));
          },
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: hasRecord || isToday
                    ? FontWeight.w800
                    : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionsList() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_todaysSessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Center(
          child: Text(
            'Tidak ada sesi terjadwal hari ini.',
            style: TextStyle(fontSize: 11.5, color: ColorUtils.slate500),
          ),
        ),
      );
    }

    final today = DateTime.now();
    final dayLabel = DateFormat('EEEE, d MMM', 'id_ID').format(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sesi hari ini · $dayLabel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Text(
                '${_todaysSessions.length} sesi',
                style: TextStyle(
                  fontSize: 10.5,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _todaysSessions.length,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemBuilder: (_, i) => _sessionTile(_todaysSessions[i]),
          ),
        ),
      ],
    );
  }

  Widget _sessionTile(Map<String, dynamic> s) {
    final isPending = (s['status'] ?? 'pending') == 'pending';
    final subject = (s['subject_name'] ?? '-').toString();
    final initial = subject.isEmpty ? '?' : subject[0].toUpperCase();
    final iconBg = isPending
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFDCFCE7);
    final iconFg = isPending ? const Color(0xFFB45309) : ColorUtils.success600;
    final time = _fmtTimeRange(s['start_time'], s['end_time']);
    final lh = (s['lesson_hour_name'] ?? '').toString();
    final cls = (s['class_name'] ?? '-').toString();
    final subtitleParts = <String>[
      cls,
      if (time.isNotEmpty) time,
      if (lh.isNotEmpty) lh,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pop(context, DateSlotPickerResult(session: s));
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: iconFg,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
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
                        '$subject · $cls',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isPending
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isPending ? 'Belum' : 'Tersimpan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isPending
                          ? const Color(0xFFB45309)
                          : ColorUtils.success600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTimeRange(dynamic start, dynamic end) {
    final s = (start ?? '').toString();
    final e = (end ?? '').toString();
    if (s.isEmpty || e.isEmpty) return '';
    String trim(String t) => t.length >= 5
        ? t.substring(0, 5).replaceAll(':', '.')
        : t.replaceAll(':', '.');
    return '${trim(s)} – ${trim(e)}';
  }
}
