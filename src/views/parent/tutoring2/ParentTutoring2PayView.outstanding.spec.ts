/**
 * The reported bug, pinned: "pada tagihan kenapa hanya ada 1 anak saja,
 * padahal punya 2 anak".
 *
 * This screen is an aggregate ACROSS a wali's children, and its child
 * list is derived from the bills it fetched (`uniqueChildren` is a Set
 * over `student_id`). It asked the server for `status=unpaid`, and
 * `Tutoring\BillController::index` matches that parameter EXACTLY
 * against one value with no whitelist:
 *
 *   ->when($request->filled('status'),
 *          fn ($b) => $b->where('status', $request->string('status')))
 *
 * So a child whose bills were all `pending` — the wali had uploaded a
 * transfer receipt and was waiting for an admin to verify it — produced
 * no rows, and with no rows the CHILD vanished from the screen too.
 *
 * The counters were wrong in the same breath, because every one of them
 * is computed over the filtered list: the "Anak" KPI, the "{children}
 * anak · {count} tagihan" header, the bill count, and the "Belum lunas"
 * rupiah TOTAL — which understated what the family owed.
 */
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2PayView from './ParentTutoring2PayView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listBills: vi.fn(), getBill: vi.fn() },
}));
vi.mock('@/services/tutoring2/billing-settings', () => ({
  TutoringBillingSettingsService: { getPaymentAccount: vi.fn() },
}));
// No `billId` — INBOX mode, which is the mode the bug lives in. (The
// sibling spec mocks the detail mode.)
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({ useAcademicYearWatcher: () => {} }));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

/**
 * The reported family. Child A has an ordinary unpaid bill; child B has
 * ONLY a bill awaiting verification, which is the whole point — B is the
 * child who disappeared.
 */
const ANAK_A_UNPAID = {
  id: 'bill-a',
  student_id: 'siswa-a',
  student_name: 'Nadia',
  amount: 350_000,
  status: 'unpaid',
  due_date: '2026-09-20',
};
const ANAK_B_PENDING = {
  id: 'bill-b',
  student_id: 'siswa-b',
  student_name: 'Rafi',
  amount: 500_000,
  status: 'pending',
  due_date: '2026-09-20',
};
const ANAK_A_PAID = {
  id: 'bill-a-old',
  student_id: 'siswa-a',
  student_name: 'Nadia',
  amount: 900_000,
  status: 'paid',
  due_date: '2026-08-20',
};

interface BillRow {
  id: string;
  student_id: string;
  student_name: string;
  amount: number;
  status: string;
  due_date: string;
}

/**
 * A stand-in for `BillController::index` that reproduces the ONE
 * behaviour this bug turns on: `status` is matched as an exact,
 * un-whitelisted, single-word `where`.
 *
 *   ->when($request->filled('status'),
 *          fn ($b) => $b->where('status', $request->string('status')))
 *
 * A mock that ignored the parameter would hand back every fixture row no
 * matter what the view asked for, and the test below would pass just as
 * happily against the broken code — which is the whole failure mode
 * being fixed. Encoding the filter here is what makes the assertion
 * about the VIEW's question rather than about the fixture.
 */
function fakeBillIndex(rows: readonly BillRow[]) {
  return async (params: { status?: string } = {}) => ({
    items: params.status == null ? [...rows] : rows.filter((r) => r.status === params.status),
    pagination: undefined,
  });
}

async function mountInbox(bills: readonly BillRow[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listBills).mockImplementation(
    fakeBillIndex(bills) as never,
  );
  vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockResolvedValue(null);

  const w = mount(ParentTutoring2PayView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: {} },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: { props: ['meta'], template: '<div data-testid="hdr">{{ meta }}</div>' },
        // Renders the KPI values so the counters can be asserted as
        // numbers on screen rather than as internals.
        KpiStripCards: {
          props: ['cards'],
          template:
            '<div data-testid="kpi"><span v-for="c in cards" :key="c.label">{{ c.label }}={{ c.value }};</span></div>',
        },
        StatusBadge: { props: ['label'], template: '<span class="badge">{{ label }}</span>' },
        Button: { template: '<button><slot /></button>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div :data-status="state?.status"><slot v-if="state?.status === \'content\'" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('ParentTutoring2PayView inbox — a child whose bills all await verification', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Pinned, so the fixtures' due dates stay in the future forever and
    // the status pills under test don't silently become "Menunggak" the
    // week this file outlives its dates.
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 8, 14, 9, 0, 0)); // 14 Sep 2026, local
  });
  afterEach(() => vi.useRealTimers());

  it('shows BOTH children when one of them has only a `pending` bill', async () => {
    const w = await mountInbox([ANAK_A_UNPAID, ANAK_B_PENDING]);

    expect(w.text()).toContain('Nadia');
    // The mutation: revert the loader to `{ status: 'unpaid' }` and the
    // fixture below is filtered out server-side, so Rafi is absent and
    // this line fails.
    expect(w.text()).toContain('Rafi');
  });

  it('does not ask the server to pre-filter the status', async () => {
    // The server matches `status` as ONE exact word, so any literal here
    // is a narrower question than "what is still owed". Pinned as a
    // parameter assertion because the filter is invisible on screen — it
    // only shows up as a missing child.
    await mountInbox([ANAK_A_UNPAID, ANAK_B_PENDING]);

    const params = vi.mocked(TutoringBimbelService.listBills).mock.calls[0]?.[0];
    expect(params).not.toHaveProperty('status');
  });

  it('counts both children and the full amount owed', async () => {
    const w = await mountInbox([ANAK_A_UNPAID, ANAK_B_PENDING]);
    const kpi = w.get('[data-testid="kpi"]').text();

    // Every one of these was computed over the server-filtered list, so
    // every one of them was understated by exactly child B.
    expect(kpi).toContain('tutoring2.parent.pay.kpiTotalChildren=2');
    expect(kpi).toContain('tutoring2.common.total=2');
    expect(kpi).toContain('Rp 850.000');
    expect(w.get('[data-testid="hdr"]').text()).toContain('2');
  });

  it('still excludes settled bills — outstanding means NOT PAID, not "everything"', async () => {
    // Dropping the server filter must not turn the inbox into a ledger.
    // Nadia's paid bill shares her student_id, so a leak shows up in the
    // total rather than as a new name.
    const w = await mountInbox([ANAK_A_UNPAID, ANAK_B_PENDING, ANAK_A_PAID]);
    const kpi = w.get('[data-testid="kpi"]').text();

    expect(kpi).toContain('Rp 850.000');
    expect(kpi).toContain('tutoring2.common.total=2');
  });

  it('a wali whose bills are ALL paid still gets the empty state', async () => {
    // The emptiness test moved from the raw page to the filtered list —
    // if it had stayed on the raw page, a fully settled wali would have
    // rendered a content panel with zero rows instead of "Tidak ada
    // tagihan".
    const w = await mountInbox([ANAK_A_PAID]);

    expect(w.get('[data-status]').attributes('data-status')).toBe('empty');
  });

  it('labels an awaiting-verification bill as such, not as "belum lunas"', async () => {
    // Surfacing the row is only half the fix. The old label function
    // folded `pending` onto the `unpaid` copy, so the row this change
    // makes visible would have told a wali who had already transferred
    // that they had not paid.
    const w = await mountInbox([ANAK_B_PENDING]);

    expect(w.text()).toContain('tutoring2.status.pending');
    expect(w.text()).not.toContain('tutoring2.status.unpaid');
  });
});
