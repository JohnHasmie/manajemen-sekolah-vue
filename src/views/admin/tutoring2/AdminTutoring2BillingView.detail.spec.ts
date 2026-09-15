/**
 * "di halaman keuangan, tagihannya diklik tidak membuka apa-apa, dan
 * tidak ada cara mengubah status pembayaran."
 *
 * ── The defect ──
 *
 * `<tr v-for="b in billsList">` carried no `@click` and the whole file
 * held zero references to a detail surface or to mark-paid. The rows
 * were inert; the only interactive control on the screen was the
 * "+ Buat tagihan" CTA.
 *
 * Nothing was missing on the server. Both endpoints have been live all
 * along —
 *
 *   GET  /api/tutoring-v2/bills/{id}            BillController::show
 *   POST /api/tutoring-v2/bills/{id}/mark-paid  BillController::markPaid
 *
 * — `TutoringBimbelService.getBill` / `.markBillPaid` already wrapped
 * both, and `PermissionCatalog::adminTutoringDefaults()` already grants
 * a bimbel admin `tutoring.bill.view` AND `tutoring.bill.mark_paid`.
 * Only the controls were missing.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The tests DRIVE THE DOM. They query the row, `trigger('click')`
 *    it, and assert on what the service received. Nothing reaches into
 *    `w.vm` to invoke a handler — that seam would keep passing after
 *    the `@click` was deleted again, which is the exact regression.
 *    The one exception is the ability block, which calls the handler
 *    outright BECAUSE the DOM control is gone there; that is the only
 *    way to prove the in-function guard exists as well.
 *
 * 2. `abilities` starts EMPTY and each mount is handed exactly what it
 *    needs. A harness that grants everything by default makes "hidden
 *    without the ability" pass for the wrong reason.
 *
 * 3. Gating is asserted against `useMe().can()`, which the backend
 *    scopes to the role named by `X-Active-Role`. Never
 *    `roles[].permission_keys` — that list is unscoped and exists only
 *    to drive the role switcher, so a user who is admin at one tenant
 *    would read as admin everywhere.
 *
 * 4. `getBill` returns a status the list row did NOT carry, and one
 *    test asserts the sheet shows the fetched one. A sheet seeded from
 *    the row and never refreshed would pass "the sheet opens" and fail
 *    that.
 *
 * 5. The mark-paid payload is asserted STRUCTURALLY against
 *    `MarkBillPaidRequest::rules()`, not just by value. Every one of
 *    its four fields is `nullable`, so the server accepts an empty body
 *    and fills in amount / method / date itself — but a key it does not
 *    declare would be silently dropped, and asserting only
 *    `toHaveBeenCalledWith('bill-1', {})` would not catch a fifth key
 *    being added later.
 *
 * 6. `Modal`, `StatusBadge` and `Button` are left REAL — only
 *    `<Teleport>` is stubbed, so the sheet renders inside the wrapper
 *    instead of on `document.body`. A hand-written Modal stub would be
 *    a second implementation of the surface under assertion.
 *
 * 7. The real `locales/id.json` is loaded with `missingWarn` left ON,
 *    so a typo'd translation key surfaces here rather than shipping as
 *    a raw key on an admin's screen.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillingView from './AdminTutoring2BillingView.vue';
import { TutoringBimbelService, type BimbelBill } from '@/services/tutoring-bimbel.service';
import idMessages from '@/locales/id.json';

const VIEW = 'tutoring.bill.view';
const MARK_PAID = 'tutoring.bill.mark_paid';

/** Exactly the keys `MarkBillPaidRequest::rules()` declares. */
const MARK_PAID_FIELDS = ['amount', 'payment_method', 'payment_date', 'admin_notes'];

vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/services/tutoring-bimbel.service')>();
  return {
    ...actual,
    TutoringBimbelService: {
      listBills: vi.fn(),
      getBillsSummary: vi.fn(),
      getBill: vi.fn(),
      markBillPaid: vi.fn(),
      createBill: vi.fn(),
      listPaymentTypes: vi.fn(),
      listEnrollments: vi.fn(),
    },
  };
});

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn() },
}));

const toastSpy = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn() }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => toastSpy,
}));

/**
 * Held in a hoisted bag so one mount helper can flip abilities without
 * re-importing the SFC — a fresh import would hand the component a
 * different service instance than the one stubbed above.
 */
const abilities = vi.hoisted(() => ({ held: new Set<string>() }));
vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: (a: string) => abilities.held.has(a) }),
}));

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages } as never,
  });
}

/**
 * The list row. Deliberately thin and deliberately `unpaid`: the whole
 * point of the sheet is that it re-reads the bill from the server.
 *
 * `due_date` is far in the future so no assertion here depends on the
 * wall clock. (The view routes both the row pill and the sheet pill
 * through `billDisplayStatus`, which does NOT pass `due_date` — see its
 * docblock — but a fixture that silently went "Menunggak" one day would
 * still be a trap for the next reader.)
 */
function listRow(overrides: Partial<BimbelBill> = {}): BimbelBill {
  return {
    id: 'bill-1',
    school_id: 'sch-1',
    student_id: 'stu-1',
    student_name: 'Rizky Pratama',
    student_number: 'B-0042',
    payment_type_id: 'pt-1',
    amount: 450_000,
    status: 'unpaid',
    source_type: 'TUTORING_MONTHLY',
    source_label: 'Bulanan',
    due_date: '2099-12-31',
    month: '2099-12',
    ...overrides,
  };
}

/**
 * What `show` sends back. `pending` — the family uploaded a transfer
 * receipt after this list page was rendered — so it reads as a
 * DIFFERENT string from the row's `unpaid` while still being unsettled,
 * which keeps the mark-paid control in play.
 *
 * It also carries `payment_type_name` and `description`, neither of
 * which the fixture row holds, so "the sheet renders the fetched
 * payload" has more than the status word behind it.
 */
function showPayload(overrides: Partial<BimbelBill> = {}): BimbelBill {
  return {
    ...listRow(),
    status: 'pending',
    payment_type_name: 'SPP Bimbel',
    description: 'Tagihan bulan Desember',
    ...overrides,
  };
}

const STUBS = {
  BrandPageHeader: true,
  KpiStripCards: true,
  MonthPickerModal: true,
  FilterFacetPickerModal: true,
  PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
  AppFilterChip: {
    props: ['label', 'value', 'iconName', 'active'],
    emits: ['click'],
    template: '<button @click="$emit(\'click\')">{{ value }}</button>',
  },
  // Renders the slot: a bare `true` stub swallows the whole table and
  // "the row is clickable" would pass on an empty screen.
  AsyncView: {
    props: ['state'],
    template: `<div><slot v-if="state?.status === 'content'" /></div>`,
  },
  AdminTutoring2BillCreateSheet: {
    template: '<div data-testid="create-sheet" />',
  },
  // Only the portal. Modal / StatusBadge / Button stay real (note 6).
  teleport: true,
};

async function mountView(held: string[] = [VIEW], rows: BimbelBill[] = [listRow()]) {
  abilities.held = new Set(held);
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listBills).mockResolvedValue({
    items: rows,
    pagination: undefined,
  });
  vi.mocked(TutoringBimbelService.getBillsSummary).mockResolvedValue({
    tertagih: 450_000,
    terbayar: 0,
    menunggak: 450_000,
    overdue_count: 1,
  });

  const w = mount(AdminTutoring2BillingView, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const ROW = '[data-testid="bill-row"]';
const SHEET = '[data-testid="bill-detail"]';
const MARK_PAID_BTN = '[data-testid="bill-detail-mark-paid"]';

beforeEach(() => {
  vi.clearAllMocks();
  abilities.held = new Set();
  vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(showPayload());
  vi.mocked(TutoringBimbelService.markBillPaid).mockResolvedValue(
    showPayload({ status: 'paid' }),
  );
});

describe('the bill row opens its detail', () => {
  it('calls the show endpoint with the id of the row that was clicked', async () => {
    const w = await mountView([VIEW], [
      listRow({ id: 'bill-other', student_name: 'Sinta' }),
      listRow(),
    ]);

    // The SECOND row — a handler hard-wired to the first would pass a
    // single-row test forever.
    await w.findAll(ROW)[1].trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.getBill).toHaveBeenCalledTimes(1);
    expect(TutoringBimbelService.getBill).toHaveBeenCalledWith('bill-1');
  });

  it('opens the sheet, which is not on screen before the click', async () => {
    const w = await mountView();

    expect(w.find(SHEET).exists()).toBe(false);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true);
  });

  it('shows the SERVER payload, not the stale list row', async () => {
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    const sheet = w.get(SHEET);
    // The row said `unpaid`; `show` says `pending`. A sheet seeded from
    // the row and never refreshed reads "Belum lunas" here.
    expect(sheet.text()).toContain('Menunggu verifikasi');
    expect(sheet.text()).not.toContain('Belum lunas');
    // Neither of these is on the fixture row at all.
    expect(sheet.text()).toContain('SPP Bimbel');
    expect(sheet.text()).toContain('Tagihan bulan Desember');
  });

  it('keeps the sheet up when the refetch fails', async () => {
    vi.mocked(TutoringBimbelService.getBill).mockRejectedValue(new Error('Network Error'));
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    // Blanking the sheet on a flaky fetch would look like the original
    // inert-row bug all over again. The row is still honest for what it
    // holds.
    expect(w.find(SHEET).exists()).toBe(true);
    expect(w.get(SHEET).text()).toContain('450.000');
  });

  it('is reachable without a mouse', async () => {
    const w = await mountView();
    const row = w.get(ROW);

    // A <tr> is not focusable on its own, and the row is the only
    // affordance into the detail.
    expect(row.attributes('tabindex')).toBe('0');
    expect(row.attributes('role')).toBe('button');
    expect(row.attributes('aria-label')).toBeTruthy();
    expect(row.classes()).toContain('cursor-pointer');

    await row.trigger('keydown.enter');
    await flushPromises();

    expect(TutoringBimbelService.getBill).toHaveBeenCalledWith('bill-1');
    expect(w.find(SHEET).exists()).toBe(true);
  });

  it('closes again', async () => {
    const w = await mountView();
    await w.get(ROW).trigger('click');
    await flushPromises();
    expect(w.find(SHEET).exists()).toBe(true);

    await w.get('[data-testid="bill-detail-close"]').trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(false);
  });
});

describe('changing the payment status from the detail', () => {
  it('posts mark-paid for the bill that is open', async () => {
    const w = await mountView([VIEW, MARK_PAID], [
      listRow({ id: 'bill-other', student_name: 'Sinta' }),
      listRow(),
    ]);

    await w.findAll(ROW)[1].trigger('click');
    await flushPromises();
    await w.get(MARK_PAID_BTN).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.markBillPaid).toHaveBeenCalledTimes(1);
    const [id] = vi.mocked(TutoringBimbelService.markBillPaid).mock.calls[0];
    expect(id).toBe('bill-1');
  });

  it('sends only fields MarkBillPaidRequest declares', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();
    await w.get(MARK_PAID_BTN).trigger('click');
    await flushPromises();

    const [, payload] = vi.mocked(TutoringBimbelService.markBillPaid).mock.calls[0];
    // Every one of the four rules is `nullable`, so an empty body is
    // valid and the server fills amount / method / date in itself.
    // What must never happen is a key the FormRequest does not declare:
    // `validated()` drops it, so the admin's intent would vanish with
    // no error anywhere.
    for (const key of Object.keys(payload ?? {})) {
      expect(MARK_PAID_FIELDS).toContain(key);
    }
  });

  it('refreshes the list AND the summary tiles so the counters do not go stale', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();
    vi.mocked(TutoringBimbelService.listBills).mockClear();
    vi.mocked(TutoringBimbelService.getBillsSummary).mockClear();

    await w.get(MARK_PAID_BTN).trigger('click');
    await flushPromises();

    // The four KPI tiles come from `getBillsSummary`, not from the rows.
    // Reloading only the list leaves "Terbayar" reading the pre-payment
    // figure until the admin navigates away.
    expect(TutoringBimbelService.listBills).toHaveBeenCalledTimes(1);
    expect(TutoringBimbelService.getBillsSummary).toHaveBeenCalledTimes(1);
  });

  it('surfaces a failure instead of pretending the bill was settled', async () => {
    vi.mocked(TutoringBimbelService.markBillPaid).mockRejectedValue(new Error('Boom'));
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();
    await w.get(MARK_PAID_BTN).trigger('click');
    await flushPromises();

    expect(toastSpy.error).toHaveBeenCalled();
    expect(toastSpy.success).not.toHaveBeenCalled();
  });

  it('offers nothing to mark on a bill that is already paid', async () => {
    vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(showPayload({ status: 'paid' }));
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true);
    // `markPaid` returns early inside its lock for an already-paid
    // bill, so the control's only possible outcome is a no-op.
    expect(w.find(MARK_PAID_BTN).exists()).toBe(false);
  });
});

describe('the mark-paid control is gated on the ability the server enforces', () => {
  it('is shown to a caller holding tutoring.bill.mark_paid', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(MARK_PAID_BTN).exists()).toBe(true);
  });

  it('is HIDDEN when tutoring.bill.mark_paid is absent from /me abilities', async () => {
    // `tutoring.bill.view` alone is what a read-only admin tier holds.
    // Gating on the read key would offer them a control whose only
    // possible outcome is a 403 from `authorize('tutoring.bill.mark_paid')`.
    const w = await mountView([VIEW]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true); // reading is still fine
    expect(w.find(MARK_PAID_BTN).exists()).toBe(false);
  });

  it('refuses the write even if the control is reached some other way', async () => {
    // The only test that bypasses the DOM, and only because the DOM
    // control is gone here (note 1). Without the in-function guard, a
    // stale sheet left open across a role switch could still post.
    const w = await mountView([VIEW]);
    await w.get(ROW).trigger('click');
    await flushPromises();

    await (w.vm as unknown as { markActiveBillPaid: () => Promise<void> }).markActiveBillPaid();
    await flushPromises();

    expect(TutoringBimbelService.markBillPaid).not.toHaveBeenCalled();
  });
});

/**
 * The copy asserted above has to be the copy that ships, in BOTH
 * locales. vue-i18n echoes a missing key back as the key itself, so a
 * renamed or dropped key would leave the assertions above green against
 * strings no admin will ever see.
 */
describe('the detail-sheet copy ships in both locales', () => {
  const KEYS = [
    'detailTitle',
    'detailSection',
    'paymentSection',
    'openDetail',
    'studentNumber',
    'paymentType',
    'note',
    'paidAt',
    'paymentMethod',
    'markPaid',
    'markPaidDone',
    'close',
  ] as const;

  it.each(['id', 'en'])('%s.json carries every detail key', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;
    const block = messages.tutoring2.admin.billing;

    for (const key of KEYS) {
      expect(block[key], `${locale}.json is missing ${key}`).toBeTruthy();
      // A key echoed back as its own path is what a missing key looks
      // like on screen.
      expect(block[key]).not.toContain('tutoring2.');
    }
  });
});
