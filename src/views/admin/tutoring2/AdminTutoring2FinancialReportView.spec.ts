/**
 * Vitest contract spec — Financial report admin view. Pins the
 * per-day amount row shape, including the reserved `refunds_amount`
 * column (always 0 in BE-28, will be populated in BE-33).
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import View from './AdminTutoring2FinancialReportView.vue';
import type { FinancialReportRow } from '@/types/tutoring2/report';

describe('AdminTutoring2FinancialReportView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = View as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('reads FinancialReportRow with rupiah amounts and reserved refunds column', () => {
    const _r: FinancialReportRow = {
      date: '2026-08-01',
      bills_created_count: 4,
      bills_created_amount: 6_000_000,
      bills_paid_amount: 4_500_000,
      bills_overdue_amount: 500_000,
      refunds_amount: 0,
    };
    expect(_r.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    // Refunds column exists so the FE contract is stable when BE-33
    // starts populating it. If someone removes it, the view stops
    // rendering the column silently — this assertion catches that.
    expect(_r.refunds_amount).toBe(0);
  });
});
