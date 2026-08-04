import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutorTutoring2SubmissionsView from './TutorTutoring2SubmissionsView.vue';
import type { Submission, SubmissionGradePayload } from '@/types/tutoring2/activity';

describe('TutorTutoring2SubmissionsView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutorTutoring2SubmissionsView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('operates on Submission rows keyed by enrollment_id (greenfield contract)', () => {
    const _s: Submission = {
      id: 'sub-1',
      activity_id: 'act-1',
      enrollment_id: 'enr-1',
      status: 'submitted',
    };
    expect(_s.enrollment_id).toBeTruthy();
  });

  it('grade payload carries a nullable score + optional feedback', () => {
    const _p: SubmissionGradePayload = { score: 85, feedback: 'Bagus' };
    const _q: SubmissionGradePayload = { score: null };
    expect(_p.score).toBe(85);
    expect(_q.score).toBeNull();
  });
});
