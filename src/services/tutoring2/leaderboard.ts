/**
 * TutoringLeaderboardService — thin wrapper over BE-21.
 *
 *   GET /api/tutoring-v2/learning-groups/{groupId}/leaderboard
 *   GET /api/tutoring-v2/programs/{programId}/leaderboard
 *
 * Response envelope is `{ items, generated_at }` — NOT the usual
 * `{ data, meta }` list envelope, so we don't reuse the shared
 * `ListEnvelope<T>` helper here.
 *
 * Requires `tutoring.leaderboard.view`; the ability is granted to
 * admin, tutor, student, and wali bimbel defaults (see
 * `PermissionCatalog::defaultsForRole`).
 */
import { api } from '@/lib/http';
import type {
  LeaderboardQuery,
  LeaderboardResponse,
} from '@/types/tutoring2/leaderboard';

function toParams(q: LeaderboardQuery = {}): Record<string, string | number> {
  const out: Record<string, string | number> = {};
  if (q.assessment_id) out.assessment_id = q.assessment_id;
  if (typeof q.limit === 'number' && q.limit > 0) out.limit = q.limit;
  return out;
}

export const TutoringLeaderboardService = {
  /**
   * Per learning-group ranking. 404 on unknown / cross-tenant groupId.
   */
  async getGroup(
    groupId: string,
    query: LeaderboardQuery = {},
  ): Promise<LeaderboardResponse> {
    const r = await api.get<LeaderboardResponse>(
      `/tutoring-v2/learning-groups/${groupId}/leaderboard`,
      { params: toParams(query) },
    );
    return r.data;
  },

  /**
   * Per program roll-up ranking. 404 on unknown / cross-tenant
   * programId. `assessment_id` in the query narrows it to a single
   * assessment; without it the endpoint averages every published,
   * graded assessment on the program.
   */
  async getProgram(
    programId: string,
    query: LeaderboardQuery = {},
  ): Promise<LeaderboardResponse> {
    const r = await api.get<LeaderboardResponse>(
      `/tutoring-v2/programs/${programId}/leaderboard`,
      { params: toParams(query) },
    );
    return r.data;
  },
};
