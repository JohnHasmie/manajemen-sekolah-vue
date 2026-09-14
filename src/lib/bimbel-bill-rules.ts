/**
 * bimbel-bill-rules.ts — the ONE money rule for bimbel bills on the web.
 *
 * ── The bug this exists for ──
 *
 * The wali payment inbox asked the server for `status=unpaid`.
 * `Tutoring\BillController::index` forwards that parameter as an EXACT
 * one-word match with no whitelist:
 *
 *   ->when($request->filled('status'),
 *          fn ($b) => $b->where('status', $request->string('status')))
 *
 * so `pending` (the wali uploaded a transfer receipt and is waiting for
 * an admin to verify it) and `partial` were filtered out SERVER-SIDE. On
 * a screen that aggregates across children, a child whose bills are all
 * `pending` produced no rows at all — and because the child list on that
 * screen is derived from the bills, the CHILD disappeared with them. A
 * wali with two children read "1 anak", which is how this was reported.
 *
 * ── Server truth, read off backend `main` (not inferred) ──
 *
 * * `app/Modules/Finance/Enums/BillStatus.php` declares exactly four
 *   cases — `unpaid` | `pending` | `partial` | `paid`. There is no
 *   `cancelled` case and no `overdue` case.
 * * `Tutoring\BillController::summary` computes money owed as
 *   `whereNotIn('status', [BillStatus::Paid->value])` — an exclusion on
 *   exactly ONE value.
 * * `Tutoring\AdminStatsController` spells tenant arrears
 *   (`billing.menunggak`) the same way, and the 09:00 reminder cron
 *   `SendBimbelReminders` chases `where('status', '!=', 'paid')`.
 *
 * So the rule is: **outstanding == not paid.** A client that quietly
 * drops a row the cron is still chasing tells a payer they owe less than
 * the tenant thinks they do.
 *
 * ── Why a module and not three more copies ──
 *
 * This is the WEB TWIN of a bug already fixed on mobile (!1298). There,
 * two bill screens had each grown their own answer to "is this still
 * money owed?" and the two answers disagreed; the fix was one shared
 * predicate in `lib/features/tutoring2/domain/bimbel_bill_rules.dart`,
 * and this file is its counterpart so the two platforms cannot drift
 * apart either. Three web call sites read it — the wali inbox, the wali
 * voucher targets, and the admin arrears panel.
 *
 * ── Overdue is DERIVED here, not read off the wire ──
 *
 * The server never writes the word `overdue`. Both admin aggregates
 * spell it as `whereNotIn('status', ['paid'])` **and**
 * `whereDate('due_date', '<', today)`, so that is the definition
 * reproduced below — date-grained, which means a bill due *today* is not
 * yet late.
 *
 * ── Labels live in i18n, not here ──
 *
 * Unlike the Dart twin (Flutter's bimbel screens carry no i18n layer),
 * the web renders every status through `tutoring2.status.*`. What this
 * module owns is the wire-word → KEY mapping, so no view can invent its
 * own answer for a word; the Indonesian text stays in `locales/id.json`
 * where every other user-facing string lives. Same shape as
 * `bimbel-session-status.ts`.
 */
import { toLocalYmd } from '@/lib/local-date';
import type { StatusBadgeTone } from '@/types/status-badge';

/** The one settled status. Matches `BillStatus::Paid`. */
export const BIMBEL_BILL_PAID_STATUS = 'paid';

/**
 * Every value `bills.status` can hold, in `BillStatus.php` order.
 *
 * `bills.status` is a free-text column, so this is the vocabulary the
 * API *writes*, not a constraint the database enforces. Used to keep
 * client status filters honest: a filter for a value outside this list
 * returns 200 + an empty page, which reads as "none exist" rather than
 * "not a real status".
 */
export const BIMBEL_BILL_STATUSES = [
  'unpaid',
  'pending',
  'partial',
  'paid',
] as const;

export type BimbelBillStatus = (typeof BIMBEL_BILL_STATUSES)[number];

/**
 * The four wire states plus the one derived state the wire cannot carry.
 *
 * A separate type from `BimbelBillStatus` on purpose: widening that
 * union would push `overdue` into anything built from the vocabulary and
 * so onto the wire, where it matches no row.
 */
export type BimbelBillDisplayStatus = BimbelBillStatus | 'overdue';

/** Display state → its key under the shared `tutoring2.status.*` block. */
const DISPLAY_I18N_KEY: Record<BimbelBillDisplayStatus, string> = {
  unpaid: 'unpaid',
  pending: 'pending',
  partial: 'partial',
  paid: 'paid',
  overdue: 'overdue',
};

/**
 * Display state → badge tone.
 *
 * `pending` is **info**, not warning. Warning is what `unpaid` uses, and
 * a wali who has already uploaded their transfer receipt has done
 * everything asked of them — painting that row the same colour as one
 * they have not acted on reads as "you still owe us something", which is
 * the confusion this whole change exists to remove. The money is still
 * outstanding (see `isBimbelBillOutstanding`); the ACTION is not theirs.
 */
const DISPLAY_TONE: Record<BimbelBillDisplayStatus, StatusBadgeTone> = {
  unpaid: 'warning',
  pending: 'info',
  partial: 'warning',
  paid: 'success',
  overdue: 'danger',
};

/** The fields of a bill row these rules actually read. */
export interface BimbelBillStatusInput {
  status?: string | null;
  due_date?: string | null;
}

function normalize(status?: string | null): string {
  return String(status ?? '').trim().toLowerCase();
}

/** Settled. The only status that owes nothing. */
export function isBimbelBillPaid(status?: string | null): boolean {
  return normalize(status) === BIMBEL_BILL_PAID_STATUS;
}

/**
 * Still money owed.
 *
 * `pending` (proof uploaded, awaiting verification) and `partial`
 * (part-settled) are both still owed — the payer has not discharged the
 * bill until an admin verifies it, and the reminder cron keeps chasing
 * them until then.
 *
 * An UNKNOWN word counts as outstanding too. If the backend adds a fifth
 * status, erring toward "still owed" surfaces the row on a screen where
 * the reader can see it and ask; erring the other way hides a bill the
 * tenant is still collecting on. Only the literal word `paid` settles.
 */
export function isBimbelBillOutstanding(status?: string | null): boolean {
  return !isBimbelBillPaid(status);
}

/** Convenience for the common `items.filter(...)` at every call site. */
export function outstandingBimbelBills<T extends BimbelBillStatusInput>(
  bills: readonly T[],
): T[] {
  return bills.filter((b) => isBimbelBillOutstanding(b.status));
}

/**
 * Past its due date and still owed — the client-side twin of the admin
 * summary's `menunggak` / `overdue_count`.
 *
 * Compared as `YYYY-MM-DD` CALENDAR STRINGS against `toLocalYmd()`,
 * never `new Date(...).toISOString()`: the latter is UTC and would call
 * a bill overdue seven hours early in WIB. `due_date` arrives from
 * `BillResource` as `->toDateString()`, so the slice is tolerance for a
 * fuller timestamp rather than a reshape.
 *
 * `today` is injectable so a test can pin a date instead of racing the
 * wall clock.
 */
export function isBimbelBillOverdue(
  bill: BimbelBillStatusInput,
  today: string = toLocalYmd(),
): boolean {
  if (!isBimbelBillOutstanding(bill.status)) return false;
  const due = String(bill.due_date ?? '').slice(0, 10);
  if (due.length !== 10) return false;
  // Strictly before today — a bill due TODAY is not yet late, matching
  // the server's `whereDate('due_date', '<', today)`.
  return due < today;
}

/**
 * What a bill's pill should say it is.
 *
 * `paid` wins outright. Otherwise an outstanding bill past its due date
 * reads `overdue`, because "menunggak" is the more urgent fact about it
 * than which of the three unsettled words the column holds.
 *
 * An unrecognised word falls back to `unpaid` rather than being echoed:
 * rendering the raw value is how an English wire word reached a payer's
 * screen on mobile, and it would do the same here.
 */
export function bimbelBillDisplayStatus(
  bill: BimbelBillStatusInput,
  today: string = toLocalYmd(),
): BimbelBillDisplayStatus {
  if (isBimbelBillPaid(bill.status)) return 'paid';
  if (isBimbelBillOverdue(bill, today)) return 'overdue';
  const s = normalize(bill.status);
  return s === 'pending' || s === 'partial' ? s : 'unpaid';
}

/** Full i18n key for a display state, e.g. `tutoring2.status.pending`. */
export function bimbelBillStatusI18nKey(s: BimbelBillDisplayStatus): string {
  return `tutoring2.status.${DISPLAY_I18N_KEY[s]}`;
}

/** Badge tone for a display state. */
export function bimbelBillStatusTone(s: BimbelBillDisplayStatus): StatusBadgeTone {
  return DISPLAY_TONE[s];
}
