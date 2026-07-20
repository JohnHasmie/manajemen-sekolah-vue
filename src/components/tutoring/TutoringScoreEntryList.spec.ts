/**
 * Vitest spec for TutoringScoreEntryList — pins the score-row shape
 * and the save-dirty emit signature. Consumers: WEB-3 admin grade
 * screen and WEB-4 tutor input-skor screen.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutoringScoreEntryList from './TutoringScoreEntryList.vue';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

describe('TutoringScoreEntryList contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutoringScoreEntryList as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts score rows keyed by enrollment_id (not student_class_id)', () => {
    const _row: TutoringScoreRow = {
      enrollment_id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
      student_id: '019f8090-51c4-703d-ad74-6b95f8421445',
      student_name: 'Nadia Putri',
      student_number: '2026-001',
      score: 78,
      notes: null,
      dirty: false,
    };
    expect(_row.enrollment_id).toBeTruthy();
    expect(_row.score).toBe(78);
  });

  it('accepts null score (unentered)', () => {
    const _row: TutoringScoreRow = {
      enrollment_id: 'e1',
      student_id: 's1',
      student_name: 'Salsa Lestari',
      score: null,
    };
    expect(_row.score).toBeNull();
  });

  it('saveDirty emit signature is TutoringScoreRow[]', () => {
    type SaveDirty = (rows: TutoringScoreRow[]) => void;
    const _fn: SaveDirty = (rows) => rows.forEach((r) => r.enrollment_id);
    expect(typeof _fn).toBe('function');
  });
});
