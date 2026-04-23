// Academic year helpers used across the app.
//
// The Indonesian school year starts in July. A calendar month >= 7 means
// the current academic year is `thisYear/nextYear`; earlier in the year
// it is `prevYear/thisYear`. Shared utilities here keep every form,
// filter, and chip picker that shows "Tahun Ajaran" agreeing on the
// same rule — mirroring [AcademicYearProvider.fetchAcademicYears] which
// uses the same July-split when nothing is cached from the backend.

/// Returns the current academic year string (e.g. `2025/2026`), based on
/// the July-split convention used across the app.
///
/// Pass [now] to override the reference date (for tests).
String currentAcademicYearString({DateTime? now}) {
  final date = now ?? DateTime.now();
  final year = date.year;
  if (date.month >= 7) {
    return '$year/${year + 1}';
  }
  return '${year - 1}/$year';
}

/// Returns a compact list of academic-year strings centred on the
/// current year — typically one year in the past and two in the future,
/// e.g. `['2024/2025', '2025/2026', '2026/2027', '2027/2028']`.
///
/// The current academic year (as computed by
/// [currentAcademicYearString]) is always included. Use [past] / [future]
/// to widen or narrow the window for a given form.
List<String> academicYearChipOptions({
  int past = 1,
  int future = 2,
  DateTime? now,
}) {
  final current = currentAcademicYearString(now: now);
  // Derive the "start year" of current from the prefix (e.g. 2025 from
  // '2025/2026') rather than from DateTime, so the list always stays
  // aligned with whatever [currentAcademicYearString] returned.
  final startYear = int.parse(current.split('/').first);
  final years = <String>[];
  for (var offset = -past; offset <= future; offset++) {
    final y = startYear + offset;
    years.add('$y/${y + 1}');
  }
  return years;
}
