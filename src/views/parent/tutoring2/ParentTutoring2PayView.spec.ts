/**
 * Behavioural spec for ParentTutoring2PayView's payment destination.
 *
 * This screen could state what a parent owed but not where to send it —
 * the "Bayar sekarang" CTA's entire behaviour was a toast saying the
 * feature was not ready, because v2 had no route for the tenant's bank
 * details. These tests cover the panel that replaced it.
 *
 * Three of them exist because of specific ways this could go wrong
 * quietly rather than loudly:
 *
 *   - a tenant with nothing configured must get a plain notice, not an
 *     empty bank block that reads as a real account with the digits
 *     missing;
 *   - a failed payment-account call must not blank the billing screen,
 *     since the destination is an ADDITION to it;
 *   - admin-authored instructions must render as TEXT, because they
 *     reach every parent on the tenant and `v-html` here would be a
 *     stored-XSS sink.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2PayView from './ParentTutoring2PayView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';
import type { PaymentAccount } from '@/types/tutoring2/billing';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listBills: vi.fn(), getBill: vi.fn() },
}));
vi.mock('@/services/tutoring2/billing-settings', () => ({
  TutoringBillingSettingsService: { getPaymentAccount: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: { billId: 'bill-1' } }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({ useAcademicYearWatcher: () => {} }));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

const BILL = {
  id: 'bill-1',
  student_name: 'Nadia',
  amount: 350000,
  status: 'unpaid',
  due_date: '2026-08-20',
};

function account(o: Partial<PaymentAccount> = {}): PaymentAccount {
  return {
    bank_name: 'BCA',
    bank_account_number: '1234567890',
    bank_account_holder: 'Yayasan Bimbel',
    qris_image_url: null,
    payment_instructions: null,
    payment_gateway_enabled: false,
    payment_gateway_provider: null,
    ...o,
  };
}

async function mountView() {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.getBill).mockResolvedValue(BILL as never);
  const w = mount(ParentTutoring2PayView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        Button: { template: '<button><slot /></button>' },
        AsyncView: {
          props: ['state'],
          template: '<div :data-status="state?.status"><slot v-if="state?.status === \'content\'" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('ParentTutoring2PayView payment destination', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows the bank details a parent needs to transfer', async () => {
    vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockResolvedValue(account());

    const html = (await mountView()).html();

    expect(html).toContain('BCA');
    expect(html).toContain('1234567890');
    expect(html).toContain('Yayasan Bimbel');
  });

  it('renders admin-authored instructions as TEXT, never as markup', async () => {
    // Instructions are tenant-authored and reach every parent on the
    // tenant. v-html here would be a stored-XSS sink.
    vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockResolvedValue(
      account({ payment_instructions: '<img src=x onerror="alert(1)">Transfer dulu' }),
    );

    const w = await mountView();
    const html = w.html();

    expect(w.text()).toContain('Transfer dulu');
    // Escaped, so it is inert content rather than an element.
    expect(html).toContain('&lt;img');
    expect(w.find('img[onerror]').exists()).toBe(false);
  });

  it('says so plainly when the tenant has configured nothing', async () => {
    vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockResolvedValue(null);

    const w = await mountView();

    // No fabricated bank block with blank values.
    expect(w.html()).not.toContain('1234567890');
    expect(w.text()).toContain('tutoring2.parent.pay.noDestination');
  });

  it('a failed payment-account call still shows the bill', async () => {
    // The destination is an ADDITION to this screen. A partial outage
    // must not turn into a blank billing page.
    vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockRejectedValue(
      new Error('502'),
    );

    const w = await mountView();

    expect(w.attributes('data-status') ?? w.find('[data-status]').attributes('data-status'))
      .not.toBe('error');
    expect(w.text()).toContain('Nadia');
  });

  it('fetches the destination alongside the bill, not on a later tap', async () => {
    vi.mocked(TutoringBillingSettingsService.getPaymentAccount).mockResolvedValue(account());

    await mountView();

    expect(TutoringBillingSettingsService.getPaymentAccount).toHaveBeenCalledTimes(1);
  });
});
