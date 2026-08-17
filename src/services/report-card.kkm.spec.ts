/**
 * Vitest spec — the report card must never invent a KKM.
 *
 * `kkm` is optional on the wire: a school may simply not have set a passing
 * threshold for a subject. The parser used to fall back to a hardcoded 75,
 * which made `detailFromJson` report subjects as remedial purely because they
 * scored under a default nobody configured — and the views then printed
 * "/ KKM 75" as though the school had set it.
 *
 * These lock both halves: `kkm` stays undefined when absent, and an unscored
 * or unthresholded subject is not counted as remedial.
 */
// @ts-nocheck — vitest types optional in this workspace
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ReportCardService } from './report-card.service';
import { api } from '@/lib/http';

vi.mock('@/lib/http', () => ({
  api: { get: vi.fn(), post: vi.fn(), delete: vi.fn() },
}));

const ARGS = {
  student_class_id: 'sc-1',
  academic_year_id: 'ay-1',
  semester_id: 'sem-1', // supplied so the parser never calls /semesters
};

function showResponse(subjects: unknown[]) {
  return { data: { data: { student_class_id: 'sc-1', subjects } } };
}

describe('report card KKM is never fabricated', () => {
  beforeEach(() => vi.clearAllMocks());

  it('leaves kkm undefined when the backend does not send one', async () => {
    (api.get as any).mockResolvedValueOnce(
      showResponse([
        { subject_id: 's1', subject_name: 'Matematika', knowledge_score: 62 },
      ]),
    );

    const detail = await ReportCardService.getDetail(ARGS);

    expect(detail?.subjects[0].kkm).toBeUndefined();
  });

  it('does not count a subject without a KKM as remedial', async () => {
    // 62 is below the old hardcoded 75 — pre-fix this returned remed_count 1.
    (api.get as any).mockResolvedValueOnce(
      showResponse([
        { subject_id: 's1', subject_name: 'Matematika', knowledge_score: 62 },
      ]),
    );

    const detail = await ReportCardService.getDetail(ARGS);

    expect(detail?.remed_count).toBe(0);
  });

  it('still counts a subject as remedial against a KKM the school DID set', async () => {
    (api.get as any).mockResolvedValueOnce(
      showResponse([
        { subject_id: 's1', subject_name: 'Matematika', knowledge_score: 62, kkm: 70 },
        { subject_id: 's2', subject_name: 'IPA', knowledge_score: 80, kkm: 70 },
      ]),
    );

    const detail = await ReportCardService.getDetail(ARGS);

    expect(detail?.subjects[0].kkm).toBe(70);
    expect(detail?.remed_count).toBe(1);
  });

  it('prefers a backend-supplied remed_count over the derived one', async () => {
    (api.get as any).mockResolvedValueOnce({
      data: {
        data: {
          student_class_id: 'sc-1',
          remed_count: 3,
          subjects: [
            { subject_id: 's1', subject_name: 'Matematika', knowledge_score: 62 },
          ],
        },
      },
    });

    const detail = await ReportCardService.getDetail(ARGS);

    expect(detail?.remed_count).toBe(3);
  });
});
