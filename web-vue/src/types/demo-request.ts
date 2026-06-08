/**
 * Demo-request types — mirror the Laravel super-admin review contract
 * (backend MR !112).
 *
 * A demo registration is no longer auto-activated. The final wizard
 * step now collects a REQUESTER identity + submits a PENDING
 * `demo_requests` row. The KamilEdu team reviews them MANUALLY from
 * this super-admin page and *activates* (approves) the demo, which
 * provisions the school + sets a 7-day expiry + notifies the
 * requester via email + WhatsApp.
 *
 * Source of truth for the shapes below:
 *   - app/Modules/Demo/Http/Resources/DemoRequestResource.php
 *     (list item, ->withPayload() detail variant)
 *   - GET    /api/demo-requests          (index, paginated)
 *   - GET    /api/demo-requests/{id}     (show, +school_payload)
 *   - POST   /api/demo-requests/{id}/approve
 *   - POST   /api/demo-requests/{id}/reject
 */
import type { DemoWizardPayload } from './demo';

/** Lifecycle status of a demo request. */
export type DemoRequestStatus =
  | 'pending'
  | 'approved'
  | 'rejected'
  | 'expired';

/**
 * Social-media channels the requester supplied. At least one is
 * required at submit time; empty channels are dropped before storage,
 * so any key present here is guaranteed non-empty.
 */
export interface DemoRequesterSocialMedia {
  facebook?: string;
  threads?: string;
  instagram?: string;
  linkedin?: string;
  other?: string;
}

/**
 * Condensed school info shown in the list / detail header. Derived
 * server-side from the stored `school_payload`.
 */
export interface DemoRequestSchoolSummary {
  name: string | null;
  education_level: string | null;
  city: string | null;
  npsn: string | null;
}

/**
 * The user who submitted the request (the authenticated Google
 * account at submit time). Only present on the detail variant when
 * the `requester` relation is eager-loaded.
 */
export interface DemoRequestRequester {
  id: string;
  name: string | null;
  email: string | null;
}

/**
 * One demo-request row as returned by the index + show endpoints.
 *
 * `school_payload` is only present on the detail (show / approve)
 * variant — the list omits it to keep payloads small.
 */
export interface DemoRequest {
  id: string;
  requester_user_id: string | null;
  status: DemoRequestStatus;

  // Identity fields collected on the final wizard step.
  full_name: string;
  nip: string;
  jabatan: string;
  whatsapp: string;
  social_media: DemoRequesterSocialMedia;

  // Condensed school info (derived from school_payload).
  school_summary: DemoRequestSchoolSummary;

  // Lifecycle / review fields.
  demo_expires_at: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  review_note: string | null;
  activated_school_id: string | null;
  created_at: string | null;
  updated_at: string | null;

  // Relations (detail only).
  requester?: DemoRequestRequester | null;

  // Full replayed wizard payload (detail / approve variant only).
  school_payload?: DemoWizardPayload | null;
}

/** Meta block from the paginated list response. */
export interface DemoRequestListMeta {
  current_page: number;
  last_page: number;
  per_page: number;
  total: number;
}

export interface DemoRequestListResult {
  items: DemoRequest[];
  meta: DemoRequestListMeta;
}

export interface DemoRequestListParams {
  status?: DemoRequestStatus;
  per_page?: number;
  page?: number;
}

/** Display metadata for each status — label + theme tone. */
export const DEMO_REQUEST_STATUS_LABELS: Record<DemoRequestStatus, string> = {
  pending: 'Menunggu Review',
  approved: 'Disetujui',
  rejected: 'Ditolak',
  expired: 'Kedaluwarsa',
};

/** Human labels for each social-media channel key. */
export const DEMO_SOCIAL_LABELS: Record<
  keyof DemoRequesterSocialMedia,
  string
> = {
  facebook: 'Facebook',
  threads: 'Threads',
  instagram: 'Instagram',
  linkedin: 'LinkedIn',
  other: 'Lainnya',
};
