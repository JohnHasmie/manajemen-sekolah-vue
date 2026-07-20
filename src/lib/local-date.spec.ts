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
import { describe, it, expect } from 'vitest';
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
