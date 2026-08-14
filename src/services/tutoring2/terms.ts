/**
 * TutoringTermsService — greenfield bimbel terms / batches client
 * (`/api/tutoring-v2/terms`).
 *
 * Own file under `services/tutoring2/` per the WEB-8 convention, same
 * as the leads and leaderboard wrappers.
 *
 * Read-only, deliberately: the backend serves `index` only, because
 * the admin screen has no create or edit affordance. `tutoring.term.
 * manage` exists and is granted to admin, but nothing calls it — when
 * a term editor lands, the write methods land with it.
 *
 * Ability gating (server-side authoritative — see TermController):
 *   - index → tutoring.term.view
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type { BimbelTerm, TermListParams } from '@/types/tutoring2/term';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

/** Drop empty-string filters so the wire stays clean and greppable. */
function toParams(q: TermListParams): Record<string, string | number> {
  const out: Record<string, string | number> = {};
  if (q.page) out.page = q.page;
  if (q.per_page) out.per_page = q.per_page;
  if (q.status) out.status = q.status;
  if (q.search) out.search = q.search;
  return out;
}

export const TutoringTermsService = {
  async list(query: TermListParams = {}) {
    const r = await api.get<ListEnvelope<BimbelTerm>>('/tutoring-v2/terms', {
      params: toParams(query),
    });
    return { items: r.data.data, pagination: r.data.meta };
  },
};
