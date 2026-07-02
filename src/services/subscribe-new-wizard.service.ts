/**
 * SubscribeNewWizardService — thin wrapper over the three wizard-state
 * endpoints on the Laravel backend:
 *
 *   GET    /billing/subscription-wizard
 *   PUT    /billing/subscription-wizard
 *   DELETE /billing/subscription-wizard
 *
 * All three require auth:sanctum. Anonymous visitors skip the server
 * copy entirely — the wizard is happy with localStorage-only until
 * they Google-login, at which point we replay the local snapshot.
 *
 * Errors are swallowed into null returns because the wizard is not
 * blocking on the draft round-trip; a failed save simply keeps the
 * client-only copy.
 */
import { api } from '@/lib/http';
import type {
  NewTenantWizardPayload,
  SubscriptionWizardStateRow,
  WizardStep,
} from '@/types/subscribe-new-wizard';

export const SubscribeNewWizardService = {
  async load(): Promise<SubscriptionWizardStateRow | null> {
    try {
      const res = await api.get('/billing/subscription-wizard');
      const raw = res.data?.data;
      if (!raw) return null;
      return {
        current_step: (raw.current_step ?? 0) as WizardStep,
        payload: (raw.payload ?? null) as NewTenantWizardPayload | null,
        last_active_at: raw.last_active_at ?? null,
        completed_at: raw.completed_at ?? null,
        provisioned_subscription_id: raw.provisioned_subscription_id ?? null,
      };
    } catch {
      return null;
    }
  },

  /**
   * Upsert the current step + payload. Debounce in the caller — this
   * function fires one round-trip per call.
   */
  async save(
    step: WizardStep,
    payload: NewTenantWizardPayload | null,
  ): Promise<boolean> {
    try {
      await api.put('/billing/subscription-wizard', {
        current_step: step,
        payload,
      });
      return true;
    } catch {
      return false;
    }
  },

  async clear(): Promise<void> {
    try {
      await api.delete('/billing/subscription-wizard');
    } catch {
      /* non-fatal — the draft will just linger server-side */
    }
  },
};
