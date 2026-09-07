/**
 * Contract spec for AdminTutoring2VouchersView.
 *
 * `discountLabel` is re-implemented below (it is inline in the SFC) so a
 * silent behaviour drift surfaces here.
 *
 * `usesLabel` and the KPI tiles are NOT re-implemented any more — they
 * are asserted against the mounted view. The shadow copy had drifted
 * into a liability: it re-stated `redemption_count ?? 0` and its
 * "unlimited" case asserted `'0 / ∞'` for a voucher that carries NO
 * redemption count at all, green-lighting the exact bug this spec was
 * supposed to guard. `VoucherController::index` never eager-loads the
 * redemptions relation, so `whenLoaded` drops the key from every row on
 * this screen: the usage column read "0" for every voucher, the
 * "Terpakai" tile read 0, and the "Sisa kuota" tile reported every cap
 * as untouched.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect } from 'vitest';
import type { BimbelVoucher } from '@/types/tutoring2/voucher';

function discountLabel(v: BimbelVoucher): string {
  return v.kind === 'percent'
    ? `${v.value}%`
    : `Rp ${v.value.toLocaleString('id-ID')}`;
}

const percentVoucher: BimbelVoucher = {
  id: 'v1',
  school_id: 's1',
  code: 'HEMAT10',
  kind: 'percent',
  value: 10,
  status: 'active',
  redemption_count: 3,
  max_redemptions: 100,
};

const fixedVoucher: BimbelVoucher = {
  id: 'v2',
  school_id: 's1',
  code: 'RP50K',
  kind: 'fixed',
  value: 50000,
  status: 'active',
  max_redemptions: null,
};

describe('AdminTutoring2VouchersView helpers', () => {
  it('renders percent discount as "N%"', () => {
    expect(discountLabel(percentVoucher)).toBe('10%');
  });

  it('renders fixed discount as "Rp N" with id-ID grouping', () => {
    expect(discountLabel(fixedVoucher)).toBe('Rp 50.000');
  });
});

// ─── Uses + quota: ABSENT is not ZERO ────────────────────────────────
import { beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2VouchersView from './AdminTutoring2VouchersView.vue';
import KpiStripCards from '@/components/feature/KpiStripCards.vue';
import { VouchersService } from '@/services/tutoring2/vouchers';

vi.mock('@/services/tutoring2/vouchers', () => ({
  VouchersService: {
    list: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    archive: vi.fn(),
    redeem: vi.fn(),
  },
}));

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: () => true }),
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
    max_redemptions: 100,
    valid_from: null,
    valid_until: null,
    // No `redemption_count` — the list endpoint does not send one.
    ...overrides,
  };
}

async function mountVouchers(items) {
  setActivePinia(createPinia());
  (VouchersService.list as any).mockResolvedValue({ items });

  const w = mount(AdminTutoring2VouchersView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          fallbackLocale: 'id',
          missingWarn: false,
          fallbackWarn: false,
          // Only the keys these assertions read back. With `{}` vue-i18n
          // echoes the key path, which would make a suffix assertion
          // pass against literally any wiring.
          messages: {
            id: {
              tutoring2: {
                admin: {
                  vouchers: { kpiCountedSuffix: '{count} kupon terdata' },
                },
              },
            },
          },
        }),
      ],
      stubs: {
        // KpiStripCards is deliberately NOT stubbed.
        BrandPageHeader: true,
        StatusBadge: true,
        NavIcon: true,
        AppFilterChip: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        Modal: true,
        Button: true,
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Column order: Kode, Diskon, Berlaku, Penggunaan, Status, Aksi. */
const USES_CELL = 3;
/** Tile order: aktif, kadaluarsa, terpakai, sisa kuota. */
const USED_TILE = 2;
const QUOTA_TILE = 3;

function usesCell(w) {
  return w.find('[data-testid="async"] tbody tr').findAll('td')[USES_CELL].text();
}

function tileValues(w) {
  return w.findComponent(KpiStripCards).props('cards').map((c) => String(c.value));
}

function tileSuffixes(w) {
  return w.findComponent(KpiStripCards).props('cards').map((c) => c.suffix);
}

describe('AdminTutoring2VouchersView uses column', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('says "— / 100" when the row carries no redemption count', async () => {
    const w = await mountVouchers([makeVoucher()]);

    expect(usesCell(w)).toBe('— / 100');
    expect(usesCell(w)).not.toBe('0 / 100');
  });

  it('says "— / ∞" for an uncapped voucher with no count', async () => {
    const w = await mountVouchers([makeVoucher({ max_redemptions: null })]);

    expect(usesCell(w)).toBe('— / ∞');
  });

  it('THE INVARIANT: a voucher that reports zero redemptions reads "0 / 100"', async () => {
    const w = await mountVouchers([makeVoucher({ redemption_count: 0 })]);

    expect(usesCell(w)).toBe('0 / 100');
  });

  it('renders a reported positive count verbatim', async () => {
    const w = await mountVouchers([makeVoucher({ redemption_count: 3 })]);

    expect(usesCell(w)).toBe('3 / 100');
  });
});

describe('AdminTutoring2VouchersView usage tiles', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('says "—" for usage and remaining quota when nothing reported', async () => {
    const w = await mountVouchers([makeVoucher(), makeVoucher({ id: 'v2', code: 'X' })]);

    const values = tileValues(w);
    expect(values[USED_TILE]).toBe('—');
    expect(values[QUOTA_TILE]).toBe('—');
    expect(values[QUOTA_TILE]).not.toBe('200');
  });

  it('THE INVARIANT: reported zeros are real numbers, not unknowns', async () => {
    const w = await mountVouchers([makeVoucher({ redemption_count: 0 })]);

    const values = tileValues(w);
    expect(values[USED_TILE]).toBe('0');
    expect(values[QUOTA_TILE]).toBe('100');
  });

  it('sums only the vouchers that reported', async () => {
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', redemption_count: 3 }),
      makeVoucher({ id: 'v2', code: 'LAIN', redemption_count: 7 }),
      makeVoucher({ id: 'v3', code: 'DIAM' }), // no count — stays out
    ]);

    const values = tileValues(w);
    expect(values[USED_TILE]).toBe('10');
    // 97 + 93 from the two that answered; the silent one contributes
    // nothing rather than pretending its full cap is untouched.
    expect(values[QUOTA_TILE]).toBe('190');
    expect(values[QUOTA_TILE]).not.toBe('290');
  });

  // ── Partial coverage says so ──────────────────────────────────────
  // The sibling Kelompok Belajar screen qualified its partial totals
  // with a "N terdata" suffix; these two tiles summed the same kind of
  // half-known payload and presented the subset as the whole.
  it('names the counted subset on both tiles when coverage is partial', async () => {
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', redemption_count: 3 }),
      makeVoucher({ id: 'v2', code: 'DIAM' }),
    ]);

    const suffixes = tileSuffixes(w);
    expect(suffixes[USED_TILE]).toBe('1 kupon terdata');
    expect(suffixes[QUOTA_TILE]).toBe('1 kupon terdata');
  });

  it('drops the coverage note when every voucher reported', async () => {
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', redemption_count: 3 }),
      makeVoucher({ id: 'v2', code: 'LAIN', redemption_count: 7 }),
    ]);

    const suffixes = tileSuffixes(w);
    expect(suffixes[USED_TILE]).toBeUndefined();
    expect(suffixes[QUOTA_TILE]).toBeUndefined();
  });
});

/**
 * ─── The two OVER-corrections ────────────────────────────────────────
 *
 * Replacing `?? 0` with "— whenever nothing reported" fixed the lie in
 * one direction and introduced two smaller ones in the other:
 *
 *   1. An EMPTY list has a real answer. No vouchers means nothing
 *      redeemed and no quota outstanding — 0, not "we don't know".
 *   2. "No cap exists" is not "the server didn't say". A wallet of
 *      uncapped vouchers has UNLIMITED remaining quota, a third fact
 *      that neither a number nor an em-dash can carry.
 */
describe('AdminTutoring2VouchersView usage tiles — known zeros and infinities', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('an empty voucher list reports real zeros, not "—"', async () => {
    const w = await mountVouchers([]);

    const values = tileValues(w);
    expect(values[USED_TILE]).toBe('0');
    expect(values[QUOTA_TILE]).toBe('0');
    expect(values[USED_TILE]).not.toBe('—');
    expect(values[QUOTA_TILE]).not.toBe('—');
  });

  it('all-uncapped vouchers report "∞" remaining, not "—"', async () => {
    // Every code is uncapped, so the remaining quota is unlimited. The
    // reduce used to seed `null` and let `max_redemptions == null` pass
    // it straight through, printing "unknown" for something known.
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', max_redemptions: null }),
      makeVoucher({ id: 'v2', code: 'LAIN', max_redemptions: null }),
    ]);

    const values = tileValues(w);
    expect(values[QUOTA_TILE]).toBe('∞');
    expect(values[QUOTA_TILE]).not.toBe('—');
    expect(values[QUOTA_TILE]).not.toBe('0');
  });

  it('"∞" does not depend on the redemption count being known', async () => {
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', max_redemptions: null, redemption_count: 12 }),
    ]);

    expect(tileValues(w)[QUOTA_TILE]).toBe('∞');
  });

  it('a single capped voucher among uncapped ones makes the quota finite again', async () => {
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', max_redemptions: null }),
      makeVoucher({ id: 'v2', code: 'CAP', max_redemptions: 50, redemption_count: 20 }),
    ]);

    expect(tileValues(w)[QUOTA_TILE]).toBe('30');
  });

  it('THE INVARIANT HOLDS: capped vouchers with no counts are still "—"', async () => {
    // The carve-outs above must not leak into the real bug.
    const w = await mountVouchers([
      makeVoucher({ id: 'v1', max_redemptions: 50 }),
      makeVoucher({ id: 'v2', code: 'LAIN', max_redemptions: 50 }),
    ]);

    const values = tileValues(w);
    expect(values[USED_TILE]).toBe('—');
    expect(values[QUOTA_TILE]).toBe('—');
    expect(values[QUOTA_TILE]).not.toBe('100');
  });
});
