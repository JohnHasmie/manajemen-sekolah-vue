/**
 * Proves the six views audited for the empty-state trap now resolve to
 * `status: 'empty'` on an empty payload.
 *
 * Rather than mount six screens (each needing its own store, router and
 * service scaffolding), this exercises the exact predicate each view
 * passes to `useDataRefresh`, against the exact payload shape its loader
 * returns. That is the whole of what was broken: the loaders were always
 * correct, and `isEmpty()`'s array-only rule never applied to them.
 *
 * Keep these in step with the views. A predicate that drifts from its
 * loader's shape is silent — which is precisely how the bug arrived.
 */
import { describe, expect, it } from 'vitest';
import { useDataRefresh } from './useDataRefresh';

async function statusFor<T>(data: T, isEmpty: (d: T) => boolean) {
  const { state, reload } = useDataRefresh<T>(async () => data, {
    immediate: false,
    watchAcademicYear: false,
    watchLocale: false,
    isEmpty,
  });
  await reload();
  return state.value.status;
}

/** view → [predicate, empty payload, non-empty payload] */
const CASES: Array<[string, (d: never) => boolean, unknown, unknown]> = [
  [
    'AdminGradeOverviewView',
    ((d: { teachers?: unknown[] }) => (d?.teachers?.length ?? 0) === 0) as never,
    { school_stats: { avg: 0 }, teachers: [] },
    { school_stats: { avg: 80 }, teachers: [{ teacher_name: 'Budi' }] },
  ],
  [
    'AdminTutoring2BillingView',
    ((d: { bills: unknown[] }) => d.bills.length === 0) as never,
    { bills: [], summary: { total: 0 } },
    { bills: [{ id: 'b1' }], summary: { total: 1 } },
  ],
  [
    'AdminTutoring2PayoutSummaryView',
    ((d: { rows: unknown[] }) => d.rows.length === 0) as never,
    { rows: [], meta: { tutor_count: 0 } },
    { rows: [{ id: 'r1' }], meta: { tutor_count: 1 } },
  ],
  [
    'ParentTutoring2VouchersView',
    ((d: { vouchers: unknown[] }) => d.vouchers.length === 0) as never,
    // Deliberately non-empty on the OTHER two keys: the page is about
    // vouchers, so context data must not make it look populated.
    { vouchers: [], enrollments: [{ id: 'e1' }], bills: [{ id: 'b1' }] },
    { vouchers: [{ id: 'v1' }], enrollments: [], bills: [] },
  ],
  [
    'TutorTutoring2RatingsView',
    ((d: { total_ratings?: number }) => (d?.total_ratings ?? 0) === 0) as never,
    { avg_rating: null, total_ratings: 0 },
    { avg_rating: 4.5, total_ratings: 12 },
  ],
  [
    'TutorTutoring2SubmissionsView',
    ((d: { rows: unknown[] }) => d.rows.length === 0) as never,
    { rows: [] },
    { rows: [{ id: 's1' }] },
  ],
];

describe('empty-state audit: object payloads now resolve to empty', () => {
  for (const [view, predicate, emptyPayload, fullPayload] of CASES) {
    it(`${view} reports empty on an empty payload`, async () => {
      expect(await statusFor(emptyPayload as never, predicate)).toBe('empty');
    });

    it(`${view} still reports content when there is data`, async () => {
      expect(await statusFor(fullPayload as never, predicate)).toBe('content');
    });
  }

  it('every payload here would have been CONTENT under the old rule', async () => {
    // The regression this audit closes: each of these is an object, and
    // the default isEmpty() only recognises null/undefined/[]. Without a
    // predicate all six render a blank content branch.
    for (const [, , emptyPayload] of CASES) {
      expect(await statusFor(emptyPayload as never, () => false)).toBe('content');
    }
  });
});
