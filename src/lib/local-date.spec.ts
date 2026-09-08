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
import { afterAll, beforeAll, describe, it, expect, vi } from 'vitest';
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
import { addDays, isValidYmd } from './local-date';

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
