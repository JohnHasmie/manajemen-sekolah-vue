/**
 * Vitest spec — the parent Nilai screens must never invent a KKM.
 *
 * `kkm` used to be typed `number` (required) on ParentGradeRow and
 * ParentGradeEntry, which forced the service to supply *something* for a
 * subject whose school had never set a passing threshold — and what it supplied
 * was a hardcoded 75. SubjectGradeDetailModal then told a guardian
 *
 *   "KKM 75"                                    in the header and every row,
 *   "Di atas KKM 3 / Di bawah KKM 2"            as counters,
 *   "Tuntas — di atas KKM 75."                  as a verdict, or
 *   "Remedial — rata-rata 13.0 poin di bawah KKM."
 *
 * all measured against a number nobody configured. The types are now
 * `number | null` and these lock the service half: absent stays absent, both on
 * the bucketed passthrough and on the pivot-by-subject branch.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ParentService } from './parent.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: { get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));

describe('parent Nilai — KKM is never fabricated', () => {
  beforeEach(() => vi.clearAllMocks());

  it('grades() keeps kkm null on the bucketed passthrough branch', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            subject_id: 's1',
            subject_name: 'Matematika',
            scores: [{ assessment: 'UH 1', score: 62 }],
          },
        ],
      },
    });

    const rows = await ParentService.grades('stu-1', 'ganjil');

    expect(rows[0].kkm).toBeNull();
  });

  it('grades() keeps kkm null when pivoting a flat list by subject', async () => {
    // No `scores` key on the first entry → takes the pivot branch.
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            subject_id: 's1',
            subject_name: 'Matematika',
            assessment: 'UH 1',
            score: 62,
          },
        ],
      },
    });

    const rows = await ParentService.grades('stu-1', 'ganjil');

    expect(rows[0].kkm).toBeNull();
  });

  it('grades() still passes through a KKM the school DID set', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            subject_id: 's1',
            subject_name: 'Matematika',
            kkm: 70,
            scores: [{ assessment: 'UH 1', score: 62 }],
          },
        ],
      },
    });

    const rows = await ParentService.grades('stu-1', 'ganjil');

    expect(rows[0].kkm).toBe(70);
  });

  it('gradesFlat() keeps kkm null when neither entry nor subject carries one', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'g1',
            subject_id: 's1',
            subject_name: 'Matematika',
            type: 'UH',
            title: 'UH BAB 3',
            date: '2026-08-01',
            score: 62,
          },
        ],
      },
    });

    const entries = await ParentService.gradesFlat('stu-1', 'ganjil');

    expect(entries[0].kkm).toBeNull();
  });

  it('gradesFlat() falls back to the master subject KKM before giving up', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'g1',
            subject_id: 's1',
            subject: { id: 's1', name: 'Matematika', kkm: 68 },
            type: 'UH',
            title: 'UH BAB 3',
            date: '2026-08-01',
            score: 62,
          },
        ],
      },
    });

    const entries = await ParentService.gradesFlat('stu-1', 'ganjil');

    expect(entries[0].kkm).toBe(68);
  });
});
