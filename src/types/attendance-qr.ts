/**
 * Gate QR + personnel-card types (PRESENSI QR) — mirror the backend
 * contract for the App\Modules\Attendance gate-QR + personnel-card
 * features (backend MR !226). Distinct from `@/types/attendance.ts`
 * (per-session student attendance) and `@/types/teacher-attendance.ts`
 * (selfie + geofence check-in).
 *
 * Gate QR: a rotating school-wide token rendered on a projector / printed
 * poster. Personnel cards: per-user QR tokens issued as printable ID
 * badges. Both are checked in via the mobile scanner (Phase 2 mobile MR).
 */

/**
 * Allowed check-in methods. Settings exposes this as an array — admins
 * pick any combination of the three. The server enforces at least one.
 * Wire values must match the backend `CheckInMethod` PHP enum + the
 * `UpdateTeacherAttendanceSettingsRequest` `in:` rule (word order is
 * QR_* not *_QR — sending GATE_QR/CARD_QR trips a 422 "invalid" error).
 *   - SELFIE   Camera selfie + GPS (the existing teacher check-in flow)
 *   - QR_GATE  Scan the school-wide rotating QR at the gate
 *   - QR_CARD  Tap your own printed personnel-card QR
 */
export type CheckInMethod = 'SELFIE' | 'QR_GATE' | 'QR_CARD';

export const CHECK_IN_METHODS: readonly CheckInMethod[] = [
  'SELFIE',
  'QR_GATE',
  'QR_CARD',
] as const;

/**
 * The currently-active gate QR token for the active school. Returned by
 * GET /attendance/gate-qr/current and POST /attendance/gate-qr/rotate.
 * The token string itself is opaque — the mobile scanner sends it back
 * verbatim. `seconds_until_rotation` lets the display tick down to the
 * next auto-rotate so projectors stay fresh without a manual refresh.
 */
export interface GateQrTokenInfo {
  /** Opaque token string (server-signed). */
  token: string;
  /** Database id of the active token row — used for cache busting. */
  token_id: string;
  school_id: string;
  /** ISO-8601 timestamp when this token went live. */
  valid_from: string;
  /** ISO-8601 timestamp when this token rolls over. */
  valid_until: string;
  /** Convenience: countdown until valid_until in whole seconds. */
  seconds_until_rotation: number;
  /** Server's clock at the moment of the response. */
  server_time: string;
}

/**
 * Per-user result of POST /attendance/personnel-cards/issue. The endpoint
 * accepts a batch of user ids and returns one row per id — `status='ok'`
 * with the new `qr_token`, or `status='skipped'` with a human `reason`
 * when the user already has an active card (re-issue requires explicit
 * revoke first) or is outside the active school.
 */
export interface PersonnelCardIssueResult {
  user_id: string;
  /** Present when status='ok'. The card's opaque token (printed onto PDF). */
  qr_token?: string;
  status: 'ok' | 'skipped' | 'error';
  /** Human Indonesian reason for non-ok rows. */
  reason?: string;
}
