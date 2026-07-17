/**
 * SuperAdminBillingService — GET/POST/DELETE
 * /billing/admin/tenants/{schoolId}/modules
 *
 * The self-service admin surface uses SubscriptionBillingService's
 * module methods (subscription_id + module_key). Super-admin ops are
 * scoped by tenant instead, so they live in a distinct service to keep
 * the RBAC boundary obvious at the call site.
 */
import { api } from '@/lib/http';
import type { AdminTenantModulesResponse } from '@/types/super-admin-billing';

function humanError(e: unknown, fallback: string): string {
  const msg = (e as { response?: { data?: { error?: string; message?: string } } })?.response?.data;
  return msg?.error ?? msg?.message ?? (e as Error)?.message ?? fallback;
}

/**
 * Empty payload used when the tenant has no active subscription (or the
 * server returned an unexpected shape). Callers can render the empty
 * state without null-checking every field.
 */
const EMPTY_RESPONSE: AdminTenantModulesResponse = {
  subscription: null,
  modules: [],
  bundles: [],
};

export const SuperAdminBillingService = {
  /**
   * List every optional module for a tenant with per-row entitlement
   * status, plus any bundles the tenant holds + a subscription snapshot
   * (amount / monthly_amount / applied_discount) so the FE can render
   * the header tile with strikethrough pricing.
   *
   * Regression fix (MTs Muhammadiyah, Jul 2026): the payload used to be
   * a plain array of module rows; backend now expands bundle rows to
   * their member modules so a tenant on `bundle_complete` no longer
   * reads as "BELUM AKTIF" for all ten members. Legacy array-shaped
   * responses from unpatched backends still work — the wrapper below
   * degrades gracefully to `{ modules, bundles: [], subscription: null }`.
   */
  async listModules(schoolId: string): Promise<AdminTenantModulesResponse> {
    try {
      const res = await api.get(`/billing/admin/tenants/${encodeURIComponent(schoolId)}/modules`);
      const body = res.data?.data ?? res.data;
      // Fresh shape: { subscription, modules, bundles }.
      if (body && typeof body === 'object' && !Array.isArray(body) && Array.isArray(body.modules)) {
        return {
          subscription: body.subscription ?? null,
          modules: body.modules,
          bundles: Array.isArray(body.bundles) ? body.bundles : [],
        };
      }
      // Legacy shape: bare array. Keep the page functional against an
      // older deployment during coordinated rollouts.
      if (Array.isArray(body)) {
        return { ...EMPTY_RESPONSE, modules: body };
      }
      return EMPTY_RESPONSE;
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memuat modul tenant.'));
    }
  },

  /**
   * Grant a module. `source=comp` is the default — most super-admin
   * grants are complimentary. `paid` is available for the rare case
   * where operations converts a bank-transfer top-up manually.
   */
  async grantModule(payload: {
    schoolId: string;
    module_key: string;
    source?: 'paid' | 'comp';
  }): Promise<void> {
    try {
      await api.post(
        `/billing/admin/tenants/${encodeURIComponent(payload.schoolId)}/modules`,
        { module_key: payload.module_key, source: payload.source ?? 'comp' },
      );
    } catch (e) {
      throw new Error(humanError(e, 'Gagal memberikan modul.'));
    }
  },

  /**
   * Revoke a module. `atPeriodEnd=true` sets cancel_at_period_end (soft
   * — module stays entitled until expires_at, drops at renewal).
   * Default false = immediate revocation (used for comp cleanups when
   * an ops decision reversed).
   */
  async revokeModule(payload: {
    schoolId: string;
    module_key: string;
    atPeriodEnd?: boolean;
  }): Promise<void> {
    try {
      await api.delete(
        `/billing/admin/tenants/${encodeURIComponent(payload.schoolId)}/modules/${encodeURIComponent(payload.module_key)}`,
        { params: { at_period_end: payload.atPeriodEnd ? 'true' : 'false' } },
      );
    } catch (e) {
      throw new Error(humanError(e, 'Gagal mencabut modul.'));
    }
  },
};
