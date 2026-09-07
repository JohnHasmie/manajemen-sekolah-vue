/**
 * "pada website role teacher di list honor kenapa di klik tidak
 * memunculkan detail list yang di klik"
 *
 * ── The defect ──
 *
 * Every row under "Pengajuan pencairan terakhir" was an inert `<li>`.
 * The whole file carried exactly one `@click`, on the "Ajukan pencairan"
 * button, so tapping a row did nothing at all — exactly as reported.
 *
 * Nothing was missing on the server. `GET /tutoring-v2/payouts/requests/{id}`
 * (`PayoutRequestController::show`) has been live all along, and
 * `PayoutsService.getRequest` already wrapped it; only a control was
 * missing.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. The wire path is the thing under test, so the tests DRIVE THE DOM:
 *    they query the row, `trigger('click')` it, and then assert on what
 *    the service received and what landed on screen. Nothing here reaches
 *    into `w.vm` to invoke a handler — a reviewer caught exactly that seam
 *    on !1245. The one exception is the ability block, which calls the
 *    handler outright precisely BECAUSE the DOM control is gone there;
 *    that is the only way to prove the in-function guard exists too.
 * 2. `grantedAbilities` starts as the DEFAULT TUTOR SET
 *    (`PermissionCatalog::tutorTutoringDefaults`), not allow-everything.
 *    A mock that grants by default makes the "hidden for a caller without
 *    the ability" test pass for the wrong reason.
 * 3. `Modal`, `StatusBadge` and `Button` are all left REAL — only
 *    `<Teleport>` is stubbed, so the sheet renders inside the wrapper
 *    instead of on `document.body`. A hand-written Modal stub would be a
 *    second implementation of the surface being asserted.
 * 4. The em-dash assertions are paired with a "present field renders its
 *    value" assertion on the SAME sheet. A sheet that rendered "—"
 *    everywhere (e.g. because `activeRequest` never got set) would
 *    otherwise satisfy them all.
 * 5. `getRequest` returns a DIFFERENT payload from the list row, and one
 *    test asserts the sheet shows the fetched value. Seeding the sheet
 *    from the row alone — never calling the endpoint — would pass a
 *    "sheet opens" test but fails that one.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import Earnings from './TutorTutoring2EarningsView.vue';
import { PayoutsService } from '@/services/tutoring2/payouts';
import idMessages from '@/locales/id.json';
import type { PayoutRequest } from '@/types/tutoring2/payout';

const VIEW_OWN = 'tutoring.payout.view_own';
const VIEW_ALL = 'tutoring.payout.view_all';

/** What `tutorTutoringDefaults()` actually grants on the payout side. */
const TUTOR_DEFAULTS = [VIEW_OWN, 'tutoring.payout.request', 'tutoring.payout.settings.view'];

let grantedAbilities: string[] = [...TUTOR_DEFAULTS];

/**
 * Spied so one test can prove the view reads the /me snapshot (scoped by
 * `X-Active-Role`) rather than the auth store's unscoped
 * `roles[].permission_keys`, which exists only for the role switcher.
 */
const canAnySpy = vi.fn((abilities: Iterable<string>) =>
  [...abilities].some((a) => grantedAbilities.includes(a)),
);

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: canAnySpy,
  }),
}));

vi.mock('@/services/tutoring2/payouts', () => ({
  PayoutsService: {
    getSelfSummary: vi.fn(),
    listMyRequests: vi.fn(),
    getRequest: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const ROW = '[data-testid="earnings-request-row"]';
const ITEM = '[data-testid="earnings-request-item"]';
const SHEET = '[data-testid="payout-request-detail"]';

/**
 * The list row. Deliberately thin: `listMyRequests` is `index`, which
 * eager-loads tutor + reviewer but the ROW the user taps is still only
 * whatever the list page happened to hold.
 */
function listRow(): PayoutRequest {
  return {
    id: 'pr-1',
    tutor_id: 'tut-1',
    tutor_name: 'Bu Sinta',
    period_month: '2026-08',
    amount: 1_250_000,
    status: 'pending',
    requested_at: '2026-09-01T09:15:00+07:00',
  };
}

/**
 * What `show` sends back. Approved and PAID, by a named reviewer, with a
 * payment reference — i.e. materially newer than the pending list row, so
 * a sheet that skipped the fetch renders visibly different text.
 *
 * `rejected_at` and `note` are ABSENT, not null: `PayoutRequestResource`
 * emits `->toIso8601String()` on a null timestamp as null, and the
 * `whenLoaded` keys vanish entirely. Both must read as "did not happen".
 */
function showPayload(overrides: Partial<PayoutRequest> = {}): PayoutRequest {
  return {
    id: 'pr-1',
    tutor_id: 'tut-1',
    tutor_name: 'Bu Sinta',
    period_month: '2026-08',
    amount: 1_250_000,
    status: 'paid',
    requested_at: '2026-09-01T09:15:00+07:00',
    approved_at: '2026-09-02T14:00:00+07:00',
    paid_at: '2026-09-03T10:30:00+07:00',
    payment_reference: 'TRF-9911',
    reviewer_id: '8f2c1d40-0000-4000-8000-000000000001',
    reviewer_name: 'Admin Bimbel',
    ...overrides,
  };
}

/** The real shipped copy — `missingWarn: false` would hide a typo'd key. */
function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages } as never,
  });
}

async function mountView(rows: PayoutRequest[] = [listRow()]) {
  setActivePinia(createPinia());
  vi.mocked(PayoutsService.getSelfSummary).mockResolvedValue({
    tutor_id: 'tut-1',
    tutor_name: 'Bu Sinta',
    period_month: '2026-08',
    sessions_taught: 12,
    base_amount: 1_200_000,
    adjustments: 50_000,
    net_amount: 1_250_000,
  });
  vi.mocked(PayoutsService.listMyRequests).mockResolvedValue({
    items: rows,
    pagination: undefined,
  });

  const w = mount(Earnings, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        // Renders the slot: a bare `true` stub swallows the whole list
        // and "the row is a button" would pass on an empty screen.
        AsyncView: {
          props: ['state'],
          template: `<div><slot v-if="state?.status === 'content'" /></div>`,
        },
        // Only the portal. Modal/StatusBadge/Button stay real (note 3).
        teleport: true,
      },
    },
  });
  await flushPromises();
  return w;
}

beforeEach(() => {
  vi.clearAllMocks();
  grantedAbilities = [...TUTOR_DEFAULTS];
});

describe('tutor honor list — the row opens the detail sheet', () => {
  it('renders the row as a real button, not an inert <li>', async () => {
    const w = await mountView();

    const row = w.find(ROW);
    expect(row.exists()).toBe(true);
    expect(row.element.tagName).toBe('BUTTON');
    // The bug was a row with no handler at all; a <div role=button>
    // would repeat it for keyboard users.
    expect(row.attributes('type')).toBe('button');
  });

  it('calls the show endpoint with the id of the row that was clicked', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(showPayload());
    const w = await mountView([
      { ...listRow(), id: 'pr-other', amount: 10_000 },
      listRow(),
    ]);

    // The SECOND row — a handler hard-wired to the first would pass a
    // single-row test forever.
    await w.findAll(ROW)[1].trigger('click');
    await flushPromises();

    expect(PayoutsService.getRequest).toHaveBeenCalledTimes(1);
    expect(PayoutsService.getRequest).toHaveBeenCalledWith('pr-1');
  });

  it('opens the sheet, which is not on screen before the click', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(showPayload());
    const w = await mountView();

    expect(w.find(SHEET).exists()).toBe(false);

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true);
  });

  it('shows the SERVER payload, not the stale list row', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(showPayload());
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    // The row said "Menunggu"; `show` says paid. If the sheet were
    // seeded from the row and never refreshed, this reads "Menunggu".
    expect(w.find(SHEET).text()).toContain('Dibayar');
    expect(w.find(SHEET).text()).not.toContain('Menunggu');
  });

  it('renders amount, period, status and the timestamps the resource carries', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(showPayload());
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    const sheet = w.get(SHEET);
    // Rp 1.250.000 — Intl uses a non-breaking space after "Rp".
    expect(w.get('[data-testid="payout-detail-amount"]').text()).toContain('1.250.000');
    expect(sheet.text()).toContain('Agustus 2026'); // period_month 2026-08
    expect(w.get('[data-testid="payout-detail-requested_at"]').text()).toContain('01 Sep 2026');
    expect(w.get('[data-testid="payout-detail-approved_at"]').text()).toContain('02 Sep 2026');
    expect(w.get('[data-testid="payout-detail-paid_at"]').text()).toContain('03 Sep 2026');
    expect(w.get('[data-testid="payout-detail-payment_reference"]').text()).toContain('TRF-9911');
  });

  it('names the reviewer and never prints their id', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(showPayload());
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    const reviewer = w.get('[data-testid="payout-detail-reviewer"]');
    expect(reviewer.text()).toContain('Admin Bimbel');
    // Eleven raw-id regressions in this module already. Not a twelfth.
    expect(w.get(SHEET).text()).not.toContain('8f2c1d40');
    expect(w.get(SHEET).text()).not.toContain('tut-1');
    expect(w.get(SHEET).text()).not.toContain('pr-1');
  });

  it('closes again', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(showPayload());
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();
    expect(w.find(SHEET).exists()).toBe(true);

    await w.get(`${SHEET} button`).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(false);
  });

  it('keeps the sheet up when the refetch fails', async () => {
    vi.mocked(PayoutsService.getRequest).mockRejectedValue(new Error('Network Error'));
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    // Blanking the sheet on a flaky fetch would look like the original
    // bug all over again. The list row is still honest for what it holds.
    expect(w.find(SHEET).exists()).toBe(true);
    expect(w.get(SHEET).text()).toContain('1.250.000');
  });
});

describe('absent optional fields read as an em-dash, never as a value', () => {
  it('dashes every key the wire did not send', async () => {
    // Exactly what a pending request looks like: `whenLoaded` and
    // `->toIso8601String()` on a null column OMIT or null these keys.
    vi.mocked(PayoutsService.getRequest).mockResolvedValue({
      id: 'pr-1',
      tutor_id: 'tut-1',
      period_month: '2026-08',
      amount: 1_250_000,
      status: 'pending',
      requested_at: '2026-09-01T09:15:00+07:00',
    });
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    for (const key of ['approved_at', 'rejected_at', 'paid_at', 'reviewer', 'payment_reference', 'note']) {
      const row = w.get(`[data-testid="payout-detail-${key}"]`);
      expect(row.text(), `${key} should be blank`).toContain('—');
      // A missing key is "did not happen", not "zero" — the exact
      // conflation !849/!850/!1236 were about.
      expect(row.text(), `${key} must not be zeroed`).not.toMatch(/\b0\b/);
    }

    // The paired positive (note 4): the sheet is genuinely populated,
    // so the dashes above are not just an unbound `activeRequest`.
    expect(w.get('[data-testid="payout-detail-requested_at"]').text()).toContain('01 Sep 2026');
    expect(w.get('[data-testid="payout-detail-amount"]').text()).toContain('1.250.000');
  });

  it('dashes a reviewer sent as an explicit null', async () => {
    vi.mocked(PayoutsService.getRequest).mockResolvedValue(
      showPayload({ reviewer_name: null, payment_reference: null, note: null }),
    );
    const w = await mountView();

    await w.get(ROW).trigger('click');
    await flushPromises();

    expect(w.get('[data-testid="payout-detail-reviewer"]').text()).toContain('—');
    expect(w.get('[data-testid="payout-detail-payment_reference"]').text()).toContain('—');
    expect(w.get('[data-testid="payout-detail-note"]').text()).toContain('—');
  });
});

describe('the control is gated on the ability the endpoint checks', () => {
  it('reads the grant off the /me snapshot, scoped by X-Active-Role', async () => {
    await mountView();

    // `PayoutRequestController::resolveReadScope` accepts EITHER key.
    expect(canAnySpy).toHaveBeenCalledWith([VIEW_OWN, VIEW_ALL]);
  });

  it('offers the row to an admin holding only view_all', async () => {
    grantedAbilities = [VIEW_ALL];
    const w = await mountView();

    expect(w.find(ROW).exists()).toBe(true);
  });

  it('drops the control for a caller holding neither key', async () => {
    grantedAbilities = ['tutoring.session.view'];
    const w = await mountView();

    expect(w.find(ROW).exists()).toBe(false);

    // The row itself is still on screen — the list read is a separate
    // ability, and hiding the honor history would be a different bug.
    const item = w.find(ITEM);
    expect(item.exists()).toBe(true);
    expect(item.text()).toContain('1.250.000');
    // ...and it is not a focus stop that does nothing.
    expect(item.find('button').exists()).toBe(false);
  });

  it('never calls the endpoint for such a caller, even off the handler', async () => {
    grantedAbilities = ['tutoring.session.view'];
    const w = await mountView();

    // The DOM control is gone, so this is the ONLY way to reach the
    // in-function guard (note 1). Deleting that guard turns this red.
    await (w.vm as unknown as {
      openRequestDetail: (r: PayoutRequest) => Promise<void>;
    }).openRequestDetail(listRow());
    await flushPromises();

    expect(PayoutsService.getRequest).not.toHaveBeenCalled();
    expect(w.find(SHEET).exists()).toBe(false);
  });
});

/**
 * The copy asserted above has to be the copy that ships, in BOTH locales.
 * vue-i18n echoes a missing key back as the key itself, so a renamed or
 * dropped key would leave the assertions above green against strings that
 * no longer exist.
 */
describe('the detail-sheet copy ships in both locales', () => {
  const KEYS = [
    'detailTitle',
    'timeline',
    'details',
    'requestedAt',
    'approvedAt',
    'rejectedAt',
    'paidAt',
    'reviewer',
    'paymentReference',
    'close',
  ] as const;

  it.each(['id', 'en'])('%s.json carries every detail key', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;
    const block = messages.tutoring2.tutor.earnings;

    for (const key of KEYS) {
      expect(block[key], `${locale}.json is missing ${key}`).toBeTruthy();
      expect(block[key]).not.toContain('tutoring2.');
    }
  });

  /**
   * The list used to print the raw wire enum ("pending", "rolled_back").
   * The tutor now sees the same words the admin queue shows for the same
   * row — pinned here so the two copies cannot drift apart.
   */
  it.each(['id', 'en'])('%s.json status copy matches the admin queue exactly', async (locale) => {
    const messages = (await import(`@/locales/${locale}.json`)).default;

    expect(messages.tutoring2.tutor.earnings.status).toEqual(
      messages.tutoring2.admin.payoutRequests.status,
    );
  });
});
