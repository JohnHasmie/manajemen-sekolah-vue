import { describe, expect, it } from 'vitest';
import {
  noCheckoutBandHeight,
  noCheckoutPctOfAll,
} from '@/components/feature/attendance-week-chart';

// Plot range used by the real chart (CHART_BASE 150 - CHART_TOP 30).
const RANGE = 120;

describe('noCheckoutPctOfAll', () => {
  it('measures against everyone counted, not just the people present', () => {
    // 2 of 10 never clocked out → 20% of all, regardless of who was absent.
    expect(
      noCheckoutPctOfAll({ present: 5, late: 1, absent: 2, noCheckout: 2 }),
    ).toBe(20);
  });

  it('does not inflate when absences rise but missing checkouts do not', () => {
    // The reason the denominator is "everyone" and not "everyone present":
    // the same 2 people must not read as a bigger checkout problem just
    // because more colleagues were absent that day.
    const fewAbsent = noCheckoutPctOfAll({
      present: 6,
      late: 0,
      absent: 2,
      noCheckout: 2,
    });
    const manyAbsent = noCheckoutPctOfAll({
      present: 2,
      late: 0,
      absent: 6,
      noCheckout: 2,
    });
    expect(fewAbsent).toBe(20);
    expect(manyAbsent).toBe(20);
  });

  it('never exceeds the bar it sits inside', () => {
    // present_pct = (present+late+noCheckout)/total, so no_checkout's
    // share of all is bounded by it — the band can only ever be a slice.
    const counts = { present: 3, late: 2, absent: 4, noCheckout: 1 };
    const total =
      counts.present + counts.late + counts.absent + counts.noCheckout;
    const presentPct =
      ((counts.present + counts.late + counts.noCheckout) / total) * 100;
    expect(noCheckoutPctOfAll(counts)).toBeLessThanOrEqual(presentPct);
  });

  it('is 100 when nobody clocked out at all', () => {
    // The MTs Muhammadiyah SKA shape — a fully hatched bar is correct here.
    expect(
      noCheckoutPctOfAll({ present: 0, late: 0, absent: 0, noCheckout: 7 }),
    ).toBe(100);
  });

  it('returns 0 for an empty day instead of dividing by zero', () => {
    expect(
      noCheckoutPctOfAll({ present: 0, late: 0, absent: 0, noCheckout: 0 }),
    ).toBe(0);
  });
});

describe('noCheckoutBandHeight', () => {
  it('scales with the share, so the band is readable off the y-axis', () => {
    // 25 points of a 120px plot = 30px, wherever the bar happens to end.
    expect(noCheckoutBandHeight(25, 100, RANGE)).toBe(30);
  });

  it('is zero when everyone clocked out', () => {
    expect(noCheckoutBandHeight(0, 100, RANGE)).toBe(0);
  });

  it('fills the bar when no_checkout accounts for the whole of it', () => {
    expect(noCheckoutBandHeight(100, 100, RANGE)).toBe(120);
  });

  it('keeps a single missing checkout visible instead of sub-pixel', () => {
    // 1 of 200 = 0.5% = 0.6px, which renders as nothing at all — the
    // wrong answer for a warning. Floored, but only to 3px.
    expect(noCheckoutBandHeight(0.5, 100, RANGE)).toBe(3);
  });

  it('never draws a band taller than the bar, floor included', () => {
    // A 1%-tall bar is 1.2px; the 3px floor must not out-grow it.
    expect(noCheckoutBandHeight(0.5, 1, RANGE)).toBeCloseTo(1.2, 5);
  });

  it('clamps a band that would overflow its bar', () => {
    // Shouldn't happen given the shared denominator, but rounding of
    // present_pct upstream means this must not be able to spill.
    expect(noCheckoutBandHeight(80, 50, RANGE)).toBe(60);
  });

  it('draws nothing for a zero-height bar', () => {
    expect(noCheckoutBandHeight(50, 0, RANGE)).toBe(0);
  });
});
