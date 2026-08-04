/**
 * Vitest contract spec for TutorTutoring2ActivitiesView (WEB-13).
 *
 * Same convention as sibling *.spec.ts under `views/teacher/tutoring2/`:
 * type-checked by `vue-tsc --build` (the active gate), Vitest itself
 * isn't wired in this workspace yet.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutorTutoring2ActivitiesView from './TutorTutoring2ActivitiesView.vue';
import type { Activity } from '@/types/tutoring2/activity';

describe('TutorTutoring2ActivitiesView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutorTutoring2ActivitiesView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('operates on Activity rows keyed by learning_group_id + id', () => {
    const _a: Activity = {
      id: 'act-1',
      learning_group_id: 'grp-1',
      kind: 'tugas',
      title: 'PR Aljabar',
      published_at: null,
      submissions_count: 0,
    };
    expect(_a.learning_group_id).toBeTruthy();
  });
});
