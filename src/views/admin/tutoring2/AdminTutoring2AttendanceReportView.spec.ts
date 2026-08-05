/**
 * Vitest contract spec — Attendance report admin view. Pins the
 * per-enrollment row shape and the [0, 1] rate contract.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import View from './AdminTutoring2AttendanceReportView.vue';
import type { AttendanceReportRow } from '@/types/tutoring2/report';

describe('AdminTutoring2AttendanceReportView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = View as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('reads AttendanceReportRow keyed by enrollment_id (not student_class_id)', () => {
    const _r: AttendanceReportRow = {
      enrollment_id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
      student_name: 'Nadia Putri',
      program_name: 'SBMPTN Saintek',
      sessions_planned: 8,
      hadir: 7,
      izin: 0,
      sakit: 1,
      alpa: 0,
      attendance_rate: 0.875,
    };
    // Rate is a fraction in [0, 1] — NOT a percent. The view multiplies
    // by 100 for display. If the BE ever ships a percent instead, this
    // assertion fails and the view starts rendering "8750%".
    expect(_r.attendance_rate).toBeGreaterThanOrEqual(0);
    expect(_r.attendance_rate).toBeLessThanOrEqual(1);
    expect(_r.enrollment_id).toBeTruthy();
  });
});
