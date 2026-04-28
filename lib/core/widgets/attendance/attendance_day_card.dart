// Single-day list row used in the parent Kehadiran "Riwayat harian"
// list and inside any per-day detail surface.
//
// Visual contract (mockup `Parent_Phase3_Kehadiran_Mockup.svg`)
// ------------------------------------------------------------
//   • White card with 0.75 px slate-200 border, 14 px corner.
//   • Left date badge 44×36 — colored to match the day's status
//     (green for hadir, amber for terlambat/sakit, cyan for izin,
//      red for alpha).
//   • Day-of-week (3-letter caps) on top of date number.
//   • Title row with optional secondary line (entry/exit time, note).
//   • Right-side status pill — same status palette as the date badge.
//   • Whole row is tappable; if [onTap] is null the row is non-clickable.
//
// Used by:
//   • parent_attendance_screen — main "Riwayat harian" list.
//   • parent_attendance_calendar_screen — selected-day detail panel.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/attendance/attendance_status.dart';

/// Indonesian short day-of-week names indexed by [DateTime.weekday].
/// `weekday` is 1-based (Monday = 1, Sunday = 7).
const _idShortWeekday = <String>[
  '', // index 0 unused
  'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN',
];

/// A single day's attendance summary as a tappable list card.
class AttendanceDayCard extends StatelessWidget {
  /// The date this row represents — used for the left badge label and
  /// for ordering callers should do externally.
  final DateTime date;

  /// Day-level status. Drives the left badge tint and the right pill.
  final AttendanceStatus status;

  /// Headline copy on the right. e.g. `"Hadir"`, `"Hadir, terlambat 12 mnt"`,
  /// `"Izin keluarga"`. Caller composes — gives full freedom over the
  /// wording the parent sees.
  final String headline;

  /// Optional secondary line under [headline]. e.g.
  /// `"Datang 06:54 · Pulang 14:30"` or `"Surat dokter terlampir"`.
  final String? secondary;

  /// Tap handler — typically navigates to the day's detail. When null,
  /// the row stays non-clickable (used in calendar selected-day panel).
  final VoidCallback? onTap;

  const AttendanceDayCard({
    super.key,
    required this.date,
    required this.status,
    required this.headline,
    this.secondary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = statusPalette(status);
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date badge
          Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _idShortWeekday[date.weekday],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.0,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Headline + secondary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                  palette.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
