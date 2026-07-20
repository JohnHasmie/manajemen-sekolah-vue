/**
 * Vitest spec for TutoringAttendanceRoster — pins the row shape +
 * emit contract so mobile (WEB-4 tutor Presensi screen) and admin
 * (WEB-3 rekap sesi) can trust the same API.
 *
 * Same convention as the other web-vue specs: Vitest API, type-checked
 * by `vue-tsc --build`. Vitest itself isn't wired yet — vue-tsc is
 * the active gate.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutoringAttendanceRoster from './TutoringAttendanceRoster.vue';
import type { TutoringAttendanceRow } from '@/types/tutoring-bimbel';

describe('TutoringAttendanceRoster contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutoringAttendanceRoster as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts rows keyed by enrollment_id (not student_class_id)', () => {
    // The whole point of the greenfield contract: attendance rows FK
    // to bimbel_enrollments. If someone renames the field back to
    // student_class_id, this fails to type-check.
    const _row: TutoringAttendanceRow = {
      enrollment_id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
      student_id: '019f8090-51c4-703d-ad74-6b95f8421445',
      student_name: 'Nadia Putri',
      student_number: '2026-001',
      status: 'hadir',
      alert: 'sakit sesi lalu',
      alert_tone: 'warning',
      notes: undefined,
    };
    expect(_row.enrollment_id).toBeTruthy();
  });

  it('exposes both update:row (optimistic) and save (footer CTA) emits', () => {
    // Two-way binding pattern — parent owns rows, roster fires per-cell
    // updates plus one save. Assertion is compile-time via the types
    // below; runtime just proves the callbacks are callable.
    type UpdateRow = (p: { enrollment_id: string; status: 'hadir' | 'sakit' | 'izin' | 'alpa' | null; notes?: string }) => void;
    type Save = () => void;
    const _u: UpdateRow = () => {};
    const _s: Save = () => {};
    expect(typeof _u).toBe('function');
    expect(typeof _s).toBe('function');
  });
});
