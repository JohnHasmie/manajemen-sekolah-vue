/**
 * How a bimbel session's status is shown to a human — in ONE place.
 *
 * ── The bug this exists for ──
 *
 * A bimbel session never changes status on its own. `done` is reached
 * only by a person pressing "Tandai selesai", and that is deliberate:
 * `Selesai` is the basis for calculating tutor honor, so it has to keep
 * meaning "the class actually happened" rather than "the clock passed".
 * A nightly job that auto-closed past sessions would make `Selesai` mean
 * the latter, and a session where the tutor never showed up would be
 * paid.
 *
 * Refusing that job leaves a real defect, but a *presentation* one: a
 * session whose time has passed and which nobody marked still reads
 * **Terjadwal**, exactly as though it were yet to come. `missed` is that
 * reading and nothing more — `scheduled` plus "the end time is behind
 * us".
 *
 * ── What this is NOT ──
 *
 * `missed` is not a status. It is absent from `SessionStatus` on the
 * backend, from the database, from every request body, and from
 * `BIMBEL_SESSION_STATUSES` — which is the filter picker's source of
 * truth and drives the `status` query parameter. Filters still send
 * `scheduled`, counters still count `scheduled`, and anything posted
 * back is untouched. Only the label and its tone change.
 *
 * ── Why a module and not another copy ──
 *
 * The status→tone switch was copy-pasted across eleven views and the
 * status→label function across seven, with a doc comment on one of them
 * asking the reader to "keep all three in lockstep" — a count that was
 * already wrong by eight. A derived state added by hand in eleven places
 * is a derived state that will read Terlewat on some screens and
 * Terjadwal on others, which is worse than not deriving it at all.
 */
import type {
  BimbelSession,
  BimbelSessionStatus,
} from '@/services/tutoring-bimbel.service';
import type { StatusBadgeTone } from '@/types/status-badge';

/**
 * The four wire states plus the one derived state the wire cannot carry.
 *
 * Deliberately a SEPARATE type from `BimbelSessionStatus` rather than a
 * widening of it. `BIMBEL_SESSION_STATUSES` is built from an exhaustive
 * `Record<BimbelSessionStatus, true>`, so widening the union there would
 * silently push `missed` into the filter picker and onto the wire.
 */
export type BimbelSessionDisplayStatus = BimbelSessionStatus | 'missed';

/** Display state → its key under the shared `tutoring2.status.*` block. */
const DISPLAY_I18N_KEY: Record<BimbelSessionDisplayStatus, string> = {
  scheduled: 'scheduled',
  missed: 'missed',
  in_progress: 'inProgress',
  done: 'done',
  cancelled: 'cancelled',
};

/**
 * Display state → badge tone.
 *
 * `missed` is **warning**, not danger and not neutral. Nothing has gone
 * wrong yet, but the row is asking somebody to act — mark it, or cancel
 * it. Danger would read as a failure that already happened; neutral is
 * what `scheduled` uses, and that calm "nothing to see here" reading is
 * precisely what this change exists to remove.
 */
const DISPLAY_TONE: Record<BimbelSessionDisplayStatus, StatusBadgeTone> = {
  scheduled: 'neutral',
  missed: 'warning',
  in_progress: 'info',
  done: 'success',
  cancelled: 'danger',
};

/**
 * The shape this module needs off a session. Widened from `BimbelSession`
 * so the several views holding a narrower row type can pass it directly.
 */
export interface BimbelSessionStatusInput {
  status: BimbelSession['status'];
  ends_at?: string | null;
  status_label?: string | null;
}

/**
 * The single derivation.
 *
 * **Only `scheduled` can become `missed`.** A `cancelled` session whose
 * time has passed is cancelled, not missed — the reason it did not happen
 * is already on the record, and re-labelling it would erase that.
 *
 * **A long-past `in_progress` session stays "Berlangsung".**
 * `in_progress` is the trace of a human action: somebody started this
 * class. It is therefore not *unmarked*, and folding it into Terlewat
 * would destroy the distinction between "nobody ever touched this" and
 * "the tutor started it and forgot to close it" — two situations that
 * need different follow-ups, only the first of which Terlewat is about.
 * (That a days-old `in_progress` also reads oddly is real, but it is a
 * separate product question and answering it here would be deciding it
 * by accident.)
 *
 * ── On time zones ──
 *
 * The comparison is between two INSTANTS — `Date.getTime()` on both
 * sides — never between calendar-day strings. That is what makes it
 * correct in WIB: `new Date('2026-09-09T21:00:00+07:00')` and
 * `Date.now()` are both absolute, so a session ending 21:00 WIB is still
 * in the future at 15:00 WIB the same day. The failure this avoids is
 * the `toISOString().slice(0, 10)` habit documented in
 * `@/lib/local-date`, which compares UTC calendar days and so shifts by
 * one for the first seven hours of every WIB day.
 *
 * An absent or unparseable `ends_at` yields the plain wire status: "we
 * were not told when this ends" is not evidence that it has passed.
 */
export function bimbelSessionDisplayStatus(
  session: BimbelSessionStatusInput,
  now: Date = new Date(),
): BimbelSessionDisplayStatus {
  if (session.status !== 'scheduled') return session.status;
  if (!session.ends_at) return 'scheduled';
  const endsAt = new Date(session.ends_at);
  if (Number.isNaN(endsAt.getTime())) return 'scheduled';
  return endsAt.getTime() < now.getTime() ? 'missed' : 'scheduled';
}

/**
 * Label for a bare WIRE status, with no session behind it.
 *
 * This is for FILTER PICKERS, which list the statuses a query may ask
 * for — not sessions. `missed` is deliberately unreachable here: it is
 * not a value the `status` query parameter accepts, so offering it in a
 * picker would build a filter that returns nothing.
 */
export function bimbelStatusLabel(
  status: BimbelSessionStatus,
  t: (key: string) => string,
): string {
  return t(`tutoring2.status.${DISPLAY_I18N_KEY[status]}`);
}

/** True when the session's time has passed with nobody marking it. */
export function bimbelSessionIsMissed(
  session: BimbelSessionStatusInput,
  now?: Date,
): boolean {
  return bimbelSessionDisplayStatus(session, now) === 'missed';
}

/** Badge tone for a session, Terlewat included. */
export function bimbelSessionStatusTone(
  session: BimbelSessionStatusInput,
  now?: Date,
): StatusBadgeTone {
  return DISPLAY_TONE[bimbelSessionDisplayStatus(session, now)];
}

/**
 * The human label for a session's status.
 *
 * `t` is passed in rather than imported: this module is used from views
 * that each own their own `useI18n()` instance, and reaching for a
 * global one here would break the locale switch on half of them.
 *
 * ── Precedence, and the one deliberate exception ──
 *
 * The server's `status_label` normally wins, because the wire is allowed
 * to be more specific than this client's union. `missed` is the
 * exception. `status_label` is the server's rendering of the same four
 * values, stamped when the row was serialized, and it carries no
 * information this client lacks about whether the end time has passed —
 * it *cannot*, because "passed" is relative to the reader's clock at the
 * moment of reading, and a row fetched at 20:59 is still on screen at
 * 21:01. For that one case the client is strictly better informed, so
 * the derived label wins. Every other status keeps wire-first precedence
 * exactly as before.
 */
export function bimbelSessionStatusLabel(
  session: BimbelSessionStatusInput,
  t: (key: string) => string,
  now?: Date,
): string {
  const display = bimbelSessionDisplayStatus(session, now);
  if (display !== 'missed') {
    const fromWire = session.status_label?.trim();
    if (fromWire) return fromWire;
  }
  return t(`tutoring2.status.${DISPLAY_I18N_KEY[display]}`);
}
