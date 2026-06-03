// Header chrome for the Ambil Presensi sheet — extracted from
// `attendance_input_picker_sheet.dart` as a `part` so the orchestrator
// stays focused on state + flow. Behavior-preserving: these are the
// same `_AmbilPresensiSheetState` methods, moved verbatim into an
// extension on the State class.
//
// Renders the cobalt header band (drag handle · kicker + title +
// today's date pill) and the segmented "Jadwal hari ini | Atur
// sendiri" tab control.
part of 'attendance_input_picker_sheet.dart';

extension _AmbilPresensiSheetHeader on _AmbilPresensiSheetState {
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
                child: const Icon(
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
            onTap: () => _setScheduleTab(true),
          ),
          _tab(
            label: widget.lp.getTranslatedText({
              'en': 'Manual',
              'id': 'Atur sendiri',
            }),
            icon: Icons.tune_rounded,
            active: !_scheduleTab,
            onTap: () => _setScheduleTab(false),
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
}
