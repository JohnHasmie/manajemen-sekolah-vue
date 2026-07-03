/**
 * Types for the super-admin modular-SaaS surface.
 *
 * Backend contract:
 *   GET    /billing/admin/tenants/{schoolId}/modules
 *   POST   /billing/admin/tenants/{schoolId}/modules      { module_key, source? }
 *   DELETE /billing/admin/tenants/{schoolId}/modules/{moduleKey}?at_period_end=…
 */

/** One row per OPTIONAL module in the catalog + whether this tenant holds it. */
export interface AdminTenantModuleRow {
  module_key: string;
  label: string;
  group: string;
  entitled: boolean;
  /** Only set when entitled=true. */
  source: 'paid' | 'comp' | null;
  /** Only set when entitled=true. */
  cancel_at_period_end: boolean | null;
  /** Effective per-seat rate — snapshot if entitled, catalog otherwise. */
  price_per_student: number;
  price_per_staff: number;
}
