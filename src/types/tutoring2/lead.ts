/**
 * Lead / prospect types for the greenfield bimbel funnel.
 *
 * Mirrors the backend `LeadResource`
 * (App\Modules\Tutoring\Http\Resources\LeadResource) plus the two
 * closed enums (`LeadStatus`, `LeadSource`). These string unions are
 * intentionally kept flat — the enum "label()" strings from PHP arrive
 * denormalised on the wire as `status_label` / `source_label`, so the
 * frontend never needs to translate its own copy of the labels.
 *
 * Lifecycle DAG (enforced server-side by UpdateLeadAction):
 *
 *   new → contacted → trial → converted | dropped
 *
 * `converted` and `dropped` are terminal. Convert flows through the
 * dedicated POST /leads/{id}/convert endpoint which spins up an
 * Enrollment; Drop flows through POST /leads/{id}/drop with a nullable
 * reason note.
 */

export type LeadStatus =
  | 'new'
  | 'contacted'
  | 'trial'
  | 'converted'
  | 'dropped';

export type LeadSource =
  | 'website'
  | 'walkin'
  | 'referral'
  | 'whatsapp'
  | 'other';

/**
 * Snapshot of the enrollment created when a lead was converted.
 * Only present when the lead is in the `converted` terminal state AND
 * the response eager-loaded `convertedEnrollment` (index + show + the
 * convert/update endpoints all do — drop does not).
 */
export interface BimbelLeadConvertedEnrollmentSnapshot {
  id: string;
  student_id: string;
  program_id: string | null;
  billing_mode: 'prepaid' | 'monthly' | 'per_session' | null;
  status:
    | 'trial'
    | 'active'
    | 'paused'
    | 'graduated'
    | 'withdrawn'
    | null;
}

export interface BimbelLead {
  id: string;
  school_id: string;
  name: string;
  phone: string | null;
  email: string | null;
  source: LeadSource | null;
  source_label: string | null;
  status: LeadStatus | null;
  status_label: string | null;
  notes: string | null;
  interest_program_id: string | null;
  /** Denormalised program name — only present when index/show eager-loads. */
  interest_program_name?: string | null;
  assigned_to_user_id: string | null;
  /** Denormalised assignee name — only present when index/show eager-loads. */
  assigned_to_name?: string | null;
  converted_enrollment_id: string | null;
  converted_enrollment?: BimbelLeadConvertedEnrollmentSnapshot | null;
  created_at: string | null;
  updated_at: string | null;
}

/** Query params for GET /leads. */
export interface LeadListParams {
  page?: number;
  per_page?: number;
  status?: LeadStatus | '';
  source?: LeadSource | '';
  assigned_to_user_id?: string;
  /** Client-side filter — the BE index endpoint does not accept `search`. */
  search?: string;
}

/** Body for POST /leads (StoreLeadRequest). */
export interface CreateLeadPayload {
  name: string;
  phone?: string | null;
  email?: string | null;
  source: LeadSource;
  interest_program_id?: string | null;
  status?: LeadStatus | null;
  notes?: string | null;
  assigned_to_user_id?: string | null;
}

/** Body for PUT /leads/{id} (UpdateLeadRequest — every field optional). */
export interface UpdateLeadPayload {
  name?: string;
  phone?: string | null;
  email?: string | null;
  source?: LeadSource;
  interest_program_id?: string | null;
  status?: LeadStatus;
  notes?: string | null;
  assigned_to_user_id?: string | null;
}

/**
 * Body for POST /leads/{id}/convert (ConvertLeadRequest).
 * `program_id` is NOT accepted here — the backend reads it from the
 * lead's `interest_program_id` inside ConvertLeadAction.
 */
export interface ConvertLeadPayload {
  student_id: string;
  package_id?: string | null;
  learning_group_id?: string | null;
  billing_mode: 'prepaid' | 'monthly' | 'per_session';
  status?:
    | 'trial'
    | 'active'
    | 'paused'
    | 'graduated'
    | 'withdrawn'
    | null;
  start_date?: string | null;
  billing_day_of_month?: number | null;
  notes?: string | null;
}

/** Body for POST /leads/{id}/drop — a bare optional reason note. */
export interface DropLeadPayload {
  notes?: string | null;
}

/** Static option lists (label pulled from BE enum `label()`). */
export const LEAD_STATUS_LABEL: Record<LeadStatus, string> = {
  new: 'Baru',
  contacted: 'Dihubungi',
  trial: 'Trial',
  converted: 'Terdaftar',
  dropped: 'Batal',
};

export const LEAD_SOURCE_LABEL: Record<LeadSource, string> = {
  website: 'Website',
  walkin: 'Datang langsung',
  referral: 'Rekomendasi',
  whatsapp: 'WhatsApp',
  other: 'Lainnya',
};

export const LEAD_STATUS_VALUES: readonly LeadStatus[] = [
  'new',
  'contacted',
  'trial',
  'converted',
  'dropped',
] as const;

export const LEAD_SOURCE_VALUES: readonly LeadSource[] = [
  'website',
  'walkin',
  'referral',
  'whatsapp',
  'other',
] as const;

/**
 * Which statuses the CONVERT endpoint will actually accept.
 *
 * Mirrors the server's inclusion set in
 * `App\Modules\Tutoring\Actions\ConvertLeadAction`:
 *
 *   $allowed = [LeadStatus::CONTACTED, LeadStatus::TRIAL];
 *
 * Anything else is refused with a 422 carrying a `status` key. Note
 * this is an INCLUSION set: `new` is refused just like the two
 * terminal statuses, because the funnel deliberately makes an admin
 * mark a lead "Dihubungi" before it can become an enrollment.
 *
 * Written as an exhaustive Record rather than a bare array on purpose:
 * if someone adds a case to `LeadStatus`, the typecheck fails here
 * until they decide whether it converts. A bare `['contacted','trial']`
 * would silently classify every future status as non-convertible and
 * drift away from the server without anyone noticing.
 *
 * This is deliberately NOT reused for Drop — the server's drop rule is
 * a different, wider set (only `converted` is refused), so sharing one
 * predicate between the two would remove a control that works.
 */
const LEAD_CONVERTIBLE_STATUS: Record<LeadStatus, boolean> = {
  new: false,
  contacted: true,
  trial: true,
  converted: false,
  dropped: false,
};

/**
 * True when the backend would accept this lead for conversion on
 * status grounds alone. A `true` here is necessary but NOT sufficient:
 * `ConvertLeadAction` checks `interest_program_id` FIRST and refuses a
 * lead with no interest program with its own 422, so the caller must
 * still surface server errors.
 */
export function isLeadConvertible(
  status: LeadStatus | null | undefined,
): boolean {
  return status != null && LEAD_CONVERTIBLE_STATUS[status] === true;
}
