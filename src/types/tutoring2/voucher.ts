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
 * Runtime counterpart of `VoucherStatus`, mirroring the backend enum
 * `App\Modules\Tutoring\Enums\VoucherStatus`.
 *
 * `VoucherStatus` is a type, so it evaporates at runtime — a call site
 * that needs to SEND a status (e.g. flipping an archived voucher back to
 * active through `PUT /tutoring-v2/vouchers/{id}`) would otherwise have
 * to retype the literal, and a backend rename would then fail silently
 * as a 422 instead of loudly at compile time.
 *
 * `satisfies Record<VoucherStatus, VoucherStatus>` makes the map
 * exhaustive in both directions: adding a case to the union without
 * adding it here is a compile error, and so is a typo in a value.
 */
export const VOUCHER_STATUS = {
  active: 'active',
  archived: 'archived',
} as const satisfies Record<VoucherStatus, VoucherStatus>;

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
  /**
   * Only populated when the backend eager-loaded the redemptions
   * relation — which `VoucherController::index` does NOT, so every row
   * on the vouchers list arrives without this key. `?? 0` would report
   * an untouched voucher; use `@/lib/absent-vs-zero`.
   */
  redemption_count?: number;
  /**
   * How many students this voucher is PERSONALLY aimed at.
   *
   * Emitted only when the caller ran `Voucher::withRecipientCount()` —
   * `VoucherController`'s index / show / store / update / archive and
   * both recipient writes all do, so every admin-facing payload carries
   * it. `myIndex` (the wali list) deliberately does NOT: the number
   * counts the other families the same promo reached.
   *
   * ABSENT IS NOT ZERO here, and the difference is load-bearing rather
   * than cosmetic: a real `0` means "general promo, anyone with the code
   * may spend it", while an absent key means the server said nothing.
   * Rendering the second as the first would label an untargeted voucher
   * and a silent one identically. Read it through `@/lib/absent-vs-zero`.
   */
  recipient_count?: number;
  /**
   * Derived server-side from `recipient_count > 0` — never a second
   * query, so it cannot disagree with the number beside it. It is the
   * same predicate `Voucher::isTargeted()` enforces on the redeem path,
   * which is why the screens branch on THIS rather than recomputing:
   * a row reading "Promo umum" must not describe a voucher the server
   * will refuse for everyone but three students.
   *
   * Absent whenever `recipient_count` is absent (same `isset` gate).
   */
  is_targeted?: boolean;
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


/**
 * One named recipient of a personal voucher — a row of
 * `GET /tutoring-v2/vouchers/{id}/recipients`
 * (`VoucherRecipientResource`).
 *
 * A RECIPIENT IS A STUDENT, NOT A USER OR A WALI. That is a deliberate
 * backend decision, not an implementation detail the client may round
 * off: redemption is already per-student via `enrollment_id`, so aiming
 * a voucher at a user account would sit COARSER than the guard enforcing
 * it — a wali with two children could then discount the wrong child's
 * bill. Every picker on this surface therefore chooses students.
 *
 * `student_name` / `student_number` are denormalised labels the backend
 * eager-loads, so the admin screen never resolves uuids itself. Both are
 * `whenLoaded`-gated server-side, hence optional here.
 */
export interface BimbelVoucherRecipient {
  id: string;
  voucher_id: string;
  student_id: string;
  student_name?: string | null;
  student_number?: string | null;
  created_at?: string;
}

/**
 * Body of `POST /tutoring-v2/vouchers/{id}/recipients`, matching
 * `AttachVoucherRecipientsRequest` exactly:
 *
 *   student_ids    required | array | min:1 | max:500
 *   student_ids.*  required | uuid  | distinct
 *
 * `required` + `min:1` means AN EMPTY ARRAY IS A 422, not a way to clear
 * the list — detaching is its own verb. Callers must refuse to submit an
 * empty selection rather than sending one and reading the rejection.
 */
export interface VoucherAttachRecipientsPayload {
  student_ids: string[];
}

/**
 * What both recipient WRITES hand back: the refreshed voucher row (so a
 * caller can splice it straight into its table with the new
 * `recipient_count` / `is_targeted` already on it) plus the count of
 * rows the operation actually changed, which arrives under `meta`.
 *
 * Both writes are IDEMPOTENT server-side, so the count can legitimately
 * be 0 — re-attaching an existing recipient, or detaching someone who
 * was never one. That is a success, not a failure.
 */
export interface VoucherRecipientMutationResult {
  voucher: BimbelVoucher;
  /** `meta.attached_count` on attach, `meta.detached_count` on detach. */
  changedCount: number;
}
