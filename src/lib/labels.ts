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

/* ──────────────────────────────────────────────────────────────────
 * Tenant type — wire value is canonical English (`school`/`tutoring`)
 * after the 2026-06-26 English-enum cutover. Backend ships a compat
 * shim that still ACCEPTS the legacy `sekolah`/`bimbel` so older
 * client builds keep working; reads should tolerate either.
 * ────────────────────────────────────────────────────────────────── */

/** Canonical wire value sent to the backend for the demo-wizard tenant choice. */
export type TenantTypeWire = 'school' | 'tutoring';

/**
 * Normalise any tenant_type value (server response, persisted payload,
 * UI button) to the canonical English wire form, or null if it doesn't
 * match a known value.
 *
 * Accepts:
 *   - `school` / `tutoring`              (canonical English)
 *   - `sekolah` / `bimbel`               (legacy Indonesian — pre-cutover)
 *   - `SCHOOL` / `TUTORING_CENTER`       (uppercase form used on the
 *                                          users/schools `tenant_type`)
 */
export function normalizeTenantType(
  raw: string | null | undefined,
): TenantTypeWire | null {
  if (!raw) return null;
  const v = String(raw).trim().toLowerCase();
  if (v === 'school' || v === 'sekolah') return 'school';
  if (v === 'tutoring' || v === 'bimbel' || v === 'tutoring_center') {
    return 'tutoring';
  }
  return null;
}

/* ──────────────────────────────────────────────────────────────────
 * Education level — wire value is canonical English
 * (`ELEMENTARY` / `JUNIOR_HIGH` / `SENIOR_HIGH` / `VOCATIONAL_HIGH`)
 * after the 2026-06-26 cutover for the four "common" school jenjang
 * (SD/SMP/SMA/SMK). Other jenjang (MI/MTs/MA/TK/PAUD/Pesantren) keep
 * their Indonesian abbreviation as-is on the wire.
 *
 * The UI still renders the Indonesian abbreviation everywhere — use
 * `educationLevelDisplay()` at the display boundary.
 * ────────────────────────────────────────────────────────────────── */

/** Canonical Indonesian display label (what the UI shows to users). */
export type EducationLevelDisplay =
  | 'SD' | 'MI' | 'SMP' | 'MTs' | 'SMA' | 'MA' | 'SMK'
  | 'TK' | 'PAUD' | 'Pesantren';

/**
 * Canonical wire value sent to the backend. The four mainline jenjang
 * are now English; everything else stays as its Indonesian abbreviation
 * (no canonical English value exists for MI / MTs / MA / TK / PAUD /
 * Pesantren).
 */
export type EducationLevelWire =
  | 'ELEMENTARY'         // SD
  | 'JUNIOR_HIGH'        // SMP
  | 'SENIOR_HIGH'        // SMA
  | 'VOCATIONAL_HIGH'    // SMK
  | EducationLevelDisplay;

/**
 * Normalise any education_level value (server response, persisted
 * payload, UI option) into the canonical wire form. Accepts both old
 * Indonesian values (SD/SMP/SMA/SMK) and the new English equivalents
 * so a deploy ordering where backend hasn't switched is still safe.
 */
export function normalizeEducationLevel(
  raw: string | null | undefined,
): EducationLevelWire | null {
  if (!raw) return null;
  const v = String(raw).trim();
  const upper = v.toUpperCase();
  // Mainline four: accept both old + new forms, return canonical English.
  if (upper === 'SD' || upper === 'ELEMENTARY') return 'ELEMENTARY';
  if (upper === 'SMP' || upper === 'JUNIOR_HIGH') return 'JUNIOR_HIGH';
  if (upper === 'SMA' || upper === 'SENIOR_HIGH') return 'SENIOR_HIGH';
  if (upper === 'SMK' || upper === 'VOCATIONAL_HIGH') return 'VOCATIONAL_HIGH';
  // Pass-through for the remaining Indonesian-only jenjang — canonical
  // values stay as their original abbreviations. Match case-insensitively
  // but return the project-canonical casing.
  switch (upper) {
    case 'MI': return 'MI';
    case 'MTS': return 'MTs';
    case 'MA': return 'MA';
    case 'TK': return 'TK';
    case 'PAUD': return 'PAUD';
    case 'PESANTREN': return 'Pesantren';
  }
  return null;
}

/**
 * Display label for an education_level wire value. Preserves the
 * Indonesian UX everywhere a jenjang chip is rendered, regardless of
 * whether the backend has switched to English wire values yet.
 *
 *   educationLevelDisplay('ELEMENTARY')      // 'SD'
 *   educationLevelDisplay('SMA')             // 'SMA' (legacy pass-through)
 *   educationLevelDisplay('Pesantren')       // 'Pesantren'
 *   educationLevelDisplay(null)              // '' (or `fallback`)
 */
export function educationLevelDisplay(
  raw: string | null | undefined,
  fallback = '',
): EducationLevelDisplay | '' | string {
  const slug = normalizeEducationLevel(raw);
  if (!slug) return raw && String(raw).trim() ? String(raw) : fallback;
  if (slug === 'ELEMENTARY') return 'SD';
  if (slug === 'JUNIOR_HIGH') return 'SMP';
  if (slug === 'SENIOR_HIGH') return 'SMA';
  if (slug === 'VOCATIONAL_HIGH') return 'SMK';
  return slug;
}
