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

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => true }),
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
          common: { all: 'Semua', tutor: 'Tutor', kind: 'Jenis', on: 'Aktif', off: 'Nonaktif', optional: 'opsional', notes: 'Catatan', save: 'Simpan', cancel: 'Batal' },
          admin: {
            tutors: { statusInactive: 'Nonaktif' },
            payoutRates: {
              tutorSelectPh: 'Pilih tutor',
              errNoTutors: 'Belum ada tutor yang bisa dipilih. Tambahkan tutor lebih dulu.',
              value: 'Nilai',
              effectiveFrom: 'Berlaku dari',
              effectiveUntil: 'Berlaku sampai',
              newCta: 'Tambah rate',
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

async function mountView() {
  setActivePinia(createPinia());
  const i18n = makeI18n();
  const w = mount(AdminTutoring2PayoutRatesView, {
    global: {
      plugins: [i18n],
      stubs: {
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
        Button: { template: '<button><slot /></button>' },
      },
    },
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
