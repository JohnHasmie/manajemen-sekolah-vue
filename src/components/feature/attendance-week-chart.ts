/**
 * Pure geometry/maths for the weekly attendance bar chart in
 * `AdminAttendanceOverviewCard.vue`.
 *
 * These live outside the SFC purely so they can be unit-tested. The
 * hatched "belum absen pulang" band is a proportion now, not a flag, and
 * a proportion that is quietly wrong is worse than no proportion at all —
 * it looks authoritative either way.
 */

/** The four buckets `GET /teacher-attendance/report/timeseries` returns. */
export interface PersonnelDayCounts {
  present: number;
  late: number;
  absent: number;
  /** Clocked in, never clocked out — the nightly job's `no_checkout`. */
  noCheckout: number;
}

/**
 * `no_checkout` as a share of EVERYONE counted that day (0..100).
 *
 * Deliberately measured against the same denominator the bar's
 * `present_pct` uses, which makes the hatched band readable straight off
 * the y-axis: a band spanning 12 percentage points means 12% of all
 * personnel never clocked out. The alternative — a share of only the
 * people who showed up — would render a taller band for the same number
 * of people on a day with many absentees, which reads as "the checkout
 * problem got worse" when only attendance changed.
 */
export function noCheckoutPctOfAll(c: PersonnelDayCounts): number {
  const total = c.present + c.late + c.absent + c.noCheckout;
  if (total <= 0) return 0;
  return (c.noCheckout / total) * 100;
}

/**
 * Pixel height of the hatched band, measured up from the bar's baseline.
 *
 * @param noCheckoutPct share of all personnel, from `noCheckoutPctOfAll`
 * @param presentPct    the bar's own height in percent (already rounded)
 * @param plotRange     pixels between the 0 and 100 gridlines
 * @param minPx         floor so a single missing checkout stays visible
 *
 * The floor is the one dishonest pixel here: one person out of 200 is
 * 0.5% ≈ 0.6px, which renders as nothing, and "nothing" is exactly the
 * wrong answer for a data-quality warning. It is capped by the bar so a
 * short bar can never sprout a band taller than itself.
 */
export function noCheckoutBandHeight(
  noCheckoutPct: number,
  presentPct: number,
  plotRange: number,
  minPx = 3,
): number {
  if (noCheckoutPct <= 0 || plotRange <= 0) return 0;
  const barHeight = (Math.max(0, Math.min(100, presentPct)) / 100) * plotRange;
  if (barHeight <= 0) return 0;
  const exact = (Math.min(noCheckoutPct, 100) / 100) * plotRange;
  return Math.min(Math.max(exact, minPx), barHeight);
}
