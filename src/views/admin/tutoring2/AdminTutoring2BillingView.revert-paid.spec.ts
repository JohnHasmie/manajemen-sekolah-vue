/**
 * "Tandai lunas" had no way back.
 *
 * ── The defect ──
 *
 * `AdminTutoring2BillingView` shipped the forward move only. An admin who
 * settled the wrong row — the list is sorted by nothing an admin picked,
 * and two siblings on the same program look alike — had no control
 * anywhere on web to undo it. The money stayed counted in "Terbayar" and
 * the only repair was a developer in tinker.
 *
 * The server side landed first and has no client:
 *
 *   POST /api/tutoring-v2/bills/{id}/revert-paid   BillController::revertPaid
 *
 * It authorizes `tutoring.bill.mark_paid` — the SAME key as the forward
 * move, deliberately, because a stricter key would ship dead (no role
 * holds it until a grant migration) and the person trusted to create the
 * money record is the person who must be able to withdraw their own
 * mis-click.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The tests DRIVE THE DOM: open the row, click the control, confirm in
 *    the real dialog, assert on what the service received. Nothing reaches
 *    into `w.vm` to invoke a handler — that seam would stay green after the
 *    `@click` was deleted. The one exception is the ability block, which
 *    calls the handler outright BECAUSE the DOM control is gone there;
 *    that is the only way to prove the in-function guard exists too.
 *
 * 2. `useConfirm` is NOT mocked. The real composable is used and
 *    `<ConfirmHost>` is mounted beside the view, so the guardian warning
 *    is asserted where an admin would actually read it. A mocked confirm
 *    would let the spec assert the ARGUMENT and stay green while the
 *    dialog rendered nothing — and "the warning shows" is the whole
 *    reason this confirmation exists rather than a bare button.
 *
 * 3. The guardian warning is asserted in BOTH directions. A warning that
 *    always renders teaches admins to click past it, so the `false` case
 *    asserting its ABSENCE is the load-bearing half.
 *
 * 4. `abilities` starts EMPTY and each mount is handed exactly what it
 *    needs. A harness that grants everything by default makes "hidden
 *    without the ability" pass for the wrong reason.
 *
 * 5. Gating is asserted against `useMe().can()`, which the backend scopes
 *    to the role named by `X-Active-Role`. Never `roles[].permission_keys`
 *    — that list is unscoped and exists only to drive the role switcher.
 *
 * 6. The bill is fetched as `paid` by `show`, NOT by the list row, so a
 *    control keyed off the stale row would fail these.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { defineComponent, h } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillingView from './AdminTutoring2BillingView.vue';
import ConfirmHost from '@/components/ui/ConfirmHost.vue';
import { TutoringBimbelService, type BimbelBill } from '@/services/tutoring-bimbel.service';
import idMessages from '@/locales/id.json';

const VIEW = 'tutoring.bill.view';
const MARK_PAID = 'tutoring.bill.mark_paid';

vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/services/tutoring-bimbel.service')>();
  return {
    ...actual,
    TutoringBimbelService: {
      listBills: vi.fn(),
      getBillsSummary: vi.fn(),
      getBill: vi.fn(),
      markBillPaid: vi.fn(),
      revertBillPaid: vi.fn(),
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

/** The list row. Deliberately `unpaid` — the sheet re-reads from the server. */
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
 * What `show` sends back: a SETTLED bill. `guardian_notified` defaults to
 * false so the warning has to be opted into per test rather than being
 * the fixture's ambient state.
 */
function paidPayload(overrides: Partial<BimbelBill> = {}): BimbelBill {
  return {
    ...listRow(),
    status: 'paid',
    payment_type_name: 'SPP Bimbel',
    paid_at: '2026-09-01',
    payment_method: 'manual_transfer',
    guardian_notified: false,
    guardian_notified_at: null,
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
  AsyncView: {
    props: ['state'],
    template: `<div><slot v-if="state?.status === 'content'" /></div>`,
  },
  AdminTutoring2BillCreateSheet: { template: '<div data-testid="create-sheet" />' },
  // Only the portal. Modal / StatusBadge / Button / ConfirmationDialog
  // stay real — a hand-written stub would be a second implementation of
  // the very surface under assertion.
  teleport: true,
};

/**
 * View + ConfirmHost together.
 *
 * `useConfirm` is a module-level singleton driven by a host mounted once
 * near the app root (App.vue). Mounting the view alone would leave
 * `confirm()` resolving against nothing rendered, so the dialog — and the
 * guardian warning inside it — could never be asserted.
 */
const Harness = defineComponent({
  setup() {
    return () => h('div', [h(AdminTutoring2BillingView), h(ConfirmHost)]);
  },
});

async function mountView(held: string[] = [VIEW], rows: BimbelBill[] = [listRow()]) {
  abilities.held = new Set(held);
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listBills).mockResolvedValue({
    items: rows,
    pagination: undefined,
  });
  vi.mocked(TutoringBimbelService.getBillsSummary).mockResolvedValue({
    tertagih: 450_000,
    terbayar: 450_000,
    menunggak: 0,
    overdue_count: 0,
  });

  const w = mount(Harness, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const ROW = '[data-testid="bill-row"]';
const SHEET = '[data-testid="bill-detail"]';
const REVERT_BTN = '[data-testid="bill-detail-revert-paid"]';
const MARK_PAID_BTN = '[data-testid="bill-detail-mark-paid"]';
const CONFIRM = '[data-testid="confirm-dialog"]';
const CONFIRM_IMPACT = '[data-testid="confirm-impact"]';
const CONFIRM_OK = '[data-testid="sheet-submit"]';
const CONFIRM_CANCEL = '[data-testid="sheet-cancel"]';

beforeEach(() => {
  vi.clearAllMocks();
  abilities.held = new Set();
  vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(paidPayload());
  vi.mocked(TutoringBimbelService.revertBillPaid).mockResolvedValue(
    paidPayload({ status: 'unpaid', paid_at: null, payment_method: null }),
  );
});

/** Open the detail of row `idx`, then press the revert control. */
async function openAndRevert(w: Awaited<ReturnType<typeof mountView>>, idx = 0) {
  await w.findAll(ROW)[idx].trigger('click');
  await flushPromises();
  await w.get(REVERT_BTN).trigger('click');
  await flushPromises();
}

describe('reverting a bill back to belum lunas', () => {
  it('posts revert-paid for the bill that is open', async () => {
    const w = await mountView([VIEW, MARK_PAID], [
      listRow({ id: 'bill-other', student_name: 'Sinta' }),
      listRow(),
    ]);

    // The SECOND row — a handler hard-wired to the first would pass a
    // single-row test forever.
    await openAndRevert(w, 1);
    await w.get(CONFIRM_OK).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.revertBillPaid).toHaveBeenCalledTimes(1);
    expect(TutoringBimbelService.revertBillPaid).toHaveBeenCalledWith('bill-1');
  });

  it('asks first, and posts nothing until the admin confirms', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);

    // The dialog is up and the write has NOT happened — this is the
    // whole point of the control: it exists because of mis-clicks, so it
    // must not itself be one.
    expect(w.find(CONFIRM).exists()).toBe(true);
    expect(TutoringBimbelService.revertBillPaid).not.toHaveBeenCalled();
  });

  it('does not post when the admin backs out', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);
    await w.get(CONFIRM_CANCEL).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.revertBillPaid).not.toHaveBeenCalled();
  });

  it('refreshes the list AND the summary tiles so the counters do not go stale', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);
    vi.mocked(TutoringBimbelService.listBills).mockClear();
    vi.mocked(TutoringBimbelService.getBillsSummary).mockClear();

    await w.get(CONFIRM_OK).trigger('click');
    await flushPromises();

    // The four KPI tiles come from `getBillsSummary`, not from the rows.
    // Reloading only the list would leave "Terbayar" still counting money
    // the tenant has just declared it never received.
    expect(TutoringBimbelService.listBills).toHaveBeenCalledTimes(1);
    expect(TutoringBimbelService.getBillsSummary).toHaveBeenCalledTimes(1);
  });

  it('repaints the sheet from the reverted payload', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);
    await w.get(CONFIRM_OK).trigger('click');
    await flushPromises();

    // `revertPaid` returns the fresh bill; the sheet must show it rather
    // than the pre-revert copy it was opened with.
    expect(w.get(SHEET).text()).toContain('Belum lunas');
    expect(w.find(REVERT_BTN).exists()).toBe(false);
  });

  it('surfaces a failure instead of pretending the revert landed', async () => {
    vi.mocked(TutoringBimbelService.revertBillPaid).mockRejectedValue(new Error('Boom'));
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);
    await w.get(CONFIRM_OK).trigger('click');
    await flushPromises();

    expect(toastSpy.error).toHaveBeenCalled();
    expect(toastSpy.success).not.toHaveBeenCalled();
  });
});

describe('the control tracks the state the bill is actually in', () => {
  it('is offered on a bill that is paid', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(REVERT_BTN).exists()).toBe(true);
  });

  it('is HIDDEN on a bill that is not paid', async () => {
    vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(paidPayload({ status: 'unpaid' }));
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true);
    // `revertPaid` returns early inside its lock for a bill that is not
    // paid, so the press could only ever be a silent no-op.
    expect(w.find(REVERT_BTN).exists()).toBe(false);
  });

  it('never offers mark-paid and revert as live actions at the same time', async () => {
    // Paid: revert is live, mark-paid is gone.
    const w = await mountView([VIEW, MARK_PAID]);
    await w.get(ROW).trigger('click');
    await flushPromises();
    expect(w.find(REVERT_BTN).exists()).toBe(true);
    expect(w.find(MARK_PAID_BTN).exists()).toBe(false);

    // Unpaid: the mirror image.
    vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(paidPayload({ status: 'unpaid' }));
    const w2 = await mountView([VIEW, MARK_PAID]);
    await w2.get(ROW).trigger('click');
    await flushPromises();
    expect(w2.find(MARK_PAID_BTN).exists()).toBe(true);
    expect(w2.find(REVERT_BTN).exists()).toBe(false);
  });
});

describe('the revert control is gated on the ability the server enforces', () => {
  it('is shown to a caller holding tutoring.bill.mark_paid', async () => {
    const w = await mountView([VIEW, MARK_PAID]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(REVERT_BTN).exists()).toBe(true);
  });

  it('is HIDDEN when tutoring.bill.mark_paid is absent from /me abilities', async () => {
    // `tutoring.bill.view` alone is what a read-only finance tier holds.
    // `BillController::revertPaid` authorizes `tutoring.bill.mark_paid`,
    // so offering them the control would offer them a 403.
    const w = await mountView([VIEW]);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true); // reading is still fine
    expect(w.find(REVERT_BTN).exists()).toBe(false);
  });

  it('refuses the write even if the control is reached some other way', async () => {
    // The only test that bypasses the DOM, and only because the DOM
    // control is gone here. Without the in-function guard, a sheet left
    // open across a role switch could still post.
    const w = await mountView([VIEW]);
    await w.get(ROW).trigger('click');
    await flushPromises();

    const view = w.findComponent(AdminTutoring2BillingView);
    await (view.vm as unknown as { revertActiveBillPaid: () => Promise<void> })
      .revertActiveBillPaid();
    await flushPromises();

    expect(TutoringBimbelService.revertBillPaid).not.toHaveBeenCalled();
  });
});

/**
 * The reason the confirmation is more than a yes/no.
 *
 * `revertPaid` dispatches NOTHING to the wali on purpose: the "tagihan
 * lunas" message cannot be unsent, and auto-firing "pembayaran
 * dibatalkan" could alarm a family when the cause was an admin
 * mis-click. So the follow-up is a phone call a human has to make — and
 * the admin can only know to make it if the dialog says the family was
 * already told.
 */
describe('the guardian-notified warning', () => {
  it('renders when the wali has already been told the bill was paid', async () => {
    vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(
      paidPayload({ guardian_notified: true, guardian_notified_at: '2026-09-01T10:00:00+07:00' }),
    );
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);

    const impact = w.find(CONFIRM_IMPACT);
    expect(impact.exists()).toBe(true);
    // The copy that ships, not a key echoed back.
    expect(impact.text()).toContain('Wali sudah diberi tahu bahwa tagihan ini lunas');
    expect(impact.text()).toContain('hubungi wali langsung');
    expect(impact.text()).not.toContain('tutoring2.');
  });

  it('is ABSENT when the wali was never notified', async () => {
    // The load-bearing direction. A warning that renders on every revert
    // is a warning admins learn to click past, and then the one time it
    // mattered it was already invisible to them.
    vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(
      paidPayload({ guardian_notified: false, guardian_notified_at: null }),
    );
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);

    expect(w.find(CONFIRM).exists()).toBe(true); // the dialog still asks
    expect(w.find(CONFIRM_IMPACT).exists()).toBe(false);
  });

  it('is ABSENT when the server did not send the flag at all', async () => {
    // `guardian_notified` absent is not the same claim as `false`, but a
    // warning invented from a missing key would be a fabricated one.
    const bill = paidPayload();
    delete bill.guardian_notified;
    delete bill.guardian_notified_at;
    vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(bill);
    const w = await mountView([VIEW, MARK_PAID]);

    await openAndRevert(w);

    expect(w.find(CONFIRM_IMPACT).exists()).toBe(false);
  });
});

/**
 * The copy asserted above has to be the copy that ships, in BOTH
 * locales. vue-i18n echoes a missing key back as the key itself, so a
 * renamed or dropped key would leave the assertions above green against
 * strings no admin will ever see.
 */
describe('the revert copy ships in both locales', () => {
  const KEYS = [
    'revertPaid',
    'revertPaidConfirmTitle',
    'revertPaidConfirmMsg',
    'revertPaidGuardianNotified',
    'revertPaidGuardianCallback',
    'revertPaidDone',
  ] as const;

  it.each(['id', 'en'])('%s.json carries every revert key', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;
    const block = messages.tutoring2.admin.billing;

    for (const key of KEYS) {
      expect(block[key], `${locale}.json is missing ${key}`).toBeTruthy();
      expect(block[key]).not.toContain('tutoring2.');
    }
  });
});
