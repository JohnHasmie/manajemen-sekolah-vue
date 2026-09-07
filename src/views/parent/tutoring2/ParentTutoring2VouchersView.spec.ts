/**
 * ParentTutoring2VouchersView — voucher usage must not be invented.
 *
 * The wali wallet read `redemption_count ?? 0` in three places, and
 * `VoucherResource` emits that field through `whenLoaded('redemptions')`
 * while NO controller in the Tutoring module eager-loads the relation.
 * The key is therefore absent from every voucher on every response —
 * list and show alike — so:
 *
 *   • the "Terpakai" KPI read 0 for every wallet;
 *   • every card read "Terpakai 0 dari 50", telling a parent a code was
 *     untouched when it may have been nearly spent;
 *   • `isQuotaUsedUp` decided "not exhausted" by arithmetic accident.
 *
 * Three distinct facts have to stay distinct here, which is why the
 * uncapped case gets its own string rather than "Terpakai —×":
 *   a real count · "the server didn't say" · "there is no limit".
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2VouchersView from './ParentTutoring2VouchersView.vue';
import KpiStripCards from '@/components/feature/KpiStripCards.vue';
import { VouchersService } from '@/services/tutoring2/vouchers';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring2/vouchers', () => ({
  VouchersService: { list: vi.fn(), redeem: vi.fn() },
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn(), listBills: vi.fn() },
}));

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: () => true }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { studentId: 'st-1' }, query: {} }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {
    /* noop in tests */
  },
}));

function makeVoucher(overrides = {}) {
  return {
    id: 'v1',
    school_id: 's1',
    code: 'HEMAT10',
    kind: 'percent',
    value: 10,
    status: 'active',
    status_label: 'Aktif',
    max_redemptions: 50,
    valid_from: null,
    valid_until: null,
    // No `redemption_count` — no controller eager-loads `redemptions`.
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
          parent: {
            vouchers: {
              quotaUnlimited: 'Terpakai {used}×',
              quotaLimited: 'Terpakai {used} dari {max}',
              quotaUnlimitedUnknown: 'Tanpa batas pemakaian',
              kpiCountedSuffix: '{count} kupon terdata',
              kpiAvailable: 'Tersedia',
              kpiExpiringSoon: 'Segera berakhir',
              kpiUsed: 'Terpakai',
              kpiOpenBills: 'Tagihan terbuka',
              noExpiry: 'Tanpa batas waktu',
              tabAvailable: 'Tersedia',
              tabHistory: 'Riwayat',
              defaultDescription: 'Promo',
            },
          },
        },
      },
    },
  });
}

async function mountView(vouchers) {
  setActivePinia(createPinia());
  (VouchersService.list as any).mockResolvedValue({ items: vouchers });
  (TutoringBimbelService.listEnrollments as any).mockResolvedValue({ items: [] });
  (TutoringBimbelService.listBills as any).mockResolvedValue({ items: [] });

  const w = mount(ParentTutoring2VouchersView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        // KpiStripCards is deliberately NOT stubbed.
        BrandPageHeader: true,
        StatusBadge: true,
        NavIcon: true,
        Button: true,
        Modal: true,
        FormField: true,
        SegmentedControl: true,
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Tile order: tersedia, segera berakhir, terpakai, tagihan terbuka. */
const USED_TILE = 2;

function tileValues(w) {
  return w.findComponent(KpiStripCards).props('cards').map((c) => String(c.value));
}

function tileSuffixes(w) {
  return w.findComponent(KpiStripCards).props('cards').map((c) => c.suffix);
}

function cardsText(w) {
  return w.find('[data-testid="async"]').text().replace(/\s+/g, ' ');
}

describe('ParentTutoring2VouchersView — quota label absent vs zero', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('says "Terpakai — dari 50" when the count was never sent', async () => {
    const w = await mountView([makeVoucher()]);

    expect(cardsText(w)).toContain('Terpakai — dari 50');
    expect(cardsText(w)).not.toContain('Terpakai 0 dari 50');
  });

  it('THE INVARIANT: a reported zero still reads "Terpakai 0 dari 50"', async () => {
    const w = await mountView([makeVoucher({ redemption_count: 0 })]);

    expect(cardsText(w)).toContain('Terpakai 0 dari 50');
    expect(cardsText(w)).not.toContain('Terpakai — dari 50');
  });

  it('renders a reported positive count verbatim', async () => {
    const w = await mountView([makeVoucher({ redemption_count: 12 })]);

    expect(cardsText(w)).toContain('Terpakai 12 dari 50');
  });

  // ── The uncapped case needs a third string ────────────────────────
  it('an uncapped voucher with no count says it has no limit', async () => {
    const w = await mountView([makeVoucher({ max_redemptions: null })]);

    expect(cardsText(w)).toContain('Tanpa batas pemakaian');
    // Never the nonsense reading, and never a fabricated zero.
    expect(cardsText(w)).not.toContain('Terpakai —×');
    expect(cardsText(w)).not.toContain('Terpakai 0×');
  });

  it('THE INVARIANT: an uncapped voucher WITH a count still shows it', async () => {
    const w = await mountView([
      makeVoucher({ max_redemptions: null, redemption_count: 0 }),
    ]);

    expect(cardsText(w)).toContain('Terpakai 0×');
    expect(cardsText(w)).not.toContain('Tanpa batas pemakaian');
  });
});

describe('ParentTutoring2VouchersView — "Terpakai" KPI', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('says "—" when vouchers exist but none reported', async () => {
    const w = await mountView([makeVoucher(), makeVoucher({ id: 'v2', code: 'LAIN' })]);

    expect(tileValues(w)[USED_TILE]).toBe('—');
    expect(tileValues(w)[USED_TILE]).not.toBe('0');
  });

  it('THE INVARIANT: a reported zero is a real 0', async () => {
    const w = await mountView([makeVoucher({ redemption_count: 0 })]);

    expect(tileValues(w)[USED_TILE]).toBe('0');
    expect(tileValues(w)[USED_TILE]).not.toBe('—');
  });

  it('sums only the vouchers that reported, and names the subset', async () => {
    const w = await mountView([
      makeVoucher({ id: 'v1', redemption_count: 3 }),
      makeVoucher({ id: 'v2', code: 'LAIN', redemption_count: 4 }),
      makeVoucher({ id: 'v3', code: 'DIAM' }), // silent
    ]);

    expect(tileValues(w)[USED_TILE]).toBe('7');
    expect(tileSuffixes(w)[USED_TILE]).toBe('2 kupon terdata');
  });

  it('drops the coverage note when every voucher reported', async () => {
    const w = await mountView([
      makeVoucher({ id: 'v1', redemption_count: 3 }),
      makeVoucher({ id: 'v2', code: 'LAIN', redemption_count: 4 }),
    ]);

    expect(tileValues(w)[USED_TILE]).toBe('7');
    expect(tileSuffixes(w)[USED_TILE]).toBeUndefined();
  });

  it('an EMPTY wallet reports a real 0, not "—"', async () => {
    // Nothing to redeem means nothing redeemed. That is knowledge.
    const w = await mountView([]);

    expect(tileValues(w)[USED_TILE]).toBe('0');
    expect(tileValues(w)[USED_TILE]).not.toBe('—');
  });
});
