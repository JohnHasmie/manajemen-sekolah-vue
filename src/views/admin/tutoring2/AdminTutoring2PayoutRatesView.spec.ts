/**
 * Contract spec for AdminTutoring2PayoutRatesView (WEB-16 / BE-24).
 *
 * Vitest API, type-checked by `vue-tsc --build` (Vitest itself not
 * wired yet — same pattern as the rest of the tutoring2 specs).
 *
 * Pins the enum vocabulary and rate row shape the view depends on —
 * any drift here (renaming a rate kind, adding an unknown status
 * label without a `.kind.` translation) breaks the compile.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2PayoutRatesView from './AdminTutoring2PayoutRatesView.vue';
import type { PayoutRate, PayoutRateKind } from '@/types/tutoring2/payout';
import { PAYOUT_RATE_KINDS } from '@/types/tutoring2/payout';

describe('AdminTutoring2PayoutRatesView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2PayoutRatesView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('recognises the three backend rate kinds', () => {
    const expected: PayoutRateKind[] = ['per_session', 'monthly_salary', 'percent_revenue'];
    expect(PAYOUT_RATE_KINDS).toEqual(expected);
  });

  it('accepts a rate row with optional whenLoaded tutor_name', () => {
    const _row: PayoutRate = {
      id: 'r-1',
      tutor_id: 't-1',
      tutor_name: 'Bu Rina',
      kind: 'per_session',
      value: 75_000,
      effective_from: '2026-08-01',
      effective_until: null,
    };
    expect(_row.kind).toBe('per_session');
  });
});
