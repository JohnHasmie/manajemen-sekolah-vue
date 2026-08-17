/**
 * Tutoring2 · Students service — thin wrapper around the greenfield
 * BE-18 endpoints under `/api/tutoring-v2/students*`.
 *
 * Split out of the monolithic `tutoring-bimbel.service.ts` on WEB-11
 * because the admin students spine grew a full CRUD sheet + create
 * response envelope that carries `guardian_temp_password` alongside
 * `data` — a distinct shape from every other bimbel endpoint. Keeping
 * it in its own module (`services/tutoring2/students.ts`) also
 * anchors the `services/tutoring2/*` folder convention new tutoring2
 * features (packages, enrollments, …) will move into.
 *
 * All requests carry `X-Tenant-ID` implicitly via the shared http
 * layer (`@/lib/http`) — no explicit school_id juggling here.
 */
import { api } from '@/lib/http';
import type { Pagination } from '@/types/api';
import type { StudentProgress } from '@/types/tutoring2/progress';
import type {
  StudentAttendanceParams,
  StudentAttendanceResult,
  StudentAttendanceRow,
  StudentAttendanceSummary,
} from '@/types/tutoring2/attendance';
import type {
  BimbelStudent,
  BimbelStudentCreatePayload,
  BimbelStudentCreateResponse,
  BimbelStudentListParams,
  BimbelStudentUpdatePayload,
} from '@/types/tutoring2/student';

interface ListEnvelope<T> {
  data: T[];
  meta?: Pagination;
}

interface OneEnvelope<T> {
  data: T;
}

/**
 * Result of `listStudents` — pagination is optional because the BE
 * omits `meta` when the resource collection was constructed off a
 * non-paginated builder. Kept `Pagination | undefined` so the FE
 * doesn't have to invent a zeroed envelope.
 */
export interface BimbelStudentListResult {
  items: BimbelStudent[];
  pagination?: Pagination;
}

export const TutoringStudentsService = {
  async list(params: BimbelStudentListParams = {}): Promise<BimbelStudentListResult> {
    const r = await api.get<ListEnvelope<BimbelStudent>>(
      '/tutoring-v2/students',
      { params },
    );
    return { items: r.data.data, pagination: r.data.meta };
  },

  async get(id: string): Promise<BimbelStudent> {
    const r = await api.get<OneEnvelope<BimbelStudent>>(`/tutoring-v2/students/${id}`);
    return r.data.data;
  },

  /**
   * Create — returns BOTH the new student + a one-time
   * `guardian_temp_password` (null when the wali user already existed,
   * or when Opsi B account-activation mode is on for the tenant, in
   * which case an activation email is dispatched instead).
   */
  async create(
    payload: BimbelStudentCreatePayload,
  ): Promise<BimbelStudentCreateResponse> {
    const r = await api.post<BimbelStudentCreateResponse>(
      '/tutoring-v2/students',
      payload,
    );
    return r.data;
  },

  async update(
    id: string,
    payload: BimbelStudentUpdatePayload,
  ): Promise<BimbelStudent> {
    const r = await api.put<OneEnvelope<BimbelStudent>>(
      `/tutoring-v2/students/${id}`,
      payload,
    );
    return r.data.data;
  },

  /**
   * `GET /tutoring-v2/students/{id}/progress` — one child's graded-score
   * history plus the per-programme peer baseline, in a single call.
   *
   * Replaced a client-side rebuild that fetched enrollments, then every
   * assessment, then ONE scores call PER ASSESSMENT — capped at 40 to
   * stop it running away. The server answers in two queries and applies
   * the publish gate, so an unfinished mark can never reach a wali.
   *
   * `program_id` filters server-side, but callers that already hold the
   * full payload should filter in memory instead of refetching — the
   * response carries every programme the child is enrolled in.
   */
  async getProgress(
    studentId: string,
    params: { program_id?: string } = {},
  ): Promise<StudentProgress> {
    const r = await api.get<OneEnvelope<StudentProgress>>(
      `/tutoring-v2/students/${studentId}/progress`,
      { params },
    );
    return r.data.data;
  },

  /**
   * `GET /tutoring-v2/students/{id}/attendance` — one child's attendance
   * history plus a summary computed over the WHOLE range server-side.
   *
   * The wali "Kehadiran" screen used to fetch the last 100 SESSIONS and
   * present them as attendance: it showed the ten most recent sessions
   * as rows and counted `status === 'done'` as present, `'cancelled'`
   * as excused. Those are facts about the centre's timetable, not about
   * the child — a session the child missed still counts as "done", and
   * a cancelled session is not an "izin" anyone applied for.
   *
   * Take the summary from the response rather than tallying `rows`:
   * rows are paginated, so a client-side tally reports one page's
   * attendance as the whole term's.
   */
  async getAttendance(
    studentId: string,
    params: StudentAttendanceParams = {},
  ): Promise<StudentAttendanceResult> {
    const r = await api.get<{
      data: StudentAttendanceRow[];
      summary: StudentAttendanceSummary;
      meta: StudentAttendanceResult['meta'];
    }>(`/tutoring-v2/students/${studentId}/attendance`, { params });
    return { rows: r.data.data, summary: r.data.summary, meta: r.data.meta };
  },

  /**
   * Soft-deactivate — sets `student_status='lulus'` on the BE
   * (see `DeactivateStudentAction`). Not a hard delete: the row still
   * exists and shows in the "inactive" filter. Reversible by an
   * update that clears student_status.
   */
  async deactivate(id: string): Promise<BimbelStudent> {
    const r = await api.post<OneEnvelope<BimbelStudent>>(
      `/tutoring-v2/students/${id}/deactivate`,
      {},
    );
    return r.data.data;
  },
};
