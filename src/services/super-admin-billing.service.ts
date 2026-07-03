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
import type { AdminTenantModuleRow } from '@/types/super-admin-billing';

function humanError(e: unknown, fallback: string): string {
  const msg = (e as { response?: { data?: { error?: string; message?: string } } })?.response?.data;
  return msg?.error ?? msg?.message ?? (e as Error)?.message ?? fallback;
}

export const SuperAdminBillingService = {
  /**
   * List every optional module for a tenant with per-row entitlement
   * status. Includes both entitled + un-entitled rows so the grid can
   * show both "grant" and "revoke" affordances in one pass.
   */
  async listModules(schoolId: string): Promise<AdminTenantModuleRow[]> {
    try {
      const res = await api.get(`/billing/admin/tenants/${encodeURIComponent(schoolId)}/modules`);
      const body = res.data?.data ?? res.data;
      return Array.isArray(body) ? body as AdminTenantModuleRow[] : [];
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
