/**
 * Vitest contract spec for RatingsService (WEB-13).
 *
 * Pins:
 *   - `/tutors/me/ratings` — self, bypasses `tutoring.tutor.view`
 *   - `/tutors/{tutorId}/ratings` — admin
 *   - the summary shape: avg_rating|null, total_ratings, distribution
 *     (all 5 keys present even when zero), last_5_notes
 */
// @ts-nocheck — vitest types optional in this workspace.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { RatingsService } from './ratings';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
  },
}));

describe('RatingsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('getSelf() hits /tutors/me/ratings and returns the summary shape', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: {
          tutor_id: 'tutor-1',
          avg_rating: 4.6,
          total_ratings: 12,
          distribution: { 1: 0, 2: 0, 3: 1, 4: 3, 5: 8 },
          last_5_notes: [
            { rating: 5, notes: 'Sangat sabar', created_at: '2026-08-01T10:00:00Z' },
          ],
        },
      },
    });

    const s = await RatingsService.getSelf();

    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/tutors/me/ratings');
    expect(s.tutor_id).toBe('tutor-1');
    expect(s.avg_rating).toBe(4.6);
    expect(s.total_ratings).toBe(12);
    expect(s.distribution[5]).toBe(8);
    expect(s.last_5_notes).toHaveLength(1);
  });

  it('getSelf() tolerates a zero-ratings tutor (avg_rating null, all zeros)', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: {
          tutor_id: 'tutor-1',
          avg_rating: null,
          total_ratings: 0,
          distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 },
          last_5_notes: [],
        },
      },
    });
    const s = await RatingsService.getSelf();
    expect(s.avg_rating).toBeNull();
    expect(s.total_ratings).toBe(0);
    expect(s.last_5_notes).toEqual([]);
  });

  it('get(tutorId) hits the admin-facing url', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: {
          tutor_id: 'tutor-9',
          avg_rating: 3.2,
          total_ratings: 5,
          distribution: { 1: 1, 2: 0, 3: 2, 4: 1, 5: 1 },
          last_5_notes: [],
        },
      },
    });
    await RatingsService.get('tutor-9');
    expect(api.get).toHaveBeenCalledWith('/tutoring-v2/tutors/tutor-9/ratings');
  });
});
