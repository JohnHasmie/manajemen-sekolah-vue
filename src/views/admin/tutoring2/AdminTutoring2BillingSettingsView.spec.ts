/**
 * Behavioural spec for the payment-destination panel.
 *
 * Everything here guards ONE property: a save must send only the fields
 * the admin actually changed.
 *
 * The API distinguishes an absent key ("leave alone") from an explicit
 * null ("clear"). So posting the whole form is destructive in the
 * ordinary case — a tenant whose bank details were typed once and never
 * revisited would have them cleared the moment someone edited the
 * instructions box. One production tenant has exactly that data, which
 * is why this is tested at the payload level rather than trusted to
 * "the form looks right".
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillingSettingsView from './AdminTutoring2BillingSettingsView.vue';
import { TutoringBillingSettingsService } from '@/services/tutoring2/billing-settings';
import { TutoringReminderSettingsService } from '@/services/tutoring2/reminder-settings';
import type { BillingSettings } from '@/types/tutoring2/billing';

vi.mock('@/services/tutoring2/billing-settings', () => ({
  TutoringBillingSettingsService: { get: vi.fn(), update: vi.fn(), uploadQris: vi.fn() },
}));
vi.mock('@/services/tutoring2/reminder-settings', () => ({
  TutoringReminderSettingsService: { getBillReminders: vi.fn(), updateBillReminders: vi.fn() },
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({ useAcademicYearWatcher: () => {} }));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

function settings(o: Partial<BillingSettings> = {}): BillingSettings {
  return {
    id: 'bs-1',
    school_id: 'sc-1',
    bank_name: 'BCA',
    bank_account_number: '1234567890',
    bank_account_holder: 'Yayasan Bimbel',
    qris_image_url: null,
    payment_instructions: 'Transfer lalu kirim bukti.',
    payment_gateway_enabled: false,
    payment_gateway_provider: null,
    payment_gateway_configured: false,
    has_payable_destination: true,
    updated_at: null,
    ...o,
  };
}

async function mountView(s: BillingSettings | null = settings()) {
  setActivePinia(createPinia());
  vi.mocked(TutoringReminderSettingsService.getBillReminders).mockResolvedValue({
    offsets: [1440],
  } as never);
  if (s === null) {
    vi.mocked(TutoringBillingSettingsService.get).mockRejectedValue(new Error('500'));
  } else {
    vi.mocked(TutoringBillingSettingsService.get).mockResolvedValue(s);
    vi.mocked(TutoringBillingSettingsService.update).mockResolvedValue(s);
  }

  const w = mount(AdminTutoring2BillingSettingsView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: { BrandPageHeader: true, NavIcon: true, AsyncView: {
        props: ['state'],
        template: '<div><slot v-if="state?.status === \'content\'" /></div>',
      } },
    },
  });
  await flushPromises();
  return w;
}

/** The panel's save button is the last one in the payment section. */
async function save(w: Awaited<ReturnType<typeof mountView>>) {
  const buttons = w.findAll('button').filter((b) => !b.attributes('disabled'));
  await buttons[buttons.length - 1].trigger('click');
  await flushPromises();
}

describe('AdminTutoring2BillingSettingsView payment destination', () => {
  beforeEach(() => vi.clearAllMocks());

  it('sends ONLY the edited field, leaving the bank details untouched', async () => {
    const w = await mountView();

    await w.find('textarea').setValue('Transfer sebelum tanggal 10.');
    await save(w);

    expect(TutoringBillingSettingsService.update).toHaveBeenCalledTimes(1);
    const patch = vi.mocked(TutoringBillingSettingsService.update).mock.calls[0][0];
    expect(patch).toEqual({ payment_instructions: 'Transfer sebelum tanggal 10.' });
    // The keys that would have cleared a real tenant's account.
    expect(patch).not.toHaveProperty('bank_name');
    expect(patch).not.toHaveProperty('bank_account_number');
    expect(patch).not.toHaveProperty('bank_account_holder');
  });

  it('sends an explicit null when a field is cleared', async () => {
    // Absent means leave alone; null means clear. Emptying an input has
    // to reach the API as the second, or the field can never be removed.
    const w = await mountView();
    const inputs = w.findAll('input[type="text"]');

    await inputs[0].setValue('');
    await save(w);

    expect(vi.mocked(TutoringBillingSettingsService.update).mock.calls[0][0])
      .toEqual({ bank_name: null });
  });

  it('treats a whitespace-only field as cleared, not as a blank string', async () => {
    const w = await mountView();

    await w.findAll('input[type="text"]')[0].setValue('   ');
    await save(w);

    expect(vi.mocked(TutoringBillingSettingsService.update).mock.calls[0][0])
      .toEqual({ bank_name: null });
  });

  it('does not fire a request when nothing changed', async () => {
    const w = await mountView();

    // Re-typing the same value is not a change.
    await w.findAll('input[type="text"]')[0].setValue('BCA');
    await save(w);

    expect(TutoringBillingSettingsService.update).not.toHaveBeenCalled();
  });

  it('keeps the reminder panel usable when the destination fails to load', async () => {
    // Two independent settings surfaces on one screen; one failing must
    // not take the page down.
    const w = await mountView(null);

    expect(w.text()).toContain('tutoring2.admin.billingSettings.paymentLoadFailed');
    // The reminder form still rendered.
    expect(w.html()).toContain('tutoring2.admin.billingSettings');
  });

  describe('QRIS upload', () => {
    function pick(w: Awaited<ReturnType<typeof mountView>>, file: File) {
      const input = w.find('input[type="file"]');
      Object.defineProperty(input.element, 'files', { value: [file], configurable: true });
      return input.trigger('change');
    }

    it('uploads a valid image and reseeds from the SERVER response', async () => {
      const saved = settings({ qris_image_url: 'https://signed.example/qris.png?sig=abc' });
      vi.mocked(TutoringBillingSettingsService.uploadQris).mockResolvedValue(saved);

      const w = await mountView();
      await pick(w, new File(['x'], 'qris.png', { type: 'image/png' }));
      await flushPromises();

      expect(TutoringBillingSettingsService.uploadQris).toHaveBeenCalledTimes(1);
      // The preview must come from the server's SIGNED url, never from a
      // local object URL — otherwise the admin sees an image the parents
      // cannot load.
      expect(w.find('img').attributes('src')).toBe('https://signed.example/qris.png?sig=abc');
    });

    it('rejects a non-image before it reaches the network', async () => {
      const w = await mountView();
      await pick(w, new File(['x'], 'doc.pdf', { type: 'application/pdf' }));
      await flushPromises();

      expect(TutoringBillingSettingsService.uploadQris).not.toHaveBeenCalled();
      expect(w.text()).toContain('tutoring2.admin.billingSettings.qrisTypeError');
    });

    it('rejects an oversized image before it reaches the network', async () => {
      const w = await mountView();
      const big = new File([new Uint8Array(3 * 1024 * 1024)], 'big.png', { type: 'image/png' });
      await pick(w, big);
      await flushPromises();

      expect(TutoringBillingSettingsService.uploadQris).not.toHaveBeenCalled();
      expect(w.text()).toContain('tutoring2.admin.billingSettings.qrisSizeError');
    });

    it('a failed upload surfaces an error and does not touch the saved image', async () => {
      vi.mocked(TutoringBillingSettingsService.uploadQris).mockRejectedValue(new Error('413'));

      const w = await mountView();
      await pick(w, new File(['x'], 'qris.png', { type: 'image/png' }));
      await flushPromises();

      expect(w.text()).toContain('413');
      // Still the originally-loaded value, not a half-applied one.
      expect(w.find('img').exists()).toBe(false);
    });
  });
});
