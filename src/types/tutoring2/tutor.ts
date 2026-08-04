/**
 * Wire types for `/api/tutoring-v2/tutors*` (BE-17).
 *
 * The backend `TutorResource` returns a Teacher row hydrated with:
 *  - `is_active`         → composite of `users_schools.is_active` +
 *                          `users_roles.is_active` for the TEACHER role
 *                          on this tenant. Authoritative for the
 *                          "Aktif / Nonaktif" tab strip.
 *  - `active_group_count`→ COUNT(bimbel_learning_groups WHERE
 *                          tutor_id = teacher.id AND status = 'active').
 *                          Non-zero blocks POST /deactivate (BE returns
 *                          409 with an Indonesian message + count).
 *
 * `phone` and `initial_rate` live in the FE-only invite form — the
 * greenfield BE-17 InviteTutorAction accepts only {email, name} today.
 * We keep them in the payload type + collect them in the UI so a follow-
 * up BE MR can start persisting them without another FE round-trip.
 *
 * Kept isolated from `types/tutoring-bimbel.ts` so the tutor domain can
 * evolve independently of the learning-group / session DTOs.
 */

/** One tutor row as returned by GET /tutoring-v2/tutors and /tutors/{id}. */
export interface Tutor {
  id: string;
  user_id: string;
  name: string;
  email?: string | null;
  employee_number?: string | null;
  gender?: string | null;
  employment_status?: string | null;
  /** True when both the tenant pivot AND the TEACHER role row are active. */
  is_active: boolean;
  /**
   * Count of ACTIVE learning groups this tutor still leads on this
   * tenant — the guard the FE surfaces before calling /deactivate.
   * DRAFT / CLOSED groups are excluded (matches BE semantics).
   */
  active_group_count: number;
  created_at?: string | null;
  updated_at?: string | null;
}

/**
 * POST /tutoring-v2/tutors/invite body.
 *
 * `email` + `name` are the only fields the BE-17 InviteTutorAction
 * actually reads today. `phone` and `initial_rate` are collected in
 * the modal so a future BE MR can persist them without a FE change —
 * see the .vue for the TODO markers.
 */
export interface InviteTutorPayload {
  email: string;
  /** Nullable: BE defaults to the email local part when omitted. */
  name?: string | null;
  /** Reserved for a future BE MR — ignored server-side today. */
  phone?: string | null;
  /** Reserved for a future BE MR — ignored server-side today. */
  initial_rate?: number | null;
}

/**
 * The 409 body BE-17 returns from POST /tutors/{id}/deactivate when the
 * tutor still leads active learning groups. Surfaced verbatim by the
 * FE danger footer so admins see the actual blocker count.
 */
export interface DeactivateTutorConflict {
  message: string;
  active_group_count: number;
}
