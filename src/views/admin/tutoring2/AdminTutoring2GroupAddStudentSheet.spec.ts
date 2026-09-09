/**
 * Vitest spec for AdminTutoring2GroupAddStudentSheet — the "Tambah
 * siswa" form on the admin group drill-in.
 *
 * Why each block earns its place:
 *
 *   • PAYLOAD. `createEnrollment` is typed `Partial<BimbelEnrollment>`,
 *     so TypeScript checks nothing about the field set — every required
 *     field is a runtime-only contract with `StoreEnrollmentRequest`.
 *     `program_id` in particular is never asked for on screen; it is
 *     lifted off the group, and `CreateEnrollmentAction` rejects the
 *     pair if it drifts ("Kelompok bukan milik program ini."). A test
 *     is the only thing holding that wire together.
 *
 *   • OPTIONAL FIELDS ARE OMITTED, NOT EMPTY-STRINGED. `package_id` is
 *     `nullable|uuid` server-side and `''` is not a uuid — sending one
 *     turns "no paket chosen" into a 422 on a field left blank on
 *     purpose. Same trap AdminTutoring2BillCreateSheet documents for
 *     `bimbel_enrollment_id`.
 *
 *   • ALREADY-ENROLLED EXCLUSION. This is the whole duplicate defence.
 *     The server's only duplicate guard fires when the NEW row would be
 *     `active`, and this sheet creates `trial` rows, so posting the same
 *     student twice would SUCCEED and put two rows for one person on the
 *     roster. Nothing server-side stops it; these assertions are the
 *     stop. The graduated/withdrawn counterpart is what keeps the fix
 *     from lying in the other direction — re-enrolling a returning
 *     student is a real flow and must stay possible.
 *
 *   • BILLING MODE. Required with no server default and no derivable
 *     answer; the sheet must refuse to submit without it rather than
 *     invent a payment arrangement. When a package IS chosen, the mode
 *     list narrows to that package's `allowed_billing_modes`, because
 *     anything else is a guaranteed 422.
 *
 *   • 422 PASS-THROUGH. The server's rejections are already plain
 *     Indonesian ("Kelompok penuh (8 / 10)."). They must reach the admin
 *     verbatim instead of collapsing into a generic failure.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupAddStudentSheet from './AdminTutoring2GroupAddStudentSheet.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringStudentsService } from '@/services/tutoring2/students';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listPackages: vi.fn(),
    createEnrollment: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn() },
}));

const toasts = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }));
vi.mock('@/composables/useToast', () => ({ useToast: () => toasts }));

const GROUP = {
  id: 'gr-1',
  program_id: 'pr-1',
  program_name: 'Intensif UTBK',
  name: 'UTBK Pagi A',
  kind: 'group',
  capacity: 12,
  status: 'active',
};

const STUDENTS = [
  { id: 'st-1', school_id: 'sc-1', name: 'Andi Wijaya', student_number: '2401' },
  { id: 'st-2', school_id: 'sc-1', name: 'Budi Santoso', student_number: '2402' },
  { id: 'st-3', school_id: 'sc-1', name: 'Citra Dewi', student_number: '2403' },
];

const PACKAGES = [
  {
    id: 'pk-1',
    program_id: 'pr-1',
    name: 'Paket 12 sesi',
    price: 1_200_000,
    total_sessions: 12,
    allowed_billing_modes: ['prepaid', 'per_session'],
    status: 'active',
  },
  {
    id: 'pk-2',
    program_id: 'pr-1',
    name: 'Paket bulanan',
    price: 500_000,
    total_sessions: null,
    allowed_billing_modes: ['monthly'],
    status: 'active',
  },
];

/** A roster row. `status` is what the exclusion rule reads. */
function enrollment(studentId, status, overrides = {}) {
  return {
    id: `en-${studentId}-${status}`,
    student_id: studentId,
    student_name: studentId,
    program_id: 'pr-1',
    learning_group_id: 'gr-1',
    billing_mode: 'prepaid',
    status,
    ...overrides,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    missingWarn: false,
    fallbackWarn: false,
    messages: {
      id: {
        tutoring2: {
          common: { student: 'Siswa', billingMode: 'Mode tagihan', startDate: 'Tanggal mulai' },
          admin: {
            groupAddStudent: {
              title: 'Tambah siswa ke kelompok',
              subtitle: 'Siswa didaftarkan langsung ke {group}.',
              submit: 'Tambahkan',
              studentSearchLabel: 'Cari siswa',
              studentSearchPh: 'Nama…',
              studentPh: 'Pilih siswa',
              studentsNone: 'Tidak ada siswa yang bisa ditambahkan.',
              studentsAlreadyEnrolled: '{count} siswa disembunyikan.',
              studentsTruncated: 'Daftar dibatasi 50 siswa pertama.',
              loading: 'Memuat siswa…',
              unnamed: 'Tanpa nama',
              packageLabel: 'Paket (opsional)',
              packagePh: 'Tanpa paket',
              billingModePh: 'Pilih mode tagihan',
              billingPrepaid: 'Prabayar',
              billingMonthly: 'SPP bulanan',
              billingPerSession: 'Per sesi',
              monthlyRateHint: 'SPP bulanan tidak mengambil tarif dari paket.',
              trialNote: 'Siswa ditambahkan dengan status Trial.',
              errStudent: 'Pilih siswa terlebih dahulu.',
              errBillingMode: 'Pilih mode tagihan terlebih dahulu.',
              success: 'Siswa ditambahkan ke kelompok.',
              errorGeneric: 'Gagal menambahkan siswa. Coba lagi.',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  // Only the teleporting shell — FormField and FormSheet stay real.
  Modal: { template: '<div data-testid="sheet"><slot /></div>' },
  BottomSheetFooter: true,
};

async function mountSheet(props = {}) {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2GroupAddStudentSheet, {
    props: { group: GROUP, roster: [], ...props },
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const sel = (w, name) => w.find(`[data-testid="field-${name}"]`);
const optionValues = (w, name) =>
  sel(w, name)
    .findAll('option')
    .map((o) => o.attributes('value'))
    .filter((v) => v !== '');

async function submit(w) {
  await w.find('form').trigger('submit');
  await flushPromises();
}

const lastPayload = () => TutoringBimbelService.createEnrollment.mock.calls.at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
  TutoringStudentsService.list.mockResolvedValue({ items: STUDENTS, pagination: undefined });
  TutoringBimbelService.listPackages.mockResolvedValue({ items: PACKAGES, pagination: undefined });
  TutoringBimbelService.createEnrollment.mockResolvedValue({
    id: 'en-new',
    student_id: 'st-1',
    program_id: 'pr-1',
    learning_group_id: 'gr-1',
    billing_mode: 'prepaid',
    status: 'trial',
  });
});

describe('AdminTutoring2GroupAddStudentSheet · payload', () => {
  it('posts the three required fields, with program_id taken from the group', async () => {
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-2');
    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    expect(TutoringBimbelService.createEnrollment).toHaveBeenCalledTimes(1);
    expect(lastPayload()).toMatchObject({
      student_id: 'st-2',
      // Never asked on screen — lifted off the group, and the server
      // rejects the pair if it drifts.
      program_id: 'pr-1',
      learning_group_id: 'gr-1',
      billing_mode: 'prepaid',
    });
  });

  it('OMITS package_id and start_date when left blank, rather than sending ""', async () => {
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    const payload = lastPayload();
    expect('package_id' in payload).toBe(false);
    expect('start_date' in payload).toBe(false);
  });

  it('sends package_id and start_date when they are filled', async () => {
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await sel(w, 'package_id').setValue('pk-1');
    await flushPromises();
    await sel(w, 'billing_mode').setValue('prepaid');
    await sel(w, 'start_date').setValue('2026-09-15');
    await flushPromises();
    await submit(w);

    expect(lastPayload()).toMatchObject({
      package_id: 'pk-1',
      start_date: '2026-09-15',
    });
  });

  it('emits saved + close and toasts success', async () => {
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    expect(w.emitted('saved')).toHaveLength(1);
    expect(w.emitted('close')).toHaveLength(1);
    expect(toasts.success).toHaveBeenCalledWith('Siswa ditambahkan ke kelompok.');
  });

  it('loads packages for THIS group’s program', async () => {
    await mountSheet();
    expect(TutoringBimbelService.listPackages).toHaveBeenCalledWith(
      'pr-1',
      expect.objectContaining({ status: 'active' }),
    );
  });
});

describe('AdminTutoring2GroupAddStudentSheet · already enrolled', () => {
  it('hides students who already hold a trial / active / paused enrollment here', async () => {
    const w = await mountSheet({
      roster: [
        enrollment('st-1', 'active'),
        enrollment('st-2', 'trial'),
        enrollment('st-3', 'paused'),
      ],
    });

    expect(optionValues(w, 'student_id')).toEqual([]);
    expect(w.find('[data-testid="students-none"]').exists()).toBe(true);
  });

  it('says how many it hid, so the list is not silently short', async () => {
    const w = await mountSheet({ roster: [enrollment('st-1', 'active')] });

    expect(optionValues(w, 'student_id')).toEqual(['st-2', 'st-3']);
    expect(w.find('[data-testid="students-already-enrolled"]').text()).toContain('1 siswa');
  });

  it('KEEPS graduated and withdrawn students pickable — that membership ended', async () => {
    const w = await mountSheet({
      roster: [enrollment('st-1', 'graduated'), enrollment('st-2', 'withdrawn')],
    });

    // All three remain: a returning student must be re-enrollable.
    expect(optionValues(w, 'student_id')).toEqual(['st-1', 'st-2', 'st-3']);
    expect(w.find('[data-testid="students-already-enrolled"]').exists()).toBe(false);
  });
});

describe('AdminTutoring2GroupAddStudentSheet · billing mode', () => {
  it('refuses to submit without one, rather than inventing a payment arrangement', async () => {
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await flushPromises();
    await submit(w);

    expect(TutoringBimbelService.createEnrollment).not.toHaveBeenCalled();
    expect(w.text()).toContain('Pilih mode tagihan terlebih dahulu.');
  });

  it('refuses to submit without a student', async () => {
    const w = await mountSheet();

    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    expect(TutoringBimbelService.createEnrollment).not.toHaveBeenCalled();
    expect(w.text()).toContain('Pilih siswa terlebih dahulu.');
  });

  it('offers all three modes when no package is chosen', async () => {
    const w = await mountSheet();
    expect(optionValues(w, 'billing_mode')).toEqual(['prepaid', 'monthly', 'per_session']);
  });

  it("narrows to the chosen package's allowed_billing_modes", async () => {
    const w = await mountSheet();

    await sel(w, 'package_id').setValue('pk-1');
    await flushPromises();

    expect(optionValues(w, 'billing_mode')).toEqual(['prepaid', 'per_session']);
  });

  it('clears a mode the newly-chosen package forbids instead of posting a 422', async () => {
    const w = await mountSheet();

    await sel(w, 'billing_mode').setValue('monthly');
    await flushPromises();
    await sel(w, 'package_id').setValue('pk-1'); // prepaid / per_session only
    await flushPromises();
    await submit(w);

    expect(TutoringBimbelService.createEnrollment).not.toHaveBeenCalled();
    expect(w.text()).toContain('Pilih mode tagihan terlebih dahulu.');
  });

  it('warns that a monthly enrollment carries no rate and so generates no bill', async () => {
    const w = await mountSheet();

    expect(w.find('[data-testid="monthly-rate-warning"]').exists()).toBe(false);
    await sel(w, 'billing_mode').setValue('monthly');
    await flushPromises();
    expect(w.find('[data-testid="monthly-rate-warning"]').exists()).toBe(true);
  });
});

describe('AdminTutoring2GroupAddStudentSheet · server rejections', () => {
  it('shows a full-group 422 in the server’s own Indonesian', async () => {
    TutoringBimbelService.createEnrollment.mockRejectedValue({
      response: {
        status: 422,
        data: {
          message: 'Kelompok penuh (12 / 12).',
          errors: { learning_group_id: ['Kelompok penuh (12 / 12).'] },
        },
      },
    });
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    expect(toasts.error).toHaveBeenCalledWith('Kelompok penuh (12 / 12).');
    expect(w.emitted('saved')).toBeFalsy();
    expect(w.emitted('close')).toBeFalsy();
  });

  it('shows the duplicate-active 422 verbatim too', async () => {
    TutoringBimbelService.createEnrollment.mockRejectedValue({
      response: {
        status: 422,
        data: { message: 'Siswa sudah punya pendaftaran aktif di program ini.' },
      },
    });
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    expect(toasts.error).toHaveBeenCalledWith(
      'Siswa sudah punya pendaftaran aktif di program ini.',
    );
  });

  it('falls back to its own copy on a 500, whose body describes internals', async () => {
    TutoringBimbelService.createEnrollment.mockRejectedValue({
      response: { status: 500, data: { message: 'Server Error' } },
    });
    const w = await mountSheet();

    await sel(w, 'student_id').setValue('st-1');
    await sel(w, 'billing_mode').setValue('prepaid');
    await flushPromises();
    await submit(w);

    expect(toasts.error).toHaveBeenCalledWith('Gagal menambahkan siswa. Coba lagi.');
  });
});

describe('shipped copy', () => {
  it.each(['id', 'en'])('%s carries every groupAddStudent key the sheet reads', async (loc) => {
    const messages = (await import(`@/locales/${loc}.json`)).default;
    const section = messages.tutoring2.admin.groupAddStudent;
    for (const key of [
      'title',
      'subtitle',
      'submit',
      'studentSearchLabel',
      'studentSearchPh',
      'studentPh',
      'studentsNone',
      'studentsAlreadyEnrolled',
      'studentsTruncated',
      'loading',
      'unnamed',
      'packageLabel',
      'packagePh',
      'billingModePh',
      'billingPrepaid',
      'billingMonthly',
      'billingPerSession',
      'monthlyRateHint',
      'trialNote',
      'errStudent',
      'errBillingMode',
      'success',
      'errorGeneric',
    ]) {
      expect(typeof section[key], `${loc}.${key}`).toBe('string');
      expect(section[key].length).toBeGreaterThan(0);
    }
    expect(typeof messages.tutoring2.admin.groupDetail.addStudentCta).toBe('string');
  });
});
