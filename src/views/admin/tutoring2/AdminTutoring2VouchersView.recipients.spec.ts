/**
 * The "Penerima" column on AdminTutoring2VouchersView.
 *
 * A voucher used to be a code plus a quota and NO OWNER; it can now name
 * students. The two kinds are handed out completely differently — a
 * general promo is a code you print on a flyer, a personal one is meant
 * for one family — so an admin who cannot tell them apart from the list
 * gives out the wrong one.
 *
 * Three facts, not two, and the third is the one that gets lost:
 *
 *   recipient_count: 0        → general promo. A REPORTED zero.
 *   recipient_count: n > 0    → personal, aimed at n students.
 *   recipient_count absent    → the server said nothing. `VoucherResource`
 *                               gates the key on `isset`, so a payload
 *                               from a path that skipped
 *                               `withRecipientCount()` carries neither
 *                               it nor `is_targeted`.
 *
 * Collapsing the third into the first would label an unknown voucher a
 * general promo and invite an admin to circulate a code that may in fact
 * be reserved — the same `?? 0` conflation `@/lib/absent-vs-zero` exists
 * to prevent, pointed at a security-adjacent fact this time.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2VouchersView from './AdminTutoring2VouchersView.vue';
import { VouchersService } from '@/services/tutoring2/vouchers';

vi.mock('@/services/tutoring2/vouchers', () => ({
  VouchersService: {
    list: vi.fn(),
    get: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    archive: vi.fn(),
    redeem: vi.fn(),
    listRecipients: vi.fn(),
    attachRecipients: vi.fn(),
    detachRecipient: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn().mockResolvedValue({ items: [] }) },
}));

/**
 * `useMe().can` reads the `abilities` array from `GET /me`, SCOPED BY
 * THE ACTIVE ROLE via `X-Active-Role`. Never `roles[].permission_keys`,
 * which is unscoped and exists only to feed the role switcher.
 */
const abilities = vi.hoisted(() => ({ granted: new Set<string>() }));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (p: string) => abilities.granted.has(p),
    canAny: (list: Iterable<string>) =>
      [...list].some((p) => abilities.granted.has(p)),
  }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));

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
    ...overrides,
  };
}

async function mountVouchers(items, granted = ['tutoring.voucher.view', 'tutoring.voucher.manage']) {
  setActivePinia(createPinia());
  abilities.granted = new Set(granted);
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
          messages: {
            id: {
              tutoring2: {
                common: { edit: 'Ubah' },
                admin: {
                  vouchers: {
                    colRecipients: 'Penerima',
                    recipientsGeneral: 'Promo umum',
                    recipientsPersonal: 'Personal · {count} siswa',
                    recipientsManage: 'Kelola penerima voucher',
                  },
                },
              },
            },
          },
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        NavIcon: true,
        AppFilterChip: true,
        KpiStripCards: true,
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

/** Kode(0), Diskon(1), Berlaku(2), Terpakai(3), Penerima(4), Status(5), Aksi(6). */
const RECIPIENTS_CELL = 4;

function recipientsCell(w, row = 0) {
  return w.findAll('[data-testid="async"] tbody tr')[row].findAll('td')[
    RECIPIENTS_CELL
  ];
}

beforeEach(() => {
  vi.clearAllMocks();
});

describe('AdminTutoring2VouchersView · Penerima column', () => {
  it('a REPORTED zero reads "Promo umum"', async () => {
    const w = await mountVouchers([
      makeVoucher({ recipient_count: 0, is_targeted: false }),
    ]);

    expect(recipientsCell(w).text()).toBe('Promo umum');
  });

  it('a non-zero count reads "Personal", and names how many', async () => {
    const w = await mountVouchers([
      makeVoucher({ recipient_count: 3, is_targeted: true }),
    ]);

    const text = recipientsCell(w).text();
    expect(text).toContain('Personal');
    expect(text).toContain('3');
    expect(text).not.toContain('Promo umum');
  });

  it('THE INVARIANT: an ABSENT count is "—", never "Promo umum"', async () => {
    // The row carries neither `recipient_count` nor `is_targeted` — the
    // shape `VoucherResource` emits when the query skipped
    // `withRecipientCount()`. Calling that a general promo would invite
    // an admin to circulate a code that may be reserved for three
    // families.
    const w = await mountVouchers([makeVoucher()]);

    expect(recipientsCell(w).text()).toBe('—');
    expect(recipientsCell(w).text()).not.toBe('Promo umum');
  });

  it('two rows of different kinds are distinguishable side by side', async () => {
    // One row alone proves nothing about a LABEL — a screen that printed
    // the same word for both kinds would satisfy either single-row
    // assertion above.
    const w = await mountVouchers([
      makeVoucher({ id: 'v-gen', recipient_count: 0, is_targeted: false }),
      makeVoucher({ id: 'v-per', code: 'KHUSUS', recipient_count: 2, is_targeted: true }),
    ]);

    expect(recipientsCell(w, 0).text()).toBe('Promo umum');
    expect(recipientsCell(w, 1).text()).toContain('Personal');
    expect(recipientsCell(w, 0).text()).not.toBe(recipientsCell(w, 1).text());
  });
});

describe('AdminTutoring2VouchersView · opening the recipients panel', () => {
  it('WITH tutoring.voucher.view the cell is a button that opens the sheet', async () => {
    (VouchersService.listRecipients as any).mockResolvedValue([]);

    const w = await mountVouchers([
      makeVoucher({ recipient_count: 0, is_targeted: false }),
    ]);

    const button = recipientsCell(w).find('[data-testid="recipients-cell-button"]');
    expect(button.exists()).toBe(true);

    await button.trigger('click');
    await flushPromises();

    // The sheet is mounted and asked the server for THIS voucher.
    expect(VouchersService.listRecipients).toHaveBeenCalledWith('v1');
  });

  it('WITHOUT tutoring.voucher.view the state is still readable, but inert', async () => {
    // `VoucherController::recipients` authorizes `.view`, the same key
    // that gates this screen — so this case is reachable only if the
    // route guard is ever loosened. The control must fail closed while
    // the badge keeps telling the truth.
    const w = await mountVouchers(
      [makeVoucher({ recipient_count: 2, is_targeted: true })],
      ['tutoring.voucher.manage'],
    );

    expect(
      recipientsCell(w).find('[data-testid="recipients-cell-button"]').exists(),
    ).toBe(false);
    expect(
      recipientsCell(w).find('[data-testid="recipients-cell-static"]').exists(),
    ).toBe(true);
    expect(recipientsCell(w).text()).toContain('Personal');
  });

  it('reloads the voucher list after the sheet reports a change', async () => {
    // Otherwise the badge keeps showing the pre-write count and the KPI
    // strip sums a mixture of before and after.
    (VouchersService.listRecipients as any).mockResolvedValue([]);

    const w = await mountVouchers([
      makeVoucher({ recipient_count: 0, is_targeted: false }),
    ]);
    expect(VouchersService.list).toHaveBeenCalledTimes(1);

    await recipientsCell(w)
      .find('[data-testid="recipients-cell-button"]')
      .trigger('click');
    await flushPromises();

    w.findComponent({ name: 'AdminTutoring2VoucherRecipientsSheet' }).vm.$emit(
      'changed',
      makeVoucher({ recipient_count: 1, is_targeted: true }),
    );
    await flushPromises();

    expect(VouchersService.list).toHaveBeenCalledTimes(2);
  });
});
