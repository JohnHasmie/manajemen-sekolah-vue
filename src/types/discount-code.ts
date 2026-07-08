/**
 * discount-code.ts — types for the super-admin discount code CRUD.
 *
 * Backend contract (see MR !358 / SuperAdminDiscountCodesController):
 *
 *   GET    /billing/admin/discount-codes            → list + meta
 *   POST   /billing/admin/discount-codes            → detail
 *   GET    /billing/admin/discount-codes/{id}       → detail
 *   PATCH  /billing/admin/discount-codes/{id}       → detail
 *   DELETE /billing/admin/discount-codes/{id}       → { deleted: true }
 *   GET    /billing/admin/discount-codes/{id}/redemptions → ledger + meta
 *
 * The subscribe-facing preview types live separately in
 * `subscription-billing.ts` — they're a subset of the admin shape and
 * shouldn't share a file (subscribe views don't need admin fields
 * like created_by / min_amount_monthly).
 */

export type DiscountCodeType = 'percent' | 'fixed';
export type DiscountCodeStatus = 'draft' | 'active' | 'paused' | 'archived';

/**
 * Effective (derived) status — computed by the backend so the FE
 * badge doesn't have to re-derive expired / exhausted / not_yet_active
 * from timestamps + used_count. Superset of the stored status.
 */
export type DiscountCodeEffectiveStatus =
  | DiscountCodeStatus
  | 'expired'
  | 'exhausted'
  | 'not_yet_active';

export type DiscountCodeTargetScope = 'all' | 'bundle' | 'modules';

/**
 * List row — the compact shape returned by index. Sort/filter friendly.
 */
export interface DiscountCodeRow {
  id: string;
  code: string;
  description: string;
  type: DiscountCodeType;
  value: number;
  duration_months: number | null;
  used_count: number;
  max_uses: number | null;
  /** 0-100 for the progress bar; null when max_uses is unlimited. */
  usage_pct: number | null;
  valid_from: string | null;
  valid_until: string | null;
  status: DiscountCodeStatus;
  effective_status: DiscountCodeEffectiveStatus;
  target_scope: DiscountCodeTargetScope;
  created_at: string | null;
}

/**
 * Detail — everything the create/edit form needs. Row + the fields
 * only relevant on the form (min spend, first_time_only, scope keys,
 * tenant allowlist, audit metadata).
 */
export interface DiscountCodeDetail extends DiscountCodeRow {
  min_amount_monthly: number;
  first_time_only: boolean;
  target_keys: string[];
  tenant_scope_ids: string[];
  created_by: string | null;
  updated_by: string | null;
  updated_at: string | null;
}

/**
 * Payload for POST — every field the create endpoint accepts. Kept
 * narrow-optional so form defaults can omit the fields backend already
 * defaults for (min_amount_monthly, first_time_only, target_scope,
 * status).
 */
export interface CreateDiscountCodePayload {
  code: string;
  description: string;
  type: DiscountCodeType;
  value: number;
  duration_months?: number | null;
  max_uses?: number | null;
  min_amount_monthly?: number;
  valid_from?: string | null;
  valid_until?: string | null;
  first_time_only?: boolean;
  status?: DiscountCodeStatus;
  target_scope?: DiscountCodeTargetScope;
  target_keys?: string[] | null;
  tenant_scope_ids?: string[] | null;
}

/** Partial update — every field optional. */
export type UpdateDiscountCodePayload = Partial<CreateDiscountCodePayload>;

export interface DiscountCodeListMeta {
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

export interface DiscountCodeListResponse {
  items: DiscountCodeRow[];
  meta: DiscountCodeListMeta;
}

export interface DiscountCodeListParams {
  search?: string;
  status?: DiscountCodeEffectiveStatus | '';
  sort?: 'newest' | 'oldest' | 'redemptions_desc' | 'redemptions_asc';
  page?: number;
  per_page?: number;
}

/**
 * Redemption ledger row — audit trail for one code. `redeemed_at`
 * always populated on backend insert; other user/subscription IDs
 * survive even if the linked rows are soft-deleted (the FK is loose).
 */
export interface DiscountCodeRedemption {
  id: string;
  subscription_id: string;
  tenant_id: string | null;
  redeemed_by_user_id: string | null;
  redeemed_at: string | null;
  discount_amount_applied: number;
  subscription_month_index: number | null;
}

export interface DiscountCodeRedemptionListResponse {
  items: DiscountCodeRedemption[];
  meta: DiscountCodeListMeta;
}
