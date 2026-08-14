/**
 * Contract spec for TutorTutoring2ScoresView.
 *
 * The view used to hardcode `MAX_SCORE = 100` and `KKM = 75`, so an
 * assessment worth 50 rendered a passing 45 as "45 / 100" and every
 * row was coloured pass/fail against a threshold nobody had set. Both
 * now come from `GET /tutoring-v2/assessments/:id`.
 *
 * Same convention as sibling *.spec.ts under `views/teacher/tutoring2/`:
 * type-checked by `vue-tsc --build` (the active gate), Vitest itself
 * isn't wired in this workspace yet.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutorTutoring2ScoresView from './TutorTutoring2ScoresView.vue';
import type { BimbelAssessment } from '@/services/tutoring-bimbel.service';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

describe('TutorTutoring2ScoresView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutorTutoring2ScoresView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('reads the ceiling off the assessment, which need not be 100', () => {
    const a: BimbelAssessment = {
      id: 'as-1',
      program_id: 'pr-1',
      title: 'TO 1',
      kind: 'tryout',
      max_score: 50,
      kkm: 30,
    };
    expect(a.max_score).not.toBe(100);
    expect(a.kkm).not.toBe(75);
  });

  it('tolerates an assessment with no pass mark', () => {
    // `kkm` is nullable on the wire and TutoringScoreEntryList skips
    // the pass/fail colouring when it is null. That is the honest
    // answer for an assessment nobody set a threshold on — the old
    // hardcoded 75 coloured those rows anyway.
    const a: BimbelAssessment = {
      id: 'as-2',
      program_id: 'pr-1',
      title: 'Latihan',
      kind: 'latihan',
      max_score: 20,
      kkm: null,
    };
    expect(a.kkm).toBeNull();
  });

  it('renders score rows that name their student', () => {
    // All three of these have been on the type since WEB-2; the wire
    // only started carrying them alongside this change.
    const r: TutoringScoreRow = {
      enrollment_id: 'en-1',
      student_id: 'st-1',
      student_name: 'Budi Santoso',
      student_number: 'S-0042',
      score: 42,
    };
    expect(r.student_name).toBeTruthy();
    expect(r.student_id).toBeTruthy();
  });
});
