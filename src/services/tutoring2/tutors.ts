/**
 * TutoringTutorsService — wraps the four `/api/tutoring-v2/tutors*`
 * endpoints delivered by BE-17 (TutorController).
 *
 * Kept in `services/tutoring2/` (not on `TutoringBimbelService`) so the
 * tutor CRUD stays self-contained and its `.spec.ts` doesn't have to
 * mock the ~30-method surface of the bigger service.
 *
 * Envelopes:
 *   GET  /tutors            → { data: Tutor[], meta: { current_page, … } }
 *   GET  /tutors/{id}       → { data: Tutor }
 *   POST /tutors/invite     → 201 { data: Tutor }
 *   POST /tutors/{id}/…     → { data: Tutor }   OR   409 { message, active_group_count }
 *
 * The 409 branch is preserved as an `AxiosError` — callers should
 * `catch (e) { if (isAxiosError(e) && e.response?.status === 409) …}`
 * and read `e.response.data` as {@link DeactivateTutorConflict} to
 * render the friendly "tutor masih memiliki X kelompok aktif" toast.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type { InviteTutorPayload, Tutor } from '@/types/tutoring2/tutor';

export interface TutorListParams {
  page?: number;
  per_page?: number;
  search?: string;
  /** `true` = only aktif, `false` = only nonaktif, omit = both. */
  active?: boolean;
}

export interface TutorListResult {
  items: Tutor[];
  pagination?: Pagination;
}

interface RawListEnvelope {
  data?: Tutor[];
  meta?: {
    current_page?: number;
    last_page?: number;
    per_page?: number;
    total?: number;
  };
}

interface RawOneEnvelope {
  data: Tutor;
}

export const TutoringTutorsService = {
  async list(params: TutorListParams = {}): Promise<TutorListResult> {
    const res = await api.get<RawListEnvelope>('/tutoring-v2/tutors', {
      params: {
        page: params.page ?? 1,
        per_page: params.per_page ?? 20,
        ...(params.search ? { search: params.search } : {}),
        // Only forward `active` when the caller opted in — the BE reads
        // "no `active` param" as "return both" (tab strip "Semua").
        ...(params.active !== undefined ? { active: params.active } : {}),
      },
    });
    const body = res.data ?? {};
    const items = body.data ?? [];
    const meta = body.meta ?? {};
    const pagination: Pagination | undefined =
      meta.current_page != null
        ? {
            total_items: meta.total ?? items.length,
            total_pages: meta.last_page ?? 1,
            current_page: meta.current_page,
            per_page: meta.per_page ?? params.per_page ?? 20,
            has_next_page: meta.current_page < (meta.last_page ?? 1),
            has_prev_page: meta.current_page > 1,
          }
        : undefined;
    return { items, pagination };
  },

  async get(id: string): Promise<Tutor> {
    const res = await api.get<RawOneEnvelope>(`/tutoring-v2/tutors/${id}`);
    return res.data.data;
  },

  /**
   * Two branches at one entry point:
   *   - email is NEW  → BE creates User + Teacher, returns 201 + Tutor
   *   - email exists  → BE attaches to tenant, still returns 201 + Tutor
   * The FE can't tell the branches apart from the response alone (BE-17
   * does not surface the branch flag); the modal shows a generic
   * success toast either way. A follow-up BE MR is expected to add
   * `attached_existing_user` — the shape is already forward-compatible
   * because we return the whole response body.
   */
  async invite(payload: InviteTutorPayload): Promise<Tutor> {
    const res = await api.post<RawOneEnvelope>(
      '/tutoring-v2/tutors/invite',
      {
        email: payload.email,
        // Trim + drop empty strings so BE's `nullable` rule triggers
        // and the "default to email local part" branch fires.
        ...(payload.name && payload.name.trim() !== '' ? { name: payload.name.trim() } : {}),
        // `phone` and `initial_rate` are intentionally forwarded even
        // though BE-17 ignores them today — a future BE MR can start
        // reading them without a FE change. Laravel's FormRequest
        // silently drops unknown keys, so this is safe.
        ...(payload.phone && payload.phone.trim() !== '' ? { phone: payload.phone.trim() } : {}),
        ...(payload.initial_rate != null ? { initial_rate: payload.initial_rate } : {}),
      },
    );
    return res.data.data;
  },

  /**
   * Flips `users_schools.is_active=false` + turns off the TEACHER role
   * row. Rejects with a 409 AxiosError whose `response.data` is a
   * {@link DeactivateTutorConflict} when the tutor still owns ACTIVE
   * learning groups. Callers MUST surface the BE message — it names
   * the block count in Indonesian and the UX depends on it.
   */
  async deactivate(id: string): Promise<Tutor> {
    const res = await api.post<RawOneEnvelope>(
      `/tutoring-v2/tutors/${id}/deactivate`,
      {},
    );
    return res.data.data;
  },
};
