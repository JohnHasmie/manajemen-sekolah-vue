/**
 * Shared display-label helpers for backend enum values.
 *
 * Backend stores semester `name` as canonical English (`odd` / `even`)
 * after the 2026_06_02 normalisation migration. The Indonesian UI still
 * shows "Ganjil" / "Genap" — convert at the display boundary.
 *
 * Defensive: also accept legacy `Ganjil` / `Gasal` / `Genap` values in
 * case a row predates the migration or a fallback API path hasn't been
 * touched yet.
 */

/** Canonical semester `name` slug returned by the backend. */
export type SemesterNameSlug = 'odd' | 'even';

/**
 * Normalise any stored semester-name value into the canonical English
 * slug (`odd` / `even`) or `null` if it doesn't match a known label.
 *
 * Accepts: `odd` / `even` (canonical), `Ganjil` / `Gasal` (legacy odd),
 * `Genap` (legacy even), case-insensitive.
 */
export function normalizeSemesterName(
  raw: string | null | undefined,
): SemesterNameSlug | null {
  if (!raw) return null;
  const v = String(raw).trim().toLowerCase();
  if (v === 'odd' || v === 'ganjil' || v === 'gasal') return 'odd';
  if (v === 'even' || v === 'genap') return 'even';
  return null;
}

/**
 * Indonesian display label for a semester `name` value.
 *
 *   semesterLabel('odd')    // 'Ganjil'
 *   semesterLabel('even')   // 'Genap'
 *   semesterLabel('Ganjil') // 'Ganjil' (legacy passthrough)
 *   semesterLabel(null)     // '' — caller usually wants an empty string
 *
 * Pass `fallback` to override the empty-string default for null/unknown.
 */
export function semesterLabel(
  raw: string | null | undefined,
  fallback = '',
): string {
  const slug = normalizeSemesterName(raw);
  if (slug === 'odd') return 'Ganjil';
  if (slug === 'even') return 'Genap';
  // Unknown value — return the raw string so seeded free-text like
  // "Semester Tambahan" still renders, instead of swallowing it.
  return raw && raw.trim() ? raw : fallback;
}

/**
 * "Sem. Ganjil" / "Sem. Genap" short-form — used in chips and headers.
 */
export function semesterShortLabel(
  raw: string | null | undefined,
  fallback = '',
): string {
  const slug = normalizeSemesterName(raw);
  if (slug === 'odd') return 'Sem. Ganjil';
  if (slug === 'even') return 'Sem. Genap';
  return raw && raw.trim() ? `Sem. ${raw}` : fallback;
}
