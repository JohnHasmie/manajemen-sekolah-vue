/**
 * SubjectService — `/api/subject` wrapper + subject-class management.
 * Mirrors `lib/features/subjects/data/subject_service.dart`.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import { subjectFromJson, type Subject } from '@/types/entities';

export interface SubjectListParams {
  page?: number;
  per_page?: number;
  search?: string;
  status?: 'active' | 'inactive' | null;
  grade_level?: string | null;
}

interface ListResult {
  items: Subject[];
  pagination?: Pagination;
}

export interface MasterSubject {
  id: string;
  name: string;
  code?: string | null;
  /**
   * Master `subjects.grade` (varchar). Single grade ("7"), a range
   * ("10-12"), or NULL for grade-agnostic mapel (Olahraga, Seni Budaya,
   * Agama). The edit-sheet parses this to auto-fill the per-school grade
   * dropdown when it's a single value; range + null are left manual.
   */
  grade?: string | null;
  /** Older API alias — some responses used to call this `grade_level`. */
  grade_level?: string | null;
}

export interface SubjectFilterOptions {
  statuses: { key: string; label: string }[];
  grade_levels: string[];
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

export const SubjectService = {
  async list(params: SubjectListParams = {}): Promise<ListResult> {
    const res = await api.get('/subject', {
      params: {
        page: params.page ?? 1,
        per_page: params.per_page ?? 20,
        ...(params.search ? { search: params.search } : {}),
        ...(params.status ? { status: params.status } : {}),
        ...(params.grade_level ? { grade_level: params.grade_level } : {}),
      },
    });
    const { data, pagination } = unwrap(res.data);
    return {
      items: data.map((r) => subjectFromJson(r as Record<string, unknown>)),
      pagination,
    };
  },

  /**
   * Subjects taught by a specific teacher (GET /teacher/{id}/subjects).
   * Used to scope teacher-facing pickers (e.g. Materi, RPP) to only the
   * mapel the teacher actually teaches. The endpoint returns a bare array
   * (no `data`/pagination envelope), so handle both shapes defensively.
   *
   * Pass scope='teaching' to drop the parent-kelas homeroom-class curriculum
   * and return ONLY the subjects the teacher teaches (assigned + scheduled
   * + grade-authored) — the schedule add/edit form needs this so picking a
   * homeroom teacher doesn't list every subject in the school.
   *
   * Pass classId to narrow further to the subjects the teacher teaches in
   * that specific class (used by the per-class Generate Rekomendasi sheet).
   */
  async listForTeacher(
    teacherId: string,
    scope?: 'teaching',
    classId?: string,
  ): Promise<Subject[]> {
    const params: Record<string, string> = {};
    if (scope) params.scope = scope;
    if (classId) params.class_id = classId;
    const res = await api.get(`/teacher/${teacherId}/subjects`, {
      params: Object.keys(params).length > 0 ? params : undefined,
    });
    const body = res.data as unknown;
    const arr = Array.isArray(body)
      ? body
      : Array.isArray((body as Record<string, unknown>)?.data)
        ? ((body as Record<string, unknown>).data as unknown[])
        : [];
    return arr.map((r) => subjectFromJson(r as Record<string, unknown>));
  },

  async create(payload: Record<string, unknown>): Promise<Subject> {
    const res = await api.post('/subject', payload);
    const body = res.data as Record<string, unknown>;
    return subjectFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async update(id: string, payload: Record<string, unknown>): Promise<Subject> {
    const res = await api.put(`/subject/${id}`, payload);
    const body = res.data as Record<string, unknown>;
    return subjectFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/subject/${id}`);
  },

  /**
   * Apply the same partial update to N subjects. Loops per-id via PUT
   * (no bulk-update endpoint). Bulk-safe payloads: `{ kkm }` for a
   * school-wide passing-score change, or `{ status, is_active }` for
   * bulk activate/deactivate. Send both status keys together because
   * the edit-sheet does (belt-and-suspenders vs a backend that has
   * historically accepted either).
   */
  async bulkUpdate(
    ids: string[],
    payload: Record<string, unknown>,
  ): Promise<{ updated: number; failed: number }> {
    let updated = 0;
    let failed = 0;
    for (const id of ids) {
      try {
        await api.put(`/subject/${id}`, payload);
        updated++;
      } catch {
        failed++;
      }
    }
    return { updated, failed };
  },

  /** Sequential per-id bulk delete (no /subject/bulk-delete endpoint). */
  async bulkRemove(ids: string[]): Promise<{ deleted: number; failed: number }> {
    let deleted = 0;
    let failed = 0;
    for (const id of ids) {
      try {
        await api.delete(`/subject/${id}`);
        deleted++;
      } catch {
        failed++;
      }
    }
    return { deleted, failed };
  },

  async get(id: string): Promise<Subject | null> {
    try {
      const res = await api.get(`/subject/${id}`);
      const body = res.data?.data ?? res.data ?? null;
      if (!body) return null;
      return subjectFromJson(body as Record<string, unknown>);
    } catch {
      return null;
    }
  },

  async getFilterOptions(): Promise<SubjectFilterOptions> {
    try {
      const res = await api.get('/subject/filter-options');
      const body = res.data?.data ?? res.data ?? {};
      return {
        statuses: Array.isArray(body.statuses) ? body.statuses : [
          { key: 'active', label: 'Aktif' },
          { key: 'inactive', label: 'Nonaktif' },
        ],
        grade_levels: Array.isArray(body.grade_levels) ? body.grade_levels.map(String) : [],
      };
    } catch {
      return {
        statuses: [
          { key: 'active', label: 'Aktif' },
          { key: 'inactive', label: 'Nonaktif' },
        ],
        grade_levels: [],
      };
    }
  },

  /** GET /master-subjects — autocomplete source for the edit sheet. */
  async listMasterSubjects(search?: string): Promise<MasterSubject[]> {
    try {
      const res = await api.get('/master-subjects', {
        params: search ? { search } : {},
      });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map((m: any) => ({
        id: String(m.id),
        name: String(m.name ?? m.nama ?? ''),
        code: m.code ?? null,
        // Backend returns the raw `grade` column on the master table
        // (varchar; "7", "10-12", or null). Keep both keys for backwards
        // compat with call sites that already reach for `grade_level`.
        grade: m.grade ?? null,
        grade_level: m.grade_level ?? m.grade ?? null,
      }));
    } catch {
      return [];
    }
  },

  /** GET /class-by-mata-pelajaran?subject_id=… — list classes attached to a subject. */
  async getAttachedClasses(
    subjectId: string,
  ): Promise<Array<{ id: string; name: string; grade_level?: string | null; homeroom_teacher_name?: string | null; student_count?: number }>> {
    try {
      const res = await api.get('/class-by-mata-pelajaran', {
        params: { subject_id: subjectId },
      });
      const body = res.data?.data ?? res.data ?? [];
      return (Array.isArray(body) ? body : []).map((c: any) => ({
        id: String(c.id),
        name: String(c.name ?? c.nama ?? ''),
        grade_level: c.grade_level ?? null,
        homeroom_teacher_name:
          c.homeroom_teacher_name ?? c.wali_kelas_nama ?? null,
        student_count: c.student_count ?? c.jumlah_siswa ?? 0,
      }));
    } catch {
      return [];
    }
  },

  /** POST /subject-class — attach a single (subject, class) pivot. */
  async attachClass(subjectId: string, classId: string): Promise<void> {
    await api.post('/subject-class', {
      subject_id: subjectId,
      class_id: classId,
    });
  },

  /** DELETE /subject-class — detach a single (subject, class) pivot. */
  async detachClass(subjectId: string, classId: string): Promise<void> {
    await api.delete('/subject-class', {
      data: { subject_id: subjectId, class_id: classId },
    });
  },

  /** POST /subject/{id}/classes/bulk-attach — multi-attach. */
  async bulkAttach(
    subjectId: string,
    classIds: string[],
  ): Promise<{ attached: number; failed: number }> {
    try {
      const res = await api.post(`/subject/${subjectId}/classes/bulk-attach`, {
        class_ids: classIds,
      });
      const body = res.data ?? {};
      return {
        attached: Number(body.attached ?? body.created ?? classIds.length),
        failed: Number(body.failed ?? body.skipped ?? 0),
      };
    } catch (e) {
      // Fallback to per-id attach if bulk endpoint 404s.
      let attached = 0; let failed = 0;
      for (const classId of classIds) {
        try { await this.attachClass(subjectId, classId); attached++; }
        catch { failed++; }
      }
      if (attached === 0 && failed === classIds.length) {
        throw new Error((e as Error).message);
      }
      return { attached, failed };
    }
  },

  /** POST /subject/{id}/classes/bulk-detach — multi-detach. */
  async bulkDetach(
    subjectId: string,
    classIds: string[],
  ): Promise<{ detached: number; failed: number }> {
    try {
      const res = await api.post(`/subject/${subjectId}/classes/bulk-detach`, {
        class_ids: classIds,
      });
      const body = res.data ?? {};
      return {
        detached: Number(body.detached ?? body.deleted ?? classIds.length),
        failed: Number(body.failed ?? body.skipped ?? 0),
      };
    } catch (e) {
      let detached = 0; let failed = 0;
      for (const classId of classIds) {
        try { await this.detachClass(subjectId, classId); detached++; }
        catch { failed++; }
      }
      if (detached === 0 && failed === classIds.length) {
        throw new Error((e as Error).message);
      }
      return { detached, failed };
    }
  },
};
