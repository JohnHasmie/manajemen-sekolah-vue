/**
 * Greenfield BE-16 voucher DTOs.
 *
 * Anchored on the backend contract at:
 *   - VoucherController      → app/Modules/Tutoring/Http/Controllers/VoucherController.php
 *   - VoucherResource        → app/Modules/Tutoring/Http/Resources/VoucherResource.php
 *   - VoucherRedemptionResource → same folder
 *   - VoucherKind + VoucherStatus enums
 *
 * NOTE — the backend uses `kind` (percent|fixed) and `value` (integer), NOT
 * `discount_type` / `discount_value`. The WEB-9 task brief mentions the
 * old naming ("discount_type", "discount_value", "max_uses",
 * "applies_to") — those don't exist on the BE-16 endpoint. We keep the
 * *labels* from the brief in the UI copy but wire the actual request +
 * response shapes to the real payload the controller accepts.
 */
export type VoucherKind = 'percent' | 'fixed';
export type VoucherStatus = 'active' | 'archived';

/**
 * Kept as an alias so callers who read the WEB-9 brief still find the
 * expected identifier. Under the hood it is `VoucherKind`.
 */
export type VoucherDiscountType = VoucherKind;

export interface BimbelVoucher {
  id: string;
  school_id: string;
  code: string;
  description?: string | null;
  kind: VoucherKind;
  kind_label?: string;
  /** Integer. When `kind==='percent'` this is 1..100. When `kind==='fixed'` this is a rupiah amount. */
  value: number;
  /** null = unlimited redemptions. */
  max_redemptions?: number | null;
  /** Only populated when the backend eager-loaded the redemptions relation. */
  redemption_count?: number;
  /** YYYY-MM-DD (backend emits toDateString()). null = no lower bound. */
  valid_from?: string | null;
  /** YYYY-MM-DD. null = no upper bound. */
  valid_until?: string | null;
  status: VoucherStatus;
  status_label?: string;
  created_at?: string;
  updated_at?: string;
}

export interface VoucherListParams {
  page?: number;
  per_page?: number;
  status?: VoucherStatus | '';
  /** BE controller reads `code` (case-insensitive contains). We expose it as `search` too so callers can be idiomatic. */
  code?: string;
  search?: string;
}

export interface VoucherCreatePayload {
  code: string;
  description?: string | null;
  kind: VoucherKind;
  value: number;
  max_redemptions?: number | null;
  valid_from?: string | null;
  valid_until?: string | null;
  status?: VoucherStatus;
}

export type VoucherUpdatePayload = Partial<VoucherCreatePayload>;

export interface VoucherRedeemPayload {
  enrollment_id: string;
  bill_id: string;
}

export interface BimbelVoucherRedemption {
  id: string;
  school_id: string;
  voucher_id: string;
  enrollment_id: string;
  bill_id: string;
  applied_amount: number;
  redeemed_at?: string | null;
  /** Only present when the backend eager-loaded the voucher relation. */
  voucher?: {
    id: string;
    code: string;
    kind: VoucherKind;
    value: number;
  } | null;
  created_at?: string;
}
