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
  gender?: 'L' | 'P' | null;
  employment_status?: string | null;
  show_all?: boolean;
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
        page: params.page ?? 1,
        per_page: params.per_page ?? 10,
        ...(params.search ? { search: params.search } : {}),
        ...(params.role ? { role: params.role } : {}),
        ...(params.subject_id ? { subject_id: params.subject_id } : {}),
        ...(params.homeroom ? { homeroom: params.homeroom } : {}),
        ...(params.class_id ? { class_id: params.class_id } : {}),
        ...(params.gender ? { gender: params.gender } : {}),
        ...(params.employment_status
          ? { employment_status: params.employment_status }
          : {}),
        ...(params.show_all ? { show_all: 1 } : {}),
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
          { key: 'L', label: 'Laki-laki' },
          { key: 'P', label: 'Perempuan' },
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
          { key: 'L', label: 'Laki-laki' },
          { key: 'P', label: 'Perempuan' },
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
   * plus the eager-loaded `homeroom_classes` list so callers
   * (auth store) can cache it and drive the wali-kelas role chips.
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
      const homeroomClasses = rawHC
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
      return { id: String(id), homeroomClasses };
    } catch {
      return null;
    }
  },
};
