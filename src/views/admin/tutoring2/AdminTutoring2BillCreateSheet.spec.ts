/**
 * Contract spec for AdminTutoring2BillCreateSheet — the manual
 * "Tambah Tagihan" form (`POST /tutoring-v2/bills`).
 *
 * What is locked here, and why each one earns a test:
 *
 *  1. THE PAYLOAD IS EXACTLY THE CONTRACT. `StoreBillRequest` requires
 *     `source_type` — it is NOT server-defaulted — and its `in:` rule
 *     accepts only the `BillSource` enum's SCREAMING_SNAKE spellings.
 *     The mobile sheet posts `bimbel_prepaid`, which that rule rejects,
 *     so "mirror mobile" had to stop at the field SET and not extend to
 *     its wire values. A test that only counted fields would not have
 *     caught it.
 *
 *  2. NO `description` KEY. The mobile form has a Deskripsi box whose
 *     value goes nowhere: no rule in `StoreBillRequest`, absent from
 *     the controller's explicit `Bill::create([…])` allowlist, no
 *     column on `bills`, no key in `BillResource`. It is omitted here
 *     on purpose, and this asserts the omission so a future "parity
 *     with mobile" pass cannot quietly re-add a field that discards
 *     what the admin types.
 *
 *  3. A CLEARED OPTIONAL FIELD IS ABSENT, NOT `''`.
 *     `bimbel_enrollment_id` is `nullable|uuid`; `''` is not a uuid, so
 *     posting one turns a field the admin deliberately left blank into
 *     a 422.
 *
 *  4. THE NOMINAL PREFILL NEVER OVERWRITES A TYPED FIGURE. A one-off
 *     bill for an amount other than the catalogue default is the
 *     ordinary reason to be on this form, so the convenience must lose
 *     to the admin every time.
 *
 *  5. ENROLMENT OPTIONS FOLLOW THE SELECTED STUDENT — including the
 *     clear on change. A pendaftaran belongs to exactly ONE student and
 *     the server validates `bimbel_enrollment_id` as a uuid and nothing
 *     more, so a stale pick would be ACCEPTED and would bill student B
 *     against student A's enrolment.
 *
 *  6. INACTIVE PAYMENT TYPES STAY LISTED, WITH THEIR STATUS SHOWN. The
 *     endpoint deliberately does not filter to active; billing a
 *     one-off against a paused type is legitimate, and a picker that
 *     silently omits rows is the harder failure to diagnose.
 *
 *  7. DUE DATE BOUNDS ARE LOCAL DATES. Pinned to Asia/Jakarta because
 *     the local and UTC forms are identical in UTC — an unpinned spec
 *     would pass against `toISOString().slice(0, 10)`.
 *
 * The real <FormField> is mounted (its <select>s and <MoneyInput> are
 * the things under test); only the teleporting Modal shell inside
 * FormSheet is stubbed, because Teleport moves it to document.body and
 * out of the wrapper.
 */
// @ts-nocheck — vitest types not installed yet
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillCreateSheet from './AdminTutoring2BillCreateSheet.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import { toLocalYmd } from '@/lib/local-date';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listPaymentTypes: vi.fn(),
    listEnrollments: vi.fn(),
    createBill: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn() },
}));

const toasts = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn() }));
vi.mock('@/composables/useToast', () => ({ useToast: () => toasts }));

// ── Fixtures ────────────────────────────────────────────────────────

const STUDENTS = [
  { id: 'st-1', school_id: 'sc-1', name: 'Aisyah Putri', student_number: 'B-001', guardian_name: 'Bu Ratna' },
  { id: 'st-2', school_id: 'sc-1', name: 'Bagus Pratama', student_number: 'B-002', guardian_name: 'Pak Yudi' },
];

const ENROLLMENTS_ST1 = [
  {
    id: 'en-1', student_id: 'st-1', program_id: 'pr-1', program_name: 'UTBK Intensif',
    learning_group_name: 'Pagi A', billing_mode: 'monthly', status: 'active', status_label: 'Aktif',
  },
];

const ENROLLMENTS_ST2 = [
  {
    id: 'en-2', student_id: 'st-2', program_id: 'pr-2', program_name: 'Kelas 9 Reguler',
    learning_group_name: 'Sore B', billing_mode: 'prepaid', status: 'active', status_label: 'Aktif',
  },
];

const PAYMENT_TYPES = [
  { id: 'pt-1', name: 'Tutoring System', amount: 350_000, period: 'monthly', status: 'active', is_default: true },
  { id: 'pt-2', name: 'Biaya Pendaftaran', amount: 150_000, period: 'once', status: 'active', is_default: false },
  // Paused on purpose — the endpoint does not filter it out, and
  // neither may the form.
  { id: 'pt-3', name: 'Paket Lama', amount: 90_000, period: 'once', status: 'inactive', is_default: false },
];

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
          common: { student: 'Siswa' },
          admin: {
            billCreate: {
              title: 'Tambah Tagihan',
              subtitle: 'Terbitkan satu tagihan manual.',
              submit: 'Simpan tagihan',
              success: 'Tagihan dibuat.',
              errorGeneric: 'Gagal membuat tagihan.',
              unnamed: 'Tanpa nama',
              loading: 'Memuat…',
              studentPh: 'Pilih siswa…',
              studentSearchLabel: 'Cari siswa',
              studentSearchPh: 'Nama, NIS, atau nama wali',
              studentsTruncated: 'Menampilkan sebagian daftar.',
              studentsEmpty: 'Tidak ada siswa aktif yang cocok.',
              enrollmentLabel: 'Pendaftaran (opsional)',
              enrollmentPh: 'Tanpa pendaftaran',
              enrollmentNeedsStudent: 'Pilih siswa dulu',
              paymentTypeLabel: 'Jenis pembayaran',
              paymentTypePh: 'Pilih jenis pembayaran…',
              ptDefault: 'BAWAAN',
              ptActive: 'AKTIF',
              ptInactive: 'NONAKTIF',
              ptNoAbility: 'Akun ini tidak bisa memuat daftar jenis pembayaran.',
              ptLoading: 'Daftar jenis pembayaran masih dimuat.',
              ptFailed: 'Daftar jenis pembayaran gagal dimuat.',
              ptEmpty: 'Belum ada jenis pembayaran di bimbel ini.',
              periodMonthly: 'Bulanan',
              periodYearly: 'Tahunan',
              periodOnce: 'Sekali bayar',
              sourceLabel: 'Sumber',
              sourcePrepaid: 'Prabayar',
              sourceMonthly: 'Bulanan (SPP)',
              sourceSession: 'Per sesi',
              amountLabel: 'Nominal (Rp)',
              amountPh: 'Contoh: 350.000',
              dueDateLabel: 'Jatuh tempo',
              errStudent: 'Pilih siswa.',
              errPaymentType: 'Pilih jenis pembayaran.',
              errAmount: 'Masukkan nominal lebih dari 0.',
              errDueDate: 'Pilih tanggal jatuh tempo.',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  // Only the teleporting shell — FormField and MoneyInput stay real.
  Modal: { template: '<div data-testid="sheet"><slot /></div>' },
  BottomSheetFooter: true,
};

async function mountSheet(props = {}) {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2BillCreateSheet, {
    props,
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const sel = (w, name) => w.find(`[data-testid="field-${name}"]`);

/** Fill every required field with something valid. */
async function fillValid(w, { amount = 350_000, dueDate = '2026-09-30' } = {}) {
  await sel(w, 'student_id').setValue('st-1');
  await flushPromises();
  await sel(w, 'payment_type_id').setValue('pt-2');
  await setAmount(w, amount);
  await sel(w, 'due_date').setValue(dueDate);
  await flushPromises();
}

/** MoneyInput is a text box with separators; type digits into it. */
async function setAmount(w, value) {
  const input = sel(w, 'amount');
  await input.setValue(String(value));
  await flushPromises();
}

/** Clicks the FormSheet's submit — the <form> submit, not the footer stub. */
async function submit(w) {
  await w.find('form').trigger('submit');
  await flushPromises();
}

const lastPayload = () => TutoringBimbelService.createBill.mock.calls.at(-1)[0];

beforeEach(() => {
  vi.clearAllMocks();
  TutoringStudentsService.list.mockResolvedValue({ items: STUDENTS, pagination: undefined });
  TutoringBimbelService.listPaymentTypes.mockResolvedValue(PAYMENT_TYPES);
  TutoringBimbelService.listEnrollments.mockResolvedValue({ items: ENROLLMENTS_ST1 });
  TutoringBimbelService.createBill.mockResolvedValue({ id: 'bi-1' });
});

// ── 1 · the wire contract ───────────────────────────────────────────

describe('the submitted payload is exactly StoreBillRequest', () => {
  it('posts the five required fields, with ids the API issued', async () => {
    const w = await mountSheet();
    await fillValid(w);
    await submit(w);

    expect(TutoringBimbelService.createBill).toHaveBeenCalledTimes(1);
    expect(lastPayload()).toEqual({
      student_id: 'st-1',
      payment_type_id: 'pt-2',
      amount: 350_000,
      due_date: '2026-09-30',
      source_type: 'TUTORING_PREPAID',
    });
  });

  it('sends source_type in the BillSource enum spelling, not the mobile one', async () => {
    const w = await mountSheet();
    await fillValid(w);
    await sel(w, 'source_type').setValue('TUTORING_MONTHLY');
    await submit(w);

    // `bimbel_monthly` — what the mobile sheet posts — fails the `in:`
    // rule outright. This must never regress to it.
    expect(lastPayload().source_type).toBe('TUTORING_MONTHLY');
    expect(lastPayload().source_type).not.toMatch(/^bimbel_/);
  });

  it('offers only the three source_type values the `in:` rule accepts', async () => {
    const w = await mountSheet();

    const values = sel(w, 'source_type')
      .findAll('option')
      .map((o) => o.element.value);
    expect(values).toEqual([
      'TUTORING_PREPAID',
      'TUTORING_MONTHLY',
      'TUTORING_SESSION',
    ]);
  });

  it('never sends `description` — the field is deliberately not on this form', async () => {
    const w = await mountSheet();
    await fillValid(w);
    await submit(w);

    expect(lastPayload()).not.toHaveProperty('description');
    // And there is no input for it to come from.
    expect(w.find('[data-testid="field-description"]').exists()).toBe(false);
  });

  it('omits a cleared optional field entirely rather than sending an empty string', async () => {
    const w = await mountSheet();
    await fillValid(w);
    // Pendaftaran deliberately left blank.
    await submit(w);

    // '' is not a uuid — sending the key at all would 422 a field the
    // admin left blank on purpose.
    expect(lastPayload()).not.toHaveProperty('bimbel_enrollment_id');
  });

  it('includes bimbel_enrollment_id once a pendaftaran IS chosen', async () => {
    const w = await mountSheet();
    await fillValid(w);
    await sel(w, 'bimbel_enrollment_id').setValue('en-1');
    await submit(w);

    expect(lastPayload().bimbel_enrollment_id).toBe('en-1');
  });

  it('refuses to post at all while a required field is missing', async () => {
    const w = await mountSheet();
    await sel(w, 'student_id').setValue(''); // nothing chosen
    await submit(w);

    expect(TutoringBimbelService.createBill).not.toHaveBeenCalled();
    expect(w.text()).toContain('Pilih siswa.');
  });
});

// ── 2 · nominal prefill ─────────────────────────────────────────────

describe('the Nominal prefill', () => {
  it('preselects the tenant default type and prefills its amount', async () => {
    const w = await mountSheet();

    expect(sel(w, 'payment_type_id').element.value).toBe('pt-1');
    expect(sel(w, 'amount').element.value).toBe('350.000');
  });

  it('replaces an amount the admin has NOT touched when the type changes', async () => {
    const w = await mountSheet();
    await sel(w, 'payment_type_id').setValue('pt-2');
    await flushPromises();

    expect(sel(w, 'amount').element.value).toBe('150.000');
  });

  it('does NOT overwrite a figure the admin typed', async () => {
    const w = await mountSheet();
    await setAmount(w, 777_000);

    await sel(w, 'payment_type_id').setValue('pt-2');
    await flushPromises();

    expect(sel(w, 'amount').element.value).toBe('777.000');
  });

  it('posts the typed figure, not the catalogue default', async () => {
    const w = await mountSheet();
    await setAmount(w, 777_000);
    await sel(w, 'payment_type_id').setValue('pt-2');
    await sel(w, 'student_id').setValue('st-1');
    await flushPromises();
    await sel(w, 'due_date').setValue('2026-09-30');
    await submit(w);

    expect(lastPayload().amount).toBe(777_000);
  });

  it('sends an integer on the wire even though the field shows separators', async () => {
    const w = await mountSheet();
    await fillValid(w, { amount: 1_250_000 });
    await submit(w);

    expect(sel(w, 'amount').element.value).toBe('1.250.000');
    expect(lastPayload().amount).toBe(1_250_000);
    expect(Number.isInteger(lastPayload().amount)).toBe(true);
  });
});

// ── 3 · pendaftaran follows the student ─────────────────────────────

describe('Pendaftaran options follow the chosen student', () => {
  it('is inert until a student is chosen, and fetches nothing', async () => {
    const w = await mountSheet();

    expect(sel(w, 'bimbel_enrollment_id').attributes('disabled')).toBeDefined();
    expect(TutoringBimbelService.listEnrollments).not.toHaveBeenCalled();
  });

  it('fetches scoped to the chosen student_id', async () => {
    const w = await mountSheet();
    await sel(w, 'student_id').setValue('st-1');
    await flushPromises();

    expect(TutoringBimbelService.listEnrollments).toHaveBeenCalledWith(
      expect.objectContaining({ student_id: 'st-1' }),
    );
    expect(sel(w, 'bimbel_enrollment_id').text()).toContain('UTBK Intensif');
  });

  it('re-fetches for the new student and CLEARS a pick that belonged to the old one', async () => {
    const w = await mountSheet();
    await sel(w, 'student_id').setValue('st-1');
    await flushPromises();
    await sel(w, 'bimbel_enrollment_id').setValue('en-1');
    expect(sel(w, 'bimbel_enrollment_id').element.value).toBe('en-1');

    TutoringBimbelService.listEnrollments.mockResolvedValue({ items: ENROLLMENTS_ST2 });
    await sel(w, 'student_id').setValue('st-2');
    await flushPromises();

    // The server validates bimbel_enrollment_id as a uuid and nothing
    // more, so a stale 'en-1' here would be ACCEPTED — billing student
    // st-2 against st-1's enrolment.
    expect(sel(w, 'bimbel_enrollment_id').element.value).toBe('');
    expect(sel(w, 'bimbel_enrollment_id').text()).not.toContain('UTBK Intensif');
    expect(sel(w, 'bimbel_enrollment_id').text()).toContain('Kelas 9 Reguler');
  });

  it('does not carry the old enrolment into the payload after a student change', async () => {
    const w = await mountSheet();
    await sel(w, 'student_id').setValue('st-1');
    await flushPromises();
    await sel(w, 'bimbel_enrollment_id').setValue('en-1');

    TutoringBimbelService.listEnrollments.mockResolvedValue({ items: ENROLLMENTS_ST2 });
    await sel(w, 'student_id').setValue('st-2');
    await flushPromises();
    await sel(w, 'payment_type_id').setValue('pt-2');
    await sel(w, 'due_date').setValue('2026-09-30');
    await flushPromises();
    await submit(w);

    expect(lastPayload().student_id).toBe('st-2');
    expect(lastPayload()).not.toHaveProperty('bimbel_enrollment_id');
  });
});

// ── 4 · the student list is searched on the SERVER ──────────────────

describe('the Siswa list', () => {
  it('asks the server for active students', async () => {
    await mountSheet();

    expect(TutoringStudentsService.list).toHaveBeenCalledWith(
      expect.objectContaining({ active: true }),
    );
  });

  it('forwards typing to the server rather than filtering the page in hand', async () => {
    const w = await mountSheet();
    TutoringStudentsService.list.mockClear();

    await sel(w, 'student_search').setValue('bagus');
    await vi.waitFor(() => {
      expect(TutoringStudentsService.list).toHaveBeenCalledWith(
        expect.objectContaining({ search: 'bagus' }),
      );
    });
  });
});

// ── 5 · payment types ───────────────────────────────────────────────

describe('the Jenis pembayaran list', () => {
  it('lists a PAUSED type rather than hiding it, and shows that it is paused', async () => {
    const w = await mountSheet();

    const labels = sel(w, 'payment_type_id')
      .findAll('option')
      .map((o) => o.text());
    const paused = labels.find((l) => l.includes('Paket Lama'));

    expect(paused).toBeDefined();
    expect(paused).toContain('NONAKTIF');
  });

  it('marks the tenant default and shows every row status', async () => {
    const w = await mountSheet();
    const labels = sel(w, 'payment_type_id')
      .findAll('option')
      .map((o) => o.text());

    expect(labels.find((l) => l.includes('Tutoring System'))).toContain('BAWAAN');
    expect(labels.find((l) => l.includes('Biaya Pendaftaran'))).toContain('AKTIF');
  });

  it('without `tutoring.payment_type.view` the field is inert and NOTHING is fetched', async () => {
    const w = await mountSheet({ canViewPaymentTypes: false });

    expect(TutoringBimbelService.listPaymentTypes).not.toHaveBeenCalled();
    expect(sel(w, 'payment_type_id').attributes('disabled')).toBeDefined();
    expect(w.text()).toContain('Akun ini tidak bisa memuat daftar jenis pembayaran.');
  });

  it('without the ability, Simpan posts nothing and says why', async () => {
    const w = await mountSheet({ canViewPaymentTypes: false });
    await sel(w, 'student_id').setValue('st-1');
    await setAmount(w, 100_000);
    await sel(w, 'due_date').setValue('2026-09-30');
    await submit(w);

    expect(TutoringBimbelService.createBill).not.toHaveBeenCalled();
    // The refusal reason is the one already on screen — the form never
    // refuses for a reason it did not show.
    expect(w.text()).toContain('Akun ini tidak bisa memuat daftar jenis pembayaran.');
  });

  it('a tenant with no payment types says so in the field', async () => {
    TutoringBimbelService.listPaymentTypes.mockResolvedValue([]);
    const w = await mountSheet();

    expect(w.text()).toContain('Belum ada jenis pembayaran di bimbel ini.');
    expect(sel(w, 'payment_type_id').attributes('disabled')).toBeDefined();
  });

  it('a failed fetch says so instead of reading as an empty catalogue', async () => {
    TutoringBimbelService.listPaymentTypes.mockRejectedValue(new Error('boom'));
    const w = await mountSheet();

    expect(w.text()).toContain('Daftar jenis pembayaran gagal dimuat.');
  });
});

// ── 6 · due date is a LOCAL date ────────────────────────────────────

describe('the Jatuh tempo bounds are local dates, not UTC-shifted ones', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    // WIB (UTC+7) — every tenant on this platform is in it, and in UTC
    // the correct and the buggy form are identical, so an unpinned spec
    // would pass against `toISOString().slice(0, 10)`.
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
    vi.useRealTimers();
  });

  it('reads the LOCAL day during the WIB morning window, when UTC still says yesterday', async () => {
    vi.useFakeTimers();
    try {
      // 2026-09-08T22:00Z === 2026-09-09 05:00 WIB. This is the exact
      // window — before 07:00 local — in which the toISOString()
      // shortcut yields YESTERDAY.
      vi.setSystemTime(new Date('2026-09-08T22:00:00Z'));

      // Premise, asserted so this cannot pass vacuously if the TZ
      // override did not take effect.
      expect(new Date().getTimezoneOffset()).toBe(-420);
      expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-08');
      expect(toLocalYmd()).toBe('2026-09-09');

      const w = await mountSheet();
      const due = sel(w, 'due_date');

      // 30 days back and a year on, from the LOCAL 9 Sep — not from the
      // UTC 8 Sep.
      expect(due.attributes('min')).toBe('2026-08-10');
      expect(due.attributes('max')).toBe('2027-09-09');
    } finally {
      vi.useRealTimers();
    }
  });

  it('posts the due date exactly as the date input reported it', async () => {
    const w = await mountSheet();
    await fillValid(w, { dueDate: '2026-12-01' });
    await submit(w);

    // A native date input emits a normalised YYYY-MM-DD in the user's
    // own calendar. It must reach the wire untouched — no Date
    // round-trip, which is where a UTC shift would creep back in.
    expect(lastPayload().due_date).toBe('2026-12-01');
  });
});

// ── 7 · outcomes ────────────────────────────────────────────────────

describe('after submit', () => {
  it('emits saved + close and toasts on success', async () => {
    const w = await mountSheet();
    await fillValid(w);
    await submit(w);

    expect(w.emitted('saved')?.[0]?.[0]).toEqual({ id: 'bi-1' });
    expect(w.emitted('close')).toBeTruthy();
    expect(toasts.success).toHaveBeenCalled();
  });

  it("surfaces the server's own 422 wording rather than a generic failure", async () => {
    TutoringBimbelService.createBill.mockRejectedValue({
      response: {
        status: 422,
        data: { message: 'The selected payment type id is invalid.' },
      },
    });
    const w = await mountSheet();
    await fillValid(w);
    await submit(w);

    expect(toasts.error).toHaveBeenCalledWith('The selected payment type id is invalid.');
    expect(w.emitted('saved')).toBeFalsy();
  });
});
