/**
 * Register-demo wizard types.
 *
 * Mirrors the Laravel `ProvisionDemoSchoolRequest` shape so the
 * client sends exactly what the backend validates. Pinia keeps the
 * working copy of `DemoWizardPayload` and persists it to
 * localStorage on every step change.
 */

export type Jenjang =
  | 'SD'
  | 'MI'
  | 'SMP'
  | 'MTs'
  | 'SMA'
  | 'MA'
  | 'SMK'
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
  | 'scenarios'
  | 'done';

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
  'done',
] as const;

/** Backend role names — what we send and what the server expects. */
export type DemoRole = 'admin' | 'teacher' | 'parent';

export interface DemoSchoolPayload {
  name: string;
  /** Canonical English column: `schools.education_level`. */
  education_level: Jenjang;
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
 *  - pengumuman       → seed announcements (global + per-class)
 *  - progress_subbab  → seed chapters/sub_chapters + ~30% marked done
 *  - kegiatan_kelas   → seed class_activities + a few submissions
 *  - tagihan          → run the billing seed (overrides billing.mode skip)
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

export interface DemoWizardPayload {
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
}

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
    key: 'demo_expiry_short',
    label: 'Demo Hampir Kedaluwarsa',
    description:
      'Set masa berlaku demo jadi 3 hari (bukan 30). Banner countdown di dashboard menampilkan state warning, bukan default normal.',
    icon: 'alert-circle',
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
export const SUBJECTS_TEMPLATE: Record<Jenjang, string[]> = {
  TK: [
    'Pengembangan Bahasa', 'Pengembangan Kognitif', 'Pengembangan Sosial',
    'Pengembangan Fisik Motorik', 'Pengembangan Seni',
  ],
  PAUD: ['Pembiasaan', 'Bermain Peran', 'Eksplorasi', 'Seni & Kreativitas'],
  SD: [
    'Pendidikan Agama', 'Pendidikan Pancasila', 'Bahasa Indonesia',
    'Matematika', 'IPA', 'IPS', 'Penjas', 'Seni Budaya', 'Bahasa Daerah',
  ],
  MI: [
    'Pendidikan Agama Islam', 'Akidah Akhlak', 'Al-Quran Hadits',
    'Pendidikan Pancasila', 'Bahasa Indonesia', 'Matematika',
    'IPA', 'IPS', 'Penjas', 'Bahasa Arab',
  ],
  SMP: [
    'Pendidikan Agama', 'Pendidikan Pancasila', 'Bahasa Indonesia',
    'Matematika', 'IPA', 'IPS', 'Bahasa Inggris',
    'Penjas', 'Seni Budaya', 'Informatika', 'Prakarya',
  ],
  MTs: [
    'Pendidikan Agama Islam', 'Akidah Akhlak', 'Al-Quran Hadits', 'Fiqih',
    'Pendidikan Pancasila', 'Bahasa Indonesia', 'Matematika',
    'IPA', 'IPS', 'Bahasa Inggris', 'Bahasa Arab', 'Penjas',
  ],
  SMA: [
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
  SMK: [
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

export function defaultSubjectsFor(educationLevel: Jenjang): string[] {
  return [...(SUBJECTS_TEMPLATE[educationLevel] ?? SUBJECTS_TEMPLATE.SMP)];
}

/* ─── Search step types ─── */

export type SearchKind = 'tenant' | 'demo' | 'registry';

export interface SchoolSearchHit {
  kind: SearchKind;
  id: string | null;
  name: string;
  /** Canonical column: schools.education_level / npsn_registry.education_level */
  education_level: string | null;
  /** Canonical column: schools.city / npsn_registry.city */
  city: string | null;
  /** npsn_registry.province (only present for `registry` hits). */
  province?: string | null;
  /** npsn_registry.address (only present for `registry` hits). */
  address?: string | null;
  npsn: string | null;
  is_demo: boolean;
  demo_owner_user_id?: string | null;
  demo_expires_at?: string | null;
}

/* ─── Provision response types ─── */

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

/* ─── Defaults ─── */

export function defaultWizardPayload(): DemoWizardPayload {
  const currentYear = new Date().getFullYear();
  const nextYear = currentYear + 1;
  return {
    school: {
      name: '',
      education_level: 'SMP',
      city: null,
      npsn: null,
      academic_year_label: `${currentYear} / ${nextYear}`,
    },
    identity: {
      mode: 'all_roles',
      primary_role: 'admin',
    },
    subjects: {
      names: defaultSubjectsFor('SMP'),
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
        'demo_expiry_short',
        'akses_request',
        'rapor_full',
      ],
    },
  };
}
