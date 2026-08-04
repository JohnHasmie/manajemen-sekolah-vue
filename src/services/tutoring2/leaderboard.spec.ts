/**
 * Vitest spec for TutoringLeaderboardService (BE-21).
 *
 * Pins the wire contract of the two leaderboard endpoints:
 *   - envelope is `{ items, generated_at }` — NOT `{ data, meta }`
 *   - `assessment_id` + `limit` only forwarded when set
 *   - `getGroup` hits /learning-groups/{id}/leaderboard
 *   - `getProgram` hits /programs/{id}/leaderboard
 *   - dense-rank + normalised avg fields survive the round-trip
 *
 * Follows the same Vitest-not-wired-yet pattern as the other web-vue
 * `.spec.ts` files; type-checks under `vue-tsc --build` which is the
 * active gate today.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { TutoringLeaderboardService } from './leaderboard';
import { api } from '@/lib/http';
import type {
  LeaderboardResponse,
  LeaderboardRow,
} from '@/types/tutoring2/leaderboard';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
  },
}));

const sampleRow: LeaderboardRow = {
  enrollment_id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
  student_id: '019f8090-4d6a-71ab-bf01-c98a6ac73294',
  student_name: 'Anaya Putri',
  student_number: 'BM-2026-001',
  avg_score: 92.5,
  assessments_taken: 4,
  rank: 1,
};

const sampleResponse: LeaderboardResponse = {
  items: [sampleRow],
  generated_at: '2026-07-22T10:00:00+07:00',
};

describe('TutoringLeaderboardService.getGroup', () => {
  beforeEach(() => vi.clearAllMocks());

  it('hits /tutoring-v2/learning-groups/{id}/leaderboard and returns the raw envelope', async () => {
    (api.get as any).mockResolvedValueOnce({ data: sampleResponse });

    const res = await TutoringLeaderboardService.getGroup('grp-1');

    expect((api.get as any).mock.calls[0][0]).toBe(
      '/tutoring-v2/learning-groups/grp-1/leaderboard',
    );
    expect(res.items).toHaveLength(1);
    expect(res.items[0].rank).toBe(1);
    expect(res.items[0].avg_score).toBeCloseTo(92.5);
    expect(res.generated_at).toBe('2026-07-22T10:00:00+07:00');
  });

  it('forwards assessment_id and limit only when set', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: { items: [], generated_at: '2026-07-22T10:00:00+07:00' },
    });
    await TutoringLeaderboardService.getGroup('grp-1', {
      assessment_id: 'a1',
      limit: 20,
    });
    expect((api.get as any).mock.calls[0][1].params).toEqual({
      assessment_id: 'a1',
      limit: 20,
    });

    (api.get as any).mockResolvedValueOnce({
      data: { items: [], generated_at: 'x' },
    });
    await TutoringLeaderboardService.getGroup('grp-1');
    expect((api.get as any).mock.calls[1][1].params).toEqual({});
  });

  it('drops non-positive limits (server default kicks in)', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: { items: [], generated_at: 'x' },
    });
    await TutoringLeaderboardService.getGroup('grp-1', { limit: 0 });
    expect((api.get as any).mock.calls[0][1].params).toEqual({});
  });
});

describe('TutoringLeaderboardService.getProgram', () => {
  beforeEach(() => vi.clearAllMocks());

  it('hits /tutoring-v2/programs/{id}/leaderboard', async () => {
    (api.get as any).mockResolvedValueOnce({ data: sampleResponse });

    const res = await TutoringLeaderboardService.getProgram('prog-1', {
      assessment_id: 'a1',
    });

    expect((api.get as any).mock.calls[0][0]).toBe(
      '/tutoring-v2/programs/prog-1/leaderboard',
    );
    expect((api.get as any).mock.calls[0][1].params).toEqual({
      assessment_id: 'a1',
    });
    expect(res.items[0].student_name).toBe('Anaya Putri');
    expect(res.items[0].assessments_taken).toBe(4);
  });
});
