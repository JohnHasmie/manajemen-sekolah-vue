/**
 * subscription-billing.ts — types for the KamilEdu subscription flow.
 *
 * DISTINCT from `billing.ts` (which models per-student SPP tagihan on
 * the parent surface). These types model the *tenant subscription*
 * surface — school/bimbel owner buying access to the platform,
 * billed monthly or yearly based on active data (siswa + guru/tutor
 * counts).
 *
 * Backend contract (see kamiledu-ai billing agent notes):
 *   GET  /billing/plans          → PricingPlan
 *   GET  /billing/my-tenants     → { tenants: SubscriptionTenant[] }
 *   POST /billing/quote          → SubscriptionQuote
 *   POST /billing/subscribe      → SubscribeResult
 *   GET  /billing/my-subscription→ MySubscription
 */

export type TenantType = 'sekolah' | 'bimbel';
export type BillingPeriod = 'monthly' | 'yearly';

/** Pricing catalog — returned by GET /billing/plans. */
export interface PricingPlan {
  currency: string;
  price_per_student: number;
  price_per_staff: number;
  /** e.g. 20 for a 20% yearly discount. */
  yearly_discount_pct: number;
  /**
   * Payment channels the backend + Midtrans setup accepts. Purely
   * cosmetic on the client — real gating happens server-side.
   */
  supported_gateways: string[];
}

/** Tenant status shown in the demo picker + banner. */
export type TenantSubscriptionStatus =
  | 'demo'
  | 'active'
  | 'expired'
  | 'trialing'
  | 'unpaid'
  | string;

/**
 * A tenant the signed-in user owns / has access to. Returned by
 * GET /billing/my-tenants.
 */
export interface SubscriptionTenant {
  id: string;
  name: string;
  tenant_type: TenantType;
  is_demo: boolean;
  student_count: number;
  staff_count: number;
  subscription_status: TenantSubscriptionStatus;
  subscription_expires_at?: string | null;
}

/**
 * Quote payload sent to POST /billing/quote — either a tenant_id (to
 * quote the existing tenant's counts) OR raw counts (for the new-signup
 * path where no tenant exists yet).
 */
export interface QuoteRequest {
  tenant_id?: string;
  tenant_type: TenantType;
  student_count: number;
  staff_count: number;
  period: BillingPeriod;
}

/** Quote response — used to confirm the amount before checkout. */
export interface SubscriptionQuote {
  currency: string;
  period: BillingPeriod;
  student_count: number;
  staff_count: number;
  student_subtotal: number;
  staff_subtotal: number;
  monthly_amount: number;
  yearly_amount: number;
  yearly_savings: number;
  chosen_amount: number;
}

/** Subscribe payload — POST /billing/subscribe. */
export interface SubscribeRequest {
  tenant_id?: string;
  tenant_type: TenantType;
  period: BillingPeriod;
  student_count: number;
  staff_count: number;
  gateway: 'midtrans' | 'bank_transfer_manual';
  /** Only present when creating a fresh tenant (no tenant_id). */
  new_tenant?: {
    name: string;
    admin_email: string;
    whatsapp: string;
  };
}

/** Manual-transfer bank instructions, returned when gateway=bank_transfer_manual. */
export interface ManualTransferInfo {
  bank_name: string;
  account_number: string;
  account_name: string;
  amount: number;
  reference: string;
  /** Optional ISO expiry — after this, the reservation is dropped. */
  expires_at?: string | null;
}

/**
 * Subscribe response. Shape depends on chosen gateway:
 *   - midtrans → snap_token + snap_redirect_url populated
 *   - bank_transfer_manual → bank_transfer_info populated
 */
export interface SubscribeResult {
  subscription_id: string;
  order_id: string;
  amount: number;
  gateway: 'midtrans' | 'bank_transfer_manual';
  snap_token?: string | null;
  snap_redirect_url?: string | null;
  bank_transfer_info?: ManualTransferInfo | null;
}

/** GET /billing/my-subscription — used by the nav chip to decide visibility. */
export interface MySubscription {
  has_subscription: boolean;
  is_active: boolean;
  status: TenantSubscriptionStatus;
  period?: BillingPeriod | null;
  expires_at?: string | null;
  tenant_id?: string | null;
}
