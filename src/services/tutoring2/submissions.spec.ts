/**
 * Vitest contract spec for SubmissionsService (WEB-13).
 *
 * Pins:
 *   - the list endpoint keys off `activity_id` (not enrollment_id)
 *   - grade() sends `score` on the wire; `feedback` is accepted at the
 *     client boundary today for source-compat with the eventual BE
 *     column
 *   - a graded response promotes `status` to 'graded' + populates
 *     `graded_at`
 */
// @ts-nocheck — vitest types optional in this workspace.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { SubmissionsService } from './submissions';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: {
    get: vi.fn(),
    post: vi.fn(),
  },
}));

describe('SubmissionsService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('listByActivity() unwraps items keyed by enrollment_id', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'sub-1',
            activity_id: 'act-1',
            enrollment_id: 'enr-1',
            student_id: 'std-1',
            student_name: 'Aisyah',
            status: 'submitted',
            score: null,
          },
        ],
        meta: { current_page: 1, per_page: 50, total: 1, last_page: 1 },
      },
    });

    const res = await SubmissionsService.listByActivity('act-1');

    expect(api.get).toHaveBeenCalledWith(
      '/tutoring-v2/activities/act-1/submissions',
      { params: {} },
    );
    expect(res.items[0].enrollment_id).toBe('enr-1');
    expect(res.items[0].student_name).toBe('Aisyah');
  });

  it('grade() POSTs score + feedback and returns a graded submission', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: {
        data: {
          id: 'sub-1',
          activity_id: 'act-1',
          enrollment_id: 'enr-1',
          status: 'graded',
          score: 85,
          graded_at: '2026-08-04T02:30:00Z',
        },
      },
    });

    const graded = await SubmissionsService.grade('sub-1', {
      score: 85,
      feedback: 'Good work',
    });

    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/submissions/sub-1/grade', {
      score: 85,
      feedback: 'Good work',
    });
    expect(graded.status).toBe('graded');
    expect(graded.score).toBe(85);
    expect(graded.graded_at).toBe('2026-08-04T02:30:00Z');
  });

  it('grade() accepts a null score (ungrade / reset)', async () => {
    (api.post as any).mockResolvedValueOnce({
      data: { data: { id: 'sub-1', status: 'graded', score: null } },
    });
    await SubmissionsService.grade('sub-1', { score: null });
    expect(api.post).toHaveBeenCalledWith('/tutoring-v2/submissions/sub-1/grade', {
      score: null,
      feedback: null,
    });
  });
});
