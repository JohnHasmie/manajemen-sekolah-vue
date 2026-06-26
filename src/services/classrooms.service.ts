/**
 * ClassroomService — `/api/class` wrapper.
 * Mirrors `lib/features/classrooms/data/classroom_service.dart`.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import { classroomFromJson, type Classroom } from '@/types/entities';

export interface ClassroomListParams {
  page?: number;
  per_page?: number;
  search?: string;
  grade_level?: string | null;
  has_homeroom?: 'yes' | 'no' | null;
}

/**
 * Grade-level (tingkat) options constrained to a school's jenjang.
 *
 * Mirrors Flutter's `ClassroomFilterHelper.generateGradeLevels`
 * (`lib/features/classrooms/.../classroom_filter_helper.dart`):
 *   ELEMENTARY        → 1-6   (SD)
 *   JUNIOR_HIGH       → 7-9   (SMP)
 *   SENIOR_HIGH /
 *   VOCATIONAL_HIGH   → 10-12 (SMA / SMK)
 * Anything else (null/unknown, e.g. MA/MTs/Pesantren) falls back to
 * the full 1-12 range so we never hide a valid option.
 *
 * Accepts BOTH the canonical English wire values (post 2026-06-26
 * cutover) and the legacy Indonesian abbreviations during the
 * transition window — backend may emit either until backfill lands.
 */
export function generateGradeLevels(jenjang?: string | null): string[] {
  let start = 1;
  let end = 12;
  if (jenjang) {
    const j = jenjang.trim().toUpperCase();
    if (j === 'SD' || j === 'ELEMENTARY') {
      start = 1;
      end = 6;
    } else if (j === 'SMP' || j === 'JUNIOR_HIGH') {
      start = 7;
      end = 9;
    } else if (
      j === 'SMA' || j === 'SMK' ||
      j === 'SENIOR_HIGH' || j === 'VOCATIONAL_HIGH'
    ) {
      start = 10;
      end = 12;
    }
  }
  return Array.from({ length: end - start + 1 }, (_, i) => String(start + i));
}

interface ListResult {
  items: Classroom[];
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

export const ClassroomService = {
  async list(params: ClassroomListParams = {}): Promise<ListResult> {
    const res = await api.get('/class', {
      params: {
        page: params.page ?? 1,
        per_page: params.per_page ?? 10,
        ...(params.search ? { search: params.search } : {}),
        ...(params.grade_level ? { grade_level: params.grade_level } : {}),
        ...(params.has_homeroom ? { has_homeroom: params.has_homeroom } : {}),
      },
    });
    const { data, pagination } = unwrap(res.data);
    return {
      items: data.map((r) => classroomFromJson(r as Record<string, unknown>)),
      pagination,
    };
  },

  async create(payload: Record<string, unknown>): Promise<Classroom> {
    const res = await api.post('/class', payload);
    const body = res.data as Record<string, unknown>;
    return classroomFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async update(id: string, payload: Record<string, unknown>): Promise<Classroom> {
    const res = await api.put(`/class/${id}`, payload);
    const body = res.data as Record<string, unknown>;
    return classroomFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/class/${id}`);
  },

  /**
   * GET /class/{id} — fresh full class row with eager-loaded homeroom
   * teacher. Used by the edit sheet's _getFreshClassData parity.
   */
  async get(id: string): Promise<Classroom | null> {
    try {
      const res = await api.get(`/class/${id}`);
      const body = res.data?.data ?? res.data ?? null;
      if (!body) return null;
      return classroomFromJson(body as Record<string, unknown>);
    } catch {
      return null;
    }
  },

  /** Sequential per-id bulk delete (no /class/bulk-delete endpoint). */
  async bulkRemove(ids: string[]): Promise<{ deleted: number; failed: number }> {
    let deleted = 0;
    let failed = 0;
    for (const id of ids) {
      try {
        await api.delete(`/class/${id}`);
        deleted++;
      } catch {
        failed++;
      }
    }
    return { deleted, failed };
  },

  /**
   * GET /class/{id}/homeroom-candidates — list teacher candidates for the
   * homeroom dropdown when editing a class. Mirrors Flutter's
   * `_ensureHomeroomTeacherInList` pre-fetch.
   */
  async waliCandidates(id: string): Promise<Array<{ id: string; name: string }>> {
    try {
      const res = await api.get(`/class/${id}/homeroom-candidates`);
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map((t: any) => ({
        id: String(t.id),
        name: String(t.name ?? t.nama ?? ''),
      }));
    } catch {
      return [];
    }
  },
};

/**
 * ClassPromotionService — POST /promotion/promote 4-step wizard
 * backend.
 *
 * Promotes selected students from a source class to a target class
 * in the next academic year. The backend creates new
 * student_classes pivot rows for the target class + AY, leaving the
 * source rows intact.
 */
export const ClassPromotionService = {
  async promote(payload: {
    source_class_id: string;
    target_class_id: string;
    student_ids: string[];
    target_academic_year_id: string | number;
  }): Promise<{ promoted: number; failed: number; message?: string }> {
    try {
      const res = await api.post('/promotion/promote', payload);
      const body = res.data ?? {};
      return {
        promoted: Number(body.promoted ?? body.created ?? body.success ?? 0),
        failed: Number(body.failed ?? body.skipped ?? 0),
        message: body.message ?? undefined,
      };
    } catch (e) {
      const ax = e as any;
      const msg = ax?.response?.data?.message ?? (e as Error).message;
      throw new Error(msg);
    }
  },
};
