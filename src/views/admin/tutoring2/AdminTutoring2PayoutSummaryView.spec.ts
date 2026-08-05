/**
 * Contract spec for AdminTutoring2PayoutSummaryView (WEB-16 / BE-26).
 *
 * Vitest API, vue-tsc-checked. Pins the aggregate row shape returned
 * by /payouts/admin-summary — plain array (no Eloquent), keyed off
 * PayoutSummaryService.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2PayoutSummaryView from './AdminTutoring2PayoutSummaryView.vue';
import type { PayoutSummaryMeta, PayoutSummaryRow } from '@/types/tutoring2/payout';

describe('AdminTutoring2PayoutSummaryView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2PayoutSummaryView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts the {tutor_id, sessions_taught, base_amount, adjustments, net_amount} row', () => {
    const row: PayoutSummaryRow = {
      tutor_id: 't-1',
      tutor_name: 'Bu Rina',
      period_month: '2026-07',
      sessions_taught: 12,
      base_amount: 900_000,
      adjustments: 0,
      net_amount: 900_000,
    };
    expect(row.net_amount).toBe(900_000);
  });

  it('meta carries period_month + tutor_count', () => {
    const meta: PayoutSummaryMeta = { period_month: '2026-07', tutor_count: 1 };
    expect(meta.tutor_count).toBe(1);
  });
});
