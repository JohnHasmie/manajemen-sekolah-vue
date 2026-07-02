/**
 * Types for the super-admin tenants directory (Aktif / Demo / Semua
 * tabs on /super-admin/schools).
 *
 * Wire shape mirrors SuperAdminTenantsController::index() in the
 * Laravel backend.
 */

export type TenantScope = 'all' | 'paid' | 'demo';

export type PlatformTenantType = 'school' | 'tutoring';

/** Row projection from GET /super-admin/tenants. */
export interface PlatformTenant {
  id: string;
  name: string;
  tenant_type: PlatformTenantType;
  is_demo: boolean;
  /** Raw schools.status enum value (`active`, `inactive`, ...). */
  status: string;
  student_count: number;
  staff_count: number;
  /**
   * Latest non-canceled subscription status collapsed onto the tenant.
   * `none` when the tenant never had a subscription row.
   */
  subscription_status:
    | 'active'
    | 'pending_payment'
    | 'awaiting_verify'
    | 'expired'
    | 'none'
    | string;
  subscription_expires_at: string | null;
  subscription_plan: 'monthly' | 'yearly' | null;
  /** For is_demo tenants only — when the demo TTL expires. */
  demo_expires_at: string | null;
  city: string | null;
  education_level: string | null;
  created_at: string | null;
}

export interface PlatformTenantMeta {
  current_page: number;
  per_page: number;
  total: number;
  last_page: number;
}

export interface PlatformTenantListParams {
  scope?: TenantScope;
  search?: string;
  per_page?: number;
  page?: number;
}

export interface PlatformTenantListResult {
  items: PlatformTenant[];
  meta: PlatformTenantMeta;
}
