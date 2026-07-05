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
   * Top-level payment channels the backend is currently willing to
   * accept. Server-side filtered: `midtrans` is DROPPED when the
   * server has no Midtrans key configured, so an instance that only
   * accepts manual transfers advertises `['bank_transfer_manual']`
   * alone. FE uses this to decide whether to render the Midtrans
   * option at all.
   */
  supported_gateways: string[];
  /**
   * Bank-transfer fallback info — used to render "Transfer ke X"
   * upfront on /subscribe when manual is the only path. Kept
   * optional because pre-!243 backends don't ship it; the FE
   * shouldn't hard-fail on an older deployment.
   */
  bank_transfer?: {
    bank_name: string;
    account_number: string;
    account_holder: string;
  };
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
  // Wire name is `plan` — backend's SubscriptionPlan enum uses this key.
  plan: BillingPeriod;
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
  // Wire name is `plan` — CreateSubscriptionRequest validates it under
  // that key against SubscriptionPlan::values() (['monthly', 'yearly']).
  plan: BillingPeriod;
  student_count: number;
  staff_count: number;
  gateway: 'midtrans' | 'bank_transfer_manual';
  /** Only present when creating a fresh tenant (no tenant_id). */
  new_tenant?: {
    name: string;
    tenant_type?: TenantType;
    admin_email: string;
    /** Newer submissions from /subscribe/new use `admin_whatsapp`;
     *  older /subscribe one-page form still ships `whatsapp`. Both
     *  are optional at the type level so callers can pick one. */
    admin_whatsapp?: string;
    whatsapp?: string;
    // /subscribe/new wizard extras; optional so legacy submissions
    // still validate.
    education_level?: string | null;
    city?: string;
    address?: string;
    npsn?: string;
    admin_name?: string;
    admin_job_title?: string;
  };
  /**
   * Existing-tenant path only. When true, the backend clears seeded
   * demo scenario data (dummy siswa, guru, sesi, tagihan) as part of
   * activation. Silently ignored on the new-tenant path.
   */
  wipe_demo_data?: boolean;
  /**
   * Modular-SaaS: array of module + bundle keys the customer picked.
   * Empty → backend falls back to legacy flat-per-seat pricing.
   */
  modules?: string[];
  /**
   * AI quota upgrades per AI module — extra monthly generates over
   * the base included. Keyed by module key (e.g. { ai_rpp: 30 }).
   */
  ai_quota?: Record<string, number>;
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
  /**
   * `bank_transfer_manual` only. Public share URL the backend mints:
   *   {frontend_url}/billing/transfer/{share_token}
   * We use it to derive the 48-char share_token — that token is the
   * only identifier the public `mark-transferred` endpoint accepts.
   */
  share_url?: string | null;
}

/**
 * GET /billing/seat-usage — live headcount vs. paid quota for the
 * currently-scoped tenant. Powers the SubscriptionUsageBanner + the
 * hard-cap 402 handler.
 */
export type SeatZone = 'normal' | 'grace' | 'overage' | 'hard';

export interface SeatUsage {
  subscription_id: string | null;
  is_demo: boolean;
  paid_student: number;
  paid_staff: number;
  hard_student: number;
  hard_staff: number;
  grace_flat: number;
  live_student: number;
  live_staff: number;
  over_student: number;
  over_staff: number;
  zone_student: SeatZone;
  zone_staff: SeatZone;
  days_remaining: number | null;
  expires_at: string | null;
}

/** POST /billing/addon/quote response. */
export interface AddonQuote {
  daily_rate: number;
  days_remaining: number;
  seats_delta_total: number;
  amount: number;
  currency: string;
}

/** POST /billing/addon response (creates the pending addon). */
export interface AddonCreated {
  addon_id: string;
  order_id: string;
  amount: number;
  currency: string;
  share_url: string;
  bank_transfer_info: {
    bank_name: string;
    account_number: string;
    account_holder: string;
    reference_code: string;
  };
  quote: AddonQuote;
}

/** 402 payload returned when a create/import trips the hard cap. */
export interface SeatHardCapError {
  error: 'seat_hard_cap_reached';
  message: string;
  dimension: 'student' | 'staff';
  is_demo: boolean;
  seats_paid: number;
  seats_live: number;
  seats_hard: number;
  batch_size: number;
  days_remaining: number | null;
  top_up_url_web: string;
  top_up_deeplink_mobile: string;
}

/**
 * Modular-SaaS catalog (GET /billing/modules/catalog).
 *
 * `optional` = sellable feature modules keyed by module key.
 * `bundles` = preset bundles (Complete, Tutoring, AI) with flat rates.
 * `core_prefixes` = always-on permission prefixes (informational).
 */
export interface ModuleCatalogItem {
  key: string;
  label: string;
  group: string;
  prefixes: string[];
  price_per_student: number;
  price_per_staff: number;
  pricing_seat: 'student' | 'staff';
  requires: string[];
  is_ai: boolean;
}

export interface BundleCatalogItem {
  key: string;
  label: string;
  members: string[];
  price_per_student: number;
  price_per_staff: number;
}

export interface ModuleCatalog {
  optional: Record<string, ModuleCatalogItem>;
  bundles: Record<string, BundleCatalogItem>;
  core_prefixes: string[];
}

/** Modular quote breakdown (POST /billing/quote with `modules[]`). */
export interface ModularQuoteLine {
  key: string;
  price_per_student: number;
  price_per_staff: number;
  monthly_line: number;
}

export interface ModularAiQuotaLine {
  key: string;
  extra_generates: number;
  monthly_line: number;
}

export interface ModularQuote {
  selected_keys: string[];
  expanded_modules: string[];
  student_count: number;
  staff_count: number;
  per_module: ModularQuoteLine[];
  ai_quota_lines: ModularAiQuotaLine[];
  monthly_amount: number;
  yearly_gross: number;
  yearly_amount: number;
  yearly_savings: number;
  chosen_amount: number;
  chosen_plan: BillingPeriod;
  currency: string;
}

/** GET /billing/my-subscription — used by the nav chip to decide visibility. */
export interface MySubscription {
  has_subscription: boolean;
  is_active: boolean;
  status: TenantSubscriptionStatus;
  period?: BillingPeriod | null;
  expires_at?: string | null;
  tenant_id?: string | null;
  /**
   * True while the active tenant is still a demo school. Drives
   * demo-only surfaces (e.g. the "Reset data demo" settings tile) so
   * they never render for a real, paying tenant.
   */
  is_demo: boolean;
}

/**
 * GET /billing/modules/mine — powers the "Kelola Modul" self-service
 * page. Richer per-row data than /entitlements (which is a flat
 * string[]): every row carries its own cancel_at_period_end flag,
 * source (paid vs comp), and price snapshots so the FE can render
 * accurate status pills + strike-through amounts.
 */
export interface MyModuleRow {
  module_key: string;
  source: 'paid' | 'comp';
  cancel_at_period_end: boolean;
  price_per_student_snapshot: number;
  price_per_staff_snapshot: number;
  monthly_extra_quota: number;
  monthly_amount: number;
}

export interface MyModulesSubscription {
  id: string;
  plan: BillingPeriod;
  status: string;
  starts_at: string | null;
  expires_at: string | null;
  student_count: number;
  staff_count: number;
  days_remaining: number;
  currency: string;
}

export interface MyModules {
  subscription: MyModulesSubscription | null;
  modules: MyModuleRow[];
}

/**
 * POST /billing/modules/add response — mirrors AddonCreated but keyed
 * by the module the tenant just bought instead of a seat delta.
 */
export interface ModuleAddonCreated {
  addon_id: string;
  order_id: string;
  module_key: string;
  amount: number;
  currency: string;
  days_remaining: number;
  share_url: string;
  bank_transfer_info: {
    bank_name: string;
    account_number: string;
    account_holder: string;
    reference_code: string;
  };
}
