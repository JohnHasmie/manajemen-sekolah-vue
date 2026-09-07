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

// Flippable so the `tutoring.voucher.manage` gate on the row controls can
// be exercised without re-importing the SFC (which would hand the
// component a different VouchersService instance than the one stubbed
// above). `hasAbility` is the app-wide gate and reads /me abilities for
// the ACTIVE role — never `roles[].permission_keys`.
const abilities = vi.hoisted(() => ({ granted: new Set<string>() }));

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: (p: string) => abilities.granted.has(p) }),
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
  if (abilities.granted.size === 0) {
    abilities.granted = new Set([
      'tutoring.voucher.view',
      'tutoring.voucher.manage',
      'tutoring.voucher.redeem',
    ]);
  }
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
                common: { edit: 'Ubah' },
                admin: {
                  vouchers: {
                    kpiCountedSuffix: '{count} kupon terdata',
                    archive: 'Arsipkan',
                    unarchive: 'Aktifkan kembali',
                    errorArchiveFailed: 'Gagal mengarsipkan voucher. Coba lagi.',
                    errorUnarchiveFailed:
                      'Gagal mengaktifkan kembali voucher. Coba lagi.',
                  },
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


/**
 * ─── Un-archiving: the missing half of a one-way door ────────────────
 *
 * Reported by Luay: "pada halaman Voucher kenapa setelah diarsipkan
 * tidak dapat diaktifkan kembali/di unarchive".
 *
 * Nothing was broken server-side and no voucher was lost. The list has
 * always carried archived rows (the default request sends no `status`
 * filter at all) and `PUT /tutoring-v2/vouchers/{id}` has always
 * accepted `status`. The row simply rendered one direction of a
 * two-direction toggle: "Arsipkan" existed, its counterpart did not.
 *
 * Same family as the dead filter chips of !1191/!1195/!1196/!1197 — the
 * capability shipped, the control did not.
 */
import { VOUCHER_STATUS } from '@/types/tutoring2/voucher';

/**
 * ─── Reading the row-actions cell ────────────────────────────────────
 *
 * Both helpers take a row index, because the sharpest assertions here
 * are about TWO rows at once: a control that is present on one status
 * and absent on the other cannot be proved by looking at either row
 * alone. Asserting only "absent on an active voucher" is satisfied just
 * as well by a screen with no such button anywhere.
 */
const ACTIONS_CELL = 5;

function actionCell(w, row = 0) {
  return w.findAll('[data-testid="async"] tbody tr')[row].findAll('td')[
    ACTIONS_CELL
  ];
}

function rowActionLabels(w, row = 0) {
  return actionCell(w, row)
    .findAll('button')
    .map((b) => b.text());
}

function rowActionButton(w, label: string, row = 0) {
  return actionCell(w, row)
    .findAll('button')
    .find((b) => b.text() === label);
}

function rowActionError(w) {
  const el = w.find('[data-testid="row-action-error"]');
  return el.exists() ? el.text() : null;
}

const ALL_VOUCHER_ABILITIES = [
  'tutoring.voucher.view',
  'tutoring.voucher.manage',
  'tutoring.voucher.redeem',
];

describe('AdminTutoring2VouchersView unarchive control', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    abilities.granted = new Set(ALL_VOUCHER_ABILITIES);
  });

  it('offers "Aktifkan kembali" on an ARCHIVED voucher', async () => {
    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);

    expect(rowActionLabels(w)).toContain('Aktifkan kembali');
  });

  it('THE FIX: clicking it PUTs the active status for that voucher', async () => {
    (VouchersService.update as any).mockResolvedValue(
      makeVoucher({ status: 'active' }),
    );

    const w = await mountVouchers([makeVoucher({ id: 'v-arc', status: 'archived' })]);
    await rowActionButton(w, 'Aktifkan kembali').trigger('click');
    await flushPromises();

    expect(VouchersService.update).toHaveBeenCalledTimes(1);
    expect((VouchersService.update as any).mock.calls[0][0]).toBe('v-arc');
    expect((VouchersService.update as any).mock.calls[0][1]).toEqual({
      status: 'active',
    });
    // The value must come from the shared constant, not a loose literal
    // that could drift away from the backend enum.
    expect((VouchersService.update as any).mock.calls[0][1].status).toBe(
      VOUCHER_STATUS.active,
    );
  });

  it('refreshes the list afterwards, exactly as Arsipkan does', async () => {
    (VouchersService.update as any).mockResolvedValue(
      makeVoucher({ status: 'active' }),
    );

    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);
    expect(VouchersService.list).toHaveBeenCalledTimes(1);

    await rowActionButton(w, 'Aktifkan kembali').trigger('click');
    await flushPromises();

    expect(VouchersService.list).toHaveBeenCalledTimes(2);
  });

  // Was: "is ABSENT on an already-active voucher, which offers Arsipkan
  // instead" — one row, one status, and therefore green on a build with
  // no Aktifkan kembali button anywhere. Mounting BOTH statuses in one
  // list turns it into a real statement about the toggle: each row shows
  // exactly one direction, and the archived row must show the other one.
  it('each row shows exactly one direction of the toggle', async () => {
    const w = await mountVouchers([
      makeVoucher({ id: 'v-act', status: 'active' }),
      makeVoucher({ id: 'v-arc', code: 'ARSIP', status: 'archived' }),
    ]);

    expect(rowActionLabels(w, 0)).toEqual(['Ubah', 'Arsipkan']);
    expect(rowActionLabels(w, 1)).toEqual(['Ubah', 'Aktifkan kembali']);
  });

  // Was: "an archived voucher does NOT also offer Arsipkan" — a pure
  // absence assertion, satisfied by a row with no buttons at all.
  // Asserting the EXACT label list says both halves of the claim: the
  // archived row drops Arsipkan *and* gains its counterpart.
  it('the archived row offers Ubah + Aktifkan kembali, and nothing else', async () => {
    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);

    expect(rowActionLabels(w)).toEqual(['Ubah', 'Aktifkan kembali']);
  });

  // Was: "hides it without the manage ability" — green on origin/main,
  // where it is hidden from everyone. A gate test has to show the gate
  // OPENING as well as closing, so both mounts live in one test.
  it('the manage ability is what gates it — present with, absent without', async () => {
    abilities.granted = new Set(ALL_VOUCHER_ABILITIES);
    const withManage = await mountVouchers([makeVoucher({ status: 'archived' })]);
    expect(rowActionLabels(withManage)).toContain('Aktifkan kembali');

    abilities.granted = new Set(['tutoring.voucher.view']);
    const withoutManage = await mountVouchers([makeVoucher({ status: 'archived' })]);
    expect(rowActionLabels(withoutManage)).not.toContain('Aktifkan kembali');
  });
});

/**
 * ─── The premise the control rests on ────────────────────────────────
 *
 * NOT evidence for the button, and deliberately not filed with it: this
 * assertion is green with or without the control, because it is about
 * the LIST REQUEST, not the row. What it guards is the reachability
 * premise — the default request sends no `status`, so archived rows
 * arrive on the first page and the reactivate control is reachable
 * without the admin ever touching the status filter. If someone later
 * makes the screen default to `status=active`, the button becomes
 * unreachable in practice while every test above stays green; this one
 * would go red and say why.
 */
describe('AdminTutoring2VouchersView default list request', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    abilities.granted = new Set(ALL_VOUCHER_ABILITIES);
  });

  it('sends no status filter, so archived rows reach the default page', async () => {
    await mountVouchers([makeVoucher({ status: 'archived' })]);

    expect((VouchersService.list as any).mock.calls[0][0].status).toBeUndefined();
  });
});

/**
 * ─── A refused write must say so ─────────────────────────────────────
 *
 * Both row controls used to be a bare `await Service.x(id)`. A 403 (the
 * manage ability revoked between page load and click), a 422, or a 500
 * became an unhandled rejection: `reload()` never ran, nothing appeared
 * on screen, and the row kept its old status — a button that did
 * nothing and said nothing. The two are fixed together and asserted
 * together so they cannot drift apart again.
 */
describe('AdminTutoring2VouchersView row-action failures', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    abilities.granted = new Set(ALL_VOUCHER_ABILITIES);
  });

  it('a failed Aktifkan kembali shows the backend message and does not refresh', async () => {
    (VouchersService.update as any).mockRejectedValue({
      response: { data: { message: 'Anda tidak berwenang mengubah voucher.' } },
    });

    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);
    expect(VouchersService.list).toHaveBeenCalledTimes(1);

    await rowActionButton(w, 'Aktifkan kembali').trigger('click');
    await flushPromises();

    expect(rowActionError(w)).toBe('Anda tidak berwenang mengubah voucher.');
    // No second fetch: the screen must not perform a refresh that would
    // read as "done" when the write was refused.
    expect(VouchersService.list).toHaveBeenCalledTimes(1);
    // And the row is still archived, still offering the same door.
    expect(rowActionLabels(w)).toEqual(['Ubah', 'Aktifkan kembali']);
  });

  it('a failed Arsipkan shows the backend message and does not refresh', async () => {
    (VouchersService.archive as any).mockRejectedValue({
      response: { data: { message: 'Voucher sedang dipakai.' } },
    });

    const w = await mountVouchers([makeVoucher({ status: 'active' })]);

    await rowActionButton(w, 'Arsipkan').trigger('click');
    await flushPromises();

    expect(rowActionError(w)).toBe('Voucher sedang dipakai.');
    expect(VouchersService.list).toHaveBeenCalledTimes(1);
    expect(rowActionLabels(w)).toEqual(['Ubah', 'Arsipkan']);
  });

  it('falls back to a translated sentence when the failure carries no message', async () => {
    // A network drop or a 500 with an empty body: there is no backend
    // text to borrow, and silence is the one thing we are fixing.
    (VouchersService.update as any).mockRejectedValue(new Error('Network Error'));

    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);
    await rowActionButton(w, 'Aktifkan kembali').trigger('click');
    await flushPromises();

    expect(rowActionError(w)).toBe('Gagal mengaktifkan kembali voucher. Coba lagi.');
  });

  it('SYMMETRY: Arsipkan falls back too — neither half is left silent', async () => {
    (VouchersService.archive as any).mockRejectedValue(new Error('Network Error'));

    const w = await mountVouchers([makeVoucher({ status: 'active' })]);
    await rowActionButton(w, 'Arsipkan').trigger('click');
    await flushPromises();

    expect(rowActionError(w)).toBe('Gagal mengarsipkan voucher. Coba lagi.');
  });

  it('a later success clears the stale failure banner', async () => {
    (VouchersService.update as any)
      .mockRejectedValueOnce(new Error('Network Error'))
      .mockResolvedValueOnce(makeVoucher({ status: 'active' }));

    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);

    await rowActionButton(w, 'Aktifkan kembali').trigger('click');
    await flushPromises();
    expect(rowActionError(w)).not.toBeNull();

    await rowActionButton(w, 'Aktifkan kembali').trigger('click');
    await flushPromises();

    expect(rowActionError(w)).toBeNull();
    expect(VouchersService.list).toHaveBeenCalledTimes(2);
  });

  // Also NOT evidence for the fix — green with or without it, since a
  // screen that never surfaces an error also never surfaces a stale one.
  // It is kept as the negative control for the assertions above: without
  // it, a banner hard-coded to render always would satisfy every one of
  // them.
  it('no banner is rendered before anything has failed', async () => {
    const w = await mountVouchers([makeVoucher({ status: 'archived' })]);

    expect(rowActionError(w)).toBeNull();
  });
});
