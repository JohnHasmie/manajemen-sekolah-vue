/**
 * Contract spec for AdminTutoring2PayoutRequestsView (WEB-16 / BE-25).
 *
 * Vitest API, vue-tsc-checked. Two halves:
 *
 * 1. The original contract block — pins the request status vocabulary
 *    and the row shape (crucially: `note` holds the reject reason, not a
 *    separate column).
 *
 * 2. The Tutor filter chip, added with the filter-chip fix. Its handler
 *    was `@click="tutorFilter = ''"`, which only ever CLEARS, and the
 *    chip displayed `truncateId(tutorFilter)` — an id fragment.
 *
 *    The one path that could actually set it was a raw text box in the
 *    "advanced" row, asking an admin to paste a tutor UUID — and that
 *    row was `v-if="statusFilter || tutorFilter"`, so it only appeared
 *    AFTER you toggled the unrelated Status chip. Filtering by tutor
 *    meant: toggle Status, then hand-type a UUID. That box is gone.
 *
 *    Part of the "semua button/filter tdk berfungsi" report a bimbel
 *    admin filed on prod. The real <FilterFacetPickerModal> is mounted
 *    (only its <Modal> shell is stubbed, because Modal teleports to
 *    body).
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import type { DefineComponent } from 'vue';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2PayoutRequestsView from './AdminTutoring2PayoutRequestsView.vue';
import { PayoutsService } from '@/services/tutoring2/payouts';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { PayoutRequest, PayoutRequestStatus } from '@/types/tutoring2/payout';
import { PAYOUT_REQUEST_STATUSES } from '@/types/tutoring2/payout';

vi.mock('@/services/tutoring2/payouts', () => ({
  PayoutsService: {
    listRequests: vi.fn(),
    approveRequest: vi.fn(),
    rejectRequest: vi.fn(),
    markRequestPaid: vi.fn(),
    rollbackRequest: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

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

function makeRequest(overrides = {}) {
  return {
    id: 'pq-1',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    period_month: '2026-08',
    amount: 1_500_000,
    status: 'pending',
    requested_at: '2026-08-15T09:00:00+07:00',
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
          common: { all: 'Semua', tutor: 'Tutor', status: 'Status', period: 'Periode' },
          admin: {
            payoutRequests: {
              status: {
                pending: 'Menunggu',
                approved: 'Disetujui',
                paid: 'Dibayar',
                rejected: 'Ditolak',
                rolled_back: 'Dikembalikan',
              },
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
  const w = mount(AdminTutoring2PayoutRequestsView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        FormField: true,
        FormSheet: true,
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
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Chips render in template order: status, period, tutor. */
const CHIP = { status: 0, period: 1, tutor: 2 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListRequestsArg() {
  const calls = (PayoutsService.listRequests as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2PayoutRequestsView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2PayoutRequestsView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('knows all five backend statuses (rolled_back included)', () => {
    const expected: PayoutRequestStatus[] = ['pending', 'approved', 'rejected', 'paid', 'rolled_back'];
    expect(PAYOUT_REQUEST_STATUSES).toEqual(expected);
  });

  it('rejects surface the reason on `note`, payment info on payment_reference', () => {
    // The BE stores the reject reason on the shared `note` column and
    // the payment reference on its own. Two rows below encode that
    // assumption so a schema drift shows up as a compile error.
    const rejected: PayoutRequest = {
      id: 'q-1',
      tutor_id: 't-1',
      period_month: '2026-07',
      amount: 900_000,
      status: 'rejected',
      note: 'Sesi bulan ini belum semua tercatat.',
    };
    const paid: PayoutRequest = {
      id: 'q-2',
      tutor_id: 't-2',
      period_month: '2026-07',
      amount: 750_000,
      status: 'paid',
      payment_reference: 'TRF-9911',
    };
    expect(rejected.note).toContain('Sesi');
    expect(paid.payment_reference).toBe('TRF-9911');
  });
});

describe('AdminTutoring2PayoutRequestsView Tutor chip', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (PayoutsService.listRequests as any).mockResolvedValue({
      items: [makeRequest()],
      pagination: undefined,
    });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('loads the tutor option list on mount', async () => {
    await mountView();

    expect(TutoringTutorsService.list).toHaveBeenCalledTimes(1);
  });

  it('starts at "Semua" and is enabled once options arrive', async () => {
    const w = await mountView();
    const chip = w.findAll('[data-testid="chip"]')[CHIP.tutor];

    expect(chip.text()).toBe('Semua');
    expect(chip.attributes('disabled')).toBeUndefined();
  });

  it('clicking the chip OPENS a picker listing tutors by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — the old handler only cleared.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('Pak Rahmat');
    expect(labels.join(' ')).toContain('Bu Sinta');
  });

  it('picking a tutor re-queries with tutor_id and shows their name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click'); // row 0 = "Semua", row 2 = tu-2
    await flushPromises();

    expect(lastListRequestsArg().tutor_id).toBe('tu-2');
    const chip = w.findAll('[data-testid="chip"]')[CHIP.tutor];
    expect(chip.text()).toBe('Bu Sinta');
    expect(chip.text()).not.toContain('tu-2');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListRequestsArg().tutor_id).toBe('tu-2');

    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListRequestsArg().tutor_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.tutor].text()).toBe('Semua');
  });

  it('filtering by tutor no longer requires touching the Status chip first', async () => {
    // The old flow: the tutor text box lived in a row rendered
    // `v-if="statusFilter || tutorFilter"`, so a tutor filter was only
    // reachable after toggling Status. Status must stay untouched here.
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[1].trigger('click'); // tu-1
    await flushPromises();

    expect(lastListRequestsArg().tutor_id).toBe('tu-1');
    expect(lastListRequestsArg().status).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Semua');
  });

  it('offers no free-text UUID box for the tutor filter', async () => {
    const w = await mountView();

    // The advanced row is status-only now, and hidden until Status is set.
    expect(w.findAll('input[type="text"]')).toHaveLength(0);
  });

  it('an empty tutor list disables the chip but leaves the toggles alone', async () => {
    (TutoringTutorsService.list as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.tutor].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.period].attributes('disabled')).toBeUndefined();
  });

  it('a failing tutor endpoint does not blank the other chips or the list', async () => {
    (TutoringTutorsService.list as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.tutor].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
    expect(PayoutsService.listRequests).toHaveBeenCalled();
  });
});
