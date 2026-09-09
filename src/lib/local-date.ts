/**
 * Format a Date to `YYYY-MM-DD` using the browser's LOCAL calendar
 * components — not UTC.
 *
 * Why this exists: the historically-common `d.toISOString().slice(0, 10)`
 * shortcut formats the date IN UTC. For any user in a positive-offset
 * timezone (Indonesia = WIB / UTC+7), opening the app in the early
 * morning hours means UTC has not rolled over into the new day yet, so
 * `today.toISOString()` returns YESTERDAY'S date. Any code that uses
 * that string as `today` (attendance report window, calendar default,
 * bill payment_date default) then silently shifts by one day.
 *
 * Concrete incident: MTs Muhammadiyah Surakarta prod bug (2026-07-20) —
 * "7 Hari" filter on the Kehadiran Pegawai report loaded the window
 * `2026-07-13 → 2026-07-19` (Mon → Sun) instead of `2026-07-14 → 2026-07-20`
 * because the admin's browser resolved `today` off `toISOString()`
 * while WIB was between 00:00 and 06:59. Today's 12 check-ins were
 * live in the DB but invisible in the chart + Log Harian.
 *
 * Prefer this helper anywhere the string represents a CALENDAR DAY the
 * user is looking at (report window, filter default, calendar cell).
 * The UTC-slice form is fine when the string is a filename stamp or
 * anything else where "the exact day" is not user-facing.
 */
export function toLocalYmd(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * Format a Date to `YYYY-MM` using the browser's LOCAL calendar
 * components — not UTC.
 *
 * Same rationale as `toLocalYmd`: `d.toISOString().slice(0, 7)` returns
 * the UTC month. In WIB (UTC+7) the last few hours of any month roll
 * back a full month when serialized via UTC — e.g. Aug 1 00:00–06:59
 * WIB stringifies as `2026-07`. Any month-picker default computed from
 * `toISOString()` then loads July's data on the morning of Aug 1.
 *
 * Prefer this helper anywhere the string is a CALENDAR MONTH the user
 * sees (payout month, billing month picker, monthly report default).
 */
export function toLocalYm(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}`;
}

/* ------------------------------------------------------------------ *
 * `YYYY-MM-DD` day arithmetic
 *
 * The day-granularity sibling of the `YYYY-MM` block below, and it
 * exists for the same reason: every step has to stay on the LOCAL
 * calendar. The tempting one-liner —
 *
 *     new Date(ymd).toISOString().slice(0, 10)
 *
 * — crosses UTC twice. `new Date('2026-09-01')` is parsed as UTC
 * midnight *by spec* (a date-only string is treated as UTC, unlike the
 * date-time form), which is already 07:00 WIB on the 1st; serialising
 * it back through `toISOString()` then re-reads it in UTC. The round
 * trip happens to cancel out, so it looks correct — right up until a
 * caller in a NEGATIVE offset (or any arithmetic in between) lands the
 * intermediate Date on the wrong side of a midnight and the result is
 * silently a day off.
 *
 * The local-component constructor has none of that ambiguity, and it
 * normalises overflow for free: day 32 rolls into the next month, day 0
 * into the previous one.
 * ------------------------------------------------------------------ */

/** A well-formed `YYYY-MM-DD`: 4-digit year, 01–12 month, 01–31 day. */
export const YMD_PATTERN = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;

export function isValidYmd(ymd: string): boolean {
  return YMD_PATTERN.test(ymd);
}

/**
 * Shift a `YYYY-MM-DD` by whole days, crossing month and year
 * boundaries. Malformed input passes through unchanged — same contract
 * as `addMonths`, so a half-typed value in a bound `v-model` degrades to
 * "no bound" rather than to the string `NaN-aN-aN`.
 *
 *   addDays('2026-09-30', 1) === '2026-10-01'
 *   addDays('2026-12-31', 1) === '2027-01-01'
 *   addDays('2026-03-01', -1) === '2026-02-28'
 */
export function addDays(ymd: string, delta: number): string {
  if (!isValidYmd(ymd)) return ymd;
  const [y, m, d] = ymd.split('-').map(Number);
  // Local midnight in, local calendar components out — never a UTC hop.
  return toLocalYmd(new Date(y, m - 1, d + delta));
}

/**
 * Human day label for a `YYYY-MM-DD` — e.g. `'2026-09-09'` →
 * "9 September 2026". The day-granularity sibling of `formatYmLabel`,
 * and it exists for exactly the same reason.
 *
 * `new Date('2026-09-09')` is parsed as UTC midnight BY SPEC, so
 * handing the wire string straight to `toLocaleDateString` renders
 * "8 September 2026" for every reader west of Greenwich. The parts are
 * split out and materialised in LOCAL time instead, which has no such
 * ambiguity.
 *
 * Malformed input is echoed back rather than rendered as
 * "Invalid Date" — same contract as `formatYmLabel`.
 */
export function formatYmdLabel(ymd: string, localeTag = 'id-ID'): string {
  if (!isValidYmd(ymd)) return ymd;
  const [y, m, d] = ymd.split('-').map(Number);
  return new Date(y, m - 1, d).toLocaleDateString(localeTag, {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

/* ------------------------------------------------------------------ *
 * `YYYY-MM` month arithmetic
 *
 * Added with the Safari month-picker fix. `<input type="month">` has no
 * picker UI in desktop Safari — it degrades to a bare text box (MDN:
 * only Chrome/Opera and Edge on desktop ship a usable implementation),
 * which is what a tutor on macOS saw on "Honor Saya". The replacement
 * is a real picker component, and every host that used to lean on the
 * browser's built-in month stepper now needs this arithmetic in JS.
 *
 * All of it goes through LOCAL calendar components for the same reason
 * `toLocalYm` exists — a UTC round-trip silently shifts a WIB user back
 * a month for the first 7 hours of every 1st.
 * ------------------------------------------------------------------ */

/** A well-formed `YYYY-MM`: 4-digit year, 01–12 month. */
export const YM_PATTERN = /^\d{4}-(0[1-9]|1[0-2])$/;

export function isValidYm(ym: string): boolean {
  return YM_PATTERN.test(ym);
}

/** Numeric parts of a `YYYY-MM` (month is 1-based). `null` when malformed. */
export function parseYm(ym: string): { year: number; month: number } | null {
  if (!isValidYm(ym)) return null;
  const [y, m] = ym.split('-');
  return { year: Number(y), month: Number(m) };
}

/**
 * Build `YYYY-MM` from a year + 1-based month, normalizing overflow:
 * `formatYm(2026, 13)` → `'2027-01'`, `formatYm(2026, 0)` → `'2025-12'`.
 * The Date constructor does the carry in LOCAL time.
 */
export function formatYm(year: number, month: number): string {
  return toLocalYm(new Date(year, month - 1, 1));
}

/** Shift a `YYYY-MM` by whole months. Malformed input passes through. */
export function addMonths(ym: string, delta: number): string {
  const p = parseYm(ym);
  if (!p) return ym;
  return formatYm(p.year, p.month + delta);
}

/**
 * Order two `YYYY-MM` strings: <0, 0, >0 like a comparator.
 * Plain string comparison is correct here precisely because both parts
 * are zero-padded fixed-width — do not "optimise" this into Date math.
 */
export function compareYm(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

/** Clamp a `YYYY-MM` into `[min, max]`. Either bound may be omitted. */
export function clampYm(ym: string, min?: string, max?: string): string {
  if (min && compareYm(ym, min) < 0) return min;
  if (max && compareYm(ym, max) > 0) return max;
  return ym;
}

/**
 * Human month label for a `YYYY-MM` — e.g. `'2026-09'` → "September 2026".
 *
 * Day 1 is materialised in LOCAL time on purpose: `new Date('2026-09')`
 * is parsed as UTC midnight by spec, which renders as August for anyone
 * west of Greenwich and is a month-boundary bug waiting to happen.
 * Malformed input is echoed back rather than rendered as "Invalid Date".
 */
export function formatYmLabel(ym: string, localeTag = 'id-ID'): string {
  const p = parseYm(ym);
  if (!p) return ym;
  return new Date(p.year, p.month - 1, 1).toLocaleDateString(localeTag, {
    month: 'long',
    year: 'numeric',
  });
}

/* ------------------------------------------------------------------ *
 * Default month-picker bounds
 *
 * Every screen that picks a `YYYY-MM` in this app is RETROSPECTIVE:
 * payout summaries, honor/earnings, month-close, attendance recap. None
 * of them has data for a month that has not happened yet, so paging
 * forward only ever produces zeroes — which on "Honor Saya" read as
 * "you earned nothing this month" rather than "this month is in the
 * future". Hence the upper bound is the CURRENT local month.
 *
 * The lower bound is a 36-month lookback. It is a guard-rail, not a
 * domain fact: no tenant on this platform has older data, three years
 * comfortably covers multi-year academic history, and it stops a
 * mis-click from walking the picker back to 1998. A host that knows a
 * real bound (tenant creation month, contract start) should pass its
 * own `min` and tighten this.
 *
 * Both are functions rather than module constants so the ceiling is
 * resolved when a picker mounts, not once when the bundle is parsed —
 * a long-lived tab would otherwise pin whatever month it was loaded in.
 * ------------------------------------------------------------------ */

export const MONTH_PICKER_LOOKBACK_MONTHS = 36;

/** Earliest month any picker offers by default. */
export function defaultMinMonth(): string {
  return addMonths(toLocalYm(), -MONTH_PICKER_LOOKBACK_MONTHS);
}

/** Latest month any picker offers by default — the current local month. */
export function defaultMaxMonth(): string {
  return toLocalYm();
}

/* ------------------------------------------------------------------ *
 * `<input type="datetime-local">` values
 *
 * Same rule as everything above, one granularity finer: the string in a
 * datetime-local box is a LOCAL wall-clock reading with no zone, and it
 * has to be produced from local calendar components. The tempting
 * `iso.slice(0, 16)` and `d.toISOString().slice(0, 16)` are both wrong —
 * they hand the user the UTC instant, so a session that starts at 08:00
 * WIB opens its edit form showing 01:00. That is the bug that had every
 * bimbel session time on mobile rendering seven hours early.
 *
 * These live here rather than beside the one screen that first needed
 * them because a private copy in a view is how this codebase ended up
 * with four `groupLabel()` functions that had drifted apart. There is
 * one local-time helper module; this is it.
 * ------------------------------------------------------------------ */

/**
 * An ISO instant → the `YYYY-MM-DDTHH:mm` a `datetime-local` input
 * binds to, read in the browser's LOCAL zone.
 *
 *   '2026-09-08T08:00:00+07:00' → '2026-09-08T08:00'   (in WIB)
 *
 * Empty / unparseable input yields `''`, which a bound input renders as
 * a blank box — the honest result for "we were not told when this is",
 * and never the string `NaN-aN-aNTaN:aN`.
 */
export function toLocalDateTimeInput(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` +
    `T${pad(d.getHours())}:${pad(d.getMinutes())}`
  );
}

/**
 * The inverse, for the wire: `'2026-09-08T16:00'` → `'2026-09-08 16:00'`.
 *
 * Deliberately still zone-LESS. Laravel's `date` validation accepts this
 * form and resolves it in the application timezone, which is what an
 * admin means when they type 16:00. Converting to an ISO instant here
 * would re-introduce the offset shift these helpers exist to prevent,
 * and it is the form the shipped tutor reschedule flow already sends —
 * so the two surfaces cannot disagree about what 16:00 means.
 */
export function localDateTimeInputToWire(value: string): string {
  return value.replace('T', ' ');
}
