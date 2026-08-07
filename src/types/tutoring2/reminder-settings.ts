/**
 * Type contracts for greenfield tutoring reminder settings (BE-9).
 *
 * Mirrors `App\Modules\Tutoring\Http\Controllers\ReminderSettingsController`
 * + `ReminderSettingsResource`:
 *
 *   GET|PUT /api/tutoring-v2/settings/session-reminders
 *   GET|PUT /api/tutoring-v2/settings/bill-reminders
 *
 * Contract differences vs. the legacy `/tutoring/settings/*` pair that
 * `TutoringService.getBillReminderSettings` talks to:
 *
 *   1. Legacy split the two kinds across two tables with different
 *      units — `offsets_minutes` for sessions, `offsets_days` for
 *      bills. Greenfield normalises BOTH to MINUTES in a single
 *      `offsets` array on one `bimbel_reminder_settings` table keyed
 *      by `kind`. A "3 days before due" bill reminder is `4320`.
 *   2. Legacy carried a separate boolean `enabled`. Greenfield folds
 *      it into the array: `offsets: []` IS "disabled". The UI keeps a
 *      master toggle and simply sends an empty array when it is off.
 *   3. GET on a tenant that has never saved returns a TRANSIENT default
 *      row that was never persisted — so `id` can be null. The first
 *      PUT is what promotes it into the table.
 *
 * Server-side validation: 0..20 offsets, each an integer 1..10080
 * (1 minute .. 1 week).
 */

export type ReminderKind = 'session' | 'bill';

/** `{ data: ReminderSettings }` on every GET/PUT. */
export interface ReminderSettings {
  /** Null until the tenant's first PUT persists the row — see note 3. */
  id: string | null;
  kind: ReminderKind | null;
  /** Minute offsets BEFORE the target, ascending + de-duplicated. */
  offsets: number[];
  updated_at: string | null;
}

/** Payload for both PUT endpoints. */
export interface UpdateReminderSettingsPayload {
  offsets: number[];
}

/** Server-side bounds, mirrored so the view can guard before the round-trip. */
export const REMINDER_MIN_OFFSET_MINUTES = 1;
export const REMINDER_MAX_OFFSET_MINUTES = 10_080;
export const REMINDER_MAX_OFFSETS = 20;
