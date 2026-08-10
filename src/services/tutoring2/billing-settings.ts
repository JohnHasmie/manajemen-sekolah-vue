/**
 * Tutoring2 · billing settings + payment account.
 *
 * Backed by a table that predates this module: `tenant_billing_settings`
 * survived the CLEAN-1 drop with real data, so most tenants already have
 * a row here even though the greenfield surface never read it.
 */
import { api } from '@/lib/http';
import type {
  BillingSettings,
  BillingSettingsUpdatePayload,
  PaymentAccount,
} from '@/types/tutoring2/billing';

interface OneEnvelope<T> {
  data: T;
}

export const TutoringBillingSettingsService = {
  /** Admin config view. Requires `tutoring.billing_settings.manage`. */
  async get(): Promise<BillingSettings> {
    const r = await api.get<OneEnvelope<BillingSettings>>('/tutoring-v2/billing-settings');
    return r.data.data;
  },

  /**
   * Partial update — send ONLY the fields the form touched.
   *
   * The backend distinguishes absent from present-and-null, so passing a
   * fully-populated object with blanks would clear fields the admin
   * never edited. One production tenant's real bank details live in this
   * row, so that distinction is worth respecting at the call site.
   */
  async update(payload: BillingSettingsUpdatePayload): Promise<BillingSettings> {
    const r = await api.put<OneEnvelope<BillingSettings>>(
      '/tutoring-v2/billing-settings',
      payload,
    );
    return r.data.data;
  },

  /**
   * What a wali/siswa is shown so they can pay.
   *
   * Resolves to `null` when the tenant has configured nothing — the
   * caller must render "belum ada informasi pembayaran" rather than a
   * blank bank block, which reads as a real account with missing digits.
   */
  async getPaymentAccount(): Promise<PaymentAccount | null> {
    const r = await api.get<OneEnvelope<PaymentAccount | null>>(
      '/tutoring-v2/payment-account',
    );
    return r.data.data ?? null;
  },
};
