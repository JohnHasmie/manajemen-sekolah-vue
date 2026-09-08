/**
 * OntimeHarianChart — the dashed "today" outline must sit on the LOCAL
 * today's bar.
 *
 * The marker was gated on `const TODAY_ISO = new
 * Date().toISOString().slice(0, 10)`, which is wrong twice over:
 *
 *   1. UTC. Before 07:00 WIB the string is yesterday, so the outline
 *      landed on the PREVIOUS bar. That is worse than no marker: the
 *      panel's whole job is "have today's staff checked in on time
 *      yet", and the admin reads yesterday's column as the answer.
 *   2. Module scope. It was evaluated once when the chunk was parsed,
 *      so a dashboard left open overnight kept outlining the day the
 *      tab was first loaded even as the data refreshed underneath.
 *
 * The TZ is pinned to Asia/Jakarta and the OLD form's output asserted
 * first — in UTC both forms agree and the spec would be vacuous.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import OntimeHarianChart from './OntimeHarianChart.vue';

function day(date: string) {
  return {
    date,
    ontime_pct: 90,
    is_workday: true,
    present_count: 10,
    late_count: 1,
    absent_count: 0,
  };
}

/**
 * The "today" outline is the only `<rect>` with a dashed cobalt stroke.
 * Returning its `x` lets us say WHICH bar it is on rather than merely
 * that one exists — an outline on the wrong bar is the actual defect.
 */
function outlinedBarX(w: unknown): string | undefined {
  const marker = w
    .findAll('rect')
    .find((r) => r.attributes('stroke') === '#1b6fb8' && r.attributes('stroke-dasharray') === '4 3');
  return marker?.attributes('x');
}

function barXFor(w: unknown, idx: number): string | undefined {
  // Bars carry a <title> tooltip; the outline rect does not.
  return w
    .findAll('rect')
    .filter((r) => r.find('title').exists())
    [idx]?.attributes('x');
}

beforeEach(() => {
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('OntimeHarianChart · "today" marker follows the LOCAL day', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  const DATA = [day('2026-09-13'), day('2026-09-14'), day('2026-09-15')];

  it('outlines TODAY at 02:00 WIB, not the bar UTC still calls today', () => {
    // 2026-09-14T19:00Z === 15 Sep 2026, 02:00 WIB.
    vi.setSystemTime(new Date('2026-09-14T19:00:00Z'));

    // Premise guards — without these the spec is vacuous on a UTC runner.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-14'); // the buggy form

    const w = mount(OntimeHarianChart, { props: { data: DATA } });

    // Index 2 is 15 Sep — the local today. Index 1 is what the UTC form
    // would have outlined.
    expect(outlinedBarX(w)).toBeDefined();
    expect(outlinedBarX(w)).not.toBe(String(Number(barXFor(w, 1)) - 2));
    expect(outlinedBarX(w)).toBe(String(Number(barXFor(w, 2)) - 2));
  });

  it('outlines nothing when no bar is the local today', () => {
    vi.setSystemTime(new Date('2026-09-20T05:00:00Z'));
    const w = mount(OntimeHarianChart, { props: { data: DATA } });
    expect(outlinedBarX(w)).toBeUndefined();
  });

  it('follows the clock past local midnight instead of pinning at import time', () => {
    // Mount at 23:50 WIB on the 14th…
    vi.setSystemTime(new Date('2026-09-14T16:50:00Z'));
    const before = mount(OntimeHarianChart, { props: { data: DATA } });
    expect(outlinedBarX(before)).toBe(String(Number(barXFor(before, 1)) - 2)); // 14 Sep

    // …and again at 00:10 WIB on the 15th. A module-level constant would
    // give both mounts the same answer.
    vi.setSystemTime(new Date('2026-09-14T17:10:00Z'));
    const after = mount(OntimeHarianChart, { props: { data: DATA } });
    expect(outlinedBarX(after)).toBe(String(Number(barXFor(after, 2)) - 2)); // 15 Sep
  });
});
