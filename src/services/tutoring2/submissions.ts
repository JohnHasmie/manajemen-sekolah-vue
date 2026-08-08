/**
 * SubmissionsService — list submissions for a greenfield tutoring
 * activity and grade them (WEB-13, mirrors BE-23 SubmissionController).
 *
 *   GET  /activities/{activityId}/submissions   roster
 *                                              admin/tutor sees all,
 *                                              siswa/wali is scoped to
 *                                              their enrollment on the
 *                                              backend.
 *   POST /submissions/{id}/grade                admin/tutor scores.
 *
 * We don't ship a client-side `submit` (that's a siswa/wali action
 * WEB-14+ will own from the siswa app). The tutor UI is grader-only.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  StudentActivityRow,
  StudentSubmissionsSummary,
  Submission,
  SubmissionGradePayload,
} from '@/types/tutoring2/activity';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

export interface SubmissionListParams {
  page?: number;
  per_page?: number;
}

export interface StudentSubmissionListParams extends SubmissionListParams {
  kind?: string;
  /**
   * `pending` is cross-status (not handed in OR not yet graded);
   * `missing` is the narrower "nothing handed in at all".
   */
  status?: 'pending' | 'missing' | 'draft' | 'submitted' | 'graded';
}

export interface StudentSubmissionListResult {
  items: StudentActivityRow[];
  summary: StudentSubmissionsSummary;
  /** Total across the whole filtered set — use it to detect truncation. */
  total: number;
  lastPage: number;
}

interface StudentRowsEnvelope {
  data: StudentActivityRow[];
  meta: {
    summary: StudentSubmissionsSummary;
    total: number;
    last_page: number;
  };
}

export const SubmissionsService = {
  async listByActivity(activityId: string, params: SubmissionListParams = {}) {
    const r = await api.get<ListEnvelope<Submission>>(
      `/tutoring-v2/activities/${activityId}/submissions`,
      { params },
    );
    return { items: r.data.data, pagination: r.data.meta };
  },

  /**
   * `GET /tutoring-v2/students/{id}/submissions` — one child's activity
   * worklist, each row already carrying that child's own submission.
   *
   * Replaced a per-activity fan-out that capped its lookups at the first
   * 30 rows. Past that cap every activity came back with a null
   * submission, which this surface renders as "belum dikumpulkan" — so a
   * child who handed their work in was shown to their parent as
   * delinquent. The cap was a correctness bug, not a performance trade.
   *
   * `meta.summary` counts the WHOLE filtered set rather than the page,
   * so KPI tiles stay correct no matter how much of the list is loaded.
   */
  async listByStudent(studentId: string, params: StudentSubmissionListParams = {}) {
    const r = await api.get<StudentRowsEnvelope>(
      `/tutoring-v2/students/${studentId}/submissions`,
      { params },
    );
    return {
      items: r.data.data,
      summary: r.data.meta.summary,
      total: r.data.meta.total,
      lastPage: r.data.meta.last_page,
    } satisfies StudentSubmissionListResult;
  },

  /**
   * POST /submissions/{id}/grade — the backend GradeSubmissionRequest
   * only whitelists `score` today, so `feedback` is stripped on the
   * server. We still send it so the day BE adds a `feedback` column
   * this is source-compatible.
   */
  async grade(submissionId: string, payload: SubmissionGradePayload): Promise<Submission> {
    const r = await api.post<OneEnvelope<Submission>>(
      `/tutoring-v2/submissions/${submissionId}/grade`,
      { score: payload.score, feedback: payload.feedback ?? null },
    );
    return r.data.data;
  },
};
