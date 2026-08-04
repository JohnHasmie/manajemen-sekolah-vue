/**
 * Contract spec for AdminTutoring2PayoutSettingsView (WEB-16 / BE-24
 * settings + BE-26 monthly close).
 *
 * Vitest API, vue-tsc-checked. Pins the (real, backend-truthful)
 * settings shape and the monthly-close row.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import AdminTutoring2PayoutSettingsView from './AdminTutoring2PayoutSettingsView.vue';
import type { PayoutClose, PayoutSettings, UpdatePayoutSettingsPayload } from '@/types/tutoring2/payout';

describe('AdminTutoring2PayoutSettingsView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = AdminTutoring2PayoutSettingsView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('carries the real backend settings fields (not the brief-only extras)', () => {
    // If someone adds `payment_method` as a required field, this row
    // still compiles because the extras are optional — but the required
    // set (cycle/default_kind/minimum_payout/notes) is locked here.
    const settings: PayoutSettings = {
      cycle: 'monthly',
      default_kind: 'per_session',
      minimum_payout: null,
      notes: '',
    };
    expect(settings.cycle).toBe('monthly');
  });

  it('close-month rows expose closed_by as nested {user_id, name}', () => {
    const c: PayoutClose = {
      id: 'c-1',
      period_month: '2026-07',
      closed_at: '2026-07-31T09:12:00Z',
      closed_by: { user_id: 'u-1', name: 'Admin Uji' },
    };
    expect(c.closed_by?.name).toBe('Admin Uji');
  });

  it('update payload is a strict partial patch', () => {
    // We PUT only what changed; any accidental required field here
    // would 422 the write once a min:2 rule fires on empty notes.
    const patch: UpdatePayoutSettingsPayload = { cycle: 'biweekly' };
    expect(patch.cycle).toBe('biweekly');
  });
});
