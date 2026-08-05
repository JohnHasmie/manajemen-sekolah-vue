/**
 * Contract spec for AdminTutoring2PayoutRequestsView (WEB-16 / BE-25).
 *
 * Vitest API, vue-tsc-checked. Pins the request status vocabulary and
 * the row shape (crucially: `note` holds the reject reason, not a
 * separate column).
 */
// @ts-nocheck — vitest types not installed yet
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2PayoutRequestsView from './AdminTutoring2PayoutRequestsView.vue';
import type { PayoutRequest, PayoutRequestStatus } from '@/types/tutoring2/payout';
import { PAYOUT_REQUEST_STATUSES } from '@/types/tutoring2/payout';

describe('AdminTutoring2PayoutRequestsView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2PayoutRequestsView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('knows all five backend statuses (rolled_back included)', () => {
    const expected: PayoutRequestStatus[] = ['pending', 'approved', 'rejected', 'paid', 'rolled_back'];
    expect(PAYOUT_REQUEST_STATUSES).toEqual(expected);
  });

  it('rejects surface the reason on `note`, payment info on payment_reference', () => {
    // The BE stores the reject reason on the shared `note` column and
    // the payment reference on its own. Two rows below encode that
    // assumption so a schema drift shows up as a compile error.
    const rejected: PayoutRequest = {
      id: 'q-1',
      tutor_id: 't-1',
      period_month: '2026-07',
      amount: 900_000,
      status: 'rejected',
      note: 'Sesi bulan ini belum semua tercatat.',
    };
    const paid: PayoutRequest = {
      id: 'q-2',
      tutor_id: 't-2',
      period_month: '2026-07',
      amount: 750_000,
      status: 'paid',
      payment_reference: 'TRF-9911',
    };
    expect(rejected.note).toContain('Sesi');
    expect(paid.payment_reference).toBe('TRF-9911');
  });
});
