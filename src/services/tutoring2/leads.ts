/**
 * TutoringLeadsService — greenfield bimbel lead/funnel client
 * (`/api/tutoring-v2/leads/*`, delivered by BE-15).
 *
 * Coexists with the sibling `TutoringBimbelService` (programs,
 * enrollments, sessions, bills). Kept in its own file under
 * `services/tutoring2/` per the greenfield WEB-8 convention so each
 * new backend surface gets its own focused wrapper + spec pair.
 *
 * The Laravel controller returns Anonymous resource collections
 * (`LeadResource::collection(...)`), which serialize to
 * `{ data: T[], meta: {...} }`. Single-resource endpoints return
 * `{ data: T }`. Every list method returns `{ items, pagination }` so
 * views don't re-implement the envelope unwrap.
 *
 * Ability gating (server-side authoritative — see LeadController):
 *   - reads (index/show)                          → tutoring.lead.view
 *   - writes (store/update/convert/drop/destroy)  → tutoring.lead.manage
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type {
  BimbelLead,
  ConvertLeadPayload,
  CreateLeadPayload,
  DropLeadPayload,
  LeadListParams,
  UpdateLeadPayload,
} from '@/types/tutoring2/lead';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

/**
 * Strip empty-string filter values so the backend index query doesn't
 * receive `?status=&source=` (which Laravel `filled()` guards would
 * ignore anyway, but we keep the wire clean and easy to grep in dev
 * tools).
 */
function pruneParams<T extends Record<string, unknown>>(input: T): Partial<T> {
  const out: Partial<T> = {};
  for (const [k, v] of Object.entries(input)) {
    if (v === undefined || v === null || v === '') continue;
    (out as Record<string, unknown>)[k] = v;
  }
  return out;
}

export const TutoringLeadsService = {
  /** GET /tutoring-v2/leads — paginated list, filters, client-side search. */
  async list(params: LeadListParams = {}): Promise<{
    items: BimbelLead[];
    pagination: Pagination | undefined;
  }> {
    // `search` is a client-side concern — the BE index endpoint only
    // filters on status / source / assigned_to_user_id. Strip it before
    // shipping so the request URL doesn't advertise an ignored param.
    const { search: _search, ...rest } = params;
    void _search;
    const r = await api.get<ListEnvelope<BimbelLead>>('/tutoring-v2/leads', {
      params: pruneParams(rest),
    });
    return { items: r.data.data, pagination: r.data.meta };
  },

  /** GET /tutoring-v2/leads/{id}. */
  async get(id: string): Promise<BimbelLead> {
    const r = await api.get<OneEnvelope<BimbelLead>>(
      `/tutoring-v2/leads/${id}`,
    );
    return r.data.data;
  },

  /** POST /tutoring-v2/leads — returns the fresh lead (201). */
  async create(payload: CreateLeadPayload): Promise<BimbelLead> {
    const r = await api.post<OneEnvelope<BimbelLead>>(
      '/tutoring-v2/leads',
      payload,
    );
    return r.data.data;
  },

  /** PUT /tutoring-v2/leads/{id}. */
  async update(id: string, payload: UpdateLeadPayload): Promise<BimbelLead> {
    const r = await api.put<OneEnvelope<BimbelLead>>(
      `/tutoring-v2/leads/${id}`,
      payload,
    );
    return r.data.data;
  },

  /**
   * POST /tutoring-v2/leads/{id}/convert — delegates to
   * CreateEnrollmentAction server-side and stamps the lead as
   * converted. The returned lead has `converted_enrollment_id`
   * populated + the `converted_enrollment` snapshot eager-loaded.
   */
  async convert(id: string, payload: ConvertLeadPayload): Promise<BimbelLead> {
    const r = await api.post<OneEnvelope<BimbelLead>>(
      `/tutoring-v2/leads/${id}/convert`,
      payload,
    );
    return r.data.data;
  },

  /**
   * POST /tutoring-v2/leads/{id}/drop — marks the lead as dropped
   * (terminal) and appends an optional reason to the notes field
   * server-side.
   */
  async drop(id: string, payload: DropLeadPayload = {}): Promise<BimbelLead> {
    const r = await api.post<OneEnvelope<BimbelLead>>(
      `/tutoring-v2/leads/${id}/drop`,
      payload,
    );
    return r.data.data;
  },

  /** DELETE /tutoring-v2/leads/{id} — hard-delete (SoftDeletes on BE). */
  async destroy(id: string): Promise<void> {
    await api.delete(`/tutoring-v2/leads/${id}`);
  },
};

export type TutoringLeadsServiceType = typeof TutoringLeadsService;
