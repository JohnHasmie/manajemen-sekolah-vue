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
import type { Submission, SubmissionGradePayload } from '@/types/tutoring2/activity';

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

export const SubmissionsService = {
  async listByActivity(activityId: string, params: SubmissionListParams = {}) {
    const r = await api.get<ListEnvelope<Submission>>(
      `/tutoring-v2/activities/${activityId}/submissions`,
      { params },
    );
    return { items: r.data.data, pagination: r.data.meta };
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
