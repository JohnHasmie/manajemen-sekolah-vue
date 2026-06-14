/**
 * GradeRecapService — `/api/grade-recaps` + `/api/grades/admin-recap-overview`
 * wrapper. Mirrors Flutter's `ApiGradeRecapService` plus the admin
 * overview branch from `GradeController`.
 *
 * Endpoint matrix:
 *   GET  /grade-recaps?class_id&subject_id&academic_year_id     → matrix rows
 *   GET  /grade-recaps/teacher-summary?teacher_id&view&...      → overview cards
 *   POST /grade-recaps                                          → save one row
 *   POST /grade-recaps/batch  body: { recaps: [...] }           → save many
 *   POST /grade-recaps/export body: { tableData, chapters, ...} → xlsx blob
 *   GET  /grades/admin-recap-overview?academic_year_id          → admin dashboard
 *
 * `academic_year_id` is auto-injected by the axios interceptor for
 * GET requests, but POST/batch payloads carry it explicitly because
 * the backend validates it as a body field.
 */
import { api } from '@/lib/http';
import {
  adminRecapOverviewFromJson,
  gradeRecapRowFromJson,
  teacherGradeRecapResponseFromJson,
  type AdminRecapOverviewResponse,
  type GradeRecapBatchResponse,
  type GradeRecapRow,
  type GradeRecapSavePayload,
  type TeacherGradeRecapResponse,
} from '@/types/grade-recap';

export const GradeRecapService = {
  /**
   * Fetch the recap matrix for one (class, subject, year). Returns
   * ALL students in the class — students without a recap row come
   * back with `has_recap=false` and null score fields so the matrix
   * can render empty editable cells without a second roster fetch.
   */
  async listMatrix(params: {
    class_id: string;
    subject_id: string;
    academic_year_id: number;
  }): Promise<GradeRecapRow[]> {
    const res = await api.get('/grade-recaps', {
      params: {
        class_id: params.class_id,
        subject_id: params.subject_id,
        academic_year_id: params.academic_year_id,
      },
    });
    const body = res.data as { data?: unknown[] } | unknown[];
    const arr = Array.isArray(body)
      ? body
      : Array.isArray((body as { data?: unknown[] })?.data)
        ? (body as { data: unknown[] }).data
        : [];
    return arr.map((r) => gradeRecapRowFromJson(r as Record<string, unknown>));
  },

  /**
   * Per-(class, subject) cards for the teacher overview page. View
   * defaults to "mengajar"; "wali_kelas" returns the homeroom
   * teacher's full subject roster (with the responsible teacher's
   * name attached to each row).
   */
  async getTeacherSummary(args: {
    teacher_id: string;
    view?: 'teaching' | 'homeroom_teacher';
    academic_year_id?: number | string;
    class_id?: string;
    subject_id?: string;
  }): Promise<TeacherGradeRecapResponse> {
    const res = await api.get('/grade-recaps/teacher-summary', {
      params: {
        teacher_id: args.teacher_id,
        view: args.view ?? 'teaching',
        ...(args.academic_year_id
          ? { academic_year_id: args.academic_year_id }
          : {}),
        ...(args.class_id ? { class_id: args.class_id } : {}),
        ...(args.subject_id ? { subject_id: args.subject_id } : {}),
      },
    });
    return teacherGradeRecapResponseFromJson(
      (res.data ?? {}) as Record<string, unknown>,
    );
  },

  /**
   * Save a single student's recap row. The full payload is required
   * even on partial edits — backend does upsert on (student_class_id,
   * subject_id, academic_year_id). Use `saveBatch` for the matrix
   * "Save all changes" action instead.
   */
  async save(payload: GradeRecapSavePayload): Promise<unknown> {
    const res = await api.post('/grade-recaps', payload);
    return res.data;
  },

  /**
   * Bulk-save N student recap rows in a single round trip. Backend
   * runs one INSERT … ON CONFLICT DO UPDATE; safe to call with up
   * to a full class roster (~40 rows).
   */
  async saveBatch(
    recaps: GradeRecapSavePayload[],
  ): Promise<GradeRecapBatchResponse> {
    const res = await api.post('/grade-recaps/batch', { recaps });
    return res.data as GradeRecapBatchResponse;
  },

  /**
   * Trigger the Excel export. Backend (`Maatwebsite\Excel`) streams
   * an `.xlsx` blob keyed to the current class/subject + today's
   * date — caller is responsible for converting the blob into a
   * downloadable file via `URL.createObjectURL`.
   */
  async exportExcel(params: {
    tableData: GradeRecapRow[];
    chapters: string[];
    className: string;
    subjectName: string;
  }): Promise<Blob> {
    const res = await api.post(
      '/grade-recaps/export',
      {
        tableData: params.tableData,
        chapters: params.chapters,
        className: params.className,
        subjectName: params.subjectName,
      },
      { responseType: 'blob' },
    );
    return res.data as Blob;
  },

  /**
   * Admin school-wide recap dashboard. One row per (class, subject)
   * slice with completeness stats + the most-recent assessment's
   * teacher resolved as a representative. Used by `AdminGradeRecap
   * View` for the read-only monitoring grid.
   */
  async getAdminOverview(params: {
    academic_year_id?: number | string;
  } = {}): Promise<AdminRecapOverviewResponse> {
    const res = await api.get('/grades/admin-recap-overview', {
      params: {
        ...(params.academic_year_id
          ? { academic_year_id: params.academic_year_id }
          : {}),
      },
    });
    return adminRecapOverviewFromJson(
      (res.data ?? {}) as Record<string, unknown>,
    );
  },
};
