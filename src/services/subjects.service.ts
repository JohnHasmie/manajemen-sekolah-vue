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

/**
 * Match returned by GET /subjects/check-existing — one row per existing
 * `subject_schools` row that shares the queried name in this school.
 * Grade is nullable: `null` means the existing row is universal
 * (grade-agnostic like Olahraga / Seni Budaya).
 */
export interface ExistingSubjectMatch {
  id: string;
  name: string;
  code?: string | null;
  grade: number | null;
}

/**
 * Response of GET /subjects/check-existing?name=X — the smart-hint
 * warning source for the create-mapel form. `has_similar` is the
 * caller-friendly boolean; `existing_grades` lists which grades already
 * carry a row with this name so the UI can prompt "kalau memang
 * universal, biarkan kosong; kalau untuk kelas lain, pilih kelasnya".
 */
export interface CheckExistingResult {
  matches: ExistingSubjectMatch[];
  has_similar: boolean;
  existing_grades: number[];
}

export interface SubjectFilterOptions {
  statuses: { key: string; label: string }[];
  grade_levels: string[];
}

/**
 * One schedule slot still pointing at a subject the admin is trying to
 * delete. Surfaced in the "subject in use" guard dialog so the admin can
 * see WHICH classes/slots would lose their mapel before confirming.
 * Mirrors the backend `affected[]` entries (MR!516, max 20 rows).
 */
export interface AffectedSchedule {
  schedule_id: string;
  class_name: string;
  day_name: string;
  hour_number: number;
}

/**
 * Thrown by {@link SubjectService.remove} when the backend answers 409
 * `subject_in_use` — the mapel is referenced by ≥1 active teaching
 * schedule and the caller didn't pass `force`. Carries the impact
 * payload so the view can render the guard dialog and offer a
 * force-retry.
 */
export class SubjectInUseError extends Error {
  readonly usedBySchedules: number;
  readonly subject: { id: string; name: string } | null;
  readonly affected: AffectedSchedule[];
  constructor(
    usedBySchedules: number,
    subject: { id: string; name: string } | null,
    affected: AffectedSchedule[],
    message?: string,
  ) {
    super(message ?? 'subject_in_use');
    this.name = 'SubjectInUseError';
    this.usedBySchedules = usedBySchedules;
    this.subject = subject;
    this.affected = affected;
  }
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

  /**
   * DELETE /subject/{id} — soft-delete a mapel (recoverable from Data
   * Terhapus for 30 days).
   *
   * Delete guard (MR!516): if the mapel is still referenced by ≥1 active
   * teaching schedule, the backend answers 409 `subject_in_use` unless
   * `force` is set. We translate that into a typed {@link SubjectInUseError}
   * so the view can show the impact dialog + offer a force-retry. Pass
   * `{ force: true }` on the confirmed retry to send `?force=true` and
   * let the delete cascade (schedule slots keep their row but lose the
   * mapel reference — also recoverable).
   */
  async remove(id: string, opts: { force?: boolean } = {}): Promise<void> {
    try {
      await api.delete(
        `/subject/${id}`,
        opts.force ? { params: { force: true } } : undefined,
      );
    } catch (e) {
      const ax = e as {
        response?: { status?: number; data?: Record<string, unknown> };
      };
      const data = ax?.response?.data;
      if (ax?.response?.status === 409 && data?.error === 'subject_in_use') {
        const rawSubject = data.subject as Record<string, unknown> | undefined;
        const rawAffected = Array.isArray(data.affected)
          ? (data.affected as Record<string, unknown>[])
          : [];
        throw new SubjectInUseError(
          Number(data.used_by_schedules ?? rawAffected.length ?? 0),
          rawSubject
            ? {
                id: String(rawSubject.id ?? id),
                name: String(rawSubject.name ?? ''),
              }
            : null,
          rawAffected.map((a) => ({
            schedule_id: String(a.schedule_id ?? a.id ?? ''),
            class_name: String(a.class_name ?? ''),
            day_name: String(a.day_name ?? ''),
            hour_number: Number(a.hour_number ?? 0),
          })),
          typeof data.message === 'string' ? data.message : undefined,
        );
      }
      throw e;
    }
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

  /**
   * GET /subjects/check-existing?name=X — smart-hint lookup that powers
   * the "Sudah ada N mapel bernama X di sekolah ini" warning card.
   *
   * The backend endpoint (parallel MR) matches case-insensitively on
   * `subject_schools.name` within the current school. Returns matches +
   * a `has_similar` flag + the distinct grade values already occupied,
   * so the form can prompt the admin to either pick a specific grade or
   * confirm the universal (grade-agnostic) intent.
   *
   * Fail-safe: on any error (endpoint missing on older backend,
   * network hiccup, non-2xx) we return an empty "no matches" shape so
   * the caller degrades to the un-hinted flow instead of blowing up
   * the whole create form.
   */
  async checkExisting(params: { name: string }): Promise<CheckExistingResult> {
    const name = params.name.trim();
    if (!name) {
      return { matches: [], has_similar: false, existing_grades: [] };
    }
    try {
      const res = await api.get('/subjects/check-existing', {
        params: { name },
      });
      const body = res.data?.data ?? res.data ?? {};
      const rawMatches = Array.isArray(body.matches) ? body.matches : [];
      const matches: ExistingSubjectMatch[] = rawMatches.map((m: any) => {
        const rawGrade = m?.grade ?? null;
        let grade: number | null = null;
        if (rawGrade !== null && rawGrade !== undefined && rawGrade !== '') {
          const n = Number(rawGrade);
          if (Number.isFinite(n) && n >= 1 && n <= 12) grade = Math.floor(n);
        }
        return {
          id: String(m?.id ?? ''),
          name: String(m?.name ?? ''),
          code: m?.code ?? null,
          grade,
        };
      });
      const rawGrades = Array.isArray(body.existing_grades)
        ? body.existing_grades
        : [];
      const existing_grades = rawGrades
        .map((g: any) => Number(g))
        .filter((n: number) => Number.isFinite(n) && n >= 1 && n <= 12)
        .map((n: number) => Math.floor(n))
        .sort((a: number, b: number) => a - b);
      const has_similar = Boolean(body.has_similar ?? matches.length > 0);
      return { matches, has_similar, existing_grades };
    } catch {
      return { matches: [], has_similar: false, existing_grades: [] };
    }
  },

  /**
   * GET /subjects/{id}/link-status — read whether a subject_schools
   * row is linked to a master curriculum subject. Drives the
   * "Tautkan ke Master" banner on the LMS screens (Rekap Nilai,
   * Bab/Chapter). Return null if the endpoint fails so the caller
   * can silently hide the banner (fail-open on read).
   */
  async getLinkStatus(subjectId: string): Promise<{
    subject_school_id: string;
    name: string;
    code: string | null;
    subject_id: number | null;
    master_name: string | null;
    is_linked: boolean;
    suggested_master_id: number | null;
  } | null> {
    try {
      const res = await api.get(`/subjects/${subjectId}/link-status`);
      const data = res.data?.data ?? null;
      if (!data || typeof data !== 'object') return null;
      const d = data as Record<string, unknown>;
      return {
        subject_school_id: String(d.subject_school_id ?? subjectId),
        name: String(d.name ?? ''),
        code: (d.code as string | null) ?? null,
        subject_id: d.subject_id == null ? null : Number(d.subject_id),
        master_name: (d.master_name as string | null) ?? null,
        is_linked: Boolean(d.is_linked),
        suggested_master_id:
          d.suggested_master_id == null ? null : Number(d.suggested_master_id),
      };
    } catch {
      return null;
    }
  },

  /**
   * PATCH /subjects/{id}/link-master — bind a subject_schools row
   * to a master curriculum subject. Backend gate: school.subject.
   * manage. Throws on failure so the picker can surface an error
   * toast (link-status is idempotent, so an ignored error would
   * silently leave the banner up).
   */
  async linkToMaster(
    subjectId: string,
    masterSubjectId: number,
  ): Promise<void> {
    await api.patch(`/subjects/${subjectId}/link-master`, {
      master_subject_id: masterSubjectId,
    });
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
