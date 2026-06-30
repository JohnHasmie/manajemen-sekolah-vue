/**
 * Conversational wizard question schema.
 *
 * One question per screen. Each entry tells the shell:
 *   - which payload slice + field to bind to (read/write)
 *   - the input type to render
 *   - validation contract: is the current value enough to advance?
 *   - whether the user is allowed to Skip (only optional questions
 *     show the "Lewati" link)
 *
 * Both paths are defined here so the shell stays generic and the
 * only thing that differs between school/tutoring is which array we
 * iterate over.
 */
import type {
  TutoringBillingMode,
  TutoringEducationLevel,
  TutoringStudentScale,
  TutoringTutorScale,
  DemoTutoringLocation,
  DemoTutoringPayload,
  DemoWizardPayload,
  EducationLevel,
} from '@/types/demo';
import {
  TUTORING_BILLING_MODE_LABEL,
  TUTORING_DEFAULT_PROGRAMS,
  TUTORING_EDUCATION_LEVEL_LABEL,
  TUTORING_STUDENT_SCALE_LABEL,
  TUTORING_TUTOR_SCALE_LABEL,
  DEMO_SOCIAL_CHANNELS,
  defaultSubjectsFor,
} from '@/types/demo';

/**
 * Input types the conversational shell knows how to render. Each maps
 * to a tiny presentational component (`inputs/*.vue`).
 */
export type QuestionInput =
  | 'text'
  | 'tel'
  | 'number'
  | 'select'
  | 'pills'
  | 'pills_with_other'
  | 'chips_multi'
  | 'chips_add'
  | 'location'
  | 'social'
  | 'scenarios';

/** Single chip option used by `pills` / `select` inputs. */
export interface QuestionOption {
  value: string;
  label: string;
  /** Secondary muted line below the label. */
  hint?: string;
}

/**
 * Question definition. The shell reads `value(payload)` to populate
 * the input, calls `setValue(payload, v)` to merge the user's answer
 * back into the working payload, then calls `isValid(payload)` to
 * decide whether "Lanjut" is enabled.
 *
 * `chapter` is purely for the small kicker badge ("TENTANG ANDA",
 * "PROGRAM & TIM", …) — it lets us group questions visually
 * without the user feeling like they're staring at a 10-step list.
 */
export interface Question {
  /** Stable key for analytics / resume. */
  key: string;
  /** Chapter kicker shown above the prompt. */
  chapter: string;
  /** The big headline question. */
  prompt: string;
  /** Subtitle / helper sentence. */
  helper?: string;
  /**
   * Highlighted intro banner shown ABOVE the prompt. Used to set
   * tone for sensitive chapters (e.g. "Identitas Anda" — informs
   * the user that data here is verified by the team and a fake
   * submission will be rejected).
   */
  chapterIntro?: { title: string; body: string };
  /** Required = no Skip link; optional = Skip allowed. */
  required: boolean;
  input: QuestionInput;
  /** Long placeholder for text/tel/number inputs. */
  placeholder?: string;
  /** Suffix label after a number/text input (e.g. "student", "tutor"). */
  suffix?: string;
  /** Static option list for `pills`/`select`/`chips_multi`. */
  options?: QuestionOption[];
  /** Default chip suggestions for `chips_add` — user can untoggle. */
  suggestions?: string[];
  /** Read the current answer from the payload. */
  value: (p: DemoWizardPayload) => unknown;
  /** Merge an answer back into the payload (immutably). */
  setValue: (p: DemoWizardPayload, v: unknown) => DemoWizardPayload;
  /** Should "Lanjut" be enabled? Only checked for required questions. */
  isValid: (p: DemoWizardPayload) => boolean;
  /**
   * Run the gibberish detector on this question's value as an extra
   * gate on top of `isValid`. Use for free-text proper-noun fields
   * (names of schools, cities, jabatan) — NOT for arbitrary strings
   * like program names which can be anything.
   */
  gibberishCheck?: boolean;
  /**
   * Run the phone sanity check (length / all-same / sequential).
   * Use for WhatsApp/tel fields.
   */
  phoneCheck?: boolean;
  /**
   * Hint shown under the input that this question's name search
   * results from the schools registry should appear. Only honoured
   * by the `school.name` question on the sekolah path.
   */
  schoolSearch?: boolean;
  /**
   * Predicate that, when true, makes the wizard SKIP this question
   * entirely (both forward and back navigation jump over it). Used
   * to elide redundant questions whose answer is already known with
   * high confidence from a previous step — e.g. picking a registry
   * NPSN hit on Q1 auto-fills education_level + city, so Q2
   * (jenjang) and Q3 (city) are not worth asking again.
   */
  skipIf?: (p: DemoWizardPayload) => boolean;
}

/* ────────────────────── TUTORING CENTER PATH ─────────────────────── */

// Canonical English wire values for the chip values + Indonesian
// display labels from TUTORING_EDUCATION_LEVEL_LABEL. The backend
// `SubmitDemoRequestRequest` validator rejects Indonesian acronyms
// post the 2026-06-26 Phase-4 cutover (causing the 422 a user hit on
// register-demo last submit) — keep this list in sync with the
// validator's Rule::in([...]).
const TUTORING_TARGET_OPTIONS: QuestionOption[] = (
  ['ELEMENTARY', 'JUNIOR_HIGH', 'SENIOR_HIGH', 'SNBT', 'KARYAWAN', 'UMUM'] as TutoringEducationLevel[]
).map((v) => ({ value: v, label: TUTORING_EDUCATION_LEVEL_LABEL[v] }));

const TUTORING_STUDENT_SCALE_OPTIONS: QuestionOption[] = (
  ['lt50', '50_200', '200_500', 'gt500'] as TutoringStudentScale[]
).map((v) => ({ value: v, label: TUTORING_STUDENT_SCALE_LABEL[v] }));

const TUTORING_TUTOR_SCALE_OPTIONS: QuestionOption[] = (
  ['1_3', '4_10', '11_30', 'gt30'] as TutoringTutorScale[]
).map((v) => ({ value: v, label: TUTORING_TUTOR_SCALE_LABEL[v] }));

const TUTORING_BILLING_OPTIONS: QuestionOption[] = (
  ['PER_SESSION', 'PER_MONTH', 'PACKAGE'] as TutoringBillingMode[]
).map((v) => ({
  value: v,
  label: TUTORING_BILLING_MODE_LABEL[v],
  hint:
    v === 'PER_SESSION'
      ? 'Tagihan otomatis terbit setiap sesi tercatat'
      : v === 'PER_MONTH'
        ? 'Tagihan bulanan tetap, terlepas dari jumlah sesi'
        : 'Bayar sekali untuk seluruh paket program',
}));

/* `p.tutoring` is the canonical wire key after the 2026-06-26 cutover. */
function patchTutoring<K extends keyof DemoTutoringPayload>(
  p: DemoWizardPayload,
  key: K,
  value: DemoTutoringPayload[K],
): DemoWizardPayload {
  return { ...p, tutoring: { ...p.tutoring, [key]: value } };
}

export const TUTORING_QUESTIONS: readonly Question[] = [
  {
    key: 'tutoring.name',
    chapter: 'Tentang lembaga',
    prompt: 'Apa nama bimbel atau lembaga Anda?',
    helper: 'Nama yang akan tampil di kop tagihan, halaman tutor, dan akun siswa.',
    required: true,
    input: 'text',
    placeholder: 'mis. Cahaya Prestasi Bimbel',
    gibberishCheck: true,
    value: (p) => p.tutoring.name,
    setValue: (p, v) => patchTutoring(p, 'name', String(v ?? '')),
    isValid: (p) => p.tutoring.name.trim().length >= 3,
  },
  {
    key: 'tutoring.location',
    chapter: 'Tentang lembaga',
    prompt: 'Di mana lokasi bimbel Anda?',
    helper:
      'Cari alamat kantor di peta, atau klik “Lokasi saya” untuk pakai posisi sekarang. Belum punya kantor fisik? Tetap pakai lokasi sekarang — centang toggle di bawah peta supaya tim tahu itu lokasi operator, bukan kantor.',
    required: true,
    input: 'location',
    value: (p) => p.tutoring.location,
    setValue: (p, v) =>
      patchTutoring(p, 'location', (v as DemoTutoringLocation | null) ?? null),
    isValid: (p) => {
      const loc = p.tutoring.location;
      if (!loc) return false;
      return Number.isFinite(loc.lat) && Number.isFinite(loc.lng);
    },
  },
  {
    key: 'tutoring.city',
    chapter: 'Tentang lembaga',
    prompt: 'Kota lembaga Anda?',
    helper: 'Untuk memetakan zona waktu dan opsi pembayaran lokal.',
    required: true,
    input: 'text',
    placeholder: 'mis. Bandung',
    gibberishCheck: true,
    // Auto-skip when the previous question's map pick reverse-geocoded
    // a city for us. The user can still go Kembali to re-pin if they
    // want to override.
    skipIf: (p) => (p.tutoring.city ?? '').trim().length >= 2 && p.tutoring.location != null,
    value: (p) => p.tutoring.city ?? '',
    setValue: (p, v) => patchTutoring(p, 'city', String(v ?? '') || null),
    isValid: (p) => (p.tutoring.city ?? '').trim().length >= 2,
  },
  {
    key: 'tutoring.target_levels',
    chapter: 'Tentang lembaga',
    prompt: 'Jenjang apa saja yang Anda bimbing?',
    helper: 'Pilih satu atau lebih. Bisa diubah lagi setelah demo aktif.',
    required: true,
    input: 'chips_multi',
    options: TUTORING_TARGET_OPTIONS,
    value: (p) => p.tutoring.target_levels,
    setValue: (p, v) => patchTutoring(p, 'target_levels', (v as TutoringEducationLevel[]) ?? []),
    isValid: (p) => p.tutoring.target_levels.length > 0,
  },
  {
    key: 'tutoring.student_scale',
    chapter: 'Tentang lembaga',
    prompt: 'Kira-kira berapa siswa aktif saat ini?',
    helper: 'Estimasi kasar saja — data demo akan disesuaikan dengan skala ini.',
    required: true,
    input: 'pills',
    options: TUTORING_STUDENT_SCALE_OPTIONS,
    value: (p) => p.tutoring.student_scale,
    setValue: (p, v) => patchTutoring(p, 'student_scale', v as TutoringStudentScale),
    isValid: (p) => !!p.tutoring.student_scale,
  },
  {
    key: 'tutoring.programs',
    chapter: 'Program & tim',
    prompt: 'Program apa saja yang Anda jalankan?',
    helper: 'Tap untuk pilih dari saran, atau tambahkan program khusus Anda.',
    required: true,
    input: 'chips_add',
    suggestions: [...TUTORING_DEFAULT_PROGRAMS],
    placeholder: 'mis. Intensif SNBT 2026',
    value: (p) => p.tutoring.programs,
    setValue: (p, v) =>
      patchTutoring(
        p,
        'programs',
        ((v as string[]) ?? []).map((s) => s.trim()).filter(Boolean),
      ),
    isValid: (p) =>
      Array.isArray(p.tutoring.programs) &&
      p.tutoring.programs.filter((s) => s.trim().length > 0).length > 0,
  },
  {
    key: 'tutoring.tutor_scale',
    chapter: 'Program & tim',
    prompt: 'Berapa banyak tutor yang aktif mengajar?',
    helper: 'Untuk menentukan jumlah akun tutor dummy yang dibuatkan.',
    required: true,
    input: 'pills',
    options: TUTORING_TUTOR_SCALE_OPTIONS,
    value: (p) => p.tutoring.tutor_scale,
    setValue: (p, v) => patchTutoring(p, 'tutor_scale', v as TutoringTutorScale),
    isValid: (p) => !!p.tutoring.tutor_scale,
  },
  {
    key: 'tutoring.billing_mode',
    chapter: 'Program & tim',
    prompt: 'Mode penagihan default yang Anda pakai?',
    helper: 'Bisa diubah per program / per siswa setelah demo aktif.',
    required: true,
    input: 'pills',
    options: TUTORING_BILLING_OPTIONS,
    value: (p) => p.tutoring.billing_mode,
    setValue: (p, v) => patchTutoring(p, 'billing_mode', v as TutoringBillingMode),
    isValid: (p) => !!p.tutoring.billing_mode,
  },
  {
    key: 'requester.full_name',
    chapter: 'Identitas Anda',
    chapterIntro: {
      title: 'Data faktual untuk verifikasi',
      body:
        'Bagian ini akan diverifikasi tim KamilEdu sebelum demo diaktifkan — termasuk telepon WhatsApp dan cek profil media sosial. Mohon isi data sebenarnya; pendaftaran fiktif atau identitas tidak konsisten akan ditolak tanpa pemberitahuan.',
    },
    prompt: 'Siapa nama lengkap Anda?',
    helper: 'Tulis nama sesuai KTP / dokumen resmi. Tim KamilEdu akan menghubungi Anda untuk verifikasi sebelum demo diaktifkan.',
    required: true,
    input: 'text',
    placeholder: 'mis. Aulia Ramadhani',
    gibberishCheck: true,
    value: (p) => p.requester.full_name,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, full_name: String(v ?? '') },
    }),
    isValid: (p) => {
      const n = p.requester.full_name.trim();
      return n.length >= 3 && n.length <= 160;
    },
  },
  {
    key: 'requester.jabatan',
    chapter: 'Identitas Anda',
    prompt: 'Apa peran Anda di lembaga ini?',
    // Helper rephrased — picker is the primary path now; the custom
    // input only surfaces when none of the chips match.
    helper: 'Pilih peran Anda. Kalau tidak ada di daftar, ketik manual di kolom Lainnya. Tim verifikasi akan mengonfirmasi peran ini lewat WhatsApp.',
    required: true,
    // Chip picker with an "Other" fallback. The 5 presets cover ~95%
    // of demo registrants per Yahya's review of past wizard sessions;
    // anyone outside that distribution types into the free-text
    // input that surfaces when "Lainnya" is selected. The
    // `setValue` and `isValid` rules read the same string field
    // either way — backend / persistence don't care which path the
    // value came from.
    input: 'pills_with_other',
    options: [
      { value: 'Owner', label: 'Owner' },
      { value: 'Admin', label: 'Admin' },
      { value: 'Tutor', label: 'Tutor' },
      { value: 'Akademik', label: 'Akademik' },
      { value: 'Kepala Sekolah', label: 'Kepala Sekolah' },
    ],
    placeholder: 'mis. Wakil Kepala / Staff',
    gibberishCheck: true,
    value: (p) => p.requester.jabatan,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, jabatan: String(v ?? '') },
    }),
    isValid: (p) => {
      const n = p.requester.jabatan.trim();
      return n.length >= 2 && n.length <= 120;
    },
  },
  {
    key: 'requester.whatsapp',
    chapter: 'Identitas Anda',
    prompt: 'Nomor WhatsApp aktif Anda?',
    helper: 'Pakai nomor WA aktif yang bisa dihubungi — tim verifikasi akan menelepon untuk konfirmasi sebelum aktivasi. Demo tidak akan diaktifkan kalau nomor tidak bisa dihubungi.',
    required: true,
    input: 'tel',
    placeholder: 'mis. 0812 3456 7890',
    phoneCheck: true,
    value: (p) => p.requester.whatsapp,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, whatsapp: String(v ?? '') },
    }),
    isValid: (p) => {
      const w = p.requester.whatsapp.trim();
      return w.length >= 6 && w.length <= 32 && /^[0-9+][0-9\s-]*$/.test(w);
    },
  },
  {
    key: 'requester.social_media',
    chapter: 'Identitas Anda',
    prompt: 'Media sosial Anda?',
    helper:
      'Minimal satu channel yang aktif dan terlihat real (Instagram pribadi, LinkedIn, dll). Tim verifikasi cek profil ini untuk memastikan identitas Anda benar-benar ada — channel kosong/fiktif akan ditolak.',
    required: true,
    input: 'social',
    value: (p) => p.requester.social_media,
    setValue: (p, v) => ({
      ...p,
      requester: {
        ...p.requester,
        social_media: { ...(v as Record<string, string>) },
      },
    }),
    isValid: (p) => {
      const sm = p.requester.social_media ?? {};
      return DEMO_SOCIAL_CHANNELS.some(
        (c) => ((sm as Record<string, string>)[c] ?? '').trim() !== '',
      );
    },
  },
  {
    key: 'tutoring.scenarios',
    chapter: 'Skenario demo',
    prompt: 'Data dummy apa yang ingin disisipkan?',
    helper:
      'Tap untuk untoggle — semuanya default-on. Bisa diubah sebelum kirim.',
    required: true,
    input: 'scenarios',
    value: (p) => p.tutoring.scenarios,
    setValue: (p, v) =>
      patchTutoring(p, 'scenarios', (v as DemoTutoringPayload['scenarios']) ?? []),
    isValid: () => true,
  },
];

/* ─────────────────────────── SCHOOL PATH ──────────────────────────── */

/**
 * School education-level chip options. `value` is the canonical English
 * wire value (post 2026-06-26 cutover) sent to the backend; `label` is
 * the Indonesian display abbreviation the user sees on the chip. Use
 * `educationLevelDisplay()` from `@/lib/labels` to map back when reading.
 */
const SCHOOL_EDUCATION_LEVEL_OPTIONS: QuestionOption[] = (
  [
    'ELEMENTARY',         // SD
    'MI',
    'JUNIOR_HIGH',        // SMP
    'MTs',
    'SENIOR_HIGH',        // SMA
    'MA',
    'VOCATIONAL_HIGH',    // SMK
    'TK',
    'PAUD',
    'Pesantren',
  ] as EducationLevel[]
).map((v) => ({
  value: v,
  // Map ENGLISH wire values back to the Indonesian display label.
  label:
    v === 'ELEMENTARY' ? 'SD'
      : v === 'JUNIOR_HIGH' ? 'SMP'
        : v === 'SENIOR_HIGH' ? 'SMA'
          : v === 'VOCATIONAL_HIGH' ? 'SMK'
            : v,
}));

const SCHOOL_CLASS_PATTERN_OPTIONS: QuestionOption[] = [
  { value: 'small', label: 'Kecil', hint: '1–2 kelas per tingkat' },
  { value: 'medium', label: 'Sedang', hint: '3–4 kelas per tingkat' },
  { value: 'large', label: 'Besar', hint: '5+ kelas per tingkat' },
];

const SCHOOL_BILLING_OPTIONS: QuestionOption[] = [
  { value: 'build_year', label: 'Aktifkan tagihan SPP', hint: 'SPP + uang gedung + UTS/UAS' },
  { value: 'skip', label: 'Skip tagihan dulu', hint: 'Bisa diaktifkan nanti dari menu Tagihan' },
];

export const SCHOOL_QUESTIONS: readonly Question[] = [
  {
    key: 'school.name',
    chapter: 'Tentang sekolah',
    prompt: 'Apa nama sekolah Anda?',
    helper: 'Ketik nama sekolah — sistem akan mencari dari registri NPSN. Klik hasil yang cocok untuk auto-fill, atau lanjut dengan ketikan Anda untuk daftar baru.',
    required: true,
    input: 'text',
    placeholder: 'mis. SMP Negeri 1 Bandung',
    gibberishCheck: true,
    schoolSearch: true,
    value: (p) => p.school.name,
    setValue: (p, v) => ({
      ...p,
      school: { ...p.school, name: String(v ?? '') },
    }),
    isValid: (p) => p.school.name.trim().length >= 3,
  },
  {
    key: 'school.education_level',
    chapter: 'Tentang sekolah',
    prompt: 'Jenjang sekolah Anda?',
    helper: 'Mata pelajaran default akan disesuaikan dengan jenjang.',
    required: true,
    input: 'pills',
    options: SCHOOL_EDUCATION_LEVEL_OPTIONS,
    // Auto-skip when Q1 picked a registry hit. Hits carry both a
    // NPSN and an education_level, so re-asking is just friction.
    skipIf: (p) => Boolean(p.school.npsn) && Boolean(p.school.education_level),
    value: (p) => p.school.education_level,
    setValue: (p, v) => {
      const lvl = v as EducationLevel;
      return {
        ...p,
        school: { ...p.school, education_level: lvl },
        // Refresh subjects to the new jenjang's template — user can
        // untoggle in the Subjects question. Keeps the two answers in sync.
        subjects: { names: defaultSubjectsFor(lvl) },
      };
    },
    isValid: (p) => !!p.school.education_level,
  },
  {
    key: 'school.city',
    chapter: 'Tentang sekolah',
    prompt: 'Kota tempat sekolah berada?',
    helper: 'Untuk zona waktu jadwal dan format kalender lokal.',
    required: true,
    input: 'text',
    placeholder: 'mis. Surabaya',
    gibberishCheck: true,
    // Same logic: a registry hit prefills the kota field, no need
    // to ask. Falls through to the question only when the user
    // typed a brand-new school name.
    skipIf: (p) => Boolean(p.school.npsn) && (p.school.city ?? '').trim().length >= 2,
    value: (p) => p.school.city ?? '',
    setValue: (p, v) => ({
      ...p,
      school: { ...p.school, city: String(v ?? '') || null },
    }),
    isValid: (p) => (p.school.city ?? '').trim().length >= 2,
  },
  {
    key: 'classes.pattern',
    chapter: 'Skala & kelas',
    prompt: 'Pola jumlah kelas per tingkat?',
    helper: 'Kami siapkan kelas dummy sesuai pola ini.',
    required: true,
    input: 'pills',
    options: SCHOOL_CLASS_PATTERN_OPTIONS,
    value: (p) => p.classes.pattern,
    setValue: (p, v) => ({
      ...p,
      classes: { ...p.classes, pattern: v as 'small' | 'medium' | 'large' | 'custom' },
    }),
    isValid: (p) => !!p.classes.pattern,
  },
  {
    key: 'students.per_class',
    chapter: 'Skala & kelas',
    prompt: 'Rata-rata siswa per kelas?',
    helper: 'Estimasi kasar saja. Bisa diubah per kelas setelah demo aktif.',
    required: true,
    input: 'number',
    suffix: 'siswa',
    placeholder: '28',
    value: (p) => p.students.per_class,
    setValue: (p, v) => ({
      ...p,
      students: {
        ...p.students,
        per_class: Math.max(1, Math.min(60, Number(v) || 0)),
      },
    }),
    isValid: (p) => p.students.per_class >= 1 && p.students.per_class <= 60,
  },
  {
    key: 'teachers.count',
    chapter: 'Skala & kelas',
    prompt: 'Berapa guru aktif di sekolah Anda?',
    helper: 'Untuk membuat akun guru dummy dan menugaskan mapel.',
    required: true,
    input: 'number',
    suffix: 'guru',
    placeholder: '12',
    value: (p) => p.teachers.count,
    setValue: (p, v) => ({
      ...p,
      teachers: {
        ...p.teachers,
        count: Math.max(1, Math.min(200, Number(v) || 0)),
      },
    }),
    isValid: (p) => p.teachers.count >= 1 && p.teachers.count <= 200,
  },
  {
    key: 'schedule.active_days',
    chapter: 'Jadwal',
    prompt: 'Hari aktif sekolah?',
    helper: '1 = Senin … 7 = Minggu. Default Senin–Jumat.',
    required: true,
    input: 'chips_multi',
    options: [
      { value: '1', label: 'Sen' },
      { value: '2', label: 'Sel' },
      { value: '3', label: 'Rab' },
      { value: '4', label: 'Kam' },
      { value: '5', label: 'Jum' },
      { value: '6', label: 'Sab' },
      { value: '7', label: 'Min' },
    ],
    value: (p) => p.schedule.active_days.map(String),
    setValue: (p, v) => ({
      ...p,
      schedule: {
        ...p.schedule,
        active_days: ((v as string[]) ?? []).map(Number).sort((a, b) => a - b),
      },
    }),
    isValid: (p) => p.schedule.active_days.length > 0,
  },
  {
    key: 'schedule.jp_per_day',
    chapter: 'Jadwal',
    prompt: 'Berapa jam pelajaran (JP) per hari?',
    helper: 'Tipikal 6–9 JP. Bisa diatur per kelas nanti.',
    required: true,
    input: 'number',
    suffix: 'JP',
    placeholder: '7',
    value: (p) => p.schedule.jp_per_day,
    setValue: (p, v) => ({
      ...p,
      schedule: {
        ...p.schedule,
        jp_per_day: Math.max(1, Math.min(12, Number(v) || 0)),
      },
    }),
    isValid: (p) => p.schedule.jp_per_day >= 1 && p.schedule.jp_per_day <= 12,
  },
  {
    key: 'billing.mode',
    chapter: 'Tagihan',
    prompt: 'Aktifkan tagihan SPP demo?',
    helper: 'Bisa di-skip — Anda tetap bisa atur tagihan nanti.',
    required: true,
    input: 'pills',
    options: SCHOOL_BILLING_OPTIONS,
    value: (p) => p.billing.mode,
    setValue: (p, v) => ({
      ...p,
      billing: { ...p.billing, mode: v as 'build_year' | 'skip' },
    }),
    isValid: () => true,
  },
  {
    key: 'requester.full_name',
    chapter: 'Identitas Anda',
    chapterIntro: {
      title: 'Data faktual untuk verifikasi',
      body:
        'Bagian ini akan diverifikasi tim KamilEdu sebelum demo diaktifkan — termasuk telepon WhatsApp dan cek profil media sosial. Mohon isi data sebenarnya; pendaftaran fiktif atau identitas tidak konsisten akan ditolak tanpa pemberitahuan.',
    },
    prompt: 'Siapa nama lengkap Anda?',
    helper: 'Tulis nama sesuai KTP / dokumen resmi. Tim KamilEdu akan menghubungi Anda untuk verifikasi sebelum demo diaktifkan.',
    required: true,
    input: 'text',
    placeholder: 'mis. Aulia Ramadhani',
    gibberishCheck: true,
    value: (p) => p.requester.full_name,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, full_name: String(v ?? '') },
    }),
    isValid: (p) => {
      const n = p.requester.full_name.trim();
      return n.length >= 3 && n.length <= 160;
    },
  },
  {
    key: 'requester.jabatan',
    chapter: 'Identitas Anda',
    prompt: 'Jabatan Anda di sekolah?',
    helper: 'Mohon isi sebenarnya (Kepala Sekolah / Wakasek / Operator Sekolah / dll). Tim verifikasi akan mengonfirmasi peran ini lewat WhatsApp.',
    required: true,
    input: 'text',
    placeholder: 'mis. Wakasek Kurikulum',
    gibberishCheck: true,
    value: (p) => p.requester.jabatan,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, jabatan: String(v ?? '') },
    }),
    isValid: (p) => {
      const n = p.requester.jabatan.trim();
      return n.length >= 2 && n.length <= 120;
    },
  },
  {
    key: 'requester.nip',
    chapter: 'Identitas Anda',
    prompt: 'NIP atau ID kepegawaian Anda?',
    helper: 'NIP resmi (PNS) atau NIK/ID internal sekolah. Wajib data faktual — dipakai tim verifikasi untuk konfirmasi keaslian sekolah.',
    required: true,
    input: 'text',
    placeholder: 'mis. 198501012010012001',
    value: (p) => p.requester.nip,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, nip: String(v ?? '') },
    }),
    isValid: (p) => {
      const n = p.requester.nip.trim();
      // NIP/ID is alphanumeric (digits + letters in some legacy ID
      // schemes), reject single-digit-repeat sequences like "111111".
      if (n.length < 3 || n.length > 60) return false;
      if (/^(.)\1+$/.test(n)) return false;
      return true;
    },
  },
  {
    key: 'requester.whatsapp',
    chapter: 'Identitas Anda',
    prompt: 'Nomor WhatsApp aktif Anda?',
    helper: 'Pakai nomor WA aktif yang bisa dihubungi — tim verifikasi akan menelepon untuk konfirmasi sebelum aktivasi. Demo tidak akan diaktifkan kalau nomor tidak bisa dihubungi.',
    required: true,
    input: 'tel',
    placeholder: 'mis. 0812 3456 7890',
    phoneCheck: true,
    value: (p) => p.requester.whatsapp,
    setValue: (p, v) => ({
      ...p,
      requester: { ...p.requester, whatsapp: String(v ?? '') },
    }),
    isValid: (p) => {
      const w = p.requester.whatsapp.trim();
      return w.length >= 6 && w.length <= 32 && /^[0-9+][0-9\s-]*$/.test(w);
    },
  },
  {
    key: 'requester.social_media',
    chapter: 'Identitas Anda',
    prompt: 'Media sosial Anda?',
    helper:
      'Minimal satu channel yang aktif dan terlihat real (Instagram pribadi, LinkedIn, dll). Tim verifikasi cek profil ini untuk memastikan identitas Anda benar-benar ada — channel kosong/fiktif akan ditolak.',
    required: true,
    input: 'social',
    value: (p) => p.requester.social_media,
    setValue: (p, v) => ({
      ...p,
      requester: {
        ...p.requester,
        social_media: { ...(v as Record<string, string>) },
      },
    }),
    isValid: (p) => {
      const sm = p.requester.social_media ?? {};
      return DEMO_SOCIAL_CHANNELS.some(
        (c) => ((sm as Record<string, string>)[c] ?? '').trim() !== '',
      );
    },
  },
];

/**
 * Single entry point used by the shell to pick the right list once
 * the tenant type is known.
 */
export function questionsFor(tenant: 'school' | 'tutoring'): readonly Question[] {
  return tenant === 'tutoring' ? TUTORING_QUESTIONS : SCHOOL_QUESTIONS;
}
