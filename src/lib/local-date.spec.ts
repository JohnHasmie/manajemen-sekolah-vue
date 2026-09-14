/**
 * Regression test for the MTs Muhammadiyah Surakarta prod bug
 * (2026-07-20): the "7 Hari" filter window landed on
 * 13–19 Jul instead of 14–20 Jul because `today.toISOString().slice(0, 10)`
 * returned Sunday's date while WIB was Monday morning before 07:00.
 *
 * The invariant this locks: `toLocalYmd(d)` returns the LOCAL
 * calendar day of `d`, regardless of how far offset from UTC the
 * caller's timezone is.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, describe, it, expect, vi } from 'vitest';
import { toLocalYmd } from './local-date';

describe('toLocalYmd', () => {
  it('returns a Date\'s LOCAL calendar day, not the UTC day', () => {
    // 2026-07-20 00:30 local (whatever the runner tz is). If someone
    // ever "fixes" this back to toISOString().slice(0, 10) the assertion
    // will flip whenever the runner is at or east of UTC.
    const d = new Date(2026, 6, 20, 0, 30, 0); // Jul is month index 6
    expect(toLocalYmd(d)).toBe('2026-07-20');
  });

  it('zero-pads month and day', () => {
    const d = new Date(2026, 0, 5); // 5 Jan
    expect(toLocalYmd(d)).toBe('2026-01-05');
  });

  it('defaults to now() when no arg is passed', () => {
    const now = new Date();
    const expected = `${now.getFullYear()}-`
      + `${String(now.getMonth() + 1).padStart(2, '0')}-`
      + `${String(now.getDate()).padStart(2, '0')}`;
    expect(toLocalYmd()).toBe(expected);
  });

  it('never returns a "yesterday" string for the caller\'s local wall clock', () => {
    // The failure mode we regressed on: for a WIB (UTC+7) admin whose
    // wall clock is Monday 06:30, `new Date().toISOString().slice(0, 10)`
    // returned Sunday's date. The helper is not timezone-aware in test
    // setup, but the calling-day contract is: whatever `d.getDate()`
    // reports, that's what surfaces.
    const d = new Date(2026, 6, 20, 6, 30, 0); // local Monday 06:30
    const out = toLocalYmd(d);
    expect(out.endsWith(`-${String(d.getDate()).padStart(2, '0')}`)).toBe(true);
  });
});

/* ------------------------------------------------------------------ *
 * `YYYY-MM` helpers, added with the Safari month-picker fix.
 *
 * These back a real picker component, so the month arithmetic they do
 * is no longer the browser's problem — it is ours, and a UTC round-trip
 * anywhere in it reintroduces exactly the off-by-a-month bug that
 * `toLocalYm` exists to prevent.
 * ------------------------------------------------------------------ */
import {
  addMonths,
  clampYm,
  compareYm,
  defaultMaxMonth,
  defaultMinMonth,
  formatYm,
  formatYmLabel,
  isValidYm,
  MONTH_PICKER_LOOKBACK_MONTHS,
  parseYm,
  toLocalYm,
} from './local-date';

describe('YYYY-MM helpers', () => {
  it('validates the wire shape and rejects the near-misses', () => {
    expect(isValidYm('2026-09')).toBe(true);
    expect(isValidYm('2026-01')).toBe(true);
    expect(isValidYm('2026-12')).toBe(true);
    // The values a free-text box happily accepted before the picker.
    expect(isValidYm('2026-9')).toBe(false);
    expect(isValidYm('2026-13')).toBe(false);
    expect(isValidYm('2026-00')).toBe(false);
    expect(isValidYm('Sep 2026')).toBe(false);
    expect(isValidYm('2026-09-01')).toBe(false);
    expect(isValidYm('')).toBe(false);
  });

  it('parses into 1-based numeric parts, or null when malformed', () => {
    expect(parseYm('2026-09')).toEqual({ year: 2026, month: 9 });
    expect(parseYm('2026-9')).toBeNull();
  });

  it('normalizes month overflow across year boundaries', () => {
    expect(formatYm(2026, 13)).toBe('2027-01');
    expect(formatYm(2026, 0)).toBe('2025-12');
    expect(formatYm(2026, 9)).toBe('2026-09');
  });

  it('steps months, carrying the year in both directions', () => {
    expect(addMonths('2026-09', 1)).toBe('2026-10');
    expect(addMonths('2026-12', 1)).toBe('2027-01');
    expect(addMonths('2026-01', -1)).toBe('2025-12');
    expect(addMonths('2026-09', -12)).toBe('2025-09');
  });

  it('passes malformed input through addMonths rather than inventing a month', () => {
    // Better a visibly wrong value the caller can spot than a silent
    // "Invalid Date" coerced into a plausible-looking string.
    expect(addMonths('rubbish', 1)).toBe('rubbish');
  });

  it('orders and clamps', () => {
    expect(compareYm('2026-08', '2026-09')).toBeLessThan(0);
    expect(compareYm('2026-09', '2026-09')).toBe(0);
    expect(compareYm('2027-01', '2026-12')).toBeGreaterThan(0);

    expect(clampYm('2020-01', '2024-01', '2026-09')).toBe('2024-01');
    expect(clampYm('2030-01', '2024-01', '2026-09')).toBe('2026-09');
    expect(clampYm('2025-06', '2024-01', '2026-09')).toBe('2025-06');
    // Either bound may be omitted.
    expect(clampYm('2030-01', '2024-01')).toBe('2030-01');
    expect(clampYm('2020-01', undefined, '2026-09')).toBe('2020-01');
  });

  it('labels a month without a UTC round-trip', () => {
    // `new Date('2026-09')` is parsed as UTC midnight by spec; the
    // helper builds day 1 from LOCAL parts instead.
    expect(formatYmLabel('2026-09', 'id-ID')).toBe('September 2026');
    expect(formatYmLabel('2026-01', 'en-US')).toBe('January 2026');
  });

  it('echoes malformed input back instead of rendering "Invalid Date"', () => {
    expect(formatYmLabel('2026-9')).toBe('2026-9');
  });

  it('bounds the picker to [now - 36 months, now]', () => {
    const max = defaultMaxMonth();
    expect(max).toBe(toLocalYm());
    expect(addMonths(max, -MONTH_PICKER_LOOKBACK_MONTHS)).toBe(defaultMinMonth());
    // The reported page is retrospective: next month must be unreachable.
    expect(compareYm(addMonths(max, 1), max)).toBeGreaterThan(0);
  });
});

describe('toLocalYm across a UTC month boundary', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    // WIB (UTC+7) — the timezone every tenant on this platform is in,
    // and the one the original bug was reported from.
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('reports SEPTEMBER for a WIB tutor at 01:30 on 1 Sep, when UTC still says August', () => {
    // 2026-08-31T18:30Z === 2026-09-01 01:30 WIB. This is the exact
    // window — the first 7 hours of the 1st — in which the
    // `toISOString().slice(0, 7)` shortcut shows the WRONG month.
    const d = new Date('2026-08-31T18:30:00Z');

    // Guard: if the TZ override did not take effect this spec would be
    // vacuous, so assert the premise before the conclusion.
    expect(d.getTimezoneOffset()).toBe(-420);
    expect(d.toISOString().slice(0, 7)).toBe('2026-08'); // the buggy form

    expect(toLocalYm(d)).toBe('2026-09'); // the correct one
  });

  it('keeps the whole month-picker default on the local side of that boundary', () => {
    vi.useFakeTimers();
    try {
      vi.setSystemTime(new Date('2026-08-31T18:30:00Z'));
      // Everything a host seeds its `month` ref from must agree.
      expect(toLocalYm()).toBe('2026-09');
      expect(defaultMaxMonth()).toBe('2026-09');
      expect(defaultMinMonth()).toBe('2023-09');
      expect(formatYmLabel(toLocalYm(), 'id-ID')).toBe('September 2026');
    } finally {
      vi.useRealTimers();
    }
  });
});

/* ------------------------------------------------------------------ *
 * `YYYY-MM-DD` day arithmetic, added with the discount-code
 * valid_from/valid_until bound.
 *
 * `addDays` computes the lower bound a date picker offers, so an
 * off-by-one here is an off-by-one in what the user is allowed to
 * select — and the backend rule it mirrors (`after:valid_from`) has no
 * slack: the day either is or is not legal.
 * ------------------------------------------------------------------ */
import { addDays, formatYmdLabel, isValidYmd } from './local-date';

describe('YYYY-MM-DD helpers', () => {
  it('validates the wire shape and rejects the near-misses', () => {
    expect(isValidYmd('2026-09-01')).toBe(true);
    expect(isValidYmd('2026-12-31')).toBe(true);

    expect(isValidYmd('2026-9-1')).toBe(false); // unpadded — what a text box used to allow
    expect(isValidYmd('2026-13-01')).toBe(false);
    expect(isValidYmd('2026-00-01')).toBe(false);
    expect(isValidYmd('2026-09-00')).toBe(false);
    expect(isValidYmd('2026-09-32')).toBe(false);
    expect(isValidYmd('2026-09')).toBe(false);
    expect(isValidYmd('')).toBe(false);
  });

  it('steps a day forward and back', () => {
    expect(addDays('2026-09-01', 1)).toBe('2026-09-02');
    expect(addDays('2026-09-02', -1)).toBe('2026-09-01');
    expect(addDays('2026-09-01', 0)).toBe('2026-09-01');
  });

  it('carries across month, year, and leap-day boundaries', () => {
    expect(addDays('2026-09-30', 1)).toBe('2026-10-01');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
    expect(addDays('2026-01-01', -1)).toBe('2025-12-31');
    expect(addDays('2026-03-01', -1)).toBe('2026-02-28'); // 2026 is not a leap year
    expect(addDays('2024-02-28', 1)).toBe('2024-02-29'); // 2024 is
    expect(addDays('2024-03-01', -1)).toBe('2024-02-29');
  });

  it('passes malformed input through unchanged, like addMonths', () => {
    // A half-typed value in a bound v-model must degrade to "no bound",
    // never to the string 'NaN-aN-aN' landing in a `min` attribute.
    expect(addDays('2026-9-1', 1)).toBe('2026-9-1');
    expect(addDays('', 1)).toBe('');
    expect(addDays('rubbish', 1)).toBe('rubbish');
  });

  it('never routes through UTC — correct even where the naive parse is off by a day', () => {
    // `addDays` reads no clock, so the hazard is not "what time is it"
    // but "how was the STRING parsed". `new Date('2026-09-01')` is UTC
    // midnight by spec (date-only strings are treated as UTC, unlike the
    // date-time form) — which in any NEGATIVE offset is still the 31st
    // locally. Anything that then reads local components off that Date
    // silently loses a day.
    const REAL_TZ = process.env.TZ;
    process.env.TZ = 'America/New_York'; // UTC-4 in September
    try {
      // Premise, asserted so the test cannot pass vacuously if the TZ
      // override stops taking effect.
      const utcParsed = new Date('2026-09-01');
      expect(utcParsed.getTimezoneOffset()).toBe(240);
      expect(utcParsed.getDate()).toBe(31); // the trap: 31 Aug, not 1 Sep

      // The helper is unaffected: it never hands the string to Date.
      expect(addDays('2026-09-01', 1)).toBe('2026-09-02');
      expect(addDays('2026-09-30', 1)).toBe('2026-10-01');
      expect(addDays('2026-01-01', -1)).toBe('2025-12-31');
    } finally {
      process.env.TZ = REAL_TZ;
    }
  });
});

/**
 * `formatYmdLabel` — the day label behind the schedule screen's
 * "Menampilkan sesi pada …" bar.
 *
 * The hazard is the same one `formatYmLabel` documents, one granularity
 * finer: `new Date('2026-09-09')` is UTC midnight BY SPEC, so handing
 * the wire string straight to `toLocaleDateString` renders the PREVIOUS
 * day for every reader west of Greenwich. The helper splits the parts
 * and materialises local midnight instead.
 */
describe('formatYmdLabel', () => {
  const REAL_TZ = process.env.TZ;
  afterEach(() => {
    process.env.TZ = REAL_TZ;
  });

  it('names the day, the month in words, and the year', () => {
    expect(formatYmdLabel('2026-09-09', 'id-ID')).toBe('9 September 2026');
    expect(formatYmdLabel('2026-01-01', 'en-US')).toBe('January 1, 2026');
  });

  it('echoes malformed input back instead of rendering "Invalid Date"', () => {
    expect(formatYmdLabel('2026-9-9')).toBe('2026-9-9');
    expect(formatYmdLabel('')).toBe('');
  });

  it('names the SAME day west of Greenwich, where the naive parse loses one', () => {
    process.env.TZ = 'America/New_York'; // UTC-4 in September
    // Premise + the trap, so this cannot pass vacuously.
    const utcParsed = new Date('2026-09-09');
    expect(utcParsed.getTimezoneOffset()).toBe(240);
    expect(utcParsed.toLocaleDateString('en-US', {
      day: 'numeric', month: 'long', year: 'numeric',
    })).toBe('September 8, 2026'); // the buggy form

    expect(formatYmdLabel('2026-09-09', 'en-US')).toBe('September 9, 2026');
  });

  it('is stable in WIB, the timezone every tenant is in', () => {
    process.env.TZ = 'Asia/Jakarta';
    expect(new Date('2026-09-09T00:00:00Z').getTimezoneOffset()).toBe(-420);

    expect(formatYmdLabel('2026-09-09', 'id-ID')).toBe('9 September 2026');
  });
});

/* ------------------------------------------------------------------ *
 * `dateRangeForFacet` — the shared window behind the two admin bimbel
 * date chips (Kehadiran "Tanggal", Jadwal sesi "Periode").
 *
 * Both chips shipped as fabricated controls: they lit up, they sat in
 * the reload watcher so pressing one fired an identical refetch (the
 * list visibly reshuffled as though it had worked), and neither value
 * ever reached a query. Wiring them needs exactly one arithmetic, and
 * it lives here rather than twice in two views so the two screens
 * cannot come to disagree about which sessions are "this week".
 *
 * The two invariants this block locks:
 *
 *   1. `to` is EXCLUSIVE — the day AFTER the last day of the window.
 *      `SessionController::index` filters `starts_at < to` on a
 *      datetime column, so a `to` equal to the last day is coerced to
 *      that day's midnight and drops the whole final day. Every window
 *      below therefore asserts BOTH bounds, never just `from`.
 *   2. Every bound is a LOCAL calendar day. Two of the cases below
 *      assert the `toISOString().slice(0, 10)` trap explicitly before
 *      asserting the helper, so they cannot pass for the wrong reason.
 * ------------------------------------------------------------------ */
import { dateRangeForFacet } from './local-date';

describe('dateRangeForFacet', () => {
  it('returns null for the "Semua" reset — no filter, not an empty one', () => {
    // The caller spreads `null` as "send no date params at all". A
    // `{ from: '', to: '' }` here would reach the API as a filter
    // nothing can match and render as "no sessions" — a lie about the
    // data rather than an absent filter.
    expect(dateRangeForFacet('', '2026-09-09')).toBeNull();
  });

  it('returns null for a malformed anchor rather than inventing a window', () => {
    expect(dateRangeForFacet('week', '2026-9-9')).toBeNull();
    expect(dateRangeForFacet('month', 'kemarin')).toBeNull();
    expect(dateRangeForFacet('today', '')).toBeNull();
  });

  it('"today" is the half-open [D, D+1) — the exclusive bound the API wants', () => {
    expect(dateRangeForFacet('today', '2026-09-09')).toEqual({
      from: '2026-09-09',
      to: '2026-09-10',
    });
  });

  it('"today" carries month and year boundaries', () => {
    expect(dateRangeForFacet('today', '2026-09-30').to).toBe('2026-10-01');
    expect(dateRangeForFacet('today', '2026-12-31')).toEqual({
      from: '2026-12-31',
      to: '2027-01-01',
    });
  });

  it('"week" runs Monday → Sunday, ending on the FOLLOWING Monday', () => {
    // 2026-09-09 is a Wednesday; its week is Mon 7 Sep – Sun 13 Sep.
    expect(new Date(2026, 8, 9).getDay()).toBe(3); // premise: Wednesday
    expect(dateRangeForFacet('week', '2026-09-09')).toEqual({
      from: '2026-09-07',
      to: '2026-09-14',
    });
  });

  it('"week" treats SUNDAY as the last day of the week, not the first', () => {
    // The off-by-a-week trap: JS getDay() calls Sunday 0, so the naive
    // `-getDay()` walks a Sunday reader forward into next week's Monday
    // and hides the six days they are actually looking at.
    expect(new Date(2026, 8, 13).getDay()).toBe(0); // premise: Sunday
    expect(dateRangeForFacet('week', '2026-09-13')).toEqual({
      from: '2026-09-07',
      to: '2026-09-14',
    });
  });

  it('"week" on a Monday starts that same day', () => {
    expect(new Date(2026, 8, 7).getDay()).toBe(1); // premise: Monday
    expect(dateRangeForFacet('week', '2026-09-07')).toEqual({
      from: '2026-09-07',
      to: '2026-09-14',
    });
  });

  it('"week" spans a month and a year boundary intact', () => {
    // Mon 28 Sep – Sun 4 Oct.
    expect(dateRangeForFacet('week', '2026-09-30')).toEqual({
      from: '2026-09-28',
      to: '2026-10-05',
    });
    // Mon 28 Dec 2026 – Sun 3 Jan 2027.
    expect(dateRangeForFacet('week', '2026-12-31')).toEqual({
      from: '2026-12-28',
      to: '2027-01-04',
    });
  });

  it('"month" is the whole calendar month, ending on the 1st of the next', () => {
    expect(dateRangeForFacet('month', '2026-09-09')).toEqual({
      from: '2026-09-01',
      to: '2026-10-01',
    });
    // The last day of the month must still be INSIDE the window: `to`
    // is 1 Oct, so 30 Sep is matched. A `to` of '2026-09-30' would drop
    // it, which is the whole reason the bound is exclusive.
    expect(dateRangeForFacet('month', '2026-09-30').to).toBe('2026-10-01');
  });

  it('"month" rolls the year over in December', () => {
    expect(dateRangeForFacet('month', '2026-12-15')).toEqual({
      from: '2026-12-01',
      to: '2027-01-01',
    });
  });

  it('"month" gets February right in a leap year and out of one', () => {
    expect(dateRangeForFacet('month', '2024-02-10')).toEqual({
      from: '2024-02-01',
      to: '2024-03-01',
    });
    expect(dateRangeForFacet('month', '2026-02-10')).toEqual({
      from: '2026-02-01',
      to: '2026-03-01',
    });
  });

  it('defaults the anchor to the caller\'s LOCAL today, never the UTC one', () => {
    const REAL_TZ = process.env.TZ;
    process.env.TZ = 'Asia/Jakarta';
    vi.useFakeTimers();
    try {
      // 2026-09-08T22:30Z === 2026-09-09 05:30 WIB. This is the exact
      // window — the first 7 hours of any WIB day — in which
      // `new Date().toISOString().slice(0, 10)` names YESTERDAY, so an
      // admin opening "Hari ini" before 07:00 would be shown the 8th.
      vi.setSystemTime(new Date('2026-09-08T22:30:00Z'));

      // Premise + the trap, asserted before the conclusion.
      expect(new Date().getTimezoneOffset()).toBe(-420);
      expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-08'); // buggy
      expect(toLocalYmd()).toBe('2026-09-09'); // correct

      expect(dateRangeForFacet('today')).toEqual({
        from: '2026-09-09',
        to: '2026-09-10',
      });
      // And the wider windows are anchored on that same local day.
      expect(dateRangeForFacet('week')).toEqual({
        from: '2026-09-07',
        to: '2026-09-14',
      });
      expect(dateRangeForFacet('month')).toEqual({
        from: '2026-09-01',
        to: '2026-10-01',
      });
    } finally {
      vi.useRealTimers();
      process.env.TZ = REAL_TZ;
    }
  });

  it('is correct in a NEGATIVE offset too', () => {
    const REAL_TZ = process.env.TZ;
    process.env.TZ = 'America/New_York'; // UTC-4 in September
    vi.useFakeTimers();
    try {
      // 2026-09-10T01:30Z === 2026-09-09 21:30 in New York. Here the
      // UTC slice runs AHEAD, naming tomorrow.
      vi.setSystemTime(new Date('2026-09-10T01:30:00Z'));

      expect(new Date().getTimezoneOffset()).toBe(240);
      expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-10'); // buggy
      expect(toLocalYmd()).toBe('2026-09-09'); // correct

      expect(dateRangeForFacet('today')).toEqual({
        from: '2026-09-09',
        to: '2026-09-10',
      });
    } finally {
      vi.useRealTimers();
      process.env.TZ = REAL_TZ;
    }
  });
});
