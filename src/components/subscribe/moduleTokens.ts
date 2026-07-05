/**
 * moduleTokens.ts — design tokens shared across the redesigned
 * subscribe surface (SubscribeView + SubscribeNewWizardView + their
 * component tree). Kept here so the palette + icon mapping stay in
 * sync when we retune the mockup-approved system.
 */

import type { ModuleCatalogItem } from '@/types/subscription-billing';
import { tenantLabel } from '@/lib/tenantTokens';

/** Category-level tints — bg + fg for the small module-icon chips. */
export const CATEGORY_TINTS: Record<string, { bg: string; fg: string }> = {
  Absensi: { bg: '#FEF3C7', fg: '#B45309' },
  Akademik: { bg: '#EFEEFD', fg: '#534AB7' },
  Guru: { bg: '#E1F5EE', fg: '#0F6E56' },
  Keuangan: { bg: '#FAECE7', fg: '#993C1D' },
  Komunikasi: { bg: '#E6F1FB', fg: '#185FA5' },
  Bimbel: { bg: '#EAF3DE', fg: '#27500A' },
  AI: { bg: '#FBEAF0', fg: '#993556' },
  Default: { bg: '#F5F8FC', fg: '#64748B' },
};

/** Per-module Tabler icon name (no `ti-` prefix). */
export const MODULE_ICONS: Record<string, string> = {
  // Legacy — grandfathered rows may still surface in ManageModulesView
  // during the migration window. Falls back to `user-check` so nothing
  // renders iconless.
  attendance_student: 'user-check',
  // Split (Jul 2026): `attendance_class` = teacher marks per-session
  // presence in classroom, `attendance_gate` = student self-scans at
  // school entrance.
  attendance_class: 'clipboard-check',
  attendance_gate: 'door-enter',
  attendance_staff: 'id-badge-2',
  grades: 'list-numbers',
  report_cards: 'report',
  class_activity: 'pencil-plus',
  schedule: 'calendar-time',
  lms: 'book-2',
  finance: 'receipt',
  communication: 'speakerphone',
  tutoring: 'books',
  ai_recommendation: 'bulb',
  ai_material_quiz: 'sparkles',
  ai_rpp: 'file-text',
};

/** Short marketing tagline shown under each module (default = sekolah). */
export const MODULE_TAGLINES: Record<string, string> = {
  attendance_student: 'Presensi harian, ekspor, QR pintu masuk.',
  attendance_class:
    'Guru tandai hadir/absen/izin per jam pelajaran, ekspor rekap.',
  attendance_gate:
    'Siswa scan QR di gerbang, log harian masuk-pulang, ekspor.',
  attendance_staff: 'Self check-in, QR gate, kartu personel PDF.',
  grades: 'Input nilai per KD, rekap, ekspor Excel.',
  report_cards: 'Cetak raport, sertifikat, transkrip PDF.',
  class_activity: 'Tugas, pengumpulan, penilaian.',
  schedule: 'Jadwal pelajaran, cek bentrok otomatis.',
  lms: 'RPP dan materi ajar terpusat.',
  finance: 'Tagihan SPP, pelunasan, bukti bayar.',
  communication: 'Pengumuman, push notif ke wali.',
  tutoring: 'Sesi, kelompok, tutor, tagihan, payout — semua dalam satu modul.',
  ai_recommendation:
    'Rekomendasi belajar siswa · 20 generate / guru / bln, bisa dinaikkan.',
  ai_material_quiz:
    'Generate materi + quiz + referensi · 20 generate / guru / bln.',
  ai_rpp:
    'Rencana pembelajaran otomatis · 15 RPP / guru / bln, bisa dinaikkan.',
};

/**
 * Module keys that ONLY work for sekolah tenants — their backend
 * endpoints don't route bimbel traffic. A bimbel admin buying any of
 * these would pay for a module that gates nothing they can use:
 *
 *   - attendance_class            → bimbel uses `tutoring.session.mark_attendance`
 *                                   for per-session peserta presence
 *   - attendance_student (legacy) → same reasoning; grandfathered rows only
 *   - attendance_staff            → bimbel uses `tutoring.session.mark_attendance` for tutor
 *   - grades / report_cards       → bimbel has no grade entry / raport
 *   - class_activity              → bimbel has `tutoring.activity.*`
 *   - schedule                    → bimbel schedules via `tutoring.session.*`
 *   - lms                         → bimbel materials are flat under `tutoring.material.*`
 *   - finance                     → bimbel bills via `tutoring.bill.*`
 *   - communication               → bimbel announces via `tutoring.group_announcement.*`
 *   - ai_recommendation / _material_quiz / _rpp
 *                                 → all three reference sekolah-only
 *                                   concepts (RPP kurikulum, KD, semester,
 *                                   chapter). Zero bimbel checks in the
 *                                   kamiledu-ai service.
 *
 * NB: `attendance_gate` is deliberately NOT in this list — bimbel
 * centers with a physical location use QR gate check-in for peserta
 * arrivals, and `bundle_tutoring` includes it by design.
 *
 * The FE hides these from the bimbel wizard + Kelola Modul add list.
 * Existing entitlements are not touched — a bimbel tenant that
 * somehow already bought one of these keeps their row (backwards
 * compat), it just won't be re-offered.
 */
export const SEKOLAH_ONLY_MODULE_KEYS: readonly string[] = Object.freeze([
  'attendance_student',
  'attendance_class',
  'attendance_staff',
  'grades',
  'report_cards',
  'class_activity',
  'schedule',
  'lms',
  'finance',
  'communication',
  'ai_recommendation',
  'ai_material_quiz',
  'ai_rpp',
]);

/**
 * True if `key` should be HIDDEN from the picker for the given tenant type.
 * Combines the earlier bimbel-only Group filter with the new sekolah-only
 * filter so callers get one predicate to answer "should I render this row".
 */
export function isModuleHiddenFor(
  key: string,
  group: string | undefined,
  tenantType: 'sekolah' | 'bimbel' | null | undefined,
): boolean {
  // Fail-CLOSED for bimbel-only modules — when the caller couldn't
  // resolve the tenant type (async race, tenants API errored to []),
  // still hide the bimbel-native groups so tutoring doesn't leak into
  // a sekolah admin's "Tambah modul" list. The reverse (sekolah-only
  // modules leaking into bimbel) stays permissive because the sekolah
  // list is broad and losing a legitimate bimbel-relevant module would
  // be worse than showing an extra picker card.
  if (group === 'Operasional Bimbel' || group === 'Bimbel') {
    return tenantType !== 'bimbel';
  }
  if (tenantType === 'bimbel') {
    return SEKOLAH_ONLY_MODULE_KEYS.includes(key);
  }
  return false;
}

/**
 * Bimbel-specific label + tagline overrides.
 *
 * We KEEP entries for the sekolah-only keys even though the picker
 * hides them, because a legacy bimbel entitlement (grandfathered from
 * before the SEKOLAH_ONLY_MODULE_KEYS filter shipped) can still surface
 * in ManageModulesView's "Aktif" list. When that happens we want the
 * row to read in peserta/tutor vocabulary, not siswa/guru — the label
 * lookup runs regardless of the picker filter.
 *
 * Additive-only for `tutoring` and any future bimbel-native modules:
 * their sekolah override is a no-op because they're bimbel-native to
 * begin with.
 */
export const BIMBEL_LABEL_OVERRIDES: Record<string, { label?: string; tagline?: string }> = {
  // Bimbel-native — clarify what the umbrella covers.
  tutoring: {
    label: 'Manajemen Sesi & Peserta',
    tagline: 'Sesi, kelompok, tutor, tagihan, payout — semua dalam satu modul bimbel.',
  },
  // The rest are sekolah-only in current architecture (hidden by
  // isModuleHiddenFor). Kept here so legacy entitlements render in
  // bimbel vocabulary if they somehow persist.
  attendance_student: {
    label: 'Absensi Peserta',
    tagline: 'Presensi per sesi, ekspor, QR pintu masuk.',
  },
  // The two split children. `attendance_class` is a sekolah-only
  // concept for bimbel (session-based presence lives in tutoring)
  // but the override is kept for grandfathered rows to at least
  // read in peserta vocabulary. `attendance_gate` is bimbel-friendly.
  attendance_class: {
    label: 'Presensi Sesi',
    tagline: 'Tutor tandai hadir/absen/izin per sesi, ekspor rekap.',
  },
  attendance_gate: {
    // Was 'Absensi Kehadiran Peserta' — "Absensi Kehadiran" doubles the
    // attendance word. Per TERMINOLOGY.md this is bimbel gate presence,
    // so it reads as "Absensi Gerbang" (entry-gate attendance).
    label: 'Absensi Gerbang Peserta',
    tagline: 'Peserta scan QR di pintu masuk, log kehadiran harian.',
  },
  attendance_staff: {
    label: 'Absensi Tutor & Staf',
    tagline: 'Self check-in tutor, QR gate, kartu personel PDF.',
  },
  grades: {
    label: 'Nilai Peserta',
    tagline: 'Input nilai per topik, rekap, ekspor Excel.',
  },
  report_cards: {
    label: 'Laporan Progres',
    tagline: 'Cetak laporan progres + sertifikat kelulusan.',
  },
  class_activity: {
    label: 'Tugas & Latihan',
    tagline: 'Tugas per sesi, pengumpulan, penilaian.',
  },
  schedule: {
    label: 'Jadwal Sesi',
    tagline: 'Jadwal sesi bimbel, cek bentrok otomatis.',
  },
  lms: {
    label: 'Materi Ajar Tutor',
    tagline: 'Silabus dan materi tutor terpusat.',
  },
  finance: {
    label: 'Pembayaran Kursus',
    tagline: 'Tagihan biaya kursus, pelunasan, bukti bayar.',
  },
  communication: {
    label: 'Pengumuman & Notifikasi',
    tagline: 'Pengumuman, push notif ke wali peserta.',
  },
  ai_recommendation: {
    tagline: 'Rekomendasi belajar peserta · 20 generate / tutor / bln, bisa dinaikkan.',
  },
  ai_material_quiz: {
    tagline: 'Generate materi + quiz + referensi · 20 generate / tutor / bln.',
  },
  ai_rpp: {
    label: 'AI Rencana Sesi',
    tagline: 'Rencana sesi otomatis · 15 rencana / tutor / bln, bisa dinaikkan.',
  },
};

/**
 * Resolve the display label for a module, honouring the tenant's type.
 * Falls back to the catalog-provided label (which is what we send from
 * the backend, matching the sekolah copy).
 */
export function moduleLabel(
  item: ModuleCatalogItem,
  tenantType: 'sekolah' | 'bimbel' | null | undefined,
): string {
  if (tenantType === 'bimbel') {
    return BIMBEL_LABEL_OVERRIDES[item.key]?.label ?? item.label;
  }
  return item.label;
}

/**
 * Resolve the tagline for a module, honouring the tenant's type.
 * Falls back to the sekolah-oriented default in MODULE_TAGLINES, then
 * to the module label if nothing better exists.
 */
export function moduleTagline(
  item: ModuleCatalogItem,
  tenantType: 'sekolah' | 'bimbel' | null | undefined,
): string {
  if (tenantType === 'bimbel') {
    const override = BIMBEL_LABEL_OVERRIDES[item.key]?.tagline;
    if (override) return override;
  }
  return MODULE_TAGLINES[item.key] ?? item.label;
}

/** Ordering used to lay out categories in the wizard grid. */
export const GROUP_ORDER = [
  'Absensi',
  'Akademik',
  'Guru',
  'Keuangan',
  'Komunikasi',
  'Bimbel',
  'AI',
];

/**
 * Human-readable Indonesian label for the pricing seat unit.
 * Bimbel tenants swap siswa/guru for peserta/tutor everywhere so the
 * calculator + module cards line up with the copy in the rest of the UI.
 */
export function seatUnit(
  item: ModuleCatalogItem,
  tenantType?: 'sekolah' | 'bimbel' | null,
): string {
  // Seat words come from the shared TenantTokens source of truth so the
  // calculator's "/ siswa" ↔ "/ peserta" and "/ guru" ↔ "/ tutor" stay
  // in lockstep with the rest of the UI. Same exact strings as before —
  // just centrally defined now.
  const concept = item.pricing_seat === 'staff' ? 'teacher' : 'student';
  return `/ ${tenantLabel(concept, tenantType)}`;
}

/** Format an IDR integer as "Rp 1.234.000". */
export function money(n: number): string {
  const clamped = Math.max(0, Math.round(n));
  return 'Rp ' + new Intl.NumberFormat('id-ID').format(clamped);
}
