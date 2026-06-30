/**
 * Register-demo wizard types.
 *
 * Mirrors the Laravel `ProvisionDemoSchoolRequest` shape so the
 * client sends exactly what the backend validates. Pinia keeps the
 * working copy of `DemoWizardPayload` and persists it to
 * localStorage on every step change.
 */

/**
 * Education level for a formal school. The four mainline jenjang
 * (SD/SMP/SMA/SMK) now use canonical English wire values per the
 * 2026-06-26 English-enum cutover; the remaining Indonesian-only
 * jenjang stay as their original abbreviation since no English
 * equivalent exists. Display layer uses `educationLevelDisplay()`
 * from `@/lib/labels` to keep the Indonesian UX intact everywhere.
 *
 * Backend ships a compat shim that accepts EITHER old (SD/SMP/SMA/SMK)
 * or new (ELEMENTARY/JUNIOR_HIGH/SENIOR_HIGH/VOCATIONAL_HIGH) on writes,
 * and may return either on reads — `normalizeEducationLevel()` in
 * `@/lib/labels` is the safe read boundary.
 */
export type EducationLevel =
  | 'ELEMENTARY'         // SD
  | 'MI'
  | 'JUNIOR_HIGH'        // SMP
  | 'MTs'
  | 'SENIOR_HIGH'        // SMA
  | 'MA'
  | 'VOCATIONAL_HIGH'    // SMK
  | 'TK'
  | 'PAUD'
  | 'Pesantren';

export type DemoStepKey =
  | 'welcome'
  | 'school'
  | 'identity'
  | 'subjects'
  | 'teacher'
  | 'class'
  | 'student'
  | 'parent'
  | 'schedule'
  | 'billing'
  | 'scenarios';

/**
 * Wizard step sequence — SCHOOL/demo data only. The REQUESTER identity
 * (Data Diri) used to be the final wizard step (`requester`) followed
 * by a terminal `done` step. Per founder request, identity now lives on
 * a SEPARATE screen (route `/register-demo/identity`) that the user is
 * sent to AFTER submitting the wizard — so someone filling from the
 * start never has to know identity is needed up front. The wizard ends
 * at `scenarios`; its final button hands off to the identity screen,
 * which collects identity, fires the combined submit, and shows the
 * pending/done state.
 */
export const DEMO_STEPS: readonly DemoStepKey[] = [
  'welcome',
  'school',
  'identity',
  'subjects',
  'teacher',
  'class',
  'student',
  'parent',
  'schedule',
  'billing',
  'scenarios',
] as const;

/** Backend role names — what we send and what the server expects. */
export type DemoRole = 'admin' | 'teacher' | 'parent';

export interface DemoSchoolPayload {
  name: string;
  /** Canonical English column: `schools.education_level`. */
  education_level: EducationLevel;
  /** Canonical English column: `schools.city`. */
  city: string | null;
  npsn: string | null;
  academic_year_label: string;
}

export interface DemoIdentityPayload {
  mode: 'all_roles' | 'single_role';
  primary_role: DemoRole;
}

export interface DemoSubjectsPayload {
  /**
   * Final list of mata pelajaran names to seed into `subject_schools`
   * for this demo. Pre-filled by jenjang template; user can untoggle
   * defaults and add custom (mulok / program keahlian / pesantren
   * mapel). Backend also creates matching `subjects` master rows on
   * first use via firstOrCreate.
   */
  names: string[];
}

export interface DemoTeachersPayload {
  count: number;
  fill_mode: 'random' | 'manual';
  manual_list: Array<{ name: string; subject: string | null }>;
}

export interface DemoClassesPayload {
  pattern: 'small' | 'medium' | 'large' | 'custom';
  per_grade: Record<string, number>;
}

export interface DemoStudentsPayload {
  per_class: number;
  fill_mode: 'random' | 'manual' | 'csv';
}

export interface DemoParentsPayload {
  mode: 'auto_link' | 'skip';
}

export interface DemoSchedulePayload {
  mode: 'auto' | 'manual';
  active_days: number[]; // 1..7
  jp_per_day: number;
  start_time: string; // 'HH:mm'
  end_time: string;
}

export type DemoBillingTemplate =
  | 'spp_bulanan'
  | 'uang_gedung'
  | 'seragam'
  | 'buku_paket'
  | 'uts_uas'
  | 'ekstrakurikuler';

export interface DemoBillingPayload {
  mode: 'build_year' | 'skip';
  templates: DemoBillingTemplate[];
  spp_nominal: number;
}

/**
 * Skenario seeding — opt-in toggles for the wizard's last config step.
 * Each enabled key triggers a corresponding seed method on the backend:
 *
 *  - kehadiran        → backfill 5 days of student_class_attendances
 *  - rpp              → seed lesson_plans (mix Approved/Pending/Draft)
 *  - announcement       → seed announcements (global + per-class)
 *  - progress_subbab  → seed chapters/sub_chapters + ~30% marked done
 *  - kegiatan_kelas   → seed class_activities + a few submissions
 *  - bill          → run the billing seed (overrides billing.mode skip)
 *
 * Default-on so a fresh wizard creates a populated demo without extra
 * clicks. Backend re-validates the list and silently ignores unknown
 * keys for forward compat.
 */
export type DemoScenarioKey =
  | 'kehadiran'
  | 'rpp'
  | 'pengumuman'
  | 'progress_subbab'
  | 'kegiatan_kelas'
  | 'tagihan'
  | 'nilai'
  | 'pembayaran'
  | 'pengumuman_event'
  | 'notifikasi'
  | 'rapor_draft'
  | 'submission_late'
  | 'audit_log'
  | 'multi_payment'
  | 'material_files'
  | 'read_statuses'
  | 'konflik_jadwal'
  | 'demo_expiry_short'
  | 'akses_request'
  | 'rapor_full';

export interface DemoScenariosPayload {
  enabled: DemoScenarioKey[];
}

/**
 * Requester social-media handles — collected at the final identity
 * step so the KamilEdu team can identify + reach the person asking
 * for a demo. Every channel is optional individually, but the form
 * (and the backend `withValidator()`) enforce that AT LEAST ONE is
 * non-empty before submit. Empty channels are dropped server-side.
 */
export type DemoSocialChannel =
  | 'facebook'
  | 'threads'
  | 'instagram'
  | 'linkedin'
  | 'other';

export interface DemoSocialMedia {
  facebook?: string;
  threads?: string;
  instagram?: string;
  linkedin?: string;
  other?: string;
}

/**
 * Requester identity — the NEW final-step form. Mirrors the backend
 * `SubmitDemoRequestRequest::identityRules()`:
 *   full_name (3-160), nip (3-60), jabatan (2-120),
 *   whatsapp (6-32, digits / + / - / space), social_media (>=1).
 * Distinct from `DemoIdentityPayload` (which is the wizard's role
 * selection, not the person's identity).
 */
export interface DemoRequesterPayload {
  full_name: string;
  nip: string;
  jabatan: string;
  whatsapp: string;
  social_media: DemoSocialMedia;
}

export interface DemoWizardPayload {
  /**
   * Tenant kind chosen on the conversational wizard's landing screen.
   * The legacy school flow keeps the same school/subjects/… slices;
   * 'tutoring' uses the `tutoring` slice instead. Backend will fork on
   * this flag (formal school vs tutoring center provisioning).
   */
  tenant_type: TenantType;
  school: DemoSchoolPayload;
  identity: DemoIdentityPayload;
  subjects: DemoSubjectsPayload;
  teachers: DemoTeachersPayload;
  classes: DemoClassesPayload;
  students: DemoStudentsPayload;
  parents: DemoParentsPayload;
  schedule: DemoSchedulePayload;
  billing: DemoBillingPayload;
  scenarios: DemoScenariosPayload;
  /**
   * Tutoring center answer slice — used when tenant_type='tutoring'.
   * JSON key renamed from `bimbel` → `tutoring` per the 2026-06-26
   * English-enum cutover; backend's Phase-1 compat shim accepts BOTH
   * `tutoring` (new, preferred) and `bimbel` (legacy) on writes so the
   * web-vue / backend deploys can roll independently.
   */
  tutoring: DemoTutoringPayload;
  /** Requester identity — submitted with the pending demo request. */
  requester: DemoRequesterPayload;
}

/* ─── Tutoring center payload ─── */

/**
 * Which tenant flavour the requester is signing up for. Picked on the
 * tenant-choice landing screen before any wizard question is asked.
 * Canonical English wire values after the 2026-06-26 cutover; backend's
 * Phase-1 compat shim still accepts the legacy `sekolah` / `bimbel`.
 */
export type TenantType = 'school' | 'tutoring';

/**
 * Education level targeted by the tutoring center — distinct from a
 * formal school's jenjang because bimbel often targets SNBT, working
 * professionals, or a general audience.
 *
 * Wire values are canonical English (post 2026-06-26 cutover —
 * `SubmitDemoRequestRequest` validator only accepts these), mirroring
 * the school-path migration in `lib/labels.ts`. Display labels (Indo
 * `SD` / `SMP` / `SMA`) live in [TUTORING_EDUCATION_LEVEL_LABEL].
 * The three tutoring-only options (`SNBT` / `KARYAWAN` / `UMUM`) have
 * no Indo↔English mapping and stay as-is.
 */
export type TutoringEducationLevel =
  | 'ELEMENTARY'    // SD
  | 'JUNIOR_HIGH'   // SMP
  | 'SENIOR_HIGH'   // SMA / SMK
  | 'SNBT'
  | 'KARYAWAN'
  | 'UMUM';

export type TutoringStudentScale = 'lt50' | '50_200' | '200_500' | 'gt500';
export type TutoringTutorScale = '1_3' | '4_10' | '11_30' | 'gt30';

/**
 * Billing modes a tutoring center offers. Mirrors
 * `tutoring_packages.billing_mode` so the backend seeder can seed
 * packages with the matching mode out of the box.
 *
 * Multi-select on the wizard: the lembaga may offer ONE OR MORE
 * modes (per-session for trial classes + per-month for regular
 * cohorts, etc.). The first selected mode is used as the
 * `tenant_billing_settings.default_mode` and each selected mode
 * enables its `allow_*` flag during provisioning.
 */
export type TutoringBillingMode = 'PER_SESSION' | 'PER_MONTH' | 'PACKAGE';

/**
 * Scenario seeding for the tutoring-tenant flow. Each key flips one
 * Phase-aware seeder branch on the backend (sessions + attendance,
 * payouts, bills, vouchers, leads, announcements, etc.).
 *
 * NOTE: The string values (`'sesi_kehadiran'`, `'bill'`, ...) are
 * the wire payload values keyed by the backend; they MUST stay Indo.
 */
export type TutoringScenarioKey =
  | 'sesi_kehadiran'
  | 'honor'
  | 'tagihan'
  | 'voucher'
  | 'leads'
  | 'pengumuman'
  | 'aktivitas'
  | 'rating';

/**
 * Picked location (Nominatim/Leaflet result) for the tutoring center —
 * set when the requester picks a point on the map picker.
 * `has_office=false` means the lat/lng is the operator's current
 * location, not a fixed office (mobile/online-first tutoring) — useful
 * signal for the team during verification.
 */
export interface DemoTutoringLocation {
  lat: number;
  lng: number;
  /** Full address from Nominatim reverse-geocode (best effort). */
  address: string | null;
  /** True when the tutoring center has a fixed office at the picked point. */
  has_office: boolean;
}

export interface DemoTutoringPayload {
  /** Tutoring center / lembaga name (3-160). */
  name: string;
  /** City where the lembaga operates. */
  city: string | null;
  /** Target education levels — minimum 1. */
  target_levels: TutoringEducationLevel[];
  /** Estimated scale of active students. */
  student_scale: TutoringStudentScale;
  /** Programs offered — minimum 1 name. */
  programs: string[];
  /** Estimated scale of tutors. */
  tutor_scale: TutoringTutorScale;
  /**
   * Billing modes the lembaga offers. Minimum 1, max 3.
   * Multi-select on the wizard. The first entry is treated as the
   * default mode for seeded packages.
   */
  billing_mode: TutoringBillingMode[];
  /**
   * Optional map pin. Null when the requester skipped the picker.
   * Used during demo-request verification to confirm the lembaga is
   * located where claimed.
   */
  location: DemoTutoringLocation | null;
  /** Dummy-data scenarios to generate. All default-on. */
  scenarios: TutoringScenarioKey[];
}

export const TUTORING_SCENARIO_DEFINITIONS: ReadonlyArray<{
  key: TutoringScenarioKey;
  label: string;
  description: string;
  icon: string;
}> = [
  {
    key: 'sesi_kehadiran',
    label: 'Sesi & Kehadiran',
    description:
      'Sesi terjadwal 14 hari + 30 hari mundur, plus catatan kehadiran per siswa (Hadir/Terlambat/Sakit/Izin/Alfa).',
    icon: 'calendar',
  },
  {
    key: 'honor',
    label: 'Honor Tutor',
    description:
      'Rate honor per-sesi / per-jam per tutor + rekening tujuan transfer. Halaman Honor & slip PDF langsung terisi.',
    icon: 'wallet',
  },
  {
    key: 'tagihan',
    label: 'Tagihan',
    description:
      'Tagihan per siswa sesuai billing_mode (per sesi / per bulan / paket), separuh lunas + separuh menunggu verifikasi.',
    icon: 'rocket',
  },
  {
    key: 'voucher',
    label: 'Voucher Promo',
    description:
      '4-6 voucher diskon (mix persentase + rupiah) dengan used_count & kedaluwarsa beragam.',
    icon: 'star',
  },
  {
    key: 'leads',
    label: 'Lead / Calon Siswa',
    description:
      '8-12 lead calon siswa (TRIAL/CONVERTED/DROPPED) berbagai sumber: IG ads, referral, walk-in.',
    icon: 'user-plus',
  },
  {
    key: 'pengumuman',
    label: 'Pengumuman Kelompok',
    description:
      'Pengumuman per kelompok dari tutor + pengumuman global admin (libur, rapat wali, jadwal try-out).',
    icon: 'mail',
  },
  {
    key: 'aktivitas',
    label: 'Aktivitas & Tugas',
    description:
      'Tugas / quiz / proyek + submissions siswa — campuran graded / pending / late, mengisi halaman Aktivitas tutor.',
    icon: 'check',
  },
  {
    key: 'rating',
    label: 'Rating Tutor',
    description:
      'Feedback siswa per sesi (rating 4-5) + komentar — mengisi summary Rating Tutor.',
    icon: 'check',
  },
];

/**
 * Indonesian display labels keyed by the canonical English wire
 * value. Keys MUST match [TutoringEducationLevel] exactly — TS will
 * fail the build if they drift.
 */
export const TUTORING_EDUCATION_LEVEL_LABEL: Record<TutoringEducationLevel, string> = {
  ELEMENTARY: 'SD',
  JUNIOR_HIGH: 'SMP',
  SENIOR_HIGH: 'SMA / SMK',
  SNBT: 'SNBT / UTBK',
  KARYAWAN: 'Karyawan',
  UMUM: 'Umum',
};

export const TUTORING_STUDENT_SCALE_LABEL: Record<TutoringStudentScale, string> = {
  lt50: '< 50 siswa',
  '50_200': '50 – 200 siswa',
  '200_500': '200 – 500 siswa',
  gt500: '> 500 siswa',
};

export const TUTORING_TUTOR_SCALE_LABEL: Record<TutoringTutorScale, string> = {
  '1_3': '1 – 3 tutor',
  '4_10': '4 – 10 tutor',
  '11_30': '11 – 30 tutor',
  gt30: '> 30 tutor',
};

export const TUTORING_BILLING_MODE_LABEL: Record<TutoringBillingMode, string> = {
  PER_SESSION: 'Per sesi',
  PER_MONTH: 'Per bulan',
  PACKAGE: 'Paket',
};

/**
 * Default program names suggested in the tutoring center chips-add
 * input. User can untoggle / add custom.
 */
export const TUTORING_DEFAULT_PROGRAMS: readonly string[] = [
  'Reguler',
  'Intensif',
  'Tryout',
] as const;

export const SCENARIO_DEFINITIONS: ReadonlyArray<{
  key: DemoScenarioKey;
  label: string;
  description: string;
  icon: string;
}> = [
  {
    key: 'kehadiran',
    label: 'Kehadiran',
    description:
      'Catatan absensi 5 hari terakhir per kelas — Hadir/Izin/Sakit/Alfa lengkap dengan jam pelajaran.',
    icon: 'check',
  },
  {
    key: 'rpp',
    label: 'Rencana Pembelajaran (RPP)',
    description:
      'Beberapa RPP per guru — campuran Draft, Menunggu review, dan Disetujui.',
    icon: 'rocket',
  },
  {
    key: 'pengumuman',
    label: 'Pengumuman',
    description:
      'Pengumuman global sekolah + pengumuman khusus kelas (info kegiatan, libur, rapat wali).',
    icon: 'mail',
  },
  {
    key: 'progress_subbab',
    label: 'Progress Sub-bab',
    description:
      'Bab + Sub-bab untuk tiap mapel, dengan ~30% sudah ditandai selesai oleh guru.',
    icon: 'database',
  },
  {
    key: 'kegiatan_kelas',
    label: 'Kegiatan Kelas',
    description:
      'Tugas, ulangan, dan kegiatan kelas — beberapa sudah dikumpulkan, beberapa belum.',
    icon: 'clock',
  },
  {
    key: 'tagihan',
    label: 'Tagihan',
    description:
      'Tagihan SPP 12 bulan + tagihan satu kali sesuai template di langkah Tagihan.',
    icon: 'rocket',
  },
  {
    key: 'nilai',
    label: 'Nilai & Rekap Nilai',
    description:
      '3 asesmen per guru (UH-1, UTS, UAS) lengkap dengan skor 70–95 untuk tiap siswa. Otomatis mengisi halaman Nilai dan Rekap Nilai.',
    icon: 'database',
  },
  {
    key: 'pembayaran',
    label: 'Pembayaran',
    description:
      '~15% tagihan dibayar — separuh menunggu verifikasi admin, separuh sudah disetujui. Mengisi tab Pembayaran + bukti lunas di Tagihan wali.',
    icon: 'check',
  },
  {
    key: 'pengumuman_event',
    label: 'Kalender Acara',
    description:
      '5 pengumuman bertipe event (rapat wali, libur, workshop guru, class meeting). Mengisi halaman Kalender Pengumuman.',
    icon: 'clock',
  },
  {
    key: 'notifikasi',
    label: 'Notifikasi',
    description:
      'Bell-notif untuk admin + akun guru/wali demo — 5 untuk owner, 2 per companion. Mengisi badge & halaman Notifikasi.',
    icon: 'mail',
  },
  {
    key: 'rapor_draft',
    label: 'Rapor Draft',
    description:
      'Pre-fill 2 mapel × seluruh siswa kelas pertama di tabel grade_recaps. Admin Rapor hub langsung menampilkan card "menunggu finalisasi".',
    icon: 'database',
  },
  {
    key: 'submission_late',
    label: 'Tugas Telat Kumpul',
    description:
      '3 kegiatan kelas dengan tenggat lewat. ~30% siswa kumpul dengan status "late" + skor kosong — uji flow penilaian susulan.',
    icon: 'alert-circle',
  },
  {
    key: 'audit_log',
    label: 'Riwayat Aktivitas',
    description:
      '~20 baris audit log untuk admin + 24 baris untuk 3 guru sample, tersebar 14 hari ke belakang. Mengisi halaman Riwayat di Profil.',
    icon: 'clock',
  },
  {
    key: 'multi_payment',
    label: 'Cicilan Tagihan',
    description:
      '5 bill lunas mendapat 1 baris payment cicilan tambahan (40–60% dari total) — wali murid lihat riwayat cicilan #1 + lunas #2.',
    icon: 'check',
  },
  {
    key: 'material_files',
    label: 'Materi PDF',
    description:
      'Baris di tabel materials untuk tiap mapel — file_path placeholder, sub_chapter_id terisi. Halaman Materi guru menampilkan daftar unduhan.',
    icon: 'database',
  },
  {
    key: 'read_statuses',
    label: 'Status Sudah Dibaca',
    description:
      '~50% pengumuman + ~30% kegiatan kelas ditandai sudah dibaca oleh sample user. State awal natural untuk mark-as-read flow.',
    icon: 'check',
  },
  {
    key: 'konflik_jadwal',
    label: 'Konflik Jadwal',
    description:
      '2 slot jadwal bentrok (kelas + JP sama, guru berbeda). Validator jadwal admin menandainya sebagai konflik yang bisa di-resolve.',
    icon: 'alert-triangle',
  },
  {
    key: 'akses_request',
    label: 'Permintaan Akses',
    description:
      '2 baris di school_access_requests (orang lain minta join sebagai guru / wali). Admin Settings → Akses Sekolah punya antrian persetujuan.',
    icon: 'user-plus',
  },
  {
    key: 'rapor_full',
    label: 'Rapor Semua Kelas',
    description:
      'grade_recaps untuk SEMUA kelas × 3–4 mapel × seluruh siswa, dengan coverage 50–100% per kelas. Admin Rapor hub menampilkan mix card Selesai vs Menunggu Finalisasi.',
    icon: 'database',
  },
];

/**
 * Per-education-level suggested mapel — mirrors backend
 * EducationLevelTemplate. Used to pre-fill the wizard's Subjects step
 * when the user picks an education_level in step 2. Backend
 * re-validates against the same template so a tampered FE can't seed
 * e.g. "ipa" for a TK school.
 */
export const SUBJECTS_TEMPLATE: Record<EducationLevel, string[]> = {
  TK: [
    'Pengembangan Bahasa', 'Pengembangan Kognitif', 'Pengembangan Sosial',
    'Pengembangan Fisik Motorik', 'Pengembangan Seni',
  ],
  PAUD: ['Pembiasaan', 'Bermain Peran', 'Eksplorasi', 'Seni & Kreativitas'],
  ELEMENTARY: [
    'Pendidikan Agama', 'Pendidikan Pancasila', 'Bahasa Indonesia',
    'Matematika', 'IPA', 'IPS', 'Penjas', 'Seni Budaya', 'Bahasa Daerah',
  ],
  MI: [
    'Pendidikan Agama Islam', 'Akidah Akhlak', 'Al-Quran Hadits',
    'Pendidikan Pancasila', 'Bahasa Indonesia', 'Matematika',
    'IPA', 'IPS', 'Penjas', 'Bahasa Arab',
  ],
  JUNIOR_HIGH: [
    'Pendidikan Agama', 'Pendidikan Pancasila', 'Bahasa Indonesia',
    'Matematika', 'IPA', 'IPS', 'Bahasa Inggris',
    'Penjas', 'Seni Budaya', 'Informatika', 'Prakarya',
  ],
  MTs: [
    'Pendidikan Agama Islam', 'Akidah Akhlak', 'Al-Quran Hadits', 'Fiqih',
    'Pendidikan Pancasila', 'Bahasa Indonesia', 'Matematika',
    'IPA', 'IPS', 'Bahasa Inggris', 'Bahasa Arab', 'Penjas',
  ],
  SENIOR_HIGH: [
    'Pendidikan Agama', 'Pendidikan Pancasila', 'Bahasa Indonesia',
    'Matematika Wajib', 'Matematika Peminatan', 'Bahasa Inggris',
    'Fisika', 'Kimia', 'Biologi', 'Sejarah', 'Ekonomi', 'Geografi',
    'Sosiologi', 'Penjas', 'Seni Budaya', 'Informatika',
  ],
  MA: [
    'Pendidikan Agama Islam', 'Akidah Akhlak', 'Al-Quran Hadits', 'Fiqih',
    'Pendidikan Pancasila', 'Bahasa Indonesia', 'Matematika',
    'Bahasa Inggris', 'Bahasa Arab', 'Sejarah Kebudayaan Islam',
    'Sejarah', 'Penjas', 'Seni Budaya',
  ],
  VOCATIONAL_HIGH: [
    'Pendidikan Agama', 'Pendidikan Pancasila', 'Bahasa Indonesia',
    'Matematika', 'Bahasa Inggris', 'Penjas', 'Sejarah', 'Seni Budaya',
    'Informatika', 'Produktif 1 (Kejuruan)', 'Produktif 2 (Kejuruan)',
    'Praktik Kerja Lapangan',
  ],
  Pesantren: [
    'Al-Quran Hadits', 'Akidah Akhlak', 'Fiqih',
    'Sejarah Kebudayaan Islam', 'Bahasa Arab',
    'Bahasa Indonesia', 'Matematika', 'Bahasa Inggris',
    'IPA Terpadu', 'IPS Terpadu',
  ],
};

export function defaultSubjectsFor(educationLevel: EducationLevel): string[] {
  return [...(SUBJECTS_TEMPLATE[educationLevel] ?? SUBJECTS_TEMPLATE.JUNIOR_HIGH)];
}

/* ─── Search step types ─── */

export type SearchKind = 'tenant' | 'demo' | 'registry';

export interface SchoolSearchHit {
  kind: SearchKind;
  id: string | null;
  name: string;
  /**
   * For tenants the canonical column is `schools.education_level`;
   * for registry hits the upstream Dapodik mirror returns `jenjang`
   * (still surfaced here for back-compat with older callers).
   */
  education_level: string | null;
  jenjang?: string | null;
  /** Tenant column. Registry hits use `kota` instead — both kept. */
  city: string | null;
  kota?: string | null;
  /** Registry only — Dapodik returns `provinsi`; some older mappers
   *  pass through as `province`. Read either side. */
  province?: string | null;
  provinsi?: string | null;
  /** Registry-only address (Dapodik `alamat`). */
  address?: string | null;
  alamat?: string | null;
  npsn: string | null;
  is_demo: boolean;
  demo_owner_user_id?: string | null;
  demo_expires_at?: string | null;
}

/* ─── Submit (pending demo request) response ─── */

/**
 * Shape returned by `POST /demo/provision` now that the demo is
 * reviewed instead of auto-activated. The endpoint no longer
 * provisions a school — it records a PENDING demo request and a
 * super-admin approves it manually later. No activation internals
 * (school id, credentials, expiry) are exposed here on purpose.
 */
export interface DemoPendingResponse {
  demo_request_id: string;
  status: 'pending';
  submitted_at: string;
}

/* ─── Legacy provision response (kept for the activation path) ─── */

export interface DemoCredential {
  role: string;
  email: string;
  password: string | null;
  is_self: boolean;
  note?: string;
}

export interface DemoSummary {
  guru: number;
  kelas: number;
  siswa: number;
  wali: number;
  jadwal: number;
  tagihan: number;
  /** Skenario counters — present when the matching scenario ran. */
  kehadiran?: number;
  rpp?: number;
  pengumuman?: number;
  progress_subbab?: number;
  kegiatan_kelas?: number;
  nilai?: number;
  pembayaran?: number;
  pengumuman_event?: number;
  notifikasi?: number;
  rapor_draft?: number;
  submission_late?: number;
  audit_log?: number;
  multi_payment?: number;
  material_files?: number;
  read_statuses?: number;
  konflik_jadwal?: number;
  demo_expiry_short?: number;
  akses_request?: number;
  rapor_full?: number;
}

export interface DemoProvisionResponse {
  school: {
    id: string;
    /** Canonical column: schools.name (was `school_name`). */
    name: string;
    /** Canonical column: schools.education_level (was `jenjang`). */
    education_level: string;
    is_demo: boolean;
    demo_expires_at: string | null;
  };
  credentials: DemoCredential[];
  summary: DemoSummary;
}

/* ─── Requester identity validation (mirrors backend rules) ─── */

export type RequesterErrorKey =
  | 'full_name'
  | 'nip'
  | 'jabatan'
  | 'whatsapp'
  | 'social_media';

/** Channels enforced by the backend's at-least-one social-media rule. */
export const DEMO_SOCIAL_CHANNELS: readonly DemoSocialChannel[] = [
  'facebook',
  'threads',
  'instagram',
  'linkedin',
  'other',
] as const;

/**
 * Client-side validation of the requester identity form. Mirrors the
 * Laravel `SubmitDemoRequestRequest::identityRules()` + the
 * at-least-one-socmed check in `withValidator()` so a bad submit is
 * caught before the network round-trip. Returns a partial map of
 * field → i18n key; an empty map means the form is valid.
 */
export function validateRequester(
  r: DemoRequesterPayload,
): Partial<Record<RequesterErrorKey, string>> {
  const errors: Partial<Record<RequesterErrorKey, string>> = {};
  const fullName = (r.full_name ?? '').trim();
  const nip = (r.nip ?? '').trim();
  const jabatan = (r.jabatan ?? '').trim();
  const whatsapp = (r.whatsapp ?? '').trim();

  if (fullName.length < 3 || fullName.length > 160) {
    errors.full_name = 'registerDemo.requesterErrFullName';
  }
  if (nip.length < 3 || nip.length > 60) {
    errors.nip = 'registerDemo.requesterErrNip';
  }
  if (jabatan.length < 2 || jabatan.length > 120) {
    errors.jabatan = 'registerDemo.requesterErrJabatan';
  }
  // Same regex shape as the backend: starts with a digit or '+', then
  // digits / spaces / dashes; 6-32 chars total.
  if (
    whatsapp.length < 6 ||
    whatsapp.length > 32 ||
    !/^[0-9+][0-9\s-]*$/.test(whatsapp)
  ) {
    errors.whatsapp = 'registerDemo.requesterErrWhatsapp';
  }

  const sm = r.social_media ?? {};
  const hasAnySocial = DEMO_SOCIAL_CHANNELS.some(
    (c) => (sm[c] ?? '').trim() !== '',
  );
  if (!hasAnySocial) {
    errors.social_media = 'registerDemo.requesterErrSocial';
  }

  return errors;
}

/* ─── Tutoring center validation ─── */

export type TutoringErrorKey =
  | 'name'
  | 'city'
  | 'target_levels'
  | 'student_scale'
  | 'programs'
  | 'tutor_scale'
  | 'billing_mode';

/**
 * Client-side validation of the tutoring center payload (required-
 * fields only; scenarios are always optional). Returns a partial map
 * of field → i18n key. Empty map = valid.
 *
 * i18n keys use the canonical `registerDemo.tutoringErr*` prefix; the
 * locale-file sweep for the matching translations is queued for
 * whenever the tutoring-validator UI ships (no caller today).
 */
export function validateTutoring(
  b: DemoTutoringPayload,
): Partial<Record<TutoringErrorKey, string>> {
  const errors: Partial<Record<TutoringErrorKey, string>> = {};
  const name = (b.name ?? '').trim();
  const city = (b.city ?? '').trim();

  if (name.length < 3 || name.length > 160) {
    errors.name = 'registerDemo.tutoringErrName';
  }
  if (city.length < 2 || city.length > 80) {
    errors.city = 'registerDemo.tutoringErrCity';
  }
  if (!Array.isArray(b.target_levels) || b.target_levels.length === 0) {
    errors.target_levels = 'registerDemo.tutoringErrTargetLevels';
  }
  if (!b.student_scale) {
    errors.student_scale = 'registerDemo.tutoringErrStudentScale';
  }
  const programs = (b.programs ?? []).map((p) => p.trim()).filter(Boolean);
  if (programs.length === 0) {
    errors.programs = 'registerDemo.tutoringErrPrograms';
  }
  if (!b.tutor_scale) {
    errors.tutor_scale = 'registerDemo.tutoringErrTutorScale';
  }
  if (!Array.isArray(b.billing_mode) || b.billing_mode.length === 0) {
    errors.billing_mode = 'registerDemo.tutoringErrBillingMode';
  }
  return errors;
}

/* ─── Defaults ─── */

export function defaultTutoringPayload(): DemoTutoringPayload {
  return {
    name: '',
    city: null,
    target_levels: ['SENIOR_HIGH'],
    student_scale: '50_200',
    programs: [],
    tutor_scale: '4_10',
    billing_mode: ['PER_MONTH'],
    location: null,
    // Default-on so a fresh tutoring-center demo is populated end-to-end.
    // The user can untoggle any they don't want before submit.
    scenarios: [
      'sesi_kehadiran',
      'honor',
      'tagihan',
      'voucher',
      'leads',
      'pengumuman',
      'aktivitas',
      'rating',
    ],
  };
}

export function defaultWizardPayload(): DemoWizardPayload {
  const currentYear = new Date().getFullYear();
  const nextYear = currentYear + 1;
  return {
    // 'school' is the back-compat default — preserves behaviour for any
    // partially-completed wizard state persisted before tenant_type
    // existed. The new flow forces a choice on the tenant-choice landing.
    tenant_type: 'school',
    tutoring: defaultTutoringPayload(),
    school: {
      name: '',
      education_level: 'JUNIOR_HIGH',
      city: null,
      npsn: null,
      academic_year_label: `${currentYear} / ${nextYear}`,
    },
    identity: {
      mode: 'all_roles',
      primary_role: 'admin',
    },
    subjects: {
      names: defaultSubjectsFor('JUNIOR_HIGH'),
    },
    teachers: {
      count: 12,
      fill_mode: 'random',
      manual_list: [],
    },
    classes: {
      pattern: 'medium',
      per_grade: {},
    },
    students: {
      per_class: 28,
      fill_mode: 'random',
    },
    parents: {
      mode: 'auto_link',
    },
    schedule: {
      mode: 'auto',
      active_days: [1, 2, 3, 4, 5],
      jp_per_day: 7,
      start_time: '07:00',
      end_time: '14:30',
    },
    billing: {
      mode: 'build_year',
      templates: ['spp_bulanan', 'uang_gedung', 'uts_uas'],
      spp_nominal: 450_000,
    },
    scenarios: {
      // Default-on so a brand-new demo is populated everywhere. Users
      // can untoggle any they don't want to test before provisioning.
      enabled: [
        'kehadiran',
        'rpp',
        'pengumuman',
        'progress_subbab',
        'kegiatan_kelas',
        'tagihan',
        'nilai',
        'pembayaran',
        'pengumuman_event',
        'notifikasi',
        'rapor_draft',
        'submission_late',
        'audit_log',
        'multi_payment',
        'material_files',
        'read_statuses',
        'konflik_jadwal',
        // 'demo_expiry_short' intentionally OFF by default — it shortens
        // the demo's expiry to showcase the "almost expired" banner, which
        // confused users (looked like a real near-expiry). Still selectable
        // in Step 10 for anyone who wants to demo that flow.
        'akses_request',
        'rapor_full',
      ],
    },
    requester: {
      full_name: '',
      nip: '',
      jabatan: '',
      whatsapp: '',
      social_media: {
        facebook: '',
        threads: '',
        instagram: '',
        linkedin: '',
        other: '',
      },
    },
  };
}

export interface DemoRegistrationItem {
  id: string;
  status: 'pending' | 'approved' | 'rejected' | 'expired';
  /**
   * Backend response tenant_type. Per the 2026-06-26 English-enum
   * cutover the server emits `'school' | 'tutoring'`; legacy rows may
   * still carry the Indonesian `'sekolah' | 'bimbel'` until backfill
   * completes. Use `normalizeTenantType()` from `@/lib/labels` when
   * comparing — string equality on this field is unsafe across the
   * transition window.
   */
  tenant_type: TenantType | 'sekolah' | 'bimbel';
  school_name: string | null;
  demo_expires_at: string | null;
  activated_school_id: string | null;
  created_at: string | null;
}

export interface ActiveSchoolItem {
  id: string;
  name: string;
  is_demo: boolean;
  /** See `DemoRegistrationItem.tenant_type` — same transition rules. */
  tenant_type: TenantType | 'sekolah' | 'bimbel';
  demo_expires_at: string | null;
}

export interface MyRegistrationsResponse {
  demo_requests: DemoRegistrationItem[];
  active_schools: ActiveSchoolItem[];
}

