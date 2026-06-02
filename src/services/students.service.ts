/**
 * StudentService — `/api/students` wrapper.
 * Mirrors `lib/features/students/data/student_service.dart`.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import { studentFromJson, type Student } from '@/types/entities';

export interface StudentListParams {
  page?: number;
  per_page?: number;
  search?: string;
  status?: string | null;
  class_ids?: string[];
  gender?: string | null;
  guardian?: string | null;
}

interface ListResult {
  items: Student[];
  pagination?: Pagination;
}

function unwrap(body: unknown): { data: unknown[]; pagination?: Pagination } {
  if (body && typeof body === 'object') {
    const b = body as Record<string, unknown>;
    const data = Array.isArray(b.data) ? b.data : [];
    const pagination = b.pagination as Pagination | undefined;
    return { data, pagination };
  }
  return { data: [] };
}

export const StudentService = {
  async list(params: StudentListParams = {}): Promise<ListResult> {
    // Backend StudentController previously only validated `class_id`
    // (singular UUID) and silently ignored `class_ids` plural — so
    // picking "7A" in the filter chip never applied. Send singular
    // when exactly one class is selected (the common case via the
    // chip), plural comma-list when 2+ are picked via the modal.
    // Backend now accepts both shapes.
    const classFilter: Record<string, string> = {};
    if (params.class_ids && params.class_ids.length === 1) {
      classFilter.class_id = params.class_ids[0];
    } else if (params.class_ids && params.class_ids.length > 1) {
      classFilter.class_ids = params.class_ids.join(',');
    }
    const res = await api.get('/student', {
      params: {
        page: params.page ?? 1,
        per_page: params.per_page ?? 10,
        ...(params.search ? { search: params.search } : {}),
        ...(params.status ? { status: params.status } : {}),
        ...classFilter,
        ...(params.gender ? { gender: params.gender } : {}),
        ...(params.guardian ? { guardian: params.guardian } : {}),
      },
    });
    const { data, pagination } = unwrap(res.data);
    return {
      items: data.map((row) => studentFromJson(row as Record<string, unknown>)),
      pagination,
    };
  },

  /**
   * Fetch a single student with full eager-loaded relations
   * (`student_classes.class`, guardian, etc.). Mirrors Flutter's
   * `getStudentById`.
   */
  async get(id: string): Promise<Student | null> {
    try {
      const res = await api.get(`/student/${id}`);
      const body = res.data as Record<string, unknown>;
      return studentFromJson((body.data ?? body) as Record<string, unknown>);
    } catch {
      return null;
    }
  },

  async create(payload: Record<string, unknown>): Promise<Student> {
    const res = await api.post('/student', payload);
    const body = res.data as Record<string, unknown>;
    return studentFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async update(id: string, payload: Record<string, unknown>): Promise<Student> {
    const res = await api.put(`/student/${id}`, payload);
    const body = res.data as Record<string, unknown>;
    return studentFromJson((body.data ?? body) as Record<string, unknown>);
  },

  async remove(id: string): Promise<void> {
    await api.delete(`/student/${id}`);
  },

  /**
   * Sequentially delete N students. Backend does NOT expose
   * `POST /student/bulk-delete` — that path 404s. Flutter loops per id
   * via DELETE /student/{id}, so we mirror that. Returns the number
   * actually deleted (failures are swallowed so the caller can show a
   * single summary toast).
   */
  async bulkRemove(ids: string[]): Promise<{ deleted: number; failed: number }> {
    let deleted = 0;
    let failed = 0;
    for (const id of ids) {
      try {
        await api.delete(`/student/${id}`);
        deleted++;
      } catch {
        failed++;
      }
    }
    return { deleted, failed };
  },

  /**
   * Fetch the roster for one class.
   *
   * Hits `/student/class/{classId}` — the canonical Flutter endpoint
   * (`ApiStudentService.getStudentByClass`). Returns the parsed
   * Student[] list ordered by what the backend serves (usually by
   * `student_number` ascending). Returns `[]` on any error.
   */
  async byClass(
    classId: string,
    opts: { academic_year_id?: string } = {},
  ): Promise<Student[]> {
    if (!classId) return [];
    try {
      const res = await api.get(`/student/class/${classId}`, {
        params: {
          ...(opts.academic_year_id
            ? { academic_year_id: opts.academic_year_id }
            : {}),
        },
      });
      const body = res.data;
      const list = Array.isArray(body?.data)
        ? body.data
        : Array.isArray(body)
          ? body
          : [];

      /**
       * Re-resolve `student_class_id` to the pivot row that matches
       * `classId` we just queried. The backend sometimes returns the
       * full `student_classes[]` for the student (e.g. last year's
       * enrolment in 8A + this year's enrolment in 7A); picking the
       * first one indiscriminately leads to a 422 on POST /grades
       * with "Mata pelajaran tidak tersedia untuk kelas siswa".
       */
      function resolveScopedClassId(raw: Record<string, unknown>): string | null {
        const list =
          (raw.student_classes as Record<string, unknown>[] | undefined) ??
          (raw.siswa_kelas as Record<string, unknown>[] | undefined) ??
          [];
        for (const row of list) {
          const nestedClass = row.class as Record<string, unknown> | undefined;
          const rowClassId = String(
            row.class_id ?? row.kelas_id ?? nestedClass?.id ?? '',
          );
          if (rowClassId === classId) {
            const id = row.id ?? row.student_class_id;
            if (id) return String(id);
          }
        }
        return null;
      }

      return list.map((row) => {
        const r = row as Record<string, unknown>;
        const student = studentFromJson(r);
        // Override student_class_id with the entry scoped to the
        // class we're querying; falls back to whatever
        // studentFromJson picked when no scoped match exists.
        const scoped = resolveScopedClassId(r);
        if (scoped) student.student_class_id = scoped;
        return student;
      });
    } catch {
      return [];
    }
  },
};
