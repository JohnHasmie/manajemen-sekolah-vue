/**
 * ParentTutoring2VouchersView — "Voucher Saya" reads the WALI list.
 *
 * Until recipient targeting shipped there was no wali-scoped voucher
 * list at all, so this screen fetched the TENANT-WIDE
 * `GET /tutoring-v2/vouchers` and walled itself off behind
 * `tutoring.voucher.view`, a key `PermissionCatalog::
 * parentTutoringDefaults()` deliberately withholds. Every wali therefore
 * saw the permission notice and never a voucher.
 *
 * `GET /tutoring-v2/vouchers/my` (`VoucherController::myIndex`) answers
 * the narrow question instead: it starts from the recipient grant, so it
 * can only ever return vouchers aimed at a student the caller owns.
 *
 * THE ENDPOINT IS THE ASSERTION, not an implementation detail. Calling
 * the tenant-wide list from a parent screen would hand every parent
 * every promo code in the lembaga — the precise leak `.view_own` exists
 * to avoid — so "it called listMine" and "it never called list" are both
 * pinned here. A test that only checked rows rendered would pass on the
 * leaking version too.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2VouchersView from './ParentTutoring2VouchersView.vue';
import { VouchersService } from '@/services/tutoring2/vouchers';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring2/vouchers', () => ({
  VouchersService: { list: vi.fn(), listMine: vi.fn(), redeem: vi.fn() },
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn(), listBills: vi.fn() },
}));

/**
 * Abilities are read through `auth.hasAbility`, which resolves
 * `useMeStore().snapshot.abilities` — the `/me` set scoped by
 * `X-Active-Role`. Never `roles[].permission_keys`. The mock mirrors
 * that shape: a set of held keys, so a test can withhold exactly one.
 */
let heldAbilities = new Set<string>();
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: (p: string) => heldAbilities.has(p) }),
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
  // The exact shape `myIndex` puts on the wire: no `redemption_count`
  // and no `recipient_count` — the first is never eager-loaded, the
  // second is deliberately withheld because it counts the OTHER
  // families the same promo reached.
  return {
    id: 'v1',
    school_id: 's1',
    code: 'PRIBADI25',
    description: 'Potongan khusus',
    kind: 'percent',
    value: 25,
    kind_label: 'Persen',
    status: 'active',
    status_label: 'Aktif',
    max_redemptions: null,
    valid_from: null,
    valid_until: null,
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
        common: { emptyTitle: 'Tidak ada data' },
        tutoring2: {
          parent: {
            vouchers: {
              title: 'Voucher Saya',
              tabAvailable: 'Tersedia',
              tabHistory: 'Riwayat',
              kpiAvailable: 'Tersedia',
              kpiExpiringSoon: 'Segera berakhir',
              kpiUsed: 'Terpakai',
              kpiOpenBills: 'Tagihan terbuka',
              defaultDescription: 'Promo',
              noExpiry: 'Tanpa batas waktu',
              quotaUnlimitedUnknown: 'Tanpa batas pemakaian',
              emptyTitle: 'Belum ada voucher untukmu',
              emptyDesc:
                'Voucher yang ditujukan khusus untuk anak Anda akan muncul di sini.',
              noPermissionTitle: 'Daftar voucher belum tersedia',
              noPermissionDesc: 'Akun wali belum punya izin.',
            },
          },
        },
      },
    },
  });
}

async function mountView(vouchers: unknown[] | null) {
  setActivePinia(createPinia());
  (VouchersService.listMine as any).mockResolvedValue({ items: vouchers ?? [] });
  (VouchersService.list as any).mockResolvedValue({ items: [] });
  (TutoringBimbelService.listEnrollments as any).mockResolvedValue({ items: [] });
  (TutoringBimbelService.listBills as any).mockResolvedValue({ items: [] });

  const w = mount(ParentTutoring2VouchersView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        // AsyncView and EmptyState are deliberately NOT stubbed — the
        // empty branch is one of the assertions.
        BrandPageHeader: true,
        ParentSwitchChildLink: true,
        KpiStripCards: true,
        StatusBadge: true,
        SegmentedControl: true,
        NavIcon: true,
        Button: true,
        Modal: true,
        FormField: true,
      },
    },
  });
  await flushPromises();
  return w;
}

beforeEach(() => {
  vi.clearAllMocks();
  heldAbilities = new Set(['tutoring.voucher.view_own', 'tutoring.voucher.redeem']);
});

describe('ParentTutoring2VouchersView — the endpoint it calls', () => {
  it('asks /vouchers/my, and NEVER the tenant-wide voucher list', async () => {
    await mountView([makeVoucher()]);

    expect(VouchersService.listMine).toHaveBeenCalledTimes(1);
    // The security assertion: the tenant-wide list would return every
    // promo code in the lembaga to a parent.
    expect(VouchersService.list).not.toHaveBeenCalled();
  });

  it('sends no filter that could widen the scope', async () => {
    await mountView([makeVoucher()]);

    const params = (VouchersService.listMine as any).mock.calls[0]?.[0] ?? {};
    expect(Object.keys(params).sort()).toEqual(['per_page']);
  });
});

describe('ParentTutoring2VouchersView — rows render from the payload', () => {
  it('renders the code, the worth and the validity of each voucher', async () => {
    const w = await mountView([
      makeVoucher({ id: 'v1', code: 'PRIBADI25', kind: 'percent', value: 25 }),
      makeVoucher({
        id: 'v2',
        code: 'POTONG50K',
        kind: 'fixed',
        value: 50000,
        valid_until: '2099-12-31',
      }),
    ]);

    const text = w.text().replace(/\s+/g, ' ');
    expect(text).toContain('PRIBADI25');
    expect(text).toContain('25%');
    expect(text).toContain('POTONG50K');
    expect(text).toContain('Rp 50.000');
  });
});

describe('ParentTutoring2VouchersView — the ability gate', () => {
  it('hides the list and fires no request without tutoring.voucher.view_own', async () => {
    heldAbilities = new Set(['tutoring.voucher.redeem']);

    const w = await mountView([makeVoucher()]);

    expect(VouchersService.listMine).not.toHaveBeenCalled();
    expect(w.text()).toContain('Daftar voucher belum tersedia');
    expect(w.text()).not.toContain('PRIBADI25');
  });

  it('shows the list when the wali holds tutoring.voucher.view_own', async () => {
    const w = await mountView([makeVoucher()]);

    expect(VouchersService.listMine).toHaveBeenCalled();
    expect(w.text()).toContain('PRIBADI25');
    expect(w.text()).not.toContain('Daftar voucher belum tersedia');
  });

  /**
   * The old gate. `tutoring.voucher.view` is the TENANT-WIDE key and is
   * withheld from wali on purpose; a wali holding only `.view_own` must
   * still get their list. Pinned because re-reading `.view` here would
   * restore the blank screen without failing any other test.
   */
  it('does not require the tenant-wide tutoring.voucher.view', async () => {
    heldAbilities = new Set(['tutoring.voucher.view_own']);

    const w = await mountView([makeVoucher()]);

    expect(VouchersService.listMine).toHaveBeenCalled();
    expect(w.text()).toContain('PRIBADI25');
  });
});

describe('ParentTutoring2VouchersView — the empty list', () => {
  /**
   * Recipient targeting only just shipped, so NO voucher has recipients
   * yet and every wali's first visit returns `[]`. That has to read as
   * "you have no vouchers", not as a screen that failed to load.
   */
  it('reads as "belum ada voucher", not as a broken screen', async () => {
    const w = await mountView([]);

    const text = w.text().replace(/\s+/g, ' ');
    expect(text).toContain('Belum ada voucher untukmu');
    expect(text).toContain('Voucher yang ditujukan khusus untuk anak Anda');
    // Not an error, and not the permission wall either.
    expect(text).not.toContain('Daftar voucher belum tersedia');
  });
});
