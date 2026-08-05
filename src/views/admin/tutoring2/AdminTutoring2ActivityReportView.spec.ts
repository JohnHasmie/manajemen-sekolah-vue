/**
 * Vitest contract spec — Activity report admin view. Locks the wire
 * shape the view depends on and asserts the component still loads.
 *
 * Same convention as the other web-vue view specs: Vitest API,
 * type-checked by `vue-tsc --build`. Vitest itself isn't wired yet.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import View from './AdminTutoring2ActivityReportView.vue';
import type { ActivityReportRow } from '@/types/tutoring2/report';

describe('AdminTutoring2ActivityReportView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = View as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('reads ActivityReportRow with per-day session totals', () => {
    const _r: ActivityReportRow = {
      date: '2026-08-01',
      sessions_scheduled: 3,
      sessions_completed: 2,
      sessions_cancelled: 1,
      attendance_marked_count: 12,
    };
    expect(_r.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(_r.sessions_scheduled).toBeGreaterThanOrEqual(_r.sessions_completed);
  });
});
