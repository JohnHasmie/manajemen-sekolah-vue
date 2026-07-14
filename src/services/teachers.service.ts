/**
 * TeacherService — `/api/teacher` wrapper.
 * Mirrors `lib/features/teachers/data/teacher_service.dart`.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import { teacherFromJson, type Teacher } from '@/types/entities';

export interface TeacherListParams {
  page?: number;
  per_page?: number;
  search?: string;
  role?: 'guru' | 'wali_kelas' | null;
  subject_id?: string | null;
  homeroom?: 'yes' | 'no' | null;
  class_id?: string | null;
  gender?: 'male' | 'female' | null;
  employment_status?: string | null;
  activity_status?: 'active' | 'inactive' | null;
  show_all?: boolean;
  academic_year_id?: string | null;
}

export interface TeacherFilterOptions {
  roles: { key: string; label: string }[];
  genders: { key: string; label: string }[];
  employment_statuses: { key: string; label: string }[];
  classes: { id: string; name: string }[];
  subjects: { id: string; name: string }[];
}

interface ListResult {
  items: Teacher[];
  pagination?: Pagination;
}

function unwrap(body: unknown) {
  if (body && typeof body === 'object') {
    const b = body as Record<string, unknown>;
    const data = Array.isArray(b.data) ? b.data : [];
    const pagination = b.pagination as Pagination | undefined;
    return { data, pagination };
  }
  return { data: [] as unknown[] };
}

export const TeacherService = {
  async list(params: TeacherListParams = {}): Promise<ListResult> {
    const res = await api.get('/teacher', {
      params: {
        // Cache-buster: the admin teacher list is re-fetched right after
        // add/edit, but the browser was serving the previous (cached) GET
        // because of pagination cache middleware.
        _: new Date().getTime(),
        page: params.page ?? 1,
        per_page: params.per_page ?? 10,
        ...(params.search ? { search: params.search } : {}),
        ...(params.role ? { role: params.role } : {}),
        ...(params.subject_id ? { subject_id: params.subject_id } : {}),
        ...(params.homeroom ? { homeroom: params.homeroom } : {}),
        ...(params.class_id ? { homeroom_class_id: params.class_id } : {}),
        ...(params.gender ? { gender: params.gender } : {}),
        ...(params.employment_status
          ? { employment_status: params.employment_status }
          : {}),
        ...(params.activity_status ? { activity_status: params.activity_status } : {}),
        ...(params.show_all ? { show_all: 1 } : {}),
        ...(params.academic_year_id ? { academic_year_id: params.academic_year_id } : {}),
      },
    });
    const { data, pagination } = unwrap(res.data);
    return {
      items: data.map((r) => teacherFromJson(r as Record<string, unknown>)),
      pagination,
    };
  },

  async create(payload: Record<string, unknown>): Promise<Teacher> {
    const res = await api.post('/teacher', payload);
    const body = res.data as Record<string, unknown>;
    return teacherFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async update(id: string, payload: Record<string, unknown>): Promise<Teacher> {
    const res = await api.put(`/teacher/${id}`, payload);
    const body = res.data as Record<string, unknown>;
    return teacherFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/teacher/${id}`);
  },

  /**
   * Admin reset of a teacher's login password.
   * `POST /teachers/{id}/reset-password`. Pass a `password` to set a
   * specific one, or omit it to let the server generate a random one.
   * Returns the resulting password so the caller can show it once.
   */
  async resetPassword(
    id: string,
    password?: string,
  ): Promise<{ password: string; was_generated: boolean }> {
    const res = await api.post(
      `/teachers/${id}/reset-password`,
      password ? { password } : {},
    );
    const body = res.data as Record<string, unknown>;
    return {
      password: String(body.password ?? ''),
      was_generated: Boolean(body.was_generated),
    };
  },

  /**
   * Apply the same partial update to N teachers. Loops per-id via PUT
   * because the backend has no dedicated bulk-update endpoint — mirrors
   * the bulkRemove shape. Payload is a shallow subset of the update
   * shape; typical bulk-safe field is `employment_status`.
   */
  async bulkUpdate(
    ids: string[],
    payload: Record<string, unknown>,
  ): Promise<{ updated: number; failed: number }> {
    let updated = 0;
    let failed = 0;
    for (const id of ids) {
      try {
        await api.put(`/teacher/${id}`, payload);
        updated++;
      } catch {
        failed++;
      }
    }
    return { updated, failed };
  },

  /**
   * Sequential per-id bulk delete. Backend does not expose a bulk
   * endpoint for teachers — Flutter loops the same way.
   */
  async bulkRemove(ids: string[]): Promise<{ deleted: number; failed: number }> {
    let deleted = 0;
    let failed = 0;
    for (const id of ids) {
      try {
        await api.delete(`/teacher/${id}`);
        deleted++;
      } catch {
        failed++;
      }
    }
    return { deleted, failed };
  },

  /**
   * GET /teacher/{id} — full teacher row with homeroom_classes,
   * subjects, employment_status. Used by the detail sheet.
   */
  async get(id: string): Promise<Teacher | null> {
    try {
      const res = await api.get(`/teacher/${id}`);
      const body = res.data?.data ?? res.data ?? null;
      if (!body) return null;
      return teacherFromJson(body as Record<string, unknown>);
    } catch {
      return null;
    }
  },

  /** GET /teacher/filter-options — populates dropdown labels. */
  async getFilterOptions(): Promise<TeacherFilterOptions> {
    try {
      const res = await api.get('/teacher/filter-options');
      const body = res.data?.data ?? res.data ?? {};
      return {
        roles: Array.isArray(body.roles) ? body.roles : [
          { key: 'guru', label: 'Guru' },
          { key: 'wali_kelas', label: 'Wali Kelas' },
        ],
        genders: Array.isArray(body.genders) ? body.genders : [
          { key: 'male', label: 'Laki-laki' },
          { key: 'female', label: 'Perempuan' },
        ],
        employment_statuses: Array.isArray(body.employment_statuses)
          ? body.employment_statuses
          : [
              { key: 'tetap', label: 'Tetap' },
              { key: 'tidak_tetap', label: 'Tidak Tetap' },
              { key: 'kontrak', label: 'Kontrak' },
              { key: 'honorer', label: 'Honorer' },
            ],
        classes: Array.isArray(body.classes) ? body.classes : [],
        subjects: Array.isArray(body.subjects) ? body.subjects : [],
      };
    } catch {
      return {
        roles: [
          { key: 'guru', label: 'Guru' },
          { key: 'wali_kelas', label: 'Wali Kelas' },
        ],
        genders: [
          { key: 'male', label: 'Laki-laki' },
          { key: 'female', label: 'Perempuan' },
        ],
        employment_statuses: [
          { key: 'tetap', label: 'Tetap' },
          { key: 'tidak_tetap', label: 'Tidak Tetap' },
        ],
        classes: [],
        subjects: [],
      };
    }
  },

  /**
   * Resolve the `teacher_profile.id` from a `user.id`.
   *
   * Multi-tenant tables (teaching-schedule, recommendations,
   * material-progress, etc.) key off `teacher_profile.id`, which is
   * a different UUID from the `user.id` carried in the auth token.
   *
   * The Flutter app calls `GET /teacher/{user_id}` and reads
   * `response.data.id`. We do the same here. Returns null on failure
   * so callers can degrade gracefully.
   */
  async resolveProfileId(userId: string): Promise<string | null> {
    const p = await this.resolveProfile(userId);
    return p?.id ?? null;
  },

  /**
   * Full teacher-profile resolver. Returns the teacher_profile.id
   * plus the parent-kelas class list so callers (auth store) can drive
   * the parent-kelas role chip strip.
   *
   * Two-step lookup, mirroring the Flutter app:
   *
   *   1. GET /teacher/{userId}             → resolves teacher_id and
   *                                          may include eager-loaded
   *                                          `homeroom_classes`.
   *   2. GET /teacher/{userId}/classes     → fallback. Returns ALL of
   *                                          the teacher's classes
   *                                          (homeroom + teaching +
   *                                          grade-authored) with an
   *                                          `is_homeroom` flag per row
   *                                          (set by TeacherRosterService).
   *                                          Filter where `is_homeroom`
   *                                          is true.
   *
   * Why the fallback exists: step (1) reads from the
   * `Teacher::homeroomClasses` Eloquent relation, which has had
   * shifting semantics over the past few backend refactors. Step (2)
   * goes through TeacherRosterService, which fuses the pivot's
   * first-row rule with teaching_schedules and grade-authored signals
   * and is the canonical source for the mobile app. Using both gives
   * us "matches the show endpoint when populated, otherwise matches
   * mobile exactly" — so the chip strip lights up regardless of
   * which relation flavour the deployed backend ships.
   */
  async resolveProfile(userId: string): Promise<{
    id: string;
    homeroomClasses: { id: string; name: string }[];
  } | null> {
    if (!userId) return null;
    try {
      const res = await api.get(`/teacher/${userId}`);
      const body = res.data?.data ?? res.data ?? null;
      if (!body) return null;
      const profile =
        typeof body.teacher === 'object'
          ? body.teacher
          : typeof body.profile === 'object'
            ? body.profile
            : body;
      const id =
        profile?.id ?? profile?.teacher_id ?? profile?.uuid ?? null;
      if (!id) return null;
      const rawHC: any[] = Array.isArray(profile?.homeroom_classes)
        ? profile.homeroom_classes
        : Array.isArray(profile?.homeroom_class)
          ? profile.homeroom_class
          : [];
      let homeroomClasses = rawHC
        .map((h: any) => ({
          id: String(h?.id ?? h?.class_id ?? h?.kelas_id ?? ''),
          name: String(
            h?.name ??
              h?.nama ??
              h?.class_name ??
              h?.kelas_nama ??
              '',
          ),
        }))
        .filter((h) => h.id);

      // Fallback: when /teacher/{id} doesn't ship `homeroom_classes`
      // (or ships an empty list because the relation didn't match
      // anything for this deployment of the backend), reach for the
      // /classes endpoint and filter is_homeroom — the same path the
      // Flutter app uses.
      if (homeroomClasses.length === 0) {
        try {
          const cRes = await api.get(`/teacher/${userId}/classes`);
          const cBody = cRes.data?.data ?? cRes.data ?? null;
          const classesArr: any[] = Array.isArray(cBody)
            ? cBody
            : Array.isArray(cBody?.classes)
              ? cBody.classes
              : Array.isArray(cBody?.kelas)
                ? cBody.kelas
                : [];
          homeroomClasses = classesArr
            .filter((c) => {
              const flag = c?.is_homeroom;
              return (
                flag === true ||
                flag === 1 ||
                String(flag).toLowerCase() === 'true' ||
                String(flag) === '1'
              );
            })
            .map((c) => ({
              id: String(c?.id ?? c?.class_id ?? ''),
              name: String(c?.name ?? c?.nama ?? c?.class_name ?? ''),
            }))
            .filter((c) => c.id);
        } catch {
          // best-effort — leave homeroomClasses as the (empty) first
          // pass; the chip strip just won't render the Parent chip.
        }
      }

      return { id: String(id), homeroomClasses };
    } catch {
      return null;
    }
  },
};
