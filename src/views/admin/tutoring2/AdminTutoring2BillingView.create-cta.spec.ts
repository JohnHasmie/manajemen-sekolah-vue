/**
 * Wiring spec for the "+ Buat tagihan" CTA on AdminTutoring2BillingView.
 *
 * This case used to live in AdminTutoring2DisabledCtas.spec.ts, which
 * locked the button's HONESTY while there was no create surface behind
 * it: `disabled`, with the reason on `title` and on an
 * `aria-describedby` line. That file's closing note says a CTA which
 * grows a real surface should move to a wiring spec of its own, and
 * this is it.
 *
 * What matters now is the opposite property — that the button leads
 * somewhere, and that it is only offered to callers who can actually
 * use it:
 *
 *   • It opens <AdminTutoring2BillCreateSheet>. A CTA with no
 *     destination is the "tombol diklik tidak terjadi apa-apa" class of
 *     bug this screen was reported for in the first place.
 *
 *   • It is gated on `tutoring.bill.create` — the ability
 *     `Tutoring\BillController::store` itself calls `authorize()` with,
 *     NOT the `tutoring.bill.view` this list reads with. Gating on the
 *     read key would offer the button to every wali and siswa the
 *     view_own scope lets in.
 *
 *   • `tutoring.payment_type.view` is resolved HERE and injected, so
 *     the sheet stays a plain form with one boolean.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillingView from './AdminTutoring2BillingView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listBills: vi.fn(),
    getBillsSummary: vi.fn(),
    // The create path belongs to the sheet, which is stubbed here.
    createBill: vi.fn(),
    listPaymentTypes: vi.fn(),
    listEnrollments: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn() },
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

/**
 * Held in a hoisted bag so a single mount helper can flip abilities
 * without re-importing the SFC — a fresh import would hand the
 * component a different service instance than the one stubbed above.
 */
const abilities = vi.hoisted(() => ({ held: new Set() }));
vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: (a) => abilities.held.has(a) }),
}));

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
          common: {
            all: 'Semua', source: 'Sumber', status: 'Status', period: 'Periode',
            roleAdmin: 'Admin', loading: 'Memuat', metaBills: '{count} tagihan',
          },
          admin: {
            billing: {
              title: 'Keuangan',
              newCta: 'Buat tagihan',
              emptyTitle: 'Belum ada tagihan',
              emptyDesc: 'Belum ada tagihan.',
              searchPh: 'Cari siswa…',
              kpiBilled: 'Tertagih', kpiPaid: 'Terbayar',
              kpiOverdue: 'Menunggak', kpiOverdueCount: 'Overdue',
              dayPrefix: 'Tgl {day}',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  BrandPageHeader: true,
  KpiStripCards: true,
  StatusBadge: true,
  MonthPickerModal: true,
  PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
  AppFilterChip: {
    props: ['label', 'value', 'iconName', 'active'],
    emits: ['click'],
    template: '<button @click="$emit(\'click\')">{{ value }}</button>',
  },
  AsyncView: {
    props: ['state'],
    template: '<div><slot :data="state?.data ?? []" /></div>',
  },
  // The sheet has its own spec; here it is only a destination.
  AdminTutoring2BillCreateSheet: {
    props: ['canViewPaymentTypes'],
    template: '<div data-testid="create-sheet" />',
  },
};

async function mountView(held = []) {
  abilities.held = new Set(held);
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2BillingView, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const CTA = '[data-testid="billing-new-cta"]';
const SHEET = '[data-testid="create-sheet"]';

beforeEach(() => {
  vi.clearAllMocks();
  TutoringBimbelService.listBills.mockResolvedValue({ items: [], pagination: undefined });
  TutoringBimbelService.getBillsSummary.mockResolvedValue({
    tertagih: 0, terbayar: 0, menunggak: 0, overdue_count: 0,
  });
});

describe('the "+ Buat tagihan" CTA', () => {
  it('is offered to a caller holding tutoring.bill.create', async () => {
    const w = await mountView(['tutoring.bill.create']);

    expect(w.find(CTA).exists()).toBe(true);
    expect(w.find(CTA).text()).toContain('Buat tagihan');
  });

  it('is no longer the disabled placeholder it shipped as', async () => {
    const w = await mountView(['tutoring.bill.create']);

    expect(w.find(CTA).attributes('disabled')).toBeUndefined();
  });

  it('opens the create sheet when clicked', async () => {
    const w = await mountView(['tutoring.bill.create']);
    expect(w.find(SHEET).exists()).toBe(false);

    await w.find(CTA).trigger('click');
    await flushPromises();

    expect(w.find(SHEET).exists()).toBe(true);
  });

  it('is HIDDEN without the ability the server enforces', async () => {
    const w = await mountView([]);

    expect(w.find(CTA).exists()).toBe(false);
  });

  it('is hidden for a caller who can only READ bills', async () => {
    // A wali or siswa reaches this data through `tutoring.bill.view_own`
    // and an admin-manager through `tutoring.bill.view`. Neither may
    // create, so gating on a read key would offer them a 403.
    const w = await mountView(['tutoring.bill.view', 'tutoring.bill.view_own']);

    expect(w.find(CTA).exists()).toBe(false);
  });

  it('passes the payment-type ability down to the sheet', async () => {
    const w = await mountView(['tutoring.bill.create', 'tutoring.payment_type.view']);
    await w.find(CTA).trigger('click');
    await flushPromises();

    expect(w.findComponent(STUBS.AdminTutoring2BillCreateSheet).props('canViewPaymentTypes')).toBe(true);
  });

  it('tells the sheet when the caller lacks tutoring.payment_type.view', async () => {
    const w = await mountView(['tutoring.bill.create']);
    await w.find(CTA).trigger('click');
    await flushPromises();

    expect(w.findComponent(STUBS.AdminTutoring2BillCreateSheet).props('canViewPaymentTypes')).toBe(false);
  });

  it('reloads the list once the sheet reports a saved bill', async () => {
    const w = await mountView(['tutoring.bill.create']);
    await w.find(CTA).trigger('click');
    await flushPromises();
    TutoringBimbelService.listBills.mockClear();

    await w.findComponent(STUBS.AdminTutoring2BillCreateSheet).vm.$emit('saved', { id: 'bi-1' });
    await flushPromises();

    expect(TutoringBimbelService.listBills).toHaveBeenCalled();
  });
});

describe('the shipped copy no longer claims the feature is missing', () => {
  it('id.json and en.json dropped billing.newCtaUnavailable', async () => {
    for (const locale of ['id', 'en']) {
      const messages = (await import(`@/locales/${locale}.json`)).default;
      expect(
        messages.tutoring2.admin.billing.newCtaUnavailable,
        `${locale}: the CTA works now`,
      ).toBeUndefined();
    }
  });

  it('every billCreate key exists in BOTH locales', async () => {
    const id = (await import('@/locales/id.json')).default;
    const en = (await import('@/locales/en.json')).default;

    const idKeys = Object.keys(id.tutoring2.admin.billCreate).sort();
    const enKeys = Object.keys(en.tutoring2.admin.billCreate).sort();

    expect(idKeys.length).toBeGreaterThan(0);
    expect(enKeys).toEqual(idKeys);
  });
});
