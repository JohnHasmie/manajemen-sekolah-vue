/**
 * tenantTokens.ts — SINGLE SOURCE OF TRUTH for the sekolah↔bimbel
 * vocabulary on the WEB (Vue) app.
 *
 * The product serves two tenant types that rename the SAME underlying
 * concepts:
 *
 *   - sekolah (regular school)      → siswa, guru, kelas, absensi, wali murid
 *   - bimbel  (tutoring center)     → peserta, tutor, kelompok belajar, absensi sesi, wali peserta
 *
 * Before this file the vocabulary was scattered across components as
 * `tenant_type === 'bimbel' ? 'peserta' : 'siswa'` style ternaries. This
 * module collapses those into ONE typed concept→{sekolah,bimbel} map plus
 * a `tenantLabel(concept, tenantType)` resolver, so the wording lives in
 * exactly one place.
 *
 * THINK: Laravel's `resources/lang/{sekolah,bimbel}.php` — the same key
 * ('student', 'teacher') resolves to different display words depending on
 * which "locale" (tenant type) is active. Here the "locale" is the tenant
 * type, not the UI language (id/en) — the i18n language axis is a
 * separate concern handled by vue-i18n / `src/lib/i18n.ts`.
 *
 * The Flutter sibling `lib/core/constants/tenant_tokens.dart` mirrors this
 * concept list — keep the two in sync. See `TENANT_TOKENS.md` for the
 * canonical concept list documented once for both platforms.
 *
 * HARD RULE: this is a CONSOLIDATION, not a rewording. Every string here
 * is EXACTLY what the UI showed before — the definitions just moved.
 */

import { normalizeTenantType } from '@/lib/labels';

/**
 * Tenant-type axis used by the subscribe surface. Kept as the Indonesian
 * `'sekolah' | 'bimbel'` form (mirrors `TenantType` in
 * `@/types/subscription-billing`) because that is what every existing
 * consumer of the vocabulary already passes. Reads are normalised
 * defensively (see `resolveTenantType`) so a caller can also hand us the
 * canonical English wire value or a raw backend string.
 */
export type TenantVocabType = 'sekolah' | 'bimbel';

/**
 * The canonical concept keys — the SAME list is mirrored in the Flutter
 * `TenantConcept` enum. Each concept renames one underlying domain object.
 *
 *   student   → siswa (sekolah)        / peserta (bimbel)
 *   teacher   → guru (sekolah)         / tutor (bimbel)
 *   schoolClass → kelas (sekolah)      / kelompok belajar (bimbel)
 *   attendance → absensi (sekolah)     / absensi sesi (bimbel)
 *   guardian  → wali murid (sekolah)   / wali peserta (bimbel)
 *   tenantType → Sekolah (sekolah)     / Bimbel (bimbel)
 */
export type TenantConcept =
  | 'student'
  | 'teacher'
  | 'schoolClass'
  | 'attendance'
  | 'guardian'
  | 'tenantType';

/** A concept's display word for each tenant type. */
export interface TenantLabelPair {
  sekolah: string;
  bimbel: string;
}

/**
 * THE source-of-truth map. concept → { sekolah, bimbel } display word.
 *
 * These are the exact strings the redesigned subscribe surface renders
 * today. Where a component had a longer variant of the same concept
 * (e.g. 'guru / staf', 'tutor / staf', 'Sekolah formal') those live in
 * `TENANT_LABEL_VARIANTS` below so the base concept word stays clean and
 * reusable while still being centrally defined.
 */
export const TENANT_LABELS: Record<TenantConcept, TenantLabelPair> = Object.freeze(
  {
    student: { sekolah: 'siswa', bimbel: 'peserta' },
    teacher: { sekolah: 'guru', bimbel: 'tutor' },
    schoolClass: { sekolah: 'kelas', bimbel: 'kelompok belajar' },
    attendance: { sekolah: 'absensi', bimbel: 'absensi sesi' },
    guardian: { sekolah: 'wali murid', bimbel: 'wali peserta' },
    tenantType: { sekolah: 'Sekolah', bimbel: 'Bimbel' },
  },
);

/**
 * Longer/decorated variants of a base concept that specific surfaces
 * render verbatim. Centralised here (rather than re-inlined) so the exact
 * copy still lives in one file, without polluting the base concept map.
 *
 * Each entry preserves an EXISTING on-screen string 1:1.
 */
export const TENANT_LABEL_VARIANTS = Object.freeze({
  /** "guru / staf" vs "tutor / staf" — the capacity-step staff field. */
  teacherStaff: { sekolah: 'guru / staf', bimbel: 'tutor / staf' } satisfies TenantLabelPair,
  /** "guru/staf" vs "tutor" — the tenant strip / picker seat caption. */
  teacherSeatCaption: { sekolah: 'guru/staf', bimbel: 'tutor' } satisfies TenantLabelPair,
  /** "Sekolah formal" vs "Bimbel / kursus" — the ManageModules hero kicker. */
  tenantTypeFormal: { sekolah: 'Sekolah formal', bimbel: 'Bimbel / kursus' } satisfies TenantLabelPair,
  /** "Sekolah Anda" vs "Bimbel Anda" — the wizard default tenant name. */
  tenantSelfName: { sekolah: 'Sekolah Anda', bimbel: 'Bimbel Anda' } satisfies TenantLabelPair,
  /** lower-case tenant word in the "Berapa besar {…} Anda?" question. */
  tenantTypeLower: { sekolah: 'sekolah', bimbel: 'bimbel' } satisfies TenantLabelPair,
  /** Official-document list in the wizard's lembaga step. */
  documentTypes: {
    sekolah: 'raport, sertifikat',
    bimbel: 'laporan progres, sertifikat',
  } satisfies TenantLabelPair,
});

export type TenantLabelVariant = keyof typeof TENANT_LABEL_VARIANTS;

/**
 * Coerce whatever tenant-type value a caller has into the
 * `'sekolah' | 'bimbel'` axis this module keys on. Anything that isn't a
 * tutoring center resolves to `'sekolah'` — this matches the pre-existing
 * ternaries, which all treated "not bimbel" as the sekolah branch.
 *
 * Accepts the Indonesian form (`sekolah`/`bimbel`), the canonical English
 * wire form (`school`/`tutoring`), and the uppercase enum
 * (`SCHOOL`/`TUTORING_CENTER`) via `normalizeTenantType` from labels.ts.
 */
export function resolveTenantType(
  raw: TenantVocabType | string | null | undefined,
): TenantVocabType {
  return normalizeTenantType(raw) === 'tutoring' ? 'bimbel' : 'sekolah';
}

/**
 * Resolve a concept's display word for the given tenant type.
 *
 *   tenantLabel('student', 'bimbel')  // 'peserta'
 *   tenantLabel('student', 'sekolah') // 'siswa'
 *   tenantLabel('teacher', null)      // 'guru'  (null → sekolah)
 */
export function tenantLabel(
  concept: TenantConcept,
  tenantType: TenantVocabType | string | null | undefined,
): string {
  return TENANT_LABELS[concept][resolveTenantType(tenantType)];
}

/**
 * Resolve a decorated variant (`TENANT_LABEL_VARIANTS`) for a tenant type.
 * Same resolver, keyed on the variant table.
 *
 *   tenantVariantLabel('teacherStaff', 'bimbel') // 'tutor / staf'
 */
export function tenantVariantLabel(
  variant: TenantLabelVariant,
  tenantType: TenantVocabType | string | null | undefined,
): string {
  return TENANT_LABEL_VARIANTS[variant][resolveTenantType(tenantType)];
}
