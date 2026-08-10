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
   * Upload the QRIS image. Persists it server-side in the same call and
   * returns the updated settings, so there is no second save to forget.
   *
   * `qris_image_url` on the response is a SIGNED, expiring URL — the
   * backend stores a storage path and signs it per request, because the
   * bucket's own endpoint rejects unsigned reads. Do not cache it, and
   * do not persist it anywhere: re-read it from the settings payload.
   */
  async uploadQris(file: File): Promise<BillingSettings> {
    const form = new FormData();
    form.append('image', file);
    const r = await api.post<OneEnvelope<BillingSettings>>(
      '/tutoring-v2/billing-settings/qris',
      form,
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
