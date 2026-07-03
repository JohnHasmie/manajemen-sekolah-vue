/**
 * moduleTokens.ts — design tokens shared across the redesigned
 * subscribe surface (SubscribeView + SubscribeNewWizardView + their
 * component tree). Kept here so the palette + icon mapping stay in
 * sync when we retune the mockup-approved system.
 */

import type { ModuleCatalogItem } from '@/types/subscription-billing';

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
  attendance_student: 'user-check',
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
  attendance_staff: 'Self check-in, QR gate, kartu personel PDF.',
  grades: 'Input nilai per KD, rekap, ekspor Excel.',
  report_cards: 'Cetak raport, sertifikat, transkrip PDF.',
  class_activity: 'Tugas, pengumpulan, penilaian.',
  schedule: 'Jadwal pelajaran, cek bentrok otomatis.',
  lms: 'RPP dan materi ajar terpusat.',
  finance: 'Tagihan SPP, pelunasan, bukti bayar.',
  communication: 'Pengumuman, push notif ke wali.',
  tutoring: 'Enrollment, sesi, pembayaran tutor.',
  ai_recommendation:
    'Rekomendasi belajar siswa · 20 generate / guru / bln, bisa dinaikkan.',
  ai_material_quiz:
    'Generate materi + quiz + referensi · 20 generate / guru / bln.',
  ai_rpp:
    'Rencana pembelajaran otomatis · 15 RPP / guru / bln, bisa dinaikkan.',
};

/**
 * Bimbel-specific label + tagline overrides. Bimbel tenants call
 * siswa → peserta, guru → tutor, raport → laporan progres. The module
 * KEYS stay identical (backend gating stays the same) — only the
 * user-facing strings shift so the wizard reads natural for a
 * tutoring center.
 */
export const BIMBEL_LABEL_OVERRIDES: Record<string, { label?: string; tagline?: string }> = {
  attendance_student: {
    label: 'Absensi Peserta',
    tagline: 'Presensi per sesi, ekspor, QR pintu masuk.',
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
  const isStaff = item.pricing_seat === 'staff';
  if (tenantType === 'bimbel') {
    return isStaff ? '/ tutor' : '/ peserta';
  }
  return isStaff ? '/ guru' : '/ siswa';
}

/** Format an IDR integer as "Rp 1.234.000". */
export function money(n: number): string {
  const clamped = Math.max(0, Math.round(n));
  return 'Rp ' + new Intl.NumberFormat('id-ID').format(clamped);
}
