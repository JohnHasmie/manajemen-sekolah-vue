/**
 * Contract spec for AdminTutoring2PayoutRatesView (WEB-16 / BE-24).
 *
 * Two halves:
 *
 * 1. The original contract block — pins the enum vocabulary and rate row
 *    shape the view depends on. Any drift there (renaming a rate kind,
 *    adding a status label without a `.kind.` translation) breaks the
 *    compile.
 *
 * 2. The tutor field on "Tambah rate", added with the UUID-box fix. It
 *    used to be `type="text"` with the placeholder "UUID tutor (BE-1x
 *    sedang menyiapkan picker)": a REQUIRED field on a form the admin
 *    cannot submit without it, asking them to paste a UUID no screen
 *    hands them. Same "control that lies" family as MRs !1191/!1195/
 *    !1196/!1197, but a create form rather than a filter chip.
 *
 *    The REAL <FormField> is mounted (not stubbed) so the assertions read
 *    the <select> and its <option>s an admin actually sees. Only the
 *    teleporting Modal shell that FormSheet wraps itself in is stubbed,
 *    because Teleport moves it to document.body and out of the wrapper.
 *
 * 3. Detail + Ubah per row (Slack 1788512017.568729). The "Aksi" column
 *    shipped with ONE button gated on `isRateLive`, so on a list of
 *    historical rates it was a header over nothing — and a rate's catatan
 *    could not be read at all, nor amended without re-typing the whole
 *    thing into the create sheet. The locked-field assertions are the
 *    load-bearing ones: the write is an upsert keyed on
 *    (tutor_id, kind, effective_from), so an editable key field would not
 *    move the rate, it would fork honorarium history into a second row.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import type { DefineComponent } from 'vue';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2PayoutRatesView from './AdminTutoring2PayoutRatesView.vue';
import { PayoutsService } from '@/services/tutoring2/payouts';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { PayoutRate, PayoutRateKind } from '@/types/tutoring2/payout';
import { PAYOUT_RATE_KINDS } from '@/types/tutoring2/payout';

vi.mock('@/services/tutoring2/payouts', () => ({
  PayoutsService: {
    listRates: vi.fn(),
    upsertRate: vi.fn(),
    endRate: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

// No useAcademicYearWatcher mock: !1193 removed that call from this view
// (useDataRefresh already reacts to the year), so mocking it here would be
// dead weight that quietly tolerates its re-introduction.

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

// Flippable so the `tutoring.payout.rates.manage` gate on Ubah can be
// exercised without re-importing the SFC (which would hand the component
// a different PayoutsService instance than the one this file stubs).
const abilities = vi.hoisted(() => ({ canManage: true }));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => abilities.canManage }),
}));

const TUTORS = [
  { id: 'tu-1', user_id: 'us-1', name: 'Pak Rahmat', is_active: true, active_group_count: 2 },
  { id: 'tu-2', user_id: 'us-2', name: 'Bu Sinta', is_active: true, active_group_count: 1 },
];

function makeRate(overrides = {}) {
  return {
    id: 'ra-1',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    kind: 'per_session',
    value: 75_000,
    effective_from: '2026-01-01',
    effective_until: null,
    notes: null,
    ...overrides,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', tutor: 'Tutor', kind: 'Jenis', on: 'Aktif', off: 'Nonaktif', optional: 'opsional', notes: 'Catatan', save: 'Simpan', cancel: 'Batal', detail: 'Detail', edit: 'Ubah', actions: 'Aksi' },
          admin: {
            tutors: { statusInactive: 'Nonaktif' },
            payoutRates: {
              tutorSelectPh: 'Pilih tutor',
              errNoTutors: 'Belum ada tutor yang bisa dipilih. Tambahkan tutor lebih dulu.',
              value: 'Nilai',
              effectiveFrom: 'Berlaku dari',
              effectiveUntil: 'Berlaku sampai',
              newCta: 'Tambah rate',
              endCta: 'Akhiri',
              sheetTitle: 'Set rate honor',
              sheetSubtitle: 'Rate berlaku sejak tanggal terpilih.',
              sheetEditTitle: 'Ubah rate honor',
              sheetEditSubtitle: 'Nilai, tanggal berakhir, dan catatan bisa diubah.',
              editLockedHint: 'Tutor, jenis, dan tanggal berlaku sejak dikunci saat mengubah.',
              createdAt: 'Dibuat',
              updatedAt: 'Diperbarui',
              filterActiveOnly: 'Hanya aktif',
              kind: {
                per_session: 'Per sesi',
                monthly_salary: 'Gaji bulanan',
                percent_revenue: 'Persen omzet',
              },
              status: { live: 'Berlaku', future: 'Akan datang', ended: 'Berakhir' },
              hintPerSession: 'Rupiah per sesi',
              hintMonthly: 'Rupiah per bulan',
              hintPercent: 'Persen 1-100',
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

const STUBS = {
  BrandPageHeader: true,
  KpiStripCards: true,
  StatusBadge: true,
  ConfirmationDialog: true,
  PageFilterToolbar: {
    template: '<div data-testid="toolbar"><slot name="chips" /></div>',
  },
  AppFilterChip: {
    props: ['label', 'value', 'iconName', 'active', 'disabled'],
    emits: ['click'],
    template:
      '<button data-testid="chip" :disabled="disabled" @click="$emit(\'click\')">{{ value }}</button>',
  },
  AsyncView: {
    props: ['state'],
    template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
  },
  // FormField is NOT stubbed — the <select> it renders is the thing
  // under test. Only the teleporting Modal shell inside FormSheet
  // is replaced, so the sheet's fields stay inside the wrapper.
  Modal: { template: '<div data-testid="sheet"><slot /></div>' },
  BottomSheetFooter: true,
  // v-bind="$attrs" so the @click on <Button> (which lands in attrs,
  // the stub declaring no emits) reaches the root element, and so
  // data-testid survives onto it.
  Button: { template: '<button v-bind="$attrs"><slot /></button>' },
};

async function mountView() {
  setActivePinia(createPinia());
  const i18n = makeI18n();
  const w = mount(AdminTutoring2PayoutRatesView, {
    global: { plugins: [i18n], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

/** Opens the "Tambah rate" sheet via the floating CTA. */
async function openSheet(w) {
  const fab = w.findAll('button').find((b) => b.text().includes('Tambah rate'));
  await fab.trigger('click');
  await flushPromises();
}

function tutorSelect(w) {
  return w.find('[data-testid="field-tutor_id"]');
}

describe('AdminTutoring2PayoutRatesView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2PayoutRatesView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('recognises the three backend rate kinds', () => {
    const expected: PayoutRateKind[] = ['per_session', 'monthly_salary', 'percent_revenue'];
    expect(PAYOUT_RATE_KINDS).toEqual(expected);
  });

  it('accepts a rate row with optional whenLoaded tutor_name', () => {
    const _row: PayoutRate = {
      id: 'r-1',
      tutor_id: 't-1',
      tutor_name: 'Bu Rina',
      kind: 'per_session',
      value: 75_000,
      effective_from: '2026-08-01',
      effective_until: null,
    };
    expect(_row.kind).toBe('per_session');
  });
});

describe('AdminTutoring2PayoutRatesView tutor field', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    abilities.canManage = true;
    (PayoutsService.listRates as any).mockResolvedValue({
      items: [makeRate()],
      pagination: undefined,
    });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('loads the tutor list on mount', async () => {
    await mountView();

    expect(TutoringTutorsService.list).toHaveBeenCalledTimes(1);
  });

  it('renders a SELECT for the tutor, not a free-text box', async () => {
    const w = await mountView();
    await openSheet(w);

    const field = tutorSelect(w);
    expect(field.exists()).toBe(true);
    // This is the regression: it used to be <input type="text">.
    expect(field.element.tagName).toBe('SELECT');
  });

  it('lists tutors by NAME with a "Pilih tutor" placeholder row', async () => {
    const w = await mountView();
    await openSheet(w);

    const labels = tutorSelect(w).findAll('option').map((o) => o.text());
    expect(labels[0]).toBe('Pilih tutor');
    expect(labels).toContain('Pak Rahmat');
    expect(labels).toContain('Bu Sinta');
  });

  it('carries tutor ids as option VALUES so the payload stays an id', async () => {
    const w = await mountView();
    await openSheet(w);

    const values = tutorSelect(w).findAll('option').map((o) => o.element.value);
    expect(values).toEqual(['', 'tu-1', 'tu-2']);
  });

  it('submits the picked tutor id — admin picks a name, BE gets the uuid', async () => {
    (PayoutsService.upsertRate as any).mockResolvedValue(makeRate());
    const w = await mountView();
    await openSheet(w);

    await tutorSelect(w).setValue('tu-2');
    // A rate also needs a positive value before submitSheet will proceed.
    await w.find('input[type="number"]').setValue('90000');
    await flushPromises();

    await w.findComponent({ name: 'FormSheet' }).vm.$emit('save');
    await flushPromises();

    expect(PayoutsService.upsertRate).toHaveBeenCalledTimes(1);
    expect((PayoutsService.upsertRate as any).mock.calls[0][0].tutor_id).toBe('tu-2');
  });

  it('labels an inactive tutor instead of hiding them', async () => {
    // A rate can legitimately be recorded for someone deactivated after
    // the period it covers, so they stay pickable — but visibly marked.
    (TutoringTutorsService.list as any).mockResolvedValue({
      items: [TUTORS[0], { ...TUTORS[1], is_active: false }],
    });

    const w = await mountView();
    await openSheet(w);

    const labels = tutorSelect(w).findAll('option').map((o) => o.text());
    expect(labels).toContain('Pak Rahmat');
    expect(labels).toContain('Bu Sinta (Nonaktif)');
  });

  it('an empty tutor list disables the field and SAYS why', async () => {
    (TutoringTutorsService.list as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    await openSheet(w);

    expect(tutorSelect(w).attributes('disabled')).toBeDefined();
    // The reason must be readable on the form, not only a hover tooltip.
    expect(w.find('[data-testid="sheet"]').text()).toContain('Belum ada tutor');
  });

  it('a failing tutor endpoint disables the field without killing the rate table', async () => {
    (TutoringTutorsService.list as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    await openSheet(w);

    expect(tutorSelect(w).attributes('disabled')).toBeDefined();
    // The list itself must still have loaded — an options failure is not
    // a data failure.
    expect(PayoutsService.listRates).toHaveBeenCalled();
    expect(w.find('[data-testid="async"]').text()).toContain('Pak Rahmat');
  });
});

/**
 * Per-row Detail + Ubah — the Slack report (1788512017.568729):
 * "di list honor tidak ada detail honor dan edit honor".
 */
describe('AdminTutoring2PayoutRatesView row actions', () => {
  /** A rate that already ENDED — the row whose "Aksi" cell was blank. */
  const ENDED = makeRate({
    id: 'ra-old',
    effective_from: '2020-01-01',
    effective_until: '2020-06-30',
    notes: 'Naik dari 60rb setelah evaluasi semester.',
    created_at: '2020-01-01T03:00:00+07:00',
    updated_at: '2020-02-02T03:00:00+07:00',
  });

  beforeEach(() => {
    vi.clearAllMocks();
    abilities.canManage = true;
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
    (PayoutsService.listRates as any).mockResolvedValue({ items: [ENDED], pagination: undefined });
  });

  function rowLabels(w) {
    return w.findAll('[data-testid="async"] button').map((b) => b.text());
  }

  it('offers Detail and Ubah on a row whose rate already ENDED', async () => {
    // Before the fix this cell rendered nothing at all: its only control
    // was gated on isRateLive, and this rate is not live.
    const w = await mountView();

    const labels = rowLabels(w);
    expect(labels).toContain('Detail');
    expect(labels).toContain('Ubah');
    // Akhiri stays live-only — an ended rate cannot be ended again.
    expect(labels).not.toContain('Akhiri');
  });

  it('Detail reveals notes + audit timestamps already in the list payload', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="detail-panel-ra-old"]').exists()).toBe(false);

    await w.find('[data-testid="detail-ra-old"]').trigger('click');
    await flushPromises();

    const panel = w.find('[data-testid="detail-panel-ra-old"]');
    expect(panel.exists()).toBe(true);
    expect(panel.text()).toContain('Naik dari 60rb');
    expect(panel.text()).toContain('Dibuat');
    // No second request: the row already carried all of it.
    expect(PayoutsService.listRates).toHaveBeenCalledTimes(1);
  });

  it('Detail toggles back closed', async () => {
    const w = await mountView();
    await w.find('[data-testid="detail-ra-old"]').trigger('click');
    await flushPromises();
    await w.find('[data-testid="detail-ra-old"]').trigger('click');
    await flushPromises();

    expect(w.find('[data-testid="detail-panel-ra-old"]').exists()).toBe(false);
  });

  it('Ubah prefills the sheet from the row instead of opening it blank', async () => {
    const w = await mountView();
    await w.find('[data-testid="edit-ra-old"]').trigger('click');
    await flushPromises();

    expect((w.find('[data-testid="field-tutor_id"]').element as any).value).toBe('tu-1');
    expect((w.find('[data-testid="field-kind"]').element as any).value).toBe('per_session');
    expect((w.find('[data-testid="field-effective_from"]').element as any).value).toBe('2020-01-01');
    expect((w.find('input[type="number"]').element as any).value).toBe('75000');
    // Title read off the component: the Modal stub does not render props.
    expect(w.findComponent({ name: 'FormSheet' }).props('title')).toBe('Ubah rate honor');
  });

  it('LOCKS the three upsert key fields in edit mode so a save cannot fork history', async () => {
    // POST /rates is updateOrCreate on (tutor_id, kind, effective_from).
    // Were any of those editable, saving would leave the original row
    // untouched and live and mint a SECOND rate beside it.
    const w = await mountView();
    await w.find('[data-testid="edit-ra-old"]').trigger('click');
    await flushPromises();

    expect(w.find('[data-testid="field-tutor_id"]').attributes('disabled')).toBeDefined();
    expect(w.find('[data-testid="field-kind"]').attributes('disabled')).toBeDefined();
    expect(w.find('[data-testid="field-effective_from"]').attributes('disabled')).toBeDefined();
    // Locked with no explanation is its own lying control.
    expect(w.find('[data-testid="sheet"]').text()).toContain('dikunci');
  });

  it('leaves the CREATE sheet fully editable — the lock is edit-only', async () => {
    const w = await mountView();
    await openSheet(w);

    expect(w.find('[data-testid="field-tutor_id"]').attributes('disabled')).toBeUndefined();
    expect(w.find('[data-testid="field-kind"]').attributes('disabled')).toBeUndefined();
    expect(w.find('[data-testid="field-effective_from"]').attributes('disabled')).toBeUndefined();
    expect(w.find('[data-testid="sheet"]').text()).not.toContain('dikunci');
    expect(w.findComponent({ name: 'FormSheet' }).props('title')).toBe('Set rate honor');
  });

  it('resubmits the SAME key tuple so the backend upserts the existing row', async () => {
    (PayoutsService.upsertRate as any).mockResolvedValue(ENDED);

    const w = await mountView();
    await w.find('[data-testid="edit-ra-old"]').trigger('click');
    await flushPromises();

    await w.find('input[type="number"]').setValue('90000');
    await w.findComponent({ name: 'FormSheet' }).vm.$emit('save');
    await flushPromises();

    const payload = (PayoutsService.upsertRate as any).mock.calls[0][0];
    expect(payload.tutor_id).toBe('tu-1');
    expect(payload.kind).toBe('per_session');
    expect(payload.effective_from).toBe('2020-01-01');
    expect(payload.value).toBe(90000);
  });

  it('reopening CREATE after an edit clears the prefill', async () => {
    const w = await mountView();
    await w.find('[data-testid="edit-ra-old"]').trigger('click');
    await flushPromises();
    await w.findComponent({ name: 'FormSheet' }).vm.$emit('cancel');
    await flushPromises();

    await openSheet(w);
    expect((w.find('[data-testid="field-tutor_id"]').element as any).value).toBe('');
  });

  it('hides Ubah without the manage ability but keeps Detail', async () => {
    // Reads are not writes: viewing a rate must survive the gate that
    // hides every write control.
    abilities.canManage = false;

    const w = await mountView();

    const labels = rowLabels(w);
    expect(labels).toContain('Detail');
    expect(labels).not.toContain('Ubah');
  });
});
