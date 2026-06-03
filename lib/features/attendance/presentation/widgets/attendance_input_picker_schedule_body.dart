// Schedule-tab body for the Ambil Presensi sheet — extracted from
// `attendance_input_picker_sheet.dart` as a `part` so the orchestrator
// stays focused on state + flow. Behavior-preserving: these are the
// same `_AmbilPresensiSheetState` methods, moved verbatim into an
// extension on the State class.
//
// Renders today's scheduled sessions sourced from
// `/attendance/teacher-calendar`: the loading/error/empty branches,
// the "Sesi sekarang" pinned banner, and the per-session schedule
// cards (time-rail · subject + class pill · siswa count · status
// pill). Tapping a card hands the picked session back via
// `_selectScheduleSession`.
part of 'attendance_input_picker_sheet.dart';

extension _AmbilPresensiSheetScheduleBody on _AmbilPresensiSheetState {
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
    final liveNow = widget.lp.getTranslatedText({
      'en': 'Live now',
      'id': 'Sesi sekarang',
    });
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
                  '$liveNow · ${s['lesson_hour_name'] ?? ''} · '
                  '${s['class_name'] ?? ''} · ${s['subject_name'] ?? ''}',
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
    // Prefer `present_count` for the "X hadir" pill — it counts only
    // students whose status is present/hadir/late. Falls back to
    // `recorded_count` (any status) for older backend responses so
    // pre-deploy clients still render something coherent. The label
    // says "hadir"; the count must match the label.
    final recordedCount =
        ((s['present_count'] ?? s['recorded_count'] ?? 0) as num).toInt();

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
      final doneWord = widget.lp.getTranslatedText({
        'en': 'Done',
        'id': 'Sudah',
      });
      label = '$doneWord · $recordedCount hadir';
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
                        "It's not a teaching day. "
                        'You can still record attendance manually.',
                    'id':
                        'Tidak ada sesi mengajar terjadwal. '
                        'Anda masih bisa mencatat presensi manual.',
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
                  onTap: () => _setScheduleTab(false),
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
}
