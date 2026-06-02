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

// ─── Semester label helpers ────────────────────────────────────────────
//
// Backend follow-up migration (2026-06-02) normalized `semesters.name`
// stored values from Indonesian (`Ganjil` / `Gasal` / `Genap`) to
// canonical English (`odd` / `even`). The UI keeps Indonesian display
// labels for users; these helpers bridge the two.
//
// Note: `academic_years.semester` (a *separate* column) still uses the
// legacy `ganjil` / `genap` values per backend convention — those call
// sites are unaffected.
// ───────────────────────────────────────────────────────────────────────

/// Maps any of the known semester encodings (`odd`, `even`, `ganjil`,
/// `gasal`, `genap`, or their Title-case variants) to the Indonesian
/// display label used across the UI (`Ganjil` / `Genap`).
///
/// Returns null when [raw] is null/empty or doesn't match a known
/// encoding — callers decide how to render the absence ("-", a fallback
/// chip, etc.).
String? semesterDisplayLabel(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toLowerCase();
  if (s.isEmpty) return null;
  switch (s) {
    case 'odd':
    case 'ganjil':
    case 'gasal':
      return 'Ganjil';
    case 'even':
    case 'genap':
      return 'Genap';
    default:
      return null;
  }
}

/// Maps any of the known semester encodings (Indonesian or canonical)
/// to the backend canonical value (`odd` / `even`) used by the
/// `semesters.name` column. Defaults to lowercased [raw] when nothing
/// matches so the value still round-trips for unknown future values.
String canonicalSemesterName(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'ganjil':
    case 'gasal':
    case 'odd':
      return 'odd';
    case 'genap':
    case 'even':
      return 'even';
    default:
      return raw.trim().toLowerCase();
  }
}
