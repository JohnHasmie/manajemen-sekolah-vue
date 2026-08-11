/**
 * The siswa checkout must show the bill the student actually owes.
 *
 * It shipped with an invented one — `SPP Januari 2026`, Rp 750.000 plus
 * a Rp 2.500 fee — and IGNORED the `:billId` in the route, so every bill
 * rendered the same total. The confirm button raised a toast.
 *
 * A student could read that figure and act on it. This is a money
 * screen, so the tests assert the amount and the absence of an invented
 * fee, not just that something rendered.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import PayView from './StudentTutoring2PayView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { getBill: vi.fn() },
}));
vi.mock('@/services/tutoring2/billing-settings', () => ({
  TutoringBillingSettingsService: { getPaymentAccount: vi.fn() },
}));
vi.mock('vue-router', () => ({ useRoute: () => ({ params: { billId: 'bill-77' } }) }));
vi.mock('@/composables/useAcademicYearWatcher', () => ({ useAcademicYearWatcher: () => {} }));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));

async function mountView(account: unknown = null) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.getBill).mockResolvedValue({
    id: 'bill-77',
    amount: 325000,
    status: 'unpaid',
    payment_type_name: 'SPP Agustus',
    due_date: '2026-08-25',
  } as never);
  vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockResolvedValue(account as never);

  const w = mount(PayView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot v-if="state?.status === \'content\'" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('StudentTutoring2PayView', () => {
  beforeEach(() => vi.clearAllMocks());

  it('fetches the bill named in the route', async () => {
    await mountView();
    expect(TutoringBimbelService.getBill).toHaveBeenCalledWith('bill-77');
  });

  it('shows the real amount and never the invented one', async () => {
    const w = await mountView();
    expect(w.text()).toContain('325.000');
    expect(w.text()).not.toContain('750.000');
    expect(w.text()).toContain('SPP Agustus');
  });

  it('adds no admin fee — the bill model carries none', async () => {
    // The old screen added Rp 2.500 to every total out of nowhere.
    const w = await mountView();
    expect(w.text()).not.toContain('2.500');
    expect(w.text()).not.toContain('752.500');
  });

  it('offers no payment method it cannot actually charge', async () => {
    // VA / e-wallet / QRIS pickers with no gateway behind them are the
    // same fabrication as the invented total.
    const w = await mountView();
    expect(w.findAll('input[type="radio"]')).toHaveLength(0);
    expect(w.text().toLowerCase()).not.toContain('e-wallet');
  });

  it('says so plainly when the tenant has no payment destination', async () => {
    const w = await mountView(null);
    expect(w.text()).toContain('tutoring2.student.pay.noDestination');
  });
});
