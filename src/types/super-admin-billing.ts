/**
 * Types for the super-admin modular-SaaS surface.
 *
 * Backend contract:
 *   GET    /billing/admin/tenants/{schoolId}/modules
 *   POST   /billing/admin/tenants/{schoolId}/modules      { module_key, source? }
 *   DELETE /billing/admin/tenants/{schoolId}/modules/{moduleKey}?at_period_end=…
 */

import type { ModuleTenantScope } from './subscription-billing';

/** One row per OPTIONAL module in the catalog + whether this tenant holds it. */
export interface AdminTenantModuleRow {
  module_key: string;
  label: string;
  group: string;
  entitled: boolean;
  /**
   * Tenant scope the module is filtered against on the server (see BE
   * `fix/billing-module-catalog-tenant-scope`). Sekolah-only modules
   * like `grades` report `tenant_scope: 'school'`; bimbel-only ones
   * like `tutoring` report `'bimbel'`; shared ones report `'all'`.
   * Optional so an older server response still deserialises.
   */
  tenant_scope?: ModuleTenantScope;
  /**
   * Where the entitlement comes from — only set when `entitled=true`.
   * An individual `subscription_modules` row wins over a bundle, so a
   * comp'd standalone grant reads `source='comp'` even if the tenant
   * also holds a bundle that includes this module.
   */
  source: 'paid' | 'comp' | null;
  /**
   * Bundle key backing this module row (e.g. `bundle_complete`) when
   * the entitlement is inherited from a package the tenant holds. Null
   * when the tenant owns the module standalone OR doesn't own it at all.
   * Regression fix (MTs Muhammadiyah, Jul 2026): before this field,
   * bundle-only members read `entitled=false` and the whole page said
   * "BELUM AKTIF" while the gate correctly unlocked them.
   */
  bundle_source: string | null;
  /** Human bundle label (e.g. `Paket Lengkap (Sekolah)`) — display-only. */
  bundle_label: string | null;
  /** Only set when entitled=true. */
  cancel_at_period_end: boolean | null;
  /** Effective per-seat rate — snapshot if entitled, catalog otherwise. */
  price_per_student: number;
  price_per_staff: number;
}

/**
 * One row per BUNDLE the tenant holds. Renders as its own "Paket aktif"
 * tile so super-admin sees at a glance which package is behind the flood
 * of green module badges + the flat bundle price snapshot.
 */
export interface AdminTenantBundleRow {
  module_key: string;
  label: string;
  source: 'paid' | 'comp';
  cancel_at_period_end: boolean;
  price_per_student: number;
  price_per_staff: number;
  members: { key: string; label: string }[];
}

/**
 * Snapshot of the tenant's active subscription — matches the shape the
 * self-service /billing/modules/mine endpoint already returns so the
 * same discount-badge / strikethrough render logic can be reused.
 * Null when the tenant has no active subscription (page renders an
 * empty state; no entitled rows to show either).
 */
export interface AdminTenantSubscriptionSnapshot {
  id: string;
  plan: 'monthly' | 'yearly';
  status: string;
  starts_at: string | null;
  expires_at: string | null;
  student_count: number;
  staff_count: number;
  days_remaining: number;
  currency: string;
  /** Full pre-discount monthly bill (Rp). */
  monthly_amount: number;
  /** Actual paid amount (Rp) — differs from monthly_amount when a
   *  discount code was applied at checkout. */
  amount: number;
  applied_discount: {
    code: string | null;
    description: string | null;
    type: 'percent' | 'nominal' | null;
    value: number | null;
    duration_months: number | null;
    valid_until: string | null;
    discount_amount: number;
  } | null;
}

/**
 * The full response payload from GET /billing/admin/tenants/{id}/modules.
 */
export interface AdminTenantModulesResponse {
  subscription: AdminTenantSubscriptionSnapshot | null;
  modules: AdminTenantModuleRow[];
  bundles: AdminTenantBundleRow[];
}
