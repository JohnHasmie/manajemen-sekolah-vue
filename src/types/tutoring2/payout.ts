/**
 * Wire-shape types for the greenfield admin payouts surface
 * (BE-24 rates + settings, BE-25 self-service requests, BE-26 monthly
 * summary + close).
 *
 * Enum values MUST match the backend PHP enums 1:1 — the resource
 * classes in `App\Modules\Tutoring\Http\Resources\{RateResource,
 * SettingsResource, PayoutRequestResource, PayoutSummaryResource,
 * PayoutCloseResource}` emit `->value` for the string-cast enums, so
 * any drift here silently 422s the writes.
 *
 * Notable divergences from the WEB-16 task brief (backend truth wins):
 *   - PayoutRateKind is `per_session | monthly_salary | percent_revenue`
 *     (NOT `monthly`). See `App\Modules\Tutoring\Enums\PayoutRateKind`.
 *   - PayoutCycle is `monthly | biweekly` (no hyphen). See
 *     `App\Modules\Tutoring\Enums\PayoutCycle`.
 *   - PayoutSettings has `minimum_payout` + `notes`; the brief's
 *     `autoclose_day` / `payment_method` fields do NOT exist server-side
 *     yet. Modelled here as optional so a future BE addition doesn't
 *     force a breaking change on this file.
 *   - PayoutRequestStatus adds `rolled_back` (transitional; live flows
 *     land back on pending/approved/rejected via the rollback action).
 */

// ─── Rate kind + cycle enums (BE-24) ───────────────────────────────

export type PayoutRateKind =
  | 'per_session'
  | 'monthly_salary'
  | 'percent_revenue';

export const PAYOUT_RATE_KINDS: PayoutRateKind[] = [
  'per_session',
  'monthly_salary',
  'percent_revenue',
];

export type PayoutCycle = 'monthly' | 'biweekly';

// ─── Payout rate row (BE-24) ────────────────────────────────────────

export interface PayoutRate {
  id: string;
  tutor_id: string;
  /** Populated via `->with('tutor:id,name')` on the list endpoint. */
  tutor_name?: string | null;
  kind: PayoutRateKind;
  /** Rupiah for per_session/monthly_salary; 1..100 for percent_revenue. */
  value: number;
  effective_from: string; // YYYY-MM-DD
  effective_until: string | null; // YYYY-MM-DD | null = open-ended
  notes?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface UpsertPayoutRatePayload {
  tutor_id: string;
  kind: PayoutRateKind;
  value: number;
  effective_from: string; // YYYY-MM-DD
  effective_until?: string | null;
  notes?: string | null;
}

export interface ListPayoutRateParams {
  page?: number;
  per_page?: number;
  tutor_id?: string;
  /** When true, exclude rates whose effective_until has already passed. */
  active_only?: boolean;
}

// ─── Payout settings (BE-24) ────────────────────────────────────────

/**
 * Tenant-wide payout settings. The backend materialises a transient
 * default when no row is persisted yet, so the FE never has to guard
 * for `null`.
 *
 * `minimum_payout` is a rupiah threshold — self-service requests below
 * it are refused server-side. `notes` is free-form guidance shown to
 * tutors on the request form (out of scope for WEB-16 but read here).
 *
 * Optional fields (`autoclose_day`, `payment_method`) are placeholders
 * for a future BE extension; the current UpdateSettingsRequest ignores
 * them silently thanks to `sometimes` rules.
 */
export interface PayoutSettings {
  id?: string | null;
  cycle: PayoutCycle;
  default_kind: PayoutRateKind;
  minimum_payout: number | null;
  notes: string;
  /** Reserved — backend accepts on PUT via `sometimes` but does not persist. */
  autoclose_day?: number | null;
  /** Reserved — see `autoclose_day`. */
  payment_method?: 'transfer' | 'cash' | 'other' | null;
  updated_at?: string;
}

export interface UpdatePayoutSettingsPayload {
  cycle?: PayoutCycle;
  default_kind?: PayoutRateKind;
  minimum_payout?: number | null;
  notes?: string;
  autoclose_day?: number | null;
  payment_method?: 'transfer' | 'cash' | 'other' | null;
}

// ─── Payout requests (BE-25) ────────────────────────────────────────

export type PayoutRequestStatus =
  | 'pending'
  | 'approved'
  | 'rejected'
  | 'paid'
  | 'rolled_back';

export const PAYOUT_REQUEST_STATUSES: PayoutRequestStatus[] = [
  'pending',
  'approved',
  'rejected',
  'paid',
  'rolled_back',
];

export interface PayoutRequest {
  id: string;
  tutor_id: string;
  tutor_name?: string | null;
  period_month: string; // YYYY-MM
  /** Rupiah, bigint on the wire → number here (fits well under 2^53). */
  amount: number;
  status: PayoutRequestStatus;
  requested_at?: string | null;
  approved_at?: string | null;
  rejected_at?: string | null;
  paid_at?: string | null;
  /** Reject reason lands on `note`; payment reference lands on its own column. */
  note?: string | null;
  payment_reference?: string | null;
  reviewer_id?: string | null;
  reviewer_name?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface ListPayoutRequestParams {
  page?: number;
  per_page?: number;
  status?: PayoutRequestStatus;
  tutor_id?: string;
  month?: string; // YYYY-MM
}

export interface RejectPayoutRequestPayload {
  reason: string;
}

export interface MarkPayoutRequestPaidPayload {
  payment_reference?: string;
}

// ─── Payout summary + monthly close (BE-26) ─────────────────────────

/**
 * One row of the (school × tutor × month) aggregate. Backing shape is
 * a plain array from PayoutSummaryService, not an Eloquent model.
 */
export interface PayoutSummaryRow {
  tutor_id: string;
  tutor_name: string;
  period_month: string; // YYYY-MM
  sessions_taught: number;
  base_amount: number;
  adjustments: number;
  net_amount: number;
}

export interface PayoutSummaryMeta {
  period_month: string;
  tutor_count: number;
}

/**
 * Self-scoped payout summary — what `GET /tutoring-v2/payouts/summary`
 * returns for the CALLING tutor.
 *
 * Same field set as one {@link PayoutSummaryRow} of the tenant-wide
 * admin aggregate, but the backend resolves `tutor_id` from the
 * caller's `user_id` → `teachers.id` rather than accepting it as a
 * param. A tutor with no `teachers` row on this tenant (never
 * onboarded) gets an empty payload, hence every field is optional.
 *
 * Contract note vs the legacy v1 endpoint: v1 accepted `?user_id=` so
 * an admin could read any tutor's summary through the tutor-side path.
 * v2 deliberately does not — admins use `/payouts/admin-summary`
 * instead. Do not reintroduce a `user_id` param here.
 */
export interface SelfPayoutSummary {
  tutor_id?: string | null;
  tutor_name?: string | null;
  period_month?: string | null; // YYYY-MM
  sessions_taught?: number;
  base_amount?: number;
  adjustments?: number;
  net_amount?: number;
}

export interface CreatePayoutRequestPayload {
  month: string; // YYYY-MM
  amount: number;
  note?: string;
}

export interface PayoutClose {
  id: string;
  period_month: string; // YYYY-MM
  closed_at?: string | null;
  closed_by?: {
    user_id: string;
    name?: string | null;
  } | null;
  note?: string | null;
}

export interface ClosePayoutMonthPayload {
  month: string; // YYYY-MM
  note?: string;
}
