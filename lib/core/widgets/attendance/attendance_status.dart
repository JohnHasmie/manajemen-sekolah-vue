// Shared attendance status vocabulary + color tokens.
//
// Used by the three attendance widgets (`AttendanceRingKpi`,
// `AttendanceDayCard`, `AttendanceCalendarGrid`) so every status pill,
// avatar tint, and calendar cell agrees on:
//
//   present  → emerald (green-50 fill / green-600 dot / green-700 text)
//   late     → amber  (amber-50 fill / amber-500 dot / amber-700 text)
//   excused  → cyan   (sky-50 fill / cyan-600 dot / cyan-700 text)
//   sick     → amber  (sick borrows the amber ramp — visually distinct
//                       from late by content placement, not color)
//   alpha    → red    (red-50 fill / red-500 dot / red-800 text)
//
// Status names match the backend `student_daily_attendances.status`
// values (see `Parent_Phase3_Kehadiran_Backend_Spec.md`). Keep the
// enum cases stable — if the backend adds a new status (e.g.
// `pending`), extend the enum and add a case to [statusPalette].
import 'package:flutter/material.dart';

/// Day-level attendance status. Drives chip color and icon throughout
/// the parent attendance flows.
enum AttendanceStatus {
  /// Hadir — child attended for the full day.
  present,

  /// Hadir, terlambat — attended but late beyond the school's
  /// configured threshold.
  late,

  /// Izin — formally excused with a permission letter.
  excused,

  /// Sakit — absent due to illness, with a doctor's note.
  sick,

  /// Alpha — absent without notice.
  alpha,

  /// Future / weekend / outside the academic calendar — rendered
  /// neutral grey in the calendar grid.
  none,
}

/// Returns the canonical color palette for a given attendance status.
/// All consumers should pull from here; never hardcode the hexes.
AttendanceStatusPalette statusPalette(AttendanceStatus status) {
  switch (status) {
    case AttendanceStatus.present:
      return const AttendanceStatusPalette(
        bg: Color(0xFFDCFCE7), // green-100
        dot: Color(0xFF16A34A), // green-600
        text: Color(0xFF15803D), // green-700
        label: 'Hadir',
      );
    case AttendanceStatus.late:
      return const AttendanceStatusPalette(
        bg: Color(0xFFFEF3C7), // amber-100
        dot: Color(0xFFF59E0B), // amber-500
        text: Color(0xFFB45309), // amber-700
        label: 'Terlambat',
      );
    case AttendanceStatus.excused:
      return const AttendanceStatusPalette(
        bg: Color(0xFFE0F2FE), // sky-100
        dot: Color(0xFF0891B2), // cyan-600
        text: Color(0xFF0E7490), // cyan-700
        label: 'Izin',
      );
    case AttendanceStatus.sick:
      return const AttendanceStatusPalette(
        bg: Color(0xFFFEF3C7), // amber-100
        dot: Color(0xFFF59E0B), // amber-500
        text: Color(0xFFB45309), // amber-700
        label: 'Sakit',
      );
    case AttendanceStatus.alpha:
      return const AttendanceStatusPalette(
        bg: Color(0xFFFEE2E2), // red-100
        dot: Color(0xFFEF4444), // red-500
        text: Color(0xFF991B1B), // red-800
        label: 'Alpha',
      );
    case AttendanceStatus.none:
      return const AttendanceStatusPalette(
        bg: Color(0xFFF1F5F9), // slate-100
        dot: Color(0xFFCBD5E1), // slate-300
        text: Color(0xFF64748B), // slate-500
        label: '',
      );
  }
}

/// Color tokens for one attendance status.
class AttendanceStatusPalette {
  /// Light fill used for status pills, day-badge backgrounds, and
  /// calendar cells.
  final Color bg;

  /// Mid-strength dot used inside pills and as the legend marker.
  final Color dot;

  /// Strong text color readable on [bg] (always >= 4.5:1 contrast for
  /// AA — pulled from the Tailwind 700-800 stops).
  final Color text;

  /// Indonesian display label.
  final String label;

  const AttendanceStatusPalette({
    required this.bg,
    required this.dot,
    required this.text,
    required this.label,
  });
}

/// Map a backend status string (`'present'`, `'hadir'`, `'late'`,
/// `'terlambat'`, `'excused'`, `'izin'`, `'sick'`, `'sakit'`, `'alpha'`,
/// `'absent'`) to the typed enum. Returns [AttendanceStatus.none] for
/// anything unrecognised so the calendar grid falls back to grey.
AttendanceStatus parseAttendanceStatus(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'present':
    case 'hadir':
      return AttendanceStatus.present;
    case 'late':
    case 'terlambat':
      return AttendanceStatus.late;
    case 'excused':
    case 'izin':
      return AttendanceStatus.excused;
    case 'sick':
    case 'sakit':
      return AttendanceStatus.sick;
    case 'alpha':
    case 'absent':
      return AttendanceStatus.alpha;
    default:
      return AttendanceStatus.none;
  }
}
