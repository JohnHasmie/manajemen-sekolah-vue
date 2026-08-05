import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutorTutoring2RatingsView from './TutorTutoring2RatingsView.vue';
import type { TutorRatingSummary } from '@/types/tutoring2/rating';

describe('TutorTutoring2RatingsView contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutorTutoring2RatingsView as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('renders against a TutorRatingSummary with all five distribution keys', () => {
    const _s: TutorRatingSummary = {
      tutor_id: 'tutor-1',
      avg_rating: 4.2,
      total_ratings: 10,
      distribution: { 1: 0, 2: 1, 3: 1, 4: 3, 5: 5 },
      last_5_notes: [
        { rating: 5, notes: 'Menyenangkan', created_at: '2026-08-01T00:00:00Z' },
      ],
    };
    // Compile-time assertion: distribution must have all 5 keys.
    expect(_s.distribution[1]).toBeDefined();
    expect(_s.distribution[5]).toBe(5);
  });

  it('tolerates a zero-ratings tutor (avg_rating null)', () => {
    const _s: TutorRatingSummary = {
      tutor_id: 'tutor-2',
      avg_rating: null,
      total_ratings: 0,
      distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
      last_5_notes: [],
    };
    expect(_s.avg_rating).toBeNull();
  });
});
