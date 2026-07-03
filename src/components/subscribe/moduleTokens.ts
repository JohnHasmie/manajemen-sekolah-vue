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

/** Short marketing tagline shown under each module. */
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

/** Human-readable Indonesian labels for the pricing seat unit. */
export function seatUnit(item: ModuleCatalogItem): '/ siswa' | '/ guru' {
  return item.pricing_seat === 'staff' ? '/ guru' : '/ siswa';
}

/** Format an IDR integer as "Rp 1.234.000". */
export function money(n: number): string {
  const clamped = Math.max(0, Math.round(n));
  return 'Rp ' + new Intl.NumberFormat('id-ID').format(clamped);
}
